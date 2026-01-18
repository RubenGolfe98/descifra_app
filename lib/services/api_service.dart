import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/article_model.dart';

class ApiService {
  final String _baseUrl = "https://www.descifrandolaguerra.es/wp-json/wp/v2";

  // 1. Traer la lista rápida
  Future<List<Article>> getArticles() async {
    // Esta URL es "mágica": trae todo en un solo viaje
    final String url = "$_baseUrl/posts?per_page=10&_embed=wp:featuredmedia&_fields=id,date,title,excerpt,featured_media,_links,_embedded";
    
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((json) => Article.fromJson(json)).toList();
    } else {
      throw Exception("Error de conexión");
    }
  }

  Future<String> getArticleContent(int id) async {
    final String url = "$_baseUrl/posts/$id?_fields=content";
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      Map<String, dynamic> data = json.decode(response.body);
      return data['content']['rendered'] ?? "";
    } else {
      throw Exception("Error al cargar el contenido");
    }
  }
}