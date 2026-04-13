import 'package:flutter_test/flutter_test.dart';
import 'package:dlg_app/models/map_image.dart';

void main() {
  group('MapImage', () {
    test('constructor sets all fields', () {
      const map = MapImage(
        url: 'https://example.com/map.jpg',
        thumbUrl: 'https://example.com/map-300x300.jpg',
        alt: 'Mapa de Europa',
      );
      expect(map.url, 'https://example.com/map.jpg');
      expect(map.thumbUrl, 'https://example.com/map-300x300.jpg');
      expect(map.alt, 'Mapa de Europa');
    });

    test('alt can be empty string', () {
      const map = MapImage(
        url: 'https://example.com/map.jpg',
        thumbUrl: 'https://example.com/map-300x300.jpg',
        alt: '',
      );
      expect(map.alt, '');
    });

    test('url and thumbUrl can be the same', () {
      const map = MapImage(
        url: 'https://example.com/map.jpg',
        thumbUrl: 'https://example.com/map.jpg',
        alt: '',
      );
      expect(map.url, map.thumbUrl);
    });
  });
}
