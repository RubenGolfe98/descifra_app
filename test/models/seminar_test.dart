import 'package:flutter_test/flutter_test.dart';
import 'package:dlg_app/models/seminar.dart';

void main() {
  group('Seminar.fromJson', () {
    final json = {
      'id': 10,
      'link': 'https://www.descifrandolaguerra.es/seminarios/ucrania/',
      'title': {'rendered': 'La guerra en Ucrania'},
      'class_list': ['post-10', 'seminario'],
      'yoast_head_json': {
        'og_description': 'Descripción del seminario',
        'og_image': [{'url': 'https://example.com/cover.jpg'}],
      },
    };

    test('parsea campos básicos', () {
      final s = Seminar.fromJson(json);
      expect(s.id, 10);
      expect(s.title, 'La guerra en Ucrania');
      expect(s.description, 'Descripción del seminario');
      expect(s.coverUrl, 'https://example.com/cover.jpg');
      expect(s.link, 'https://www.descifrandolaguerra.es/seminarios/ucrania/');
    });

    test('isPremium false por defecto', () {
      expect(Seminar.fromJson(json).isPremium, false);
    });

    test('isPremium true cuando class_list contiene rcp-is-restricted', () {
      final j = Map<String, dynamic>.from(json)
        ..['class_list'] = ['post-10', 'seminario', 'rcp-is-restricted'];
      expect(Seminar.fromJson(j).isPremium, true);
    });

    test('strip HTML en título', () {
      final j = Map<String, dynamic>.from(json)
        ..['title'] = {'rendered': '<em>Seminario</em>'};
      expect(Seminar.fromJson(j).title, 'Seminario');
    });

    test('coverUrl vacía si no hay og_image', () {
      final j = Map<String, dynamic>.from(json)
        ..['yoast_head_json'] = {'og_description': 'desc'};
      expect(Seminar.fromJson(j).coverUrl, '');
    });
  });

  group('SeminarSession', () {
    test('construye correctamente', () {
      const s = SeminarSession(title: 'Sesión 1', url: 'https://example.com/s1/');
      expect(s.title, 'Sesión 1');
      expect(s.isActive, false);
    });
  });

  group('SeminarSessionDetail', () {
    test('construye con todos los campos', () {
      const d = SeminarSessionDetail(
        title: 'Sesión',
        vimeoUrl: 'https://player.vimeo.com/video/123',
        description: 'Descripción',
        materials: [],
        allSessions: [],
      );
      expect(d.vimeoUrl, contains('vimeo'));
      expect(d.materials, isEmpty);
    });
  });

  group('SeminarMaterial', () {
    test('construye correctamente', () {
      const m = SeminarMaterial(name: 'Apuntes', url: 'https://example.com/doc.pdf');
      expect(m.name, 'Apuntes');
      expect(m.url, endsWith('.pdf'));
    });
  });
}
