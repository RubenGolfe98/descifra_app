class Article {
  final int id;
  final String title;
  final String excerpt;
  String content;
  final DateTime date;
  final int featuredMediaId;
  String? imageUrl;

  Article({
    required this.id,
    required this.title,
    required this.excerpt,
    this.content = "",
    required this.date,
    required this.featuredMediaId,
    this.imageUrl,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    String img = "";
    
    // Extraemos la URL de la imagen que viene "incrustada"
    try {
      if (json['_embedded'] != null && json['_embedded']['wp:featuredmedia'] != null) {
        // Intentamos pillar la versión 'medium' para velocidad, si no la original
        var sizes = json['_embedded']['wp:featuredmedia'][0]['media_details']['sizes'];
        img = sizes['medium']?['source_url'] ?? json['_embedded']['wp:featuredmedia'][0]['source_url'];
      }
    } catch (e) {
      img = "https://via.placeholder.com/400x200?text=DLG";
    }

    return Article(
      id: json['id'],
      title: json['title']['rendered'] ?? "Sin título",
      excerpt: _cleanHtml(json['excerpt']['rendered'] ?? ""),
      date: DateTime.parse(json['date']),
      featuredMediaId: json['featured_media'] ?? 0,
      imageUrl: img
    );
  }

  static String _cleanHtml(String html) {
    // Esta función elimina etiquetas HTML como <p> o <strong>
    return html
        .replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ')
        .trim();
  }
}