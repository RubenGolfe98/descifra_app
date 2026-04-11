class ArticleDetail {
  final int id;
  final String title;
  final String content;
  final String author;
  final DateTime date;
  final String imageUrl;
  final bool isPremium;

  const ArticleDetail({
    required this.id,
    required this.title,
    required this.content,
    required this.author,
    required this.date,
    required this.imageUrl,
    required this.isPremium,
  });

  factory ArticleDetail.fromJson(Map<String, dynamic> json) {
    final classList = List<String>.from(json['class_list'] ?? []);
    return ArticleDetail(
      id: json['id'] as int,
      title: _strip(json['title']?['rendered'] ?? ''),
      content: json['content']?['rendered'] ?? '',
      author: json['yoast_head_json']?['author'] ?? '',
      date: DateTime.parse(json['date'] as String),
      imageUrl: json['jetpack_featured_media_url'] ?? '',
      isPremium: classList.contains('rcp-is-restricted'),
    );
  }

  static String _strip(String html) =>
      html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
}
