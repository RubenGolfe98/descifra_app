import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/coverage.dart';

class CoverageRepository {
  static const _baseUrl = 'https://www.descifrandolaguerra.es/wp-json/wp/v2';
  static const _ttl = Duration(hours: 2);

  final http.Client _client;

  // Caché listado con TTL
  static List<Coverage>? _listCache;
  static DateTime? _listCachedAt;

  // Caché detalles (sin TTL — los detalles no cambian)
  static final Map<int, CoverageDetail> _detailCache = {};

  CoverageRepository({http.Client? client}) : _client = client ?? http.Client();

  static void clearCache() {
    _listCache = null;
    _listCachedAt = null;
    _detailCache.clear();
  }

  bool get _listCacheValid =>
      _listCache != null &&
      _listCachedAt != null &&
      DateTime.now().difference(_listCachedAt!) < _ttl;

  Future<List<Coverage>> fetchCoverages({int page = 1, int perPage = 5}) async {
    if (page == 1 && _listCacheValid) {
      if (kDebugMode) debugPrint('📰 [Coverages] Desde caché');
      return _listCache!;
    }
    try {
      final uri = Uri.parse('$_baseUrl/cobertura').replace(queryParameters: {
        'per_page': perPage.toString(),
        'page': page.toString(),
        'orderby': 'date',
        'order': 'desc',
        '_fields': 'id,title,slug,link,yoast_head_json.og_image,yoast_head_json.description',
      });
      final response = await _client.get(uri).timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) return [];
      final List<dynamic> data = jsonDecode(response.body);
      final coverages = data.map((j) => Coverage.fromJson(j)).toList();
      if (page == 1) {
        _listCache = coverages;
        _listCachedAt = DateTime.now();
      }
      return coverages;
    } catch (e) {
      if (kDebugMode) debugPrint('📰 [Coverages] Error: $e');
      return _listCache ?? [];
    }
  }

  Future<CoverageDetail?> fetchCoverageDetail(int id) async {
    if (_detailCache.containsKey(id)) {
      if (kDebugMode) debugPrint('📰 [Coverages] Detail desde caché: $id');
      return _detailCache[id];
    }
    try {
      final uri = Uri.parse('$_baseUrl/cobertura/$id').replace(queryParameters: {
        '_fields': 'id,title,slug,link,content',
      });
      final response = await _client.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      final detail = CoverageDetail.fromJson(jsonDecode(response.body));
      _detailCache[id] = detail;
      return detail;
    } catch (e) {
      if (kDebugMode) debugPrint('📰 [Coverages] fetchDetail error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchRelatedArticles(
      String coverageSlug, {int page = 1, int perPage = 10}) async {
    try {
      final uri = Uri.parse('$_baseUrl/posts').replace(queryParameters: {
        'cobertura': coverageSlug,
        'per_page': perPage.toString(),
        'page': page.toString(),
        '_fields': 'id,date,title,slug,jetpack_featured_media_url,yoast_head_json.description,yoast_head_json.author,class_list',
      });
      final response = await _client.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } catch (e) {
      if (kDebugMode) debugPrint('📰 [Coverages] fetchRelated error: $e');
      return [];
    }
  }

  /// Precarga en background — llamar desde ExploreScreen
  static void prefetch() {
    final repo = CoverageRepository();
    if (repo._listCacheValid) return;
    repo.fetchCoverages(page: 1, perPage: 5).ignore();
    if (kDebugMode) debugPrint('📰 [Coverages] Precarga iniciada');
  }
}