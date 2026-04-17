import '../models/coverage.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CoverageRepository {
  static const _baseUrl = 'https://www.descifrandolaguerra.es/wp-json/wp/v2';
  final http.Client _client;

  // Caché en memoria para detalles
  static final Map<int, CoverageDetail> _detailCache = {};

  CoverageRepository({http.Client? client}) : _client = client ?? http.Client();

  Future<List<Coverage>> fetchCoverages({int page = 1, int perPage = 5}) async {
    try {
      final uri = Uri.parse('$_baseUrl/cobertura').replace(queryParameters: {
        'per_page': perPage.toString(),
        'page': page.toString(),
        'orderby': 'date',
        'order': 'desc',
        '_fields': 'id,title,slug,link,yoast_head_json.og_image,yoast_head_json.description',
      });
      final response = await _client.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return [];
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((j) => Coverage.fromJson(j)).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('📰 [Coverages] Error: $e');
      return [];
    }
  }


  Future<CoverageDetail?> fetchCoverageDetail(int id) async {
    if (_detailCache.containsKey(id)) return _detailCache[id];
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
}