import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/article.dart';
import '../screens/article_detail_screen.dart';
import '../services/auth_notifier.dart';
import '../theme/app_colors.dart';
import 'paywall_dialog.dart';

/// Tarjeta de artículo reutilizable en todas las pantallas.
/// Gestiona internamente el tap, paywall y navegación al detalle.
class ArticleCard extends StatelessWidget {
  final Article article;

  const ArticleCard({super.key, required this.article});

  void _handleTap(BuildContext context) {
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
    return GestureDetector(
      onTap: () => _handleTap(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.border, width: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: article.imageUrl,
                width: 80,
                height: 64,
                fit: BoxFit.cover,
                memCacheWidth: 160,
                fadeInDuration: const Duration(milliseconds: 150),
                placeholder: (_, __) => Container(
                  width: 80,
                  height: 64,
                  color: AppColors.surface,
                ),
                errorWidget: (_, __, ___) => Container(
                  width: 80,
                  height: 64,
                  color: AppColors.surface,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Contenido
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    article.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      ArticleCategoryBadge(category: article.category),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          article.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ),
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
    final isAnalysis = category == ArticleCategory.analisis;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: isAnalysis ? AppColors.analysisBg : AppColors.newsBg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isAnalysis ? 'Análisis' : 'Noticia',
        style: TextStyle(
          color: isAnalysis ? AppColors.analysisText : AppColors.newsText,
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
          Text('Premium',
              style: TextStyle(color: AppColors.premiumText, fontSize: 9)),
        ],
      ),
    );
  }
}