import 'package:flutter_test/flutter_test.dart';
import 'package:dlg_app/models/book.dart';

void main() {
  group('Book', () {
    final baseJson = {
      'id': 46018,
      'title': {'rendered': 'La pugna por el nuevo orden internacional'},
      'content': {'rendered': '<p>Descripción del contenido.</p>'},
      'link': 'https://www.descifrandolaguerra.es/libros/la-pugna/',
      'yoast_head_json': {
        'og_description': 'Un libro sobre geopolítica.',
        'og_image': [
          {'url': 'https://example.com/cover.jpg', 'width': 1695, 'height': 2560}
        ],
      },
    };

    test('fromJson parses basic fields correctly', () {
      final book = Book.fromJson(baseJson);
      expect(book.id, 46018);
      expect(book.title, 'La pugna por el nuevo orden internacional');
      expect(book.description, 'Un libro sobre geopolítica.');
      expect(book.coverUrl, 'https://example.com/cover.jpg');
      expect(book.contentHtml, '<p>Descripción del contenido.</p>');
      expect(book.link, 'https://www.descifrandolaguerra.es/libros/la-pugna/');
    });

    test('fromJson sets empty defaults for optional fields', () {
      final book = Book.fromJson(baseJson);
      expect(book.publishDate, '');
      expect(book.authors, isEmpty);
      expect(book.editorial, '');
      expect(book.amazonUrl, '');
      expect(book.amazonKindleUrl, '');
    });

    test('fromJson handles missing og_image', () {
      final json = Map<String, dynamic>.from(baseJson);
      json['yoast_head_json'] = {'og_description': 'Desc'};
      final book = Book.fromJson(json);
      expect(book.coverUrl, '');
    });

    test('fromJson handles empty og_image list', () {
      final json = Map<String, dynamic>.from(baseJson);
      json['yoast_head_json'] = {'og_image': []};
      final book = Book.fromJson(json);
      expect(book.coverUrl, '');
    });

    test('fromJson strips HTML from title', () {
      final json = Map<String, dynamic>.from(baseJson);
      json['title'] = {'rendered': '<strong>Título con HTML</strong>'};
      final book = Book.fromJson(json);
      expect(book.title, 'Título con HTML');
    });

    test('withFicha creates copy with ficha data', () {
      final book = Book.fromJson(baseJson);
      final withFicha = book.withFicha(
        publishDate: '24/05/2023',
        authors: ['Autor Uno', 'Autor Dos'],
        editorial: 'Espasa',
        amazonUrl: 'https://amzn.to/abc',
        amazonKindleUrl: 'https://amzn.to/xyz',
      );

      expect(withFicha.id, book.id);
      expect(withFicha.title, book.title);
      expect(withFicha.publishDate, '24/05/2023');
      expect(withFicha.authors, ['Autor Uno', 'Autor Dos']);
      expect(withFicha.editorial, 'Espasa');
      expect(withFicha.amazonUrl, 'https://amzn.to/abc');
      expect(withFicha.amazonKindleUrl, 'https://amzn.to/xyz');
    });

    test('withFicha does not mutate original', () {
      final book = Book.fromJson(baseJson);
      book.withFicha(
        publishDate: '01/01/2024',
        authors: ['Autor'],
        editorial: 'Ed',
        amazonUrl: 'url',
        amazonKindleUrl: 'url2',
      );
      expect(book.publishDate, '');
      expect(book.authors, isEmpty);
    });

    test('direct constructor sets all fields', () {
      const book = Book(
        id: 1,
        title: 'Título',
        description: 'Desc',
        coverUrl: 'https://cover.jpg',
        contentHtml: '<p>Content</p>',
        link: 'https://link',
        publishDate: '01/01/2023',
        authors: ['Autor A'],
        editorial: 'Editorial',
        amazonUrl: 'https://amzn.to/1',
        amazonKindleUrl: 'https://amzn.to/2',
      );
      expect(book.authors.length, 1);
      expect(book.editorial, 'Editorial');
    });
  });
}
