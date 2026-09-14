import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_notifier.dart';
import '../theme/app_colors.dart';
import '../utils/image_url.dart';

/// Tarjeta de contenido unificada (estilo seminarios) para todos los listados.
/// Imagen de portada opcional, badges, título y descripción sin límites de
/// caracteres, y meta opcional. Reutilizable para cualquier tipo de contenido.
class ContentCard extends StatelessWidget {
  final String imageUrl;
  final Map<int, String> imageSizes;
  final String title;
  final String description;
  final VoidCallback onTap;
  final List<Widget> badges;
  final String? meta;

  const ContentCard({
    super.key,
    required this.imageUrl,
    this.imageSizes = const {},
    required this.title,
    required this.description,
    required this.onTap,
    this.badges = const [],
    this.meta,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeNotifier, bool>((t) => t.isDark);
    final justified =
        context.select<ThemeNotifier, bool>((t) => t.justifiedText);
    final align = justified ? TextAlign.justify : TextAlign.start;
    final radius = BorderRadius.circular(12);

    return Material(
      elevation: 0,
      color: AppColors.surf(isDark),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: AppColors.bord(isDark), width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl.isNotEmpty)
              _CoverImage(url: imageUrl, sizes: imageSizes, isDark: isDark),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (badges.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: badges,
                      ),
                    ),
                  Text(
                    title,
                    textAlign: align,
                    style: TextStyle(
                      color: AppColors.textPri(isDark),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  if (description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        description,
                        textAlign: align,
                        style: TextStyle(
                          color: AppColors.textSec(isDark),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  if (meta != null && meta!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        meta!,
                        style: TextStyle(
                          color: AppColors.textMut(isDark),
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Imagen de portada del card. Descarga el tamaño generado por WordPress más
/// adecuado para la pantalla y decodifica a la resolución física exacta.
class _CoverImage extends StatelessWidget {
  final String url;
  final Map<int, String> sizes;
  final bool isDark;

  const _CoverImage(
      {required this.url, required this.sizes, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cacheWidth = imageCacheWidth(context);
    final resolvedUrl = bestImageUrl(
        sizes: sizes, fallbackUrl: url, targetWidth: cacheWidth);
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: CachedNetworkImage(
        imageUrl: resolvedUrl,
        width: double.infinity,
        fit: BoxFit.cover,
        memCacheWidth: cacheWidth,
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (_, __) => Container(color: AppColors.surf(isDark)),
        errorWidget: (_, __, ___) => Container(
          color: AppColors.surf(isDark),
          child: Icon(Icons.image_not_supported,
              color: AppColors.textMut(isDark), size: 20),
        ),
      ),
    );
  }
}

/// Badge unificado para cards: categoría, tags, premium, destacado, etc.
class CardBadge extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;

  const CardBadge({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      style: TextStyle(
        color: foreground,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: icon == null
          ? text
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: foreground, size: 10),
                const SizedBox(width: 3),
                text,
              ],
            ),
    );
  }
}
