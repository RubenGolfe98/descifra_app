import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'logging_http_client.dart';

/// Servicio que descarga los tags de WordPress y los cachea de forma persistente.
/// Se descarga una sola vez y se reutiliza entre sesiones.
class TagService {
  static const _storageKeyNames = 'dlg_tags_map';
  static const _storageKeyIds = 'dlg_tags_ids';
  static const _baseUrl = 'https://www.descifrandolaguerra.es/wp-json/wp/v2';
  static final _storage = FlutterSecureStorage();

  /// Mapa slug → nombre bonito (ej: "espana" → "España")
  static Map<String, String> _tagsMap = {};

  /// Mapa slug → id de WordPress (ej: "espana" → 149)
  static Map<String, int> _tagsIds = {};
  static bool _loaded = false;

  /// Devuelve el nombre bonito de un tag-slug del class_list.
  static String? getTagName(String classListEntry) {
    if (!classListEntry.startsWith('tag-')) return null;
    final slug = classListEntry.substring(4);
    return _tagsMap[slug];
  }

  /// Devuelve el ID de WordPress de un tag por slug.
  /// Evita la petición extra a la API.
  static int? getTagId(String slug) => _tagsIds[slug];

  /// Extrae los nombres de tags de un class_list.
  static List<String> getTagNames(List<String> classList) {
    final tags = <String>[];
    for (final entry in classList) {
      final name = getTagName(entry);
      if (name != null) tags.add(name);
    }
    return tags;
  }

  /// Inicializa el servicio — carga desde caché local o descarga si no existe.
  static Future<void> initialize({http.Client? client}) async {
    if (_loaded) return;

    try {
      final cachedNames = await _storage.read(key: _storageKeyNames);
      final cachedIds = await _storage.read(key: _storageKeyIds);
      if (cachedNames != null && cachedIds != null) {
        _tagsMap = Map<String, String>.from(jsonDecode(cachedNames));
        _tagsIds = Map<String, int>.from((jsonDecode(cachedIds) as Map)
            .map((k, v) => MapEntry(k as String, v as int)));
        _loaded = true;
        if (kDebugMode) {
          debugPrint('🏷️ [Tags] ${_tagsMap.length} tags desde caché');
        }
        return;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('🏷️ [Tags] Error leyendo caché: $e');
    }

    await _fetchAndCache(client ?? LoggingHttpClient());
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
        await _storage.write(key: _storageKeyNames, value: jsonEncode(names));
        await _storage.write(key: _storageKeyIds, value: jsonEncode(ids));
        if (kDebugMode) {
          debugPrint('🏷️ [Tags] ${names.length} tags descargados y cacheados');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('🏷️ [Tags] Error descargando tags: $e');
    }
  }

  /// Fuerza una actualización desde el servidor.
  static Future<void> refresh({http.Client? client}) async {
    _loaded = false;
    _tagsMap.clear();
    _tagsIds.clear();
    await _fetchAndCache(client ?? LoggingHttpClient());
  }
}
