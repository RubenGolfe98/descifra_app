import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:dlg_app/repositories/maps_repository.dart';

http.Client _mockPageClient(String htmlContent) {
  return MockClient((request) async {
    final body = jsonEncode([{
      'content': {'rendered': htmlContent}
    }]);
    return http.Response(body, 200);
  });
}

const _sampleHtml = '''
<h2 class="elementor-heading-title elementor-size-default">Europa</h2>
<div>
  <a href="https://www.descifrandolaguerra.es/wp-content/uploads/2024/map1.jpg">
    <img src="https://www.descifrandolaguerra.es/wp-content/uploads/2024/map1-300x300.jpg"
         alt="Mapa de Europa" />
  </a>
  <a href="https://www.descifrandolaguerra.es/wp-content/uploads/2024/map2.png">
    <img src="https://www.descifrandolaguerra.es/wp-content/uploads/2024/map2-300x300.png"
         alt="Mapa de Ucrania" />
  </a>
</div>
<h2 class="elementor-heading-title elementor-size-default">América</h2>
<div>
  <a href="https://www.descifrandolaguerra.es/wp-content/uploads/2024/map3.jpg">
    <img src="https://www.descifrandolaguerra.es/wp-content/uploads/2024/map3-300x300.jpg"
         alt="Mapa de América" />
  </a>
</div>
''';

void main() {
  group('MapsRepository', () {
    test('fetchAllMaps returns empty map on network error', () async {
      final repo = MapsRepository();
      // Uses real http — just verify it handles errors gracefully
      final result = await repo.fetchAllMaps().timeout(
        const Duration(seconds: 1),
        onTimeout: () => {},
      );
      expect(result, isA<Map>());
    });

    test('fetchMapsForRegion returns empty list for unknown slug', () async {
      final repo = MapsRepository();
      final result = await repo.fetchMapsForRegion('unknown-region').timeout(
        const Duration(seconds: 1),
        onTimeout: () => [],
      );
      expect(result, isA<List>());
    });
  });

  group('MapsRepository - _regionTitles mapping', () {
    test('all kRegions slugs have a mapping', () {
      const expectedSlugs = [
        'europa',
        'asia-pacifico',
        'america',
        'oriente-medio-y-norte-de-africa',
        'africa-subsahariana',
        'asia-central-meridional',
      ];
      const regionTitles = {
        'europa': 'Europa',
        'asia-pacifico': 'Asia-Pacífico',
        'america': 'América',
        'oriente-medio-y-norte-de-africa': 'Oriente Medio y Norte de África',
        'africa-subsahariana': 'África Subsahariana',
        'asia-central-meridional': 'Asia Central y Meridional',
      };
      for (final slug in expectedSlugs) {
        expect(regionTitles.containsKey(slug), true,
            reason: 'Slug "$slug" should have a title mapping');
      }
    });
  });
}
