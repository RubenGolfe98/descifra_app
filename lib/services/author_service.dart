import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'logging_http_client.dart';

class AuthorService {
  static const _prefsKey = 'dlg_authors_map';
  static const _prefsKeyTimestamp = 'dlg_authors_ts';
  static const _ttlDays = 7;
  static const _baseUrl = 'https://www.descifrandolaguerra.es/wp-json/wp/v2';

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
          _silentRefresh(client ?? LoggingHttpClient());
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

  static Future<void> _silentRefresh(http.Client client) async {
    try {
      if (kDebugMode) debugPrint('👤 [Authors] Refrescando en segundo plano...');
      final map = <String, int>{};
      int page = 1;
      bool hasMore = true;

      while (hasMore) {
        final uri = Uri.parse('$_baseUrl/users').replace(queryParameters: {
          'per_page': '100',
          'page': page.toString(),
          '_fields': 'id,name',
        });

        final response =
            await client.get(uri).timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) break;

        final List<dynamic> data = jsonDecode(response.body);
        for (final author in data) {
          map[author['name'] as String] = author['id'] as int;
        }

        hasMore = data.length == 100;
        page++;
      }

      if (map.isNotEmpty) {
        _authorsMap = map;
        await _persist(map);
        if (kDebugMode) {
          debugPrint('👤 [Authors] ${map.length} autores actualizados en segundo plano');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('👤 [Authors] Error en refresh silencioso: $e');
    }
  }

  static Future<void> _fetchAndCache(http.Client client) async {
    try {
      final map = <String, int>{};
      int page = 1;
      bool hasMore = true;

      while (hasMore) {
        final uri = Uri.parse('$_baseUrl/users').replace(queryParameters: {
          'per_page': '100',
          'page': page.toString(),
          '_fields': 'id,name',
        });

        final response =
            await client.get(uri).timeout(const Duration(seconds: 35));
        if (response.statusCode != 200) break;

        final List<dynamic> data = jsonDecode(response.body);
        for (final author in data) {
          map[author['name'] as String] = author['id'] as int;
        }

        hasMore = data.length == 100;
        page++;
      }

      if (map.isNotEmpty) {
        _authorsMap = map;
        _loaded = true;
        await _persist(map);
        if (kDebugMode) {
          debugPrint('👤 [Authors] ${map.length} autores descargados y cacheados');
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
      await prefs.setInt(_prefsKeyTimestamp, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      if (kDebugMode) debugPrint('👤 [Authors] Error persistiendo caché: $e');
    }
  }

  static Future<void> refresh({http.Client? client}) async {
    _loaded = false;
    _authorsMap.clear();
    await _fetchAndCache(client ?? LoggingHttpClient());
  }
}
