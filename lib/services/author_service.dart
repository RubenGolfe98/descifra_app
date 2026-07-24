import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'logging_http_client.dart';

class AuthorService {
  static const _storageKey = 'dlg_authors_map';
  static const _baseUrl = 'https://www.descifrandolaguerra.es/wp-json/wp/v2';
  static final _storage = FlutterSecureStorage();

  /// Mapa nombre → id (ej: "Albert Junyent Cebrián" → 2903)
  static Map<String, int> _authorsMap = {};
  static bool _loaded = false;

  /// Devuelve el ID de un autor por nombre. Instantáneo si está cacheado.
  static int? getAuthorId(String name) => _authorsMap[name];

  static Future<void> initialize({http.Client? client}) async {
    if (_loaded) return;

    try {
      final cached = await _storage.read(key: _storageKey);
      if (cached != null) {
        _authorsMap = Map<String, int>.from((jsonDecode(cached) as Map)
            .map((k, v) => MapEntry(k as String, v as int)));
        _loaded = true;
        return;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('👤 [Authors] Error leyendo caché: $e');
    }

    await _fetchAndCache(client ?? LoggingHttpClient());
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
        await _storage.write(key: _storageKey, value: jsonEncode(map));
      }
    } catch (e) {
      if (kDebugMode) debugPrint('👤 [Authors] Error descargando autores: $e');
    }
  }

  static Future<void> refresh({http.Client? client}) async {
    _loaded = false;
    _authorsMap.clear();
    await _fetchAndCache(client ?? LoggingHttpClient());
  }
}
