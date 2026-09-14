import 'package:flutter/widgets.dart';

/// Ancho de decodificación (píxeles físicos) para una imagen mostrada con
/// [width] píxeles lógicos (o a ancho de pantalla si no se indica).
///
/// Se usa como `memCacheWidth` de `CachedNetworkImage`: la imagen se decodifica
/// a la resolución exacta que la pantalla puede mostrar — ni más (memoria) ni
/// menos (borrosidad). El clamp superior evita bitmaps absurdos en pantallas
/// externas; el decoder de Flutter nunca upscalea más allá del original.
int imageCacheWidth(BuildContext context, {double? width}) {
  final dpr = MediaQuery.of(context).devicePixelRatio;
  final logical = width ?? MediaQuery.of(context).size.width;
  final px = (logical * dpr).round();
  return px > 2560 ? 2560 : px;
}

/// Elige la URL del tamaño generado por WordPress más adecuado para
/// [targetWidth] píxeles físicos: el menor tamaño que lo cubre, o el original
/// ([fallbackUrl]) si ninguno llega. Garantiza nitidez con el mínimo peso.
///
/// [sizes] es un mapa ancho(px) → URL, parseado de
/// `_embedded.wp:featuredmedia[0].media_details.sizes`.
String bestImageUrl({
  required Map<int, String> sizes,
  required String fallbackUrl,
  required int targetWidth,
}) {
  if (sizes.isEmpty) return fallbackUrl;
  final widths = sizes.keys.toList()..sort();
  for (final w in widths) {
    if (w >= targetWidth) return sizes[w]!;
  }
  return fallbackUrl;
}
