class Seminar {
  final int id;
  final String title;
  final String description;
  final String coverUrl;
  final String link;
  final bool isPremium;

  const Seminar({
    required this.id,
    required this.title,
    required this.description,
    required this.coverUrl,
    required this.link,
    this.isPremium = false,
  });

  factory Seminar.fromJson(Map<String, dynamic> json) {
    final ogImages = json['yoast_head_json']?['og_image'] as List?;
    final coverUrl = ogImages != null && ogImages.isNotEmpty
        ? ogImages[0]['url'] as String? ?? ''
        : '';
    final classList = List<String>.from(json['class_list'] ?? []);

    return Seminar(
      id: json['id'] as int,
      title: _stripHtml(json['title']?['rendered'] ?? ''),
      description: json['yoast_head_json']?['og_description'] ?? '',
      coverUrl: coverUrl,
      link: json['link'] ?? '',
      isPremium: classList.contains('rcp-is-restricted'),
    );
  }

  static String _stripHtml(String html) =>
      html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
}

class SeminarSession {
  final String title;
  final String url;
  final bool isActive;

  const SeminarSession({
    required this.title,
    required this.url,
    this.isActive = false,
  });
}

class SeminarSessionDetail {
  final String title;
  final String vimeoUrl;
  final String description;
  final List<SeminarMaterial> materials;
  final List<SeminarSession> allSessions;

  const SeminarSessionDetail({
    required this.title,
    required this.vimeoUrl,
    required this.description,
    required this.materials,
    required this.allSessions,
  });
}

class SeminarMaterial {
  final String name;
  final String url;

  const SeminarMaterial({required this.name, required this.url});
}
