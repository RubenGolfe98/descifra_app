class MapImage {
  final String url;       // URL de la imagen completa
  final String thumbUrl;  // URL del thumbnail 300x300
  final String alt;       // Texto alternativo / descripción

  const MapImage({
    required this.url,
    required this.thumbUrl,
    required this.alt,
  });
}
