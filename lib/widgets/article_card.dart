import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/article.dart';
import '../services/tag_service.dart';
import '../services/theme_notifier.dart';
import '../theme/app_colors.dart';
import '../utils/access_helper.dart';
import '../utils/date_formatter.dart';
import 'content_card.dart';

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
    return ContentCard(
      imageUrl: article.imageUrl,
      imageSizes: article.imageSizes,
      title: article.title,
      description: article.description,
      meta: DateFormatter.short(article.date),
      badges: [
        ArticleCategoryBadge(category: article.category),
        for (final slug in article.tagSlugs) ArticleTagBadge(slug: slug),
        if (article.isPremium) const ArticlePremiumBadge(),
      ],
      onTap: () => _handleTap(context),
    );
  }
}

// ─── Badge de categoría ───────────────────────────────────────────────────────
class ArticleCategoryBadge extends StatelessWidget {
  final ArticleCategory category;

  const ArticleCategoryBadge({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeNotifier, bool>((t) => t.isDark);
    final Color bg;
    final Color fg;
    final String label;

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

    return CardBadge(label: label, background: bg, foreground: fg);
  }
}

// ─── Badge premium ────────────────────────────────────────────────────────────
class ArticlePremiumBadge extends StatelessWidget {
  const ArticlePremiumBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeNotifier, bool>((t) => t.isDark);
    return CardBadge(
      label: 'Exclusivo',
      background: AppColors.premiumBg(isDark),
      foreground: AppColors.premiumText(isDark),
      icon: Icons.lock_outline,
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
    final name = TagService.getTagName('tag-$slug');
    if (name == null) return const SizedBox.shrink();

    return CardBadge(
      label: name,
      background: AppColors.tagBg(isDark),
      foreground: AppColors.tagText(isDark),
    );
  }
}
