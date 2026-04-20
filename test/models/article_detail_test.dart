import 'package:flutter_test/flutter_test.dart';
import 'package:dlg_app/models/article_detail.dart';

void main() {
  group('ArticleDetail.fromJson', () {
    final json = {
      'id': 1,
      'date': '2024-03-15T10:00:00',
      'title': {'rendered': 'Título del artículo'},
      'content': {'rendered': '<p>Contenido completo</p>'},
      'yoast_head_json': {'author': 'Juan García'},
      'jetpack_featured_media_url': 'https://example.com/img.jpg',
      'class_list': ['post-1', 'post'],
    };

    test('parsea todos los campos', () {
      final d = ArticleDetail.fromJson(json);
      expect(d.id, 1);
      expect(d.title, 'Título del artículo');
      expect(d.content, '<p>Contenido completo</p>');
      expect(d.author, 'Juan García');
      expect(d.imageUrl, 'https://example.com/img.jpg');
      expect(d.isPremium, false);
    });

    test('isPremium true con rcp-is-restricted', () {
      final j = Map<String, dynamic>.from(json)
        ..['class_list'] = ['post-1', 'rcp-is-restricted'];
      expect(ArticleDetail.fromJson(j).isPremium, true);
    });

    test('content vacío si protegido', () {
      final j = Map<String, dynamic>.from(json)
        ..['content'] = {'rendered': '', 'protected': true};
      expect(ArticleDetail.fromJson(j).content, '');
    });

    test('strip HTML en título', () {
      final j = Map<String, dynamic>.from(json)
        ..['title'] = {'rendered': '<strong>Título</strong>'};
      expect(ArticleDetail.fromJson(j).title, 'Título');
    });

    test('parsea fecha correctamente', () {
      final d = ArticleDetail.fromJson(json);
      expect(d.date.year, 2024);
      expect(d.date.month, 3);
      expect(d.date.day, 15);
    });

    test('author vacío si no hay yoast_head_json', () {
      final j = Map<String, dynamic>.from(json)..remove('yoast_head_json');
      expect(ArticleDetail.fromJson(j).author, '');
    });
  });
}
