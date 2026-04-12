import 'package:flutter_test/flutter_test.dart';
import 'package:dlg_app/models/region.dart';

void main() {
  group('Region', () {
    test('constructor sets all fields', () {
      const region = Region(
        id: 101,
        name: 'Oriente Medio',
        slug: 'oriente-medio',
        count: 500,
        imageUrl: 'https://example.com/map.svg',
      );

      expect(region.id, 101);
      expect(region.name, 'Oriente Medio');
      expect(region.slug, 'oriente-medio');
      expect(region.count, 500);
      expect(region.imageUrl, 'https://example.com/map.svg');
    });
  });

  group('kRegions', () {
    test('contains 6 regions', () {
      expect(kRegions.length, 6);
    });

    test('all regions have non-empty fields', () {
      for (final region in kRegions) {
        expect(region.id, isPositive);
        expect(region.name, isNotEmpty);
        expect(region.slug, isNotEmpty);
        expect(region.count, isPositive);
        expect(region.imageUrl, isNotEmpty);
        expect(region.imageUrl, startsWith('https://'));
      }
    });

    test('all region IDs are unique', () {
      final ids = kRegions.map((r) => r.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('all region slugs are unique', () {
      final slugs = kRegions.map((r) => r.slug).toList();
      expect(slugs.toSet().length, slugs.length);
    });

    test('contains expected regions', () {
      final names = kRegions.map((r) => r.name).toList();
      expect(names, contains('Europa'));
      expect(names, contains('América'));
      expect(names, contains('África Subsahariana'));
    });

    test('image URLs point to descifrandolaguerra.es', () {
      for (final region in kRegions) {
        expect(region.imageUrl, contains('descifrandolaguerra.es'));
      }
    });
  });
}
