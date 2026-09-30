import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/map_image.dart';
import '../utils/image_url.dart';

/// Celda de un grid de mapas: descarga el mapa a resolución completa (la misma
/// URL que abre el visor, que así abre al instante desde caché) y lo decodifica
/// al tamaño físico real de la celda. Si falla, recurre a la miniatura.
class MapGridImage extends StatelessWidget {
  final MapImage map;
  final Color background;
  final Color iconColor;

  const MapGridImage({
    super.key,
    required this.map,
    required this.background,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cacheWidth =
            imageCacheWidth(context, width: constraints.maxWidth);
        return CachedNetworkImage(
          imageUrl: map.url,
          fit: BoxFit.cover,
          memCacheWidth: cacheWidth,
          placeholder: (_, __) => Container(color: background),
          errorWidget: (_, __, ___) => CachedNetworkImage(
            imageUrl: map.thumbUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: background),
            errorWidget: (_, __, ___) => Container(
              color: background,
              child: Icon(Icons.map_outlined, color: iconColor, size: 32),
            ),
          ),
        );
      },
    );
  }
}
