import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:dlg_app/models/article.dart';
import 'package:dlg_app/repositories/article_repository.dart';
import 'package:dlg_app/services/article_cache.dart';

class MockArticleCache extends ArticleCache {
  String? _listData;
  String? _detailData;
  bool _isStale;

  MockArticleCache({String? listData, String? detailData, bool isStale = false})
      : _listData = listData,
        _detailData = detailData,
        _isStale = isStale;

  @override Future<String?> getList({String? key}) async => _listData;
  @override Future<void> saveList(String json, {String? key}) async { _listData = json; }
  @override Future<bool> isListStale({String? key}) async => _isStale;
  @override Future<String?> getDetail(int id) async => _detailData;
  @override Future<void> saveDetail(int id, String json) async { _detailData = json; }
  @override Future<bool> isDetailStale(int id) async => _isStale;
}

final _articleJson = {
  'id': 1, 'date': '2024-01-15T10:00:00', 'slug': 'test-article',
  'title': {'rendered': 'Test Article'},
  'yoast_head_json': {'description': 'Test desc', 'author': 'author'},
  'jetpack_featured_media_url': 'https://example.com/img.jpg',
  'class_list': ['post-1', 'post'],
};

final _detailJson = {
  'id': 1, 'date': '2024-01-15T10:00:00',
  'title': {'rendered': 'Test Article'},
  'content': {'rendered': '<p>Content</p>'},
  'yoast_head_json': {'author': 'author'},
  'jetpack_featured_media_url': 'https://example.com/img.jpg',
  'class_list': ['post-1', 'post'],
};

final _detailEmptyContent = {
  'id': 1, 'date': '2024-01-15T10:00:00',
  'title': {'rendered': 'Test Article'},
  'content': {'rendered': ''},
  'yoast_head_json': {'author': 'author'},
  'jetpack_featured_media_url': 'https://example.com/img.jpg',
  'class_list': ['post-1', 'rcp-is-restricted', 'rcp-no-access'],
};

http.Client _mockClient(dynamic response, {int statusCode = 200}) =>
    MockClient((_) async => http.Response(jsonEncode(response), statusCode));

void main() {
  group('ArticleRepository - fetchLatestArticles', () {
    test('returns cached data when cache is fresh', () async {
      final repo = ArticleRepository(
        client: _mockClient([]),
        cache: MockArticleCache(listData: jsonEncode([_articleJson]), isStale: false),
      );
      final articles = await repo.fetchLatestArticles();
      expect(articles.length, 1);
      expect(articles.first.title, 'Test Article');
    });

    test('fetches from network when no cache', () async {
      final repo = ArticleRepository(client: _mockClient([_articleJson]), cache: MockArticleCache());
      final articles = await repo.fetchLatestArticles();
      expect(articles.length, 1);
    });

    test('returns empty list on network error', () async {
      final repo = ArticleRepository(
        client: MockClient((_) async => throw Exception('error')),
        cache: MockArticleCache(),
      );
      expect(await repo.fetchLatestArticles(), isEmpty);
    });

    test('calls onRefreshed when cache is stale', () async {
      final freshArticle = Map<String, dynamic>.from(_articleJson)..['id'] = 99;
      bool refreshed = false;
      final repo = ArticleRepository(
        client: _mockClient([freshArticle]),
        cache: MockArticleCache(listData: jsonEncode([_articleJson]), isStale: true),
      );
      await repo.fetchLatestArticles(onRefreshed: (_) => refreshed = true);
      await Future.delayed(const Duration(milliseconds: 100));
      expect(refreshed, true);
    });
  });

  group('ArticleRepository - fetchMoreArticles (devuelve List?)', () {
    test('returns articles from network', () async {
      final repo = ArticleRepository(client: _mockClient([_articleJson]), cache: MockArticleCache());
      final articles = await repo.fetchMoreArticles(page: 2);
      expect(articles, isNotNull);
      expect(articles!.length, 1);
    });

    test('returns null on network error — no marca fin de lista', () async {
      final repo = ArticleRepository(
        client: MockClient((_) async => throw Exception('error')),
        cache: MockArticleCache(),
      );
      expect(await repo.fetchMoreArticles(page: 2), isNull);
    });

    test('returns null on 503', () async {
      final repo = ArticleRepository(client: _mockClient('error', statusCode: 503), cache: MockArticleCache());
      expect(await repo.fetchMoreArticles(page: 2), isNull);
    });

    test('returns empty list on 400 — fin real de paginación', () async {
      final repo = ArticleRepository(client: _mockClient('bad', statusCode: 400), cache: MockArticleCache());
      final articles = await repo.fetchMoreArticles(page: 999);
      expect(articles, isEmpty);
    });
  });

  group('ArticleRepository - fetchMoreArticlesByRegion (devuelve List?)', () {
    test('returns articles from network', () async {
      final repo = ArticleRepository(client: _mockClient([_articleJson]), cache: MockArticleCache());
      final articles = await repo.fetchMoreArticlesByRegion(regionId: 101, page: 2);
      expect(articles, isNotNull);
      expect(articles!.length, 1);
    });

    test('returns null on error', () async {
      final repo = ArticleRepository(
        client: MockClient((_) async => throw Exception('error')),
        cache: MockArticleCache(),
      );
      expect(await repo.fetchMoreArticlesByRegion(regionId: 101, page: 2), isNull);
    });

    test('returns empty list on 400', () async {
      final repo = ArticleRepository(client: _mockClient('bad', statusCode: 400), cache: MockArticleCache());
      expect(await repo.fetchMoreArticlesByRegion(regionId: 101, page: 999), isEmpty);
    });
  });

  group('ArticleRepository - fetchMoreAnalysisArticles (devuelve List?)', () {
    test('returns articles from network', () async {
      final repo = ArticleRepository(client: _mockClient([_articleJson]), cache: MockArticleCache());
      final articles = await repo.fetchMoreAnalysisArticles(page: 2);
      expect(articles, isNotNull);
    });

    test('returns null on error', () async {
      final repo = ArticleRepository(
        client: MockClient((_) async => throw Exception('error')),
        cache: MockArticleCache(),
      );
      expect(await repo.fetchMoreAnalysisArticles(page: 2), isNull);
    });

    test('returns empty list on 400', () async {
      final repo = ArticleRepository(client: _mockClient('bad', statusCode: 400), cache: MockArticleCache());
      expect(await repo.fetchMoreAnalysisArticles(page: 999), isEmpty);
    });
  });

  group('ArticleRepository - fetchArticleDetail', () {
    test('returns detail from network when no cache', () async {
      final repo = ArticleRepository(client: _mockClient(_detailJson), cache: MockArticleCache());
      final detail = await repo.fetchArticleDetail(1);
      expect(detail.content, '<p>Content</p>');
    });

    test('returns cached detail when cache is fresh', () async {
      final repo = ArticleRepository(
        client: _mockClient(_detailJson),
        cache: MockArticleCache(detailData: jsonEncode(_detailJson), isStale: false),
      );
      final detail = await repo.fetchArticleDetail(1);
      expect(detail.content, '<p>Content</p>');
    });

    test('forceRefresh bypasses cache and calls network', () async {
      int calls = 0;
      final repo = ArticleRepository(
        client: MockClient((_) async { calls++; return http.Response(jsonEncode(_detailJson), 200); }),
        cache: MockArticleCache(detailData: jsonEncode(_detailJson), isStale: false),
      );
      await repo.fetchArticleDetail(1, forceRefresh: false);
      expect(calls, 0); // usó caché
      await repo.fetchArticleDetail(1, forceRefresh: true);
      expect(calls, 1); // fue a red
    });

    test('background refresh triggered when cached content is empty', () async {
      bool refreshed = false;
      final repo = ArticleRepository(
        client: _mockClient(_detailJson),
        cache: MockArticleCache(detailData: jsonEncode(_detailEmptyContent), isStale: false),
      );
      await repo.fetchArticleDetail(1, onRefreshed: (_) => refreshed = true);
      await Future.delayed(const Duration(milliseconds: 100));
      expect(refreshed, true);
    });

    test('throws when network fails and no cache', () async {
      // Nota: este test tarda ~6s por los reintentos automáticos (2s + 4s)
      final repo = ArticleRepository(
        client: MockClient((_) async => throw Exception('error')),
        cache: MockArticleCache(),
      );
      expect(
        () => repo.fetchArticleDetail(1),
        throwsException,
      );
    }, timeout: const Timeout(Duration(seconds: 15)));
  });

  group('ArticleRepository - fetchArticleBySlug', () {
    test('returns article when found', () async {
      final repo = ArticleRepository(client: _mockClient([_articleJson]), cache: MockArticleCache());
      final article = await repo.fetchArticleBySlug('test-article');
      expect(article?.slug, 'test-article');
    });

    test('returns null when not found', () async {
      final repo = ArticleRepository(client: _mockClient([]), cache: MockArticleCache());
      expect(await repo.fetchArticleBySlug('non-existent'), isNull);
    });

    test('returns null on network error', () async {
      final repo = ArticleRepository(
        client: MockClient((_) async => throw Exception('error')),
        cache: MockArticleCache(),
      );
      expect(await repo.fetchArticleBySlug('slug'), isNull);
    });
  });

  group('ArticleRepository - searchArticles', () {
    test('returns articles matching query', () async {
      final repo = ArticleRepository(client: _mockClient([_articleJson]), cache: MockArticleCache());
      expect(await repo.searchArticles('iran'), hasLength(1));
    });

    test('returns empty for empty query', () async {
      final repo = ArticleRepository(client: _mockClient([_articleJson]), cache: MockArticleCache());
      expect(await repo.searchArticles(''), isEmpty);
    });

    test('returns empty for whitespace query', () async {
      final repo = ArticleRepository(client: _mockClient([_articleJson]), cache: MockArticleCache());
      expect(await repo.searchArticles('   '), isEmpty);
    });

    test('returns empty on network error', () async {
      final repo = ArticleRepository(
        client: MockClient((_) async => throw Exception('error')),
        cache: MockArticleCache(),
      );
      expect(await repo.searchArticles('iran'), isEmpty);
    });

    test('returns empty on non-200', () async {
      final repo = ArticleRepository(client: _mockClient([], statusCode: 404), cache: MockArticleCache());
      expect(await repo.searchArticles('iran'), isEmpty);
    });
  });

  group('ArticleRepository - fetchAnalysisArticles', () {
    test('returns analysis articles', () async {
      final json = Map<String, dynamic>.from(_articleJson)
        ..['class_list'] = ['category-analisis'];
      final repo = ArticleRepository(client: _mockClient([json]), cache: MockArticleCache());
      final articles = await repo.fetchAnalysisArticles();
      expect(articles.first.category, ArticleCategory.analisis);
    });
  });
}