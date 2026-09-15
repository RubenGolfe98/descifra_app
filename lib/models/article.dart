class Article {
  final int id;
  final DateTime date;
  final String title;
  final String description;
  final String author;
  final String imageUrl;
  final Map<int, String>
      imageSizes; // ancho(px) → URL (tamaños generados por WP)
  final bool isPremium;
  final ArticleCategory category;
  final String slug;
  final List<String> tagSlugs; // slugs de tags (sin prefijo "tag-");

  const Article({
    required this.id,
    required this.date,
    required this.title,
    required this.description,
    required this.author,
    required this.imageUrl,
    this.imageSizes = const {},
    required this.isPremium,
    this.category = ArticleCategory.noticia,
    this.slug = '',
    this.tagSlugs = const [],
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    final classList = List<String>.from(json['class_list'] ?? []);

    ArticleCategory category = ArticleCategory.noticia;
    if (classList.contains('category-analisis')) {
      category = ArticleCategory.analisis;
    } else if (classList.contains('category-entrevistas')) {
      category = ArticleCategory.entrevista;
    }

    // Extraer tags del class_list (entradas que empiezan con "tag-")
    final tagSlugs = classList
        .where((c) => c.startsWith('tag-'))
        .map((c) => c.substring(4))
        .toList();

    return Article(
      id: json['id'] as int,
      date: DateTime.parse(json['date'] as String),
      title: _stripHtml(json['title']?['rendered'] ?? ''),
      description: json['yoast_head_json']?['description'] ?? '',
      author: json['yoast_head_json']?['author'] ?? '',
      imageUrl: json['jetpack_featured_media_url'] ?? '',
      imageSizes: _parseImageSizes(json),
      isPremium: classList.contains('rcp-is-restricted'),
      category: category,
      slug: json['slug'] ?? '',
      tagSlugs: tagSlugs,
    );
  }

  /// Tamaños generados por WordPress de la imagen destacada
  /// (requiere `_embed=1` en la petición). Vacío si no está disponible.
  static Map<int, String> _parseImageSizes(Map<String, dynamic> json) {
    final embedded = json['_embedded'] as Map<String, dynamic>?;
    final media = embedded?['wp:featuredmedia'] as List?;
    if (media == null || media.isEmpty) return const {};
    final sizes = media[0]['media_details']?['sizes'] as Map<String, dynamic>?;
    if (sizes == null) return const {};
    final out = <int, String>{};
    for (final entry in sizes.entries) {
      final value = entry.value;
      if (value is! Map) continue;
      final width = value['width'];
      final url = value['source_url'];
      if (width is int && url is String) out[width] = url;
    }
    return out;
  }

  static String _stripHtml(String html) =>
      html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
}

enum ArticleCategory { noticia, analisis, entrevista }
