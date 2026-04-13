import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/map_image.dart';

class MapsRepository {
  static const _pageId = '2620';
  static const _baseUrl = 'https://www.descifrandolaguerra.es/wp-json/wp/v2';

  // Mapeo de slugs de región a títulos en el HTML de la página de mapas
  static const Map<String, String> _regionTitles = {
    'europa':                       'Europa',
    'asia-pacifico':                'Asia-Pacífico',
    'america':                      'América',
    'oriente-medio-y-norte-de-africa': 'Oriente Medio y Norte de África',
    'africa-subsahariana':          'África Subsahariana',
    'asia-central-meridional':      'Asia Central y Meridional',
  };

  Future<Map<String, List<MapImage>>> fetchAllMaps() async {
    try {
      final uri = Uri.parse('$_baseUrl/pages/$_pageId?_fields=content');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return {};
      final json = jsonDecode(response.body);
      final html = json['content']?['rendered'] as String? ?? '';
      return _parseHtml(html);
    } catch (e) {
      if (kDebugMode) debugPrint('🗺️ [Maps] Error: $e');
      return {};
    }
  }

  Future<List<MapImage>> fetchMapsForRegion(String regionSlug) async {
    final all = await fetchAllMaps();
    final title = _regionTitles[regionSlug];
    if (title == null) return [];

    // Búsqueda exacta primero
    if (all.containsKey(title)) return all[title]!;

    // Búsqueda parcial — por si el título está mezclado con otro texto
    final key = all.keys.firstWhere(
      (k) => k.contains(title),
      orElse: () => '',
    );
    return key.isNotEmpty ? all[key]! : [];
  }

  Map<String, List<MapImage>> _parseHtml(String html) {
    final result = <String, List<MapImage>>{};

    // Extraer todos los h2 y su posición
    final h2Regex = RegExp(
      r'elementor-heading-title[^>]*>(.*?)</h2>',
      dotAll: true,
    );

    final hrefRegex = RegExp(
      r'href="(https://www\.descifrandolaguerra\.es/wp-content/uploads/[^"]+\.(?:jpg|png|jpeg|webp))"',
    );
    final thumbRegex = RegExp(
      r'src="(https://www\.descifrandolaguerra\.es/wp-content/uploads/[^"]+\.(?:jpg|png|jpeg|webp))"',
    );
    final altRegex = RegExp(r'alt="([^"]{5,})"');

    final h2Matches = h2Regex.allMatches(html).toList();

    for (int i = 0; i < h2Matches.length; i++) {
      final rawTitle = h2Matches[i].group(1) ?? '';
      final title = rawTitle
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (title.isEmpty) continue;

      final effectiveTitle = title.contains('Europa') && title.length > 10
          ? 'Europa'
          : title;

      // El bloque va desde el fin de este h2 hasta el inicio del siguiente h2
      final blockStart = h2Matches[i].end;
      final blockEnd = i + 1 < h2Matches.length
          ? h2Matches[i + 1].start
          : html.length;
      final block = html.substring(blockStart, blockEnd);

      final hrefs = hrefRegex.allMatches(block).map((m) => m.group(1)!).toList();
      final thumbs = thumbRegex.allMatches(block).map((m) => m.group(1)!).toList();
      final alts = altRegex.allMatches(block).map((m) => m.group(1)!).toList();

      if (hrefs.isEmpty) continue;

      final maps = <MapImage>[];
      for (int j = 0; j < hrefs.length; j++) {
        final url = hrefs[j];
        // Buscar el thumb más pequeño (contiene dimensiones en el nombre)
        final thumb = thumbs.where((t) => t.contains('-300x') || t.contains('-268x'))
            .elementAtOrNull(j) ?? (j < thumbs.length ? thumbs[j] : url);
        final alt = j < alts.length ? alts[j] : '';
        maps.add(MapImage(url: url, thumbUrl: thumb, alt: alt));
      }

      if (maps.isNotEmpty) result[title] = maps;
    }

    return result;
  }
}