import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'logging_http_client.dart';

class TagService {
  static const _prefsKeyNames = 'dlg_tags_map';
  static const _prefsKeyIds = 'dlg_tags_ids';
  static const _prefsKeyTimestamp = 'dlg_tags_ts';
  static const _ttlDays = 7;
  static const _baseUrl = 'https://www.descifrandolaguerra.es/wp-json/wp/v2';

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
          _silentRefresh(client ?? LoggingHttpClient());
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

  static Future<void> _silentRefresh(http.Client client) async {
    try {
      if (kDebugMode) debugPrint('🏷️ [Tags] Refrescando en segundo plano...');
      final names = <String, String>{};
      final ids = <String, int>{};
      int page = 1;
      bool hasMore = true;

      while (hasMore) {
        final uri = Uri.parse('$_baseUrl/tags').replace(queryParameters: {
          'per_page': '100',
          'page': page.toString(),
          '_fields': 'id,slug,name',
        });

        final response =
            await client.get(uri).timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) break;

        final List<dynamic> data = jsonDecode(response.body);
        for (final tag in data) {
          final slug = tag['slug'] as String;
          names[slug] = tag['name'] as String;
          ids[slug] = tag['id'] as int;
        }

        hasMore = data.length == 100;
        page++;
      }

      if (names.isNotEmpty) {
        _tagsMap = names;
        _tagsIds = ids;
        await _persist(names, ids);
        if (kDebugMode) {
          debugPrint('🏷️ [Tags] ${names.length} tags actualizados en segundo plano');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('🏷️ [Tags] Error en refresh silencioso: $e');
    }
  }

  static Future<void> _fetchAndCache(http.Client client) async {
    try {
      final names = <String, String>{};
      final ids = <String, int>{};
      int page = 1;
      bool hasMore = true;

      while (hasMore) {
        final uri = Uri.parse('$_baseUrl/tags').replace(queryParameters: {
          'per_page': '100',
          'page': page.toString(),
          '_fields': 'id,slug,name',
        });

        final response =
            await client.get(uri).timeout(const Duration(seconds: 35));
        if (response.statusCode != 200) break;

        final List<dynamic> data = jsonDecode(response.body);
        for (final tag in data) {
          final slug = tag['slug'] as String;
          names[slug] = tag['name'] as String;
          ids[slug] = tag['id'] as int;
        }

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

  static Future<void> _persist(Map<String, String> names, Map<String, int> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKeyNames, jsonEncode(names));
      await prefs.setString(_prefsKeyIds, jsonEncode(ids));
      await prefs.setInt(_prefsKeyTimestamp, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      if (kDebugMode) debugPrint('🏷️ [Tags] Error persistiendo caché: $e');
    }
  }

  static Future<void> refresh({http.Client? client}) async {
    _loaded = false;
    _tagsMap.clear();
    _tagsIds.clear();
    await _fetchAndCache(client ?? LoggingHttpClient());
  }
}
