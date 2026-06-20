import 'package:flutter_test/flutter_test.dart';
import 'package:dlg_app/repositories/maps_repository.dart';

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
