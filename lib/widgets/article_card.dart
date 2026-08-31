import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/article.dart';
import '../services/tag_service.dart';
import '../services/theme_notifier.dart';
import '../theme/app_colors.dart';
import '../utils/access_helper.dart';

/// Tarjeta de artículo reutilizable en todas las pantallas.
/// Gestiona internamente el tap, control de acceso y navegación al detalle.
class ArticleCard extends StatelessWidget {
  final Article article;
  final VoidCallback? onTap;

  const ArticleCard({super.key, required this.article, this.onTap});

  void _handleTap(BuildContext context) {
    if (onTap != null) {
      onTap!();
      return;
    }
    openArticle(context, article);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeNotifier, bool>((t) => t.isDark);
    final justified = context.select<ThemeNotifier, bool>((t) => t.justifiedText);
    return Material(
      type: MaterialType.card,
      elevation: 0,
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleTap(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(color: AppColors.bord(isDark), width: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: article.imageUrl,
                      width: 100,
                      height: 80,
                      fit: BoxFit.cover,
                      memCacheWidth: 300,
                      fadeInDuration: const Duration(milliseconds: 150),
                      placeholder: (_, __) => Container(
                          width: 100, height: 80, color: AppColors.surf(isDark)),
                      errorWidget: (_, __, ___) => Container(
                          width: 100, height: 80, color: AppColors.surf(isDark)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          article.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: justified ? TextAlign.justify : TextAlign.start,
                          style: TextStyle(
                              color: AppColors.textPri(isDark),
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              height: 1.35),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          article.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          textAlign: justified ? TextAlign.justify : TextAlign.start,
                          style: TextStyle(
                              color: AppColors.textSec(isDark),
                              fontSize: 11,
                              height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  ArticleCategoryBadge(category: article.category),
                  if (article.tagSlugs.isNotEmpty) const SizedBox(width: 6),
                  for (final slug in article.tagSlugs)
                    ArticleTagBadge(slug: slug),
                  const Spacer(),
                  if (article.isPremium) const ArticlePremiumBadge(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Badge de categoría ───────────────────────────────────────────────────────
class ArticleCategoryBadge extends StatelessWidget {
  final ArticleCategory category;
  final bool overlay;

  const ArticleCategoryBadge({
    super.key,
    required this.category,
    this.overlay = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeNotifier, bool>((t) => t.isDark);
    final justified = context.select<ThemeNotifier, bool>((t) => t.justifiedText);
    final Color bg;
    final Color fg;
    final String label;

    if (overlay) {
      switch (category) {
        case ArticleCategory.analisis:
          bg = const Color(0xFF185FA5);
          fg = Colors.white;
          label = 'Análisis';
        case ArticleCategory.entrevista:
          bg = const Color(0xFFA0522D);
          fg = Colors.white;
          label = 'Entrevista';
        case ArticleCategory.noticia:
          bg = const Color(0xFF1D9E75);
          fg = Colors.white;
          label = 'Noticia';
      }
    } else {
      switch (category) {
        case ArticleCategory.analisis:
          bg = AppColors.analysisBg(isDark);
          fg = AppColors.analysisText(isDark);
          label = 'Análisis';
        case ArticleCategory.entrevista:
          bg = AppColors.interviewBg(isDark);
          fg = AppColors.interviewText(isDark);
          label = 'Entrevista';
        case ArticleCategory.noticia:
          bg = AppColors.newsBg(isDark);
          fg = AppColors.newsText(isDark);
          label = 'Noticia';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        textAlign: justified ? TextAlign.justify : TextAlign.start,
        style: TextStyle(
          color: fg,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─── Badge premium ────────────────────────────────────────────────────────────
class ArticlePremiumBadge extends StatelessWidget {
  final bool overlay;

  const ArticlePremiumBadge({super.key, this.overlay = false});

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeNotifier, bool>((t) => t.isDark);
    final justified = context.select<ThemeNotifier, bool>((t) => t.justifiedText);

    final Color bg;
    final Color fg;
    if (overlay) {
      bg = const Color(0xFFC0392B);
      fg = Colors.white;
    } else {
      bg = AppColors.premiumBg(isDark);
      fg = AppColors.premiumText(isDark);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, color: fg, size: 8),
          const SizedBox(width: 3),
          Text('Exclusivo',
              textAlign: justified ? TextAlign.justify : TextAlign.start,
              style: TextStyle(
                  color: fg,
                  fontSize: 9,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ─── Badge de tag (país/tema) ─────────────────────────────────────────────────
class ArticleTagBadge extends StatelessWidget {
  final String slug;
  const ArticleTagBadge({super.key, required this.slug});

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeNotifier, bool>((t) => t.isDark);
    final justified = context.select<ThemeNotifier, bool>((t) => t.justifiedText);
    final name = TagService.getTagName('tag-$slug');
    if (name == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.tagBg(isDark),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        name,
        textAlign: justified ? TextAlign.justify : TextAlign.start,
        style: TextStyle(
          color: AppColors.tagText(isDark),
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
