import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/article.dart';
import '../models/article_detail.dart';
import '../services/logging_http_client.dart';

class ArticleRepository {
  static const String _baseUrl = 'https://www.descifrandolaguerra.es/wp-json/wp/v2';
  static const String _listFields =
      'id,date,title,jetpack_featured_media_url,yoast_head_json.description,yoast_head_json.author,class_list';
  static const String _detailFields =
      'id,date,title,content,jetpack_featured_media_url,yoast_head_json.author,class_list';

  final http.Client _client;

  ArticleRepository({http.Client? client}) : _client = client ?? LoggingHttpClient();

  Future<List<Article>> fetchLatestArticles({int perPage = 10, int page = 1}) async {
    final uri = Uri.parse('$_baseUrl/posts').replace(queryParameters: {
      'per_page': perPage.toString(),
      'page': page.toString(),
      '_fields': _listFields,
    });

    final response = await _client.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Error al cargar noticias (${response.statusCode})');
    }

    final List<dynamic> data = jsonDecode(response.body);
    return data.map((json) => Article.fromJson(json)).toList();
  }

  /// Obtiene el detalle completo de un artículo, con las cookies
  /// de sesión si el usuario está logueado (para contenido premium)
  Future<ArticleDetail> fetchArticleDetail(int id,
      {String? cookies, String? restNonce}) async {
    final uri = Uri.parse('$_baseUrl/posts/$id').replace(queryParameters: {
      '_fields': _detailFields,
    });

    final headers = <String, String>{};
    if (cookies != null && cookies.isNotEmpty) {
      headers['Cookie'] = cookies;
    }
    if (restNonce != null && restNonce.isNotEmpty) {
      headers['X-WP-Nonce'] = restNonce;
    }

    final response = await _client
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Error al cargar el artículo (${response.statusCode})');
    }

    return ArticleDetail.fromJson(jsonDecode(response.body));
  }
}