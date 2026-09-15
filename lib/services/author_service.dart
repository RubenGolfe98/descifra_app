import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'logging_http_client.dart';

class AuthorService {
  static const _prefsKey = 'dlg_authors_map';
  static const _prefsKeyTimestamp = 'dlg_authors_ts';

  /// Los autores cambian poco: no compensa comprobarlos cada semana.
  static const _ttlDays = 30;
  static const _baseUrl = 'https://www.descifrandolaguerra.es/wp-json/wp/v2';

  /// Espera antes de volver a intentar un refresco que ha fallado. Evita que
  /// un fallo deje la caché marcada como obsoleta para siempre y se reintente
  /// en cada arranque.
  static const _retryAfterFailure = Duration(hours: 6);

  /// El endpoint de usuarios tarda entre 12 y 18 segundos por página de 100.
  /// Al ir por el pool de fondo no bloquea al usuario, así que se le da
  /// margen suficiente para completarse.
  static const _bgTimeout = Duration(seconds: 30);

  static Map<String, int> _authorsMap = {};
  static bool _loaded = false;

  static int? getAuthorId(String name) => _authorsMap[name];

  static Future<void> initialize({http.Client? client}) async {
    if (_loaded) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_prefsKey);
      if (cached != null) {
        _authorsMap = Map<String, int>.from((jsonDecode(cached) as Map)
            .map((k, v) => MapEntry(k as String, v as int)));
        _loaded = true;
        if (kDebugMode) {
          debugPrint('👤 [Authors] ${_authorsMap.length} autores desde caché');
        }

        final savedTs = prefs.getInt(_prefsKeyTimestamp);
        if (savedTs != null && _isStale(savedTs)) {
          await _silentRefresh(client ?? LoggingHttpClient());
        }
        return;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('👤 [Authors] Error leyendo caché: $e');
    }

    await _fetchAndCache(client ?? LoggingHttpClient());
  }

  static bool _isStale(int savedTs) {
    final age = DateTime.now().millisecondsSinceEpoch - savedTs;
    return age > _ttlDays * 24 * 60 * 60 * 1000;
  }

  static Uri _uri(int page, {int perPage = 100}) =>
      Uri.parse('$_baseUrl/users').replace(queryParameters: {
        'per_page': perPage.toString(),
        'page': page.toString(),
        '_fields': 'id,name',
      });

  /// Vuelca una página de resultados en el mapa indicado.
  static void _absorb(List<dynamic> data, Map<String, int> map) {
    for (final author in data) {
      map[author['name'] as String] = author['id'] as int;
    }
  }

  /// Comprueba si el número de autores ha cambiado desde la última descarga.
  /// Una consulta de un solo elemento devuelve el total en la cabecera
  /// X-WP-Total, lo que evita varias peticiones lentas cuando no hay novedades.
  static Future<bool> _hasChanged(http.Client client) async {
    try {
      final response =
          await client.get(_uri(1, perPage: 1)).timeout(_bgTimeout);
      if (response.statusCode != 200) return false;

      final total = int.tryParse(response.headers['x-wp-total'] ?? '');
      // Sin la cabecera no se puede comparar: mejor descargar.
      if (total == null) return true;

      if (kDebugMode) {
        debugPrint(
            '👤 [Authors] servidor: $total · local: ${_authorsMap.length}');
      }
      return total != _authorsMap.length;
    } catch (e) {
      if (kDebugMode) debugPrint('👤 [Authors] Error comprobando total: $e');
      return false;
    }
  }

  /// Refresco en segundo plano. Mantiene la caché si algo falla y retrasa el
  /// siguiente intento para no reintentar en cada arranque.
  static Future<void> _silentRefresh(http.Client client) async {
    try {
      if (kDebugMode) debugPrint('👤 [Authors] Comprobando novedades...');

      if (!await _hasChanged(client)) {
        if (kDebugMode) debugPrint('👤 [Authors] Sin cambios');
        // La caché sigue siendo válida: se reinicia el TTL completo.
        await _touchTimestamp(DateTime.now());
        return;
      }

      if (kDebugMode) debugPrint('👤 [Authors] Descargando cambios...');

      // Primera página: sirve para saber si hay más y para fallar pronto.
      final first = await client.get(_uri(1)).timeout(_bgTimeout);
      if (first.statusCode != 200) {
        await _delayNextAttempt();
        return;
      }

      final map = <String, int>{};
      final firstData = jsonDecode(first.body) as List<dynamic>;
      _absorb(firstData, map);

      // Si la primera página viene llena, el resto se piden a la vez en lugar
      // de encadenarse, que multiplicaba el tiempo total por el número de
      // páginas.
      if (firstData.length == 100) {
        final rest = await Future.wait([
          for (var page = 2; page <= 3; page++)
            client.get(_uri(page)).timeout(_bgTimeout),
        ]);
        for (final response in rest) {
          if (response.statusCode != 200) break;
          final data = jsonDecode(response.body) as List<dynamic>;
          if (data.isEmpty) break;
          _absorb(data, map);
        }
      }

      if (map.isNotEmpty) {
        _authorsMap = map;
        await _persist(map);
        if (kDebugMode) {
          debugPrint('👤 [Authors] ${map.length} autores actualizados');
        }
      } else {
        await _delayNextAttempt();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('👤 [Authors] Error en refresh silencioso: $e');
      }
      await _delayNextAttempt();
    }
  }

  static Future<void> _fetchAndCache(http.Client client) async {
    try {
      final map = <String, int>{};
      int page = 1;
      bool hasMore = true;

      while (hasMore) {
        final response =
            await client.get(_uri(page)).timeout(const Duration(seconds: 35));
        if (response.statusCode != 200) break;

        final List<dynamic> data = jsonDecode(response.body);
        _absorb(data, map);

        hasMore = data.length == 100;
        page++;
      }

      if (map.isNotEmpty) {
        _authorsMap = map;
        _loaded = true;
        await _persist(map);
        if (kDebugMode) {
          debugPrint(
              '👤 [Authors] ${map.length} autores descargados y cacheados');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('👤 [Authors] Error descargando autores: $e');
    }
  }

  static Future<void> _persist(Map<String, int> map) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(map));
      await prefs.setInt(
          _prefsKeyTimestamp, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      if (kDebugMode) debugPrint('👤 [Authors] Error persistiendo caché: $e');
    }
  }

  /// Actualiza la marca de tiempo sin tocar los datos cacheados.
  static Future<void> _touchTimestamp(DateTime moment) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsKeyTimestamp, moment.millisecondsSinceEpoch);
    } catch (_) {}
  }

  /// Retrasa el próximo refresco sin invalidar los datos ya cacheados.
  static Future<void> _delayNextAttempt() async {
    await _touchTimestamp(
      DateTime.now()
          .subtract(const Duration(days: _ttlDays))
          .add(_retryAfterFailure),
    );
    if (kDebugMode) {
      debugPrint(
          '👤 [Authors] Próximo intento en ${_retryAfterFailure.inHours}h');
    }
  }

  static Future<void> refresh({http.Client? client}) async {
    _loaded = false;
    _authorsMap.clear();
    await _fetchAndCache(client ?? LoggingHttpClient());
  }
}
