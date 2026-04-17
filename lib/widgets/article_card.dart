import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/article.dart';
import '../screens/article_detail_screen.dart';
import '../services/auth_notifier.dart';
import '../services/theme_notifier.dart';
import '../theme/app_colors.dart';
import 'paywall_dialog.dart';

/// Tarjeta de artículo reutilizable en todas las pantallas.
/// Gestiona internamente el tap, paywall y navegación al detalle.
class ArticleCard extends StatelessWidget {
  final Article article;
  final VoidCallback? onTap;

  const ArticleCard({super.key, required this.article, this.onTap});

  void _handleTap(BuildContext context) {
    if (onTap != null) {
      onTap!();
      return;
    }
    final auth = context.read<AuthNotifier>();
    final canAccess = !article.isPremium ||
        (auth.state.isLoggedIn && auth.state.isSubscriber);

    if (!canAccess) {
      showPaywallDialog(
        context,
        onLoginTap: () => TabNavigator.of(context)?.jumpToProfile(),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ArticleDetailScreen(article: article),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDark;
    return GestureDetector(
      onTap: () => _handleTap(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.bord(isDark), width: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: article.imageUrl,
                width: 100,
                height: 80,
                fit: BoxFit.cover,
                memCacheWidth: 200,
                fadeInDuration: const Duration(milliseconds: 150),
                placeholder: (_, __) => Container(width: 100, height: 80, color: AppColors.surf(isDark)),
                errorWidget: (_, __, ___) => Container(width: 100, height: 80, color: AppColors.surf(isDark)),
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
                    style: TextStyle(color: AppColors.textPri(isDark), fontSize: 13, fontWeight: FontWeight.w800, height: 1.35),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    article.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textSec(isDark), fontSize: 11, height: 1.4),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      ArticleCategoryBadge(category: article.category),
                      const SizedBox(width: 6),
                      Expanded(child: Text(article.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.textPri(isDark), fontSize: 10))),
                      if (article.isPremium) const ArticlePremiumBadge(),
                    ],
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

// ─── Badge de categoría ───────────────────────────────────────────────────────
class ArticleCategoryBadge extends StatelessWidget {
  final ArticleCategory category;
  const ArticleCategoryBadge({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final String label;

    switch (category) {
      case ArticleCategory.analisis:
        bg = AppColors.analysisBg;
        fg = AppColors.analysisText;
        label = 'Análisis';
      case ArticleCategory.entrevista:
        bg = AppColors.interviewBg;
        fg = AppColors.interviewText;
        label = 'Entrevista';
      case ArticleCategory.noticia:
        bg = AppColors.newsBg;
        fg = AppColors.newsText;
        label = 'Noticia';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 9,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ─── Badge premium ────────────────────────────────────────────────────────────
class ArticlePremiumBadge extends StatelessWidget {
  const ArticlePremiumBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.premiumBg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.lock_outline, color: AppColors.premiumText, size: 8),
          SizedBox(width: 3),
          Text('Exclusivo',
              style: TextStyle(color: AppColors.premiumText, fontSize: 9)),
        ],
      ),
    );
  }
}