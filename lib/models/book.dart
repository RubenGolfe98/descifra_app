class Book {
  final int id;
  final String title;
  final String description;
  final String coverUrl;
  final String contentHtml;
  final String link;
  final String publishDate;
  final List<String> authors;
  final String editorial;
  final String amazonUrl;
  final String amazonKindleUrl;

  const Book({
    required this.id,
    required this.title,
    required this.description,
    required this.coverUrl,
    required this.contentHtml,
    required this.link,
    this.publishDate = '',
    this.authors = const [],
    this.editorial = '',
    this.amazonUrl = '',
    this.amazonKindleUrl = '',
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    final ogImages = json['yoast_head_json']?['og_image'] as List?;
    final coverUrl = ogImages != null && ogImages.isNotEmpty
        ? ogImages[0]['url'] as String? ?? ''
        : '';
    return Book(
      id: json['id'] as int,
      title: _stripHtml(json['title']?['rendered'] ?? ''),
      description: json['yoast_head_json']?['og_description'] ?? '',
      coverUrl: coverUrl,
      contentHtml: json['content']?['rendered'] ?? '',
      link: json['link'] ?? '',
    );
  }

  Book withFicha({
    required String publishDate,
    required List<String> authors,
    required String editorial,
    required String amazonUrl,
    required String amazonKindleUrl,
  }) => Book(
    id: id, title: title, description: description,
    coverUrl: coverUrl, contentHtml: contentHtml, link: link,
    publishDate: publishDate, authors: authors, editorial: editorial,
    amazonUrl: amazonUrl, amazonKindleUrl: amazonKindleUrl,
  );

  static String _stripHtml(String html) =>
      html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
}