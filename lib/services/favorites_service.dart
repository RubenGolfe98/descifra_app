import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/article.dart';

class FavoritesService extends ChangeNotifier {
  static const _ajaxUrl = 'https://www.descifrandolaguerra.es/wp-admin/admin-ajax.php';

  final http.Client _client;

  // IDs de artículos guardados localmente
  final Set<int> _savedIds = {};
  // Artículos completos para mostrar en la pantalla de guardados
  final List<Article> _savedArticles = [];
  bool _loaded = false;

  FavoritesService({http.Client? client}) : _client = client ?? http.Client();

  Set<int> get savedIds => Set.unmodifiable(_savedIds);
  List<Article> get savedArticles => List.unmodifiable(_savedArticles);
  bool get loaded => _loaded;

  bool isSaved(int postId) => _savedIds.contains(postId);

  /// Carga los favoritos actuales desde el servidor usando action=favorites_array
  Future<void> loadFavorites(String cookies) async {
    try {
      final response = await _client.post(
        Uri.parse(_ajaxUrl),
        headers: {
          'Cookie': cookies,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: 'action=favorites_array',
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') _parseFavorites(data);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⭐ [Favorites] loadFavorites error: $e');
    }
    _loaded = true;
    notifyListeners();
  }

  /// Añade o elimina un artículo de favoritos
  Future<bool> toggleFavorite(int postId, String cookies) async {
    final isCurrentlySaved = _savedIds.contains(postId);
    final newStatus = isCurrentlySaved ? 'inactive' : 'active';

    // Optimistic update
    if (isCurrentlySaved) {
      _savedIds.remove(postId);
      _savedArticles.removeWhere((a) => a.id == postId);
    } else {
      _savedIds.add(postId);
    }
    notifyListeners();

    try {
      final response = await _client.post(
        Uri.parse(_ajaxUrl),
        headers: {
          'Cookie': cookies,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: 'action=favorites_favorite&postid=$postId&siteid=1&status=$newStatus&user_consent_accepted=false',
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          _parseFavorites(data);
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⭐ [Favorites] toggle error: $e');
    }

    // Revertir si falló
    if (isCurrentlySaved) {
      _savedIds.add(postId);
    } else {
      _savedIds.remove(postId);
    }
    notifyListeners();
    return false;
  }

  void _parseFavorites(Map<String, dynamic> data) {
    _savedIds.clear();
    _savedArticles.clear();

    final favorites = data['favorites'] as List?;
    if (favorites == null || favorites.isEmpty) return;

    final posts = favorites[0]['posts'] as Map<String, dynamic>?;
    if (posts == null) return;

    for (final entry in posts.values) {
      final postId = entry['post_id'] as int?;
      if (postId == null) continue;
      _savedIds.add(postId);

      // Extraer URL de imagen del thumbnail medium
      final thumbHtml = entry['thumbnails']?['medium'] as String? ?? '';
      final imgMatch = RegExp(r'src="([^"]+)"').firstMatch(thumbHtml);
      final imageUrl = imgMatch?.group(1) ?? '';

      final title = (entry['title'] as String? ?? '')
          .replaceAll('&#8230;', '…')
          .replaceAll('&#8217;', '\u2019')
          .replaceAll(RegExp(r'&#\d+;'), '');

      final permalink = entry['permalink'] as String? ?? '';
      final slug = Uri.parse(permalink).pathSegments
          .where((s) => s.isNotEmpty)
          .lastOrNull ?? '';

      _savedArticles.add(Article(
        id: postId,
        date: DateTime.now(),
        title: title,
        description: '',
        author: '',
        imageUrl: imageUrl,
        isPremium: false,
        slug: slug,
      ));
    }
  }

  void clear() {
    _savedIds.clear();
    _savedArticles.clear();
    _loaded = false;
    notifyListeners();
  }
}