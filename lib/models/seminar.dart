class Seminar {
  final int id;
  final String title;
  final String description;
  final String coverUrl;
  final Map<int, String> imageSizes; // ancho(px) → URL (tamaños generados por WP)
  final String link;
  final bool isPremium;
  final String contentHtml;

  const Seminar({
    required this.id,
    required this.title,
    required this.description,
    required this.coverUrl,
    this.imageSizes = const {},
    required this.link,
    this.isPremium = false,
    this.contentHtml = '',
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
      imageSizes: _parseImageSizes(json),
      link: json['link'] ?? '',
      isPremium: classList.contains('rcp-is-restricted'),
      contentHtml: json['content']?['rendered'] ?? '',
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
