import 'package:flutter_test/flutter_test.dart';
import 'package:dlg_app/models/coverage.dart';

void main() {
  group('Coverage.fromJson', () {
    final json = {
      'id': 1,
      'slug': 'guerra-ucrania',
      'link': 'https://www.descifrandolaguerra.es/coberturas/guerra-ucrania/',
      'title': {'rendered': 'Guerra en Ucrania'},
      'yoast_head_json': {
        'description': 'Cobertura de la guerra',
        'og_image': [{'url': 'https://example.com/img.jpg'}],
      },
    };

    test('parsea campos básicos', () {
      final c = Coverage.fromJson(json);
      expect(c.id, 1);
      expect(c.slug, 'guerra-ucrania');
      expect(c.title, 'Guerra en Ucrania');
      expect(c.description, 'Cobertura de la guerra');
      expect(c.imageUrl, 'https://example.com/img.jpg');
    });

    test('strip HTML en título', () {
      final j = Map<String, dynamic>.from(json)
        ..['title'] = {'rendered': '<strong>Título</strong>'};
      expect(Coverage.fromJson(j).title, 'Título');
    });

    test('imageUrl vacía si no hay og_image', () {
      final j = Map<String, dynamic>.from(json)
        ..['yoast_head_json'] = {'description': 'desc'};
      expect(Coverage.fromJson(j).imageUrl, '');
    });

    test('imageUrl vacía si og_image es lista vacía', () {
      final j = Map<String, dynamic>.from(json)
        ..['yoast_head_json'] = {'og_image': []};
      expect(Coverage.fromJson(j).imageUrl, '');
    });
  });

  group('CoverageDetail.fromJson', () {
    final json = {
      'id': 2,
      'slug': 'guerra-ucrania',
      'link': 'https://example.com/',
      'title': {'rendered': 'Detalle'},
      'content': {'rendered': '<p>Contenido</p>'},
      'yoast_head_json': {
        'description': 'desc',
        'og_image': [{'url': 'https://example.com/img.jpg'}],
      },
    };

    test('parsea contentHtml', () {
      final d = CoverageDetail.fromJson(json);
      expect(d.contentHtml, '<p>Contenido</p>');
    });

    test('contentHtml vacío si no hay content', () {
      final j = Map<String, dynamic>.from(json)..remove('content');
      expect(CoverageDetail.fromJson(j).contentHtml, '');
    });
  });
}
