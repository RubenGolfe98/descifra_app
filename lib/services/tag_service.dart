import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'logging_http_client.dart';

class TagService {
  static const _prefsKeyNames = 'dlg_tags_map';
  static const _prefsKeyIds = 'dlg_tags_ids';
  static const _prefsKeyTimestamp = 'dlg_tags_ts';

  /// Los tags son nombres de países y temas: cambian muy de tanto en tanto,
  /// así que no compensa comprobarlos cada semana.
  static const _ttlDays = 30;
  static const _baseUrl = 'https://www.descifrandolaguerra.es/wp-json/wp/v2';

  /// Espera antes de volver a intentar un refresco que ha fallado. Evita que
  /// un fallo deje la caché marcada como obsoleta para siempre y se reintente
  /// en cada arranque.
  static const _retryAfterFailure = Duration(hours: 6);

  /// El endpoint de tags tarda entre 12 y 18 segundos por página de 100.
  /// Al ir por el pool de fondo no bloquea al usuario, así que se le da
  /// margen suficiente para completarse.
  static const _bgTimeout = Duration(seconds: 30);

  static Map<String, String> _tagsMap = {};
  static Map<String, int> _tagsIds = {};
  static bool _loaded = false;

  static String? getTagName(String classListEntry) {
    if (!classListEntry.startsWith('tag-')) return null;
    final slug = classListEntry.substring(4);
    return _tagsMap[slug];
  }

  static int? getTagId(String slug) => _tagsIds[slug];

  static List<String> getTagNames(List<String> classList) {
    final tags = <String>[];
    for (final entry in classList) {
      final name = getTagName(entry);
      if (name != null) tags.add(name);
    }
    return tags;
  }

  static Future<void> initialize({http.Client? client}) async {
    if (_loaded) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedNames = prefs.getString(_prefsKeyNames);
      final cachedIds = prefs.getString(_prefsKeyIds);
      if (cachedNames != null && cachedIds != null) {
        _tagsMap = Map<String, String>.from(jsonDecode(cachedNames));
        _tagsIds = Map<String, int>.from((jsonDecode(cachedIds) as Map)
            .map((k, v) => MapEntry(k as String, v as int)));
        _loaded = true;
        if (kDebugMode) {
          debugPrint('🏷️ [Tags] ${_tagsMap.length} tags desde caché');
        }

        final savedTs = prefs.getInt(_prefsKeyTimestamp);
        if (savedTs != null && _isStale(savedTs)) {
          await _silentRefresh(client ?? LoggingHttpClient());
        }
        return;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('🏷️ [Tags] Error leyendo caché: $e');
    }

    await _fetchAndCache(client ?? LoggingHttpClient());
  }

  static bool _isStale(int savedTs) {
    final age = DateTime.now().millisecondsSinceEpoch - savedTs;
    return age > _ttlDays * 24 * 60 * 60 * 1000;
  }

  static Uri _uri(int page, {int perPage = 100}) =>
      Uri.parse('$_baseUrl/tags').replace(queryParameters: {
        'per_page': perPage.toString(),
        'page': page.toString(),
        '_fields': 'id,slug,name',
      });

  /// Vuelca una página de resultados en los mapas indicados.
  static void _absorb(
      List<dynamic> data, Map<String, String> names, Map<String, int> ids) {
    for (final tag in data) {
      final slug = tag['slug'] as String;
      names[slug] = tag['name'] as String;
      ids[slug] = tag['id'] as int;
    }
  }

  /// Comprueba si el número de tags ha cambiado desde la última descarga.
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
        debugPrint('🏷️ [Tags] servidor: $total · local: ${_tagsMap.length}');
      }
      return total != _tagsMap.length;
    } catch (e) {
      if (kDebugMode) debugPrint('🏷️ [Tags] Error comprobando total: $e');
      return false;
    }
  }

  /// Refresco en segundo plano. Mantiene la caché si algo falla y retrasa el
  /// siguiente intento para no reintentar en cada arranque.
  static Future<void> _silentRefresh(http.Client client) async {
    try {
      if (kDebugMode) debugPrint('🏷️ [Tags] Comprobando novedades...');

      if (!await _hasChanged(client)) {
        if (kDebugMode) debugPrint('🏷️ [Tags] Sin cambios');
        // La caché sigue siendo válida: se reinicia el TTL completo.
        await _touchTimestamp(DateTime.now());
        return;
      }

      if (kDebugMode) debugPrint('🏷️ [Tags] Descargando cambios...');

      // Primera página: sirve para saber si hay más y para fallar pronto.
      final first = await client.get(_uri(1)).timeout(_bgTimeout);
      if (first.statusCode != 200) {
        await _delayNextAttempt();
        return;
      }

      final names = <String, String>{};
      final ids = <String, int>{};
      final firstData = jsonDecode(first.body) as List<dynamic>;
      _absorb(firstData, names, ids);

      // Si la primera página viene llena, el resto se piden a la vez en lugar
      // de encadenarse, que multiplicaba el tiempo total por el número de
      // páginas.
      if (firstData.length == 100) {
        final rest = await Future.wait([
          for (var page = 2; page <= 4; page++)
            client.get(_uri(page)).timeout(_bgTimeout),
        ]);
        for (final response in rest) {
          if (response.statusCode != 200) break;
          final data = jsonDecode(response.body) as List<dynamic>;
          if (data.isEmpty) break;
          _absorb(data, names, ids);
        }
      }

      if (names.isNotEmpty) {
        _tagsMap = names;
        _tagsIds = ids;
        await _persist(names, ids);
        if (kDebugMode) {
          debugPrint('🏷️ [Tags] ${names.length} tags actualizados');
        }
      } else {
        await _delayNextAttempt();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('🏷️ [Tags] Error en refresh silencioso: $e');
      await _delayNextAttempt();
    }
  }

  static Future<void> _fetchAndCache(http.Client client) async {
    try {
      final names = <String, String>{};
      final ids = <String, int>{};
      int page = 1;
      bool hasMore = true;

      while (hasMore) {
        final response =
            await client.get(_uri(page)).timeout(const Duration(seconds: 35));
        if (response.statusCode != 200) break;

        final List<dynamic> data = jsonDecode(response.body);
        _absorb(data, names, ids);

        hasMore = data.length == 100;
        page++;
      }

      if (names.isNotEmpty) {
        _tagsMap = names;
        _tagsIds = ids;
        _loaded = true;
        await _persist(names, ids);
        if (kDebugMode) {
          debugPrint('🏷️ [Tags] ${names.length} tags descargados y cacheados');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('🏷️ [Tags] Error descargando tags: $e');
    }
  }

  static Future<void> _persist(
      Map<String, String> names, Map<String, int> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKeyNames, jsonEncode(names));
      await prefs.setString(_prefsKeyIds, jsonEncode(ids));
      await prefs.setInt(
          _prefsKeyTimestamp, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      if (kDebugMode) debugPrint('🏷️ [Tags] Error persistiendo caché: $e');
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
          '🏷️ [Tags] Próximo intento en ${_retryAfterFailure.inHours}h');
    }
  }

  static Future<void> refresh({http.Client? client}) async {
    _loaded = false;
    _tagsMap.clear();
    _tagsIds.clear();
    await _fetchAndCache(client ?? LoggingHttpClient());
  }
}
