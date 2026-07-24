class Article {
  final int id;
  final DateTime date;
  final String title;
  final String description;
  final String author;
  final String imageUrl;
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
      isPremium: classList.contains('rcp-is-restricted'),
      category: category,
      slug: json['slug'] ?? '',
      tagSlugs: tagSlugs,
    );
  }

  static String _stripHtml(String html) =>
      html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
}

enum ArticleCategory { noticia, analisis, entrevista }
