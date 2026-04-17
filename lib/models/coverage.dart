class Coverage {
  final int id;
  final String title;
  final String slug;
  final String link;
  final String imageUrl;
  final String description;

  const Coverage({
    required this.id,
    required this.title,
    required this.slug,
    required this.link,
    required this.imageUrl,
    required this.description,
  });

  factory Coverage.fromJson(Map<String, dynamic> json) {
    final ogImages = json['yoast_head_json']?['og_image'] as List?;
    final imageUrl = ogImages != null && ogImages.isNotEmpty
        ? ogImages[0]['url'] as String? ?? ''
        : '';

    return Coverage(
      id: json['id'] as int,
      title: _stripHtml(json['title']?['rendered'] ?? ''),
      slug: json['slug'] ?? '',
      link: json['link'] ?? '',
      imageUrl: imageUrl,
      description: json['yoast_head_json']?['description'] ?? '',
    );
  }

  static String _stripHtml(String html) =>
      html.replaceAll(RegExp(r'<[^>]*>'), '').trim();

}


class CoverageDetail {
  final int id;
  final String title;
  final String slug;
  final String link;
  final String imageUrl;
  final String description;
  final String contentHtml;

  const CoverageDetail({
    required this.id,
    required this.title,
    required this.slug,
    required this.link,
    required this.imageUrl,
    required this.description,
    required this.contentHtml,
  });

  factory CoverageDetail.fromJson(Map<String, dynamic> json) {
    final ogImages = json['yoast_head_json']?['og_image'] as List?;
    final imageUrl = ogImages != null && ogImages.isNotEmpty
        ? ogImages[0]['url'] as String? ?? ''
        : '';

    return CoverageDetail(
      id: json['id'] as int,
      title: _stripHtml(json['title']?['rendered'] ?? ''),
      slug: json['slug'] ?? '',
      link: json['link'] ?? '',
      imageUrl: imageUrl,
      description: json['yoast_head_json']?['description'] ?? '',
      contentHtml: json['content']?['rendered'] ?? '',
    );
  }

  static String _stripHtml(String html) =>
      html.replaceAll(RegExp(r'<[^>]*>'), '').trim();

}