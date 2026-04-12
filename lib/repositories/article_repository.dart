import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/article.dart';
import '../models/article_detail.dart';
import '../services/article_cache.dart';
import '../services/logging_http_client.dart';

class ArticleRepository {
  static const String _baseUrl =
      'https://www.descifrandolaguerra.es/wp-json/wp/v2';
  static const String _listFields =
      'id,date,title,slug,jetpack_featured_media_url,yoast_head_json.description,yoast_head_json.author,class_list';
  static const String _detailFields =
      'id,date,title,content,jetpack_featured_media_url,yoast_head_json.author,class_list';

  // ─── Claves de caché ──────────────────────────────────────────────────────
  static const String _cacheKeyLatest   = 'articles_latest';
  static const String _cacheKeyAnalysis = 'articles_analysis';
  static String _cacheKeyRegion(int id)  => 'articles_region_$id';

  final http.Client _client;
  final ArticleCache _cache;

  ArticleRepository({http.Client? client, ArticleCache? cache})
      : _client = client ?? LoggingHttpClient(),
        _cache = cache ?? ArticleCache();

  // ─── Listado con caché ─────────────────────────────────────────────────────

  /// Devuelve artículos de caché inmediatamente si existen,
  /// luego refresca en background si han pasado más de 30 min.
  Future<List<Article>> fetchLatestArticles({
    int perPage = 10,
    int page = 1,
    void Function(List<Article>)? onRefreshed,
  }) async {
    final cached = await _cache.getList(key: _cacheKeyLatest);

    if (cached != null) {
      if (kDebugMode) debugPrint('📦 [Cache] Listado desde caché');
      final articles = _parseList(cached);
      final stale = await _cache.isListStale(key: _cacheKeyLatest);
      if (stale) {
        if (kDebugMode) debugPrint('📦 [Cache] Listado obsoleto — refrescando en background');
        _fetchListFromNetwork(perPage, page).then((fresh) {
          if (fresh != null && onRefreshed != null) onRefreshed(fresh);
        });
      }
      return articles;
    }

    if (kDebugMode) debugPrint('📦 [Cache] Sin caché — cargando de red');
    final fresh = await _fetchListFromNetwork(perPage, page);
    return fresh ?? [];
  }

  Future<List<Article>?> _fetchListFromNetwork(int perPage, int page) async {
    try {
      final uri = Uri.parse('$_baseUrl/posts').replace(queryParameters: {
        'per_page': perPage.toString(),
        'page': page.toString(),
        '_fields': _listFields,
      });

      final response =
          await _client.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;

      await _cache.saveList(response.body, key: _cacheKeyLatest);
      return _parseList(response.body);
    } catch (e) {
      if (kDebugMode) debugPrint('📦 [Cache] Error red listado: $e');
      return null;
    }
  }

  List<Article> _parseList(String json) {
    final List<dynamic> data = jsonDecode(json);
    return data.map((j) => Article.fromJson(j)).toList();
  }

  // ─── Artículos por región ─────────────────────────────────────────────────

  Future<List<Article>> fetchArticlesByRegion(
    int regionId, {
    int perPage = 20,
    int page = 1,
    void Function(List<Article>)? onRefreshed,
  }) async {
    final cacheKey = _cacheKeyRegion(regionId);
    final cached = await _cache.getList(key: cacheKey);

    if (cached != null) {
      final articles = _parseList(cached);
      final stale = await _cache.isListStale(key: cacheKey);
      if (stale) {
        _fetchRegionFromNetwork(regionId, perPage, page, cacheKey)
            .then((fresh) {
          if (fresh != null && onRefreshed != null) onRefreshed(fresh);
        });
      }
      return articles;
    }

    final fresh =
        await _fetchRegionFromNetwork(regionId, perPage, page, cacheKey);
    return fresh ?? [];
  }

  Future<List<Article>?> _fetchRegionFromNetwork(
      int regionId, int perPage, int page, String cacheKey) async {
    try {
      final uri = Uri.parse('$_baseUrl/posts').replace(queryParameters: {
        'region': regionId.toString(),
        'per_page': perPage.toString(),
        'page': page.toString(),
        '_fields': _listFields,
      });

      final response =
          await _client.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;

      await _cache.saveList(response.body, key: cacheKey);
      return _parseList(response.body);
    } catch (e) {
      if (kDebugMode) debugPrint('📦 [Repo] Error región $regionId: $e');
      return null;
    }
  }

  static const int _analysisCategoryId = 255;

  Future<List<Article>> fetchAnalysisArticles({
    int perPage = 10,
    void Function(List<Article>)? onRefreshed,
  }) async {
    const cacheKey = _cacheKeyAnalysis;
    final cached = await _cache.getList(key: cacheKey);

    if (cached != null) {
      final articles = _parseList(cached);
      final stale = await _cache.isListStale(key: cacheKey);
      if (stale) {
        _fetchCategoryFromNetwork(_analysisCategoryId, perPage, 1, cacheKey)
            .then((fresh) {
          if (fresh != null && onRefreshed != null) onRefreshed(fresh);
        });
      }
      return articles;
    }

    final fresh = await _fetchCategoryFromNetwork(
        _analysisCategoryId, perPage, 1, cacheKey);
    return fresh ?? [];
  }

  Future<List<Article>> fetchMoreAnalysisArticles({
    required int page,
    int perPage = 10,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/posts').replace(queryParameters: {
        'categories': _analysisCategoryId.toString(),
        'per_page': perPage.toString(),
        'page': page.toString(),
        '_fields': _listFields,
      });
      final response =
          await _client.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];
      return _parseList(response.body);
    } catch (e) {
      if (kDebugMode) debugPrint('📦 [Repo] Error análisis p$page: $e');
      return [];
    }
  }

  Future<List<Article>?> _fetchCategoryFromNetwork(
      int categoryId, int perPage, int page, String cacheKey) async {
    try {
      final uri = Uri.parse('$_baseUrl/posts').replace(queryParameters: {
        'categories': categoryId.toString(),
        'per_page': perPage.toString(),
        'page': page.toString(),
        '_fields': _listFields,
      });
      final response =
          await _client.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      await _cache.saveList(response.body, key: cacheKey);
      return _parseList(response.body);
    } catch (e) {
      if (kDebugMode) debugPrint('📦 [Repo] Error categoría $categoryId: $e');
      return null;
    }
  }
  Future<List<Article>> fetchMoreArticles({
    required int page,
    int perPage = 10,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/posts').replace(queryParameters: {
        'per_page': perPage.toString(),
        'page': page.toString(),
        '_fields': _listFields,
      });
      final response =
          await _client.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];
      return _parseList(response.body);
    } catch (e) {
      if (kDebugMode) debugPrint('📦 [Repo] Error paginación p$page: $e');
      return [];
    }
  }

  /// Carga más artículos de una región (página 2+) — sin caché
  Future<List<Article>> fetchMoreArticlesByRegion({
    required int regionId,
    required int page,
    int perPage = 10,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/posts').replace(queryParameters: {
        'region': regionId.toString(),
        'per_page': perPage.toString(),
        'page': page.toString(),
        '_fields': _listFields,
      });
      final response =
          await _client.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];
      return _parseList(response.body);
    } catch (e) {
      if (kDebugMode) debugPrint('📦 [Repo] Error paginación región $regionId p$page: $e');
      return [];
    }
  }
  /// Devuelve null si no se encuentra.
  Future<Article?> fetchArticleBySlug(String slug) async {
    try {
      final uri = Uri.parse('$_baseUrl/posts').replace(queryParameters: {
        'slug': slug,
        '_fields': _listFields,
      });

      final response =
          await _client.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final List<dynamic> data = jsonDecode(response.body);
      if (data.isEmpty) return null;

      return Article.fromJson(data.first);
    } catch (e) {
      if (kDebugMode) debugPrint('📦 [Repo] Error buscando slug "$slug": $e');
      return null;
    }
  }

  /// Devuelve detalle de caché inmediatamente si existe,
  /// luego refresca en background si está obsoleto.
  /// Si el nonce caduca (401), lo renueva automáticamente y reintenta.
  Future<ArticleDetail> fetchArticleDetail(
    int id, {
    String? cookies,
    String? restNonce,
    Future<String?> Function()? onNonceExpired,
    void Function(ArticleDetail)? onRefreshed,
  }) async {
    final cached = await _cache.getDetail(id);

    if (cached != null) {
      if (kDebugMode) debugPrint('📦 [Cache] Detalle $id desde caché');
      final detail = ArticleDetail.fromJson(jsonDecode(cached));

      final stale = await _cache.isDetailStale(id);
      if (stale) {
        if (kDebugMode) debugPrint('📦 [Cache] Detalle $id obsoleto — refrescando');
        _fetchDetailFromNetwork(id,
                cookies: cookies,
                restNonce: restNonce,
                onNonceExpired: onNonceExpired)
            .then((fresh) {
          if (fresh != null && onRefreshed != null) onRefreshed(fresh);
        });
      }
      return detail;
    }

    if (kDebugMode) debugPrint('📦 [Cache] Sin caché detalle $id — cargando de red');
    final fresh = await _fetchDetailFromNetwork(id,
        cookies: cookies,
        restNonce: restNonce,
        onNonceExpired: onNonceExpired);
    if (fresh == null) throw Exception('Error al cargar el artículo');
    return fresh;
  }

  Future<ArticleDetail?> _fetchDetailFromNetwork(
    int id, {
    String? cookies,
    String? restNonce,
    Future<String?> Function()? onNonceExpired,
  }) async {
    try {
      final uri =
          Uri.parse('$_baseUrl/posts/$id').replace(queryParameters: {
        '_fields': _detailFields,
      });

      final headers = <String, String>{};
      if (cookies != null && cookies.isNotEmpty) headers['Cookie'] = cookies;
      if (restNonce != null && restNonce.isNotEmpty) {
        headers['X-WP-Nonce'] = restNonce;
      }

      var response = await _client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));

      // Si el nonce ha caducado (401), intentar renovarlo y reintentar una vez
      if (response.statusCode == 401 && onNonceExpired != null) {
        if (kDebugMode) debugPrint('📦 [Repo] Nonce caducado, renovando...');
        final newNonce = await onNonceExpired();
        if (newNonce != null) {
          headers['X-WP-Nonce'] = newNonce;
          response = await _client
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 15));
        }
      }

      if (response.statusCode != 200) return null;

      await _cache.saveDetail(id, response.body);
      return ArticleDetail.fromJson(jsonDecode(response.body));
    } catch (e) {
      if (kDebugMode) debugPrint('📦 [Cache] Error red detalle $id: $e');
      return null;
    }
  }
}