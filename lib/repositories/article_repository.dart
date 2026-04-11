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
      'id,date,title,jetpack_featured_media_url,yoast_head_json.description,yoast_head_json.author,class_list';
  static const String _detailFields =
      'id,date,title,content,jetpack_featured_media_url,yoast_head_json.author,class_list';

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
    final cached = await _cache.getList();

    if (cached != null) {
      debugPrint('📦 [Cache] Listado desde caché');
      final articles = _parseList(cached);

      // Refrescar en background si está obsoleto
      final stale = await _cache.isListStale();
      if (stale) {
        debugPrint('📦 [Cache] Listado obsoleto — refrescando en background');
        _fetchListFromNetwork(perPage, page).then((fresh) {
          if (fresh != null && onRefreshed != null) onRefreshed(fresh);
        });
      }
      return articles;
    }

    // Sin caché — esperar la red
    debugPrint('📦 [Cache] Sin caché — cargando de red');
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

      await _cache.saveList(response.body);
      return _parseList(response.body);
    } catch (e) {
      debugPrint('📦 [Cache] Error red listado: $e');
      return null;
    }
  }

  List<Article> _parseList(String json) {
    final List<dynamic> data = jsonDecode(json);
    return data.map((j) => Article.fromJson(j)).toList();
  }

  // ─── Buscar por slug ───────────────────────────────────────────────────────

  /// Busca un artículo por su slug (la parte final de la URL de DLG).
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
      debugPrint('📦 [Repo] Error buscando slug "$slug": $e');
      return null;
    }
  }

  /// Devuelve detalle de caché inmediatamente si existe,
  /// luego refresca en background si está obsoleto.
  Future<ArticleDetail> fetchArticleDetail(
    int id, {
    String? cookies,
    String? restNonce,
    void Function(ArticleDetail)? onRefreshed,
  }) async {
    final cached = await _cache.getDetail(id);

    if (cached != null) {
      debugPrint('📦 [Cache] Detalle $id desde caché');
      final detail = ArticleDetail.fromJson(jsonDecode(cached));

      final stale = await _cache.isDetailStale(id);
      if (stale) {
        debugPrint('📦 [Cache] Detalle $id obsoleto — refrescando');
        _fetchDetailFromNetwork(id, cookies: cookies, restNonce: restNonce)
            .then((fresh) {
          if (fresh != null && onRefreshed != null) onRefreshed(fresh);
        });
      }
      return detail;
    }

    // Sin caché — esperar la red
    debugPrint('📦 [Cache] Sin caché detalle $id — cargando de red');
    final fresh = await _fetchDetailFromNetwork(id,
        cookies: cookies, restNonce: restNonce);
    if (fresh == null) throw Exception('Error al cargar el artículo');
    return fresh;
  }

  Future<ArticleDetail?> _fetchDetailFromNetwork(
    int id, {
    String? cookies,
    String? restNonce,
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

      final response = await _client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;

      await _cache.saveDetail(id, response.body);
      return ArticleDetail.fromJson(jsonDecode(response.body));
    } catch (e) {
      debugPrint('📦 [Cache] Error red detalle $id: $e');
      return null;
    }
  }
}