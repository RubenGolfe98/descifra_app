import 'package:flutter_test/flutter_test.dart';
import 'package:dlg_app/models/article.dart';

void main() {
  group('Article', () {
    final baseJson = {
      'id': 1,
      'date': '2024-01-15T10:00:00',
      'slug': 'test-article',
      'title': {'rendered': 'Test Article'},
      'yoast_head_json': {
        'description': 'Test description',
        'author': 'test-author',
      },
      'jetpack_featured_media_url': 'https://example.com/image.jpg',
      'class_list': ['post-1', 'post', 'type-post', 'status-publish'],
    };

    test('fromJson parses basic fields correctly', () {
      final article = Article.fromJson(baseJson);

      expect(article.id, 1);
      expect(article.title, 'Test Article');
      expect(article.description, 'Test description');
      expect(article.author, 'test-author');
      expect(article.imageUrl, 'https://example.com/image.jpg');
      expect(article.slug, 'test-article');
      expect(article.isPremium, false);
      expect(article.category, ArticleCategory.noticia);
    });

    test('fromJson detects premium articles', () {
      final json = Map<String, dynamic>.from(baseJson);
      json['class_list'] = [...baseJson['class_list'] as List, 'rcp-is-restricted'];

      final article = Article.fromJson(json);
      expect(article.isPremium, true);
    });

    test('fromJson detects analysis category', () {
      final json = Map<String, dynamic>.from(baseJson);
      json['class_list'] = [...baseJson['class_list'] as List, 'category-analisis'];

      final article = Article.fromJson(json);
      expect(article.category, ArticleCategory.analisis);
    });

    test('fromJson strips HTML from title', () {
      final json = Map<String, dynamic>.from(baseJson);
      json['title'] = {'rendered': '<strong>Bold Title</strong>'};

      final article = Article.fromJson(json);
      expect(article.title, 'Bold Title');
    });

    test('fromJson handles missing optional fields', () {
      final minimalJson = {
        'id': 2,
        'date': '2024-01-15T10:00:00',
        'title': {'rendered': 'Minimal'},
        'class_list': [],
      };

      final article = Article.fromJson(minimalJson);
      expect(article.description, '');
      expect(article.author, '');
      expect(article.imageUrl, '');
      expect(article.slug, '');
      expect(article.isPremium, false);
      expect(article.category, ArticleCategory.noticia);
    });

    test('fromJson handles null class_list', () {
      final json = Map<String, dynamic>.from(baseJson);
      json['class_list'] = null;

      final article = Article.fromJson(json);
      expect(article.isPremium, false);
      expect(article.category, ArticleCategory.noticia);
    });

    test('direct constructor sets all fields', () {
      final date = DateTime(2024, 1, 15);
      final article = Article(
        id: 99,
        date: date,
        title: 'Direct',
        description: 'Desc',
        author: 'Author',
        imageUrl: 'url',
        isPremium: true,
        category: ArticleCategory.analisis,
        slug: 'direct-slug',
      );

      expect(article.id, 99);
      expect(article.date, date);
      expect(article.isPremium, true);
      expect(article.category, ArticleCategory.analisis);
      expect(article.slug, 'direct-slug');
    });

    test('default category is noticia', () {
      final article = Article(
        id: 1,
        date: DateTime.now(),
        title: 'T',
        description: 'D',
        author: 'A',
        imageUrl: '',
        isPremium: false,
      );
      expect(article.category, ArticleCategory.noticia);
    });

    test('default slug is empty string', () {
      final article = Article(
        id: 1,
        date: DateTime.now(),
        title: 'T',
        description: 'D',
        author: 'A',
        imageUrl: '',
        isPremium: false,
      );
      expect(article.slug, '');
    });
  });

  group('ArticleCategory', () {
    test('has noticia, analisis and entrevista values', () {
      expect(ArticleCategory.values.length, 3);
      expect(ArticleCategory.values, contains(ArticleCategory.noticia));
      expect(ArticleCategory.values, contains(ArticleCategory.analisis));
      expect(ArticleCategory.values, contains(ArticleCategory.entrevista));
    });
  });
}