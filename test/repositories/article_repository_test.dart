import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:dlg_app/models/article.dart';
import 'package:dlg_app/repositories/article_repository.dart';
import 'package:dlg_app/services/article_cache.dart';

// ─── Mock de ArticleCache ─────────────────────────────────────────────────────
class MockArticleCache extends ArticleCache {
  String? _listData;
  String? _detailData;
  bool _isStale;

  MockArticleCache({String? listData, String? detailData, bool isStale = false})
      : _listData = listData,
        _detailData = detailData,
        _isStale = isStale;

  @override
  Future<String?> getList({String? key}) async => _listData;

  @override
  Future<void> saveList(String json, {String? key}) async {
    _listData = json;
  }

  @override
  Future<bool> isListStale({String? key}) async => _isStale;

  @override
  Future<String?> getDetail(int id) async => _detailData;

  @override
  Future<void> saveDetail(int id, String json) async {
    _detailData = json;
  }

  @override
  Future<bool> isDetailStale(int id) async => _isStale;
}

// ─── Datos de test ────────────────────────────────────────────────────────────
final _articleJson = {
  'id': 1,
  'date': '2024-01-15T10:00:00',
  'slug': 'test-article',
  'title': {'rendered': 'Test Article'},
  'yoast_head_json': {'description': 'Test desc', 'author': 'author'},
  'jetpack_featured_media_url': 'https://example.com/img.jpg',
  'class_list': ['post-1', 'post'],
};

final _detailJson = {
  'id': 1,
  'date': '2024-01-15T10:00:00',
  'slug': 'test-article',
  'title': {'rendered': 'Test Article'},
  'content': {'rendered': '<p>Content</p>'},
  'yoast_head_json': {'author': 'author'},
  'jetpack_featured_media_url': 'https://example.com/img.jpg',
  'class_list': ['post-1', 'post'],
};

http.Client _mockClient(dynamic response, {int statusCode = 200}) {
  return MockClient((request) async {
    return http.Response(jsonEncode(response), statusCode);
  });
}

void main() {
  group('ArticleRepository - fetchLatestArticles', () {
    test('returns cached data when cache is fresh', () async {
      final cachedData = jsonEncode([_articleJson]);
      final repo = ArticleRepository(
        client: _mockClient([]),
        cache: MockArticleCache(listData: cachedData, isStale: false),
      );

      final articles = await repo.fetchLatestArticles();
      expect(articles.length, 1);
      expect(articles.first.title, 'Test Article');
    });

    test('fetches from network when no cache', () async {
      final repo = ArticleRepository(
        client: _mockClient([_articleJson]),
        cache: MockArticleCache(),
      );

      final articles = await repo.fetchLatestArticles();
      expect(articles.length, 1);
      expect(articles.first.id, 1);
    });

    test('returns empty list on network error', () async {
      final repo = ArticleRepository(
        client: MockClient((_) async => throw Exception('Network error')),
        cache: MockArticleCache(),
      );

      final articles = await repo.fetchLatestArticles();
      expect(articles, isEmpty);
    });

    test('returns empty list on non-200 status', () async {
      final repo = ArticleRepository(
        client: _mockClient([], statusCode: 500),
        cache: MockArticleCache(),
      );

      final articles = await repo.fetchLatestArticles();
      expect(articles, isEmpty);
    });

    test('calls onRefreshed when cache is stale', () async {
      final cachedData = jsonEncode([_articleJson]);
      final freshArticle = Map<String, dynamic>.from(_articleJson);
      freshArticle['id'] = 99;

      bool refreshed = false;
      final repo = ArticleRepository(
        client: _mockClient([freshArticle]),
        cache: MockArticleCache(listData: cachedData, isStale: true),
      );

      await repo.fetchLatestArticles(onRefreshed: (_) => refreshed = true);
      await Future.delayed(const Duration(milliseconds: 100));
      expect(refreshed, true);
    });
  });

  group('ArticleRepository - fetchMoreArticles', () {
    test('returns articles from network', () async {
      final repo = ArticleRepository(
        client: _mockClient([_articleJson]),
        cache: MockArticleCache(),
      );

      final articles = await repo.fetchMoreArticles(page: 2);
      expect(articles.length, 1);
    });

    test('returns empty on error', () async {
      final repo = ArticleRepository(
        client: MockClient((_) async => throw Exception('error')),
        cache: MockArticleCache(),
      );

      final articles = await repo.fetchMoreArticles(page: 2);
      expect(articles, isEmpty);
    });
  });

  group('ArticleRepository - fetchArticlesByRegion', () {
    test('fetches articles for a region', () async {
      final repo = ArticleRepository(
        client: _mockClient([_articleJson]),
        cache: MockArticleCache(),
      );

      final articles = await repo.fetchArticlesByRegion(101);
      expect(articles.length, 1);
    });
  });

  group('ArticleRepository - fetchMoreArticlesByRegion', () {
    test('returns articles from network', () async {
      final repo = ArticleRepository(
        client: _mockClient([_articleJson]),
        cache: MockArticleCache(),
      );

      final articles = await repo.fetchMoreArticlesByRegion(
        regionId: 101,
        page: 2,
      );
      expect(articles.length, 1);
    });
  });

  group('ArticleRepository - fetchArticleBySlug', () {
    test('returns article when found', () async {
      final repo = ArticleRepository(
        client: _mockClient([_articleJson]),
        cache: MockArticleCache(),
      );

      final article = await repo.fetchArticleBySlug('test-article');
      expect(article, isNotNull);
      expect(article!.slug, 'test-article');
    });

    test('returns null when not found', () async {
      final repo = ArticleRepository(
        client: _mockClient([]),
        cache: MockArticleCache(),
      );

      final article = await repo.fetchArticleBySlug('non-existent');
      expect(article, isNull);
    });

    test('returns null on network error', () async {
      final repo = ArticleRepository(
        client: MockClient((_) async => throw Exception('error')),
        cache: MockArticleCache(),
      );

      final article = await repo.fetchArticleBySlug('any-slug');
      expect(article, isNull);
    });
  });

  group('ArticleRepository - fetchAnalysisArticles', () {
    test('fetches analysis articles from network', () async {
      final analysisJson = Map<String, dynamic>.from(_articleJson);
      analysisJson['class_list'] = ['category-analisis'];

      final repo = ArticleRepository(
        client: _mockClient([analysisJson]),
        cache: MockArticleCache(),
      );

      final articles = await repo.fetchAnalysisArticles();
      expect(articles.length, 1);
      expect(articles.first.category, ArticleCategory.analisis);
    });
  });

  group('ArticleRepository - searchArticles', () {
    test('returns articles matching query', () async {
      final repo = ArticleRepository(
        client: _mockClient([_articleJson]),
        cache: MockArticleCache(),
      );
      final articles = await repo.searchArticles('iran');
      expect(articles.length, 1);
      expect(articles.first.title, 'Test Article');
    });

    test('returns empty list for empty query', () async {
      final repo = ArticleRepository(
        client: _mockClient([_articleJson]),
        cache: MockArticleCache(),
      );
      final articles = await repo.searchArticles('');
      expect(articles, isEmpty);
    });

    test('returns empty list for whitespace query', () async {
      final repo = ArticleRepository(
        client: _mockClient([_articleJson]),
        cache: MockArticleCache(),
      );
      final articles = await repo.searchArticles('   ');
      expect(articles, isEmpty);
    });

    test('returns empty list on network error', () async {
      final repo = ArticleRepository(
        client: MockClient((_) async => throw Exception('error')),
        cache: MockArticleCache(),
      );
      final articles = await repo.searchArticles('iran');
      expect(articles, isEmpty);
    });

    test('returns empty list on non-200 status', () async {
      final repo = ArticleRepository(
        client: _mockClient([], statusCode: 404),
        cache: MockArticleCache(),
      );
      final articles = await repo.searchArticles('iran');
      expect(articles, isEmpty);
    });

    test('respects perPage parameter', () async {
      final repo = ArticleRepository(
        client: _mockClient([_articleJson]),
        cache: MockArticleCache(),
      );
      final articles = await repo.searchArticles('test', perPage: 5);
      expect(articles.length, lessThanOrEqualTo(5));
    });
  });
}