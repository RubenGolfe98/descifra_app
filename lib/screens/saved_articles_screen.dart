import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_notifier.dart';
import '../services/favorites_service.dart';
import '../services/theme_notifier.dart';
import '../theme/app_colors.dart';
import '../widgets/article_card.dart';

class SavedArticlesScreen extends StatelessWidget {
  const SavedArticlesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDark;
    final auth = context.watch<AuthNotifier>();
    final favorites = context.watch<FavoritesService>();
    final pri = AppColors.textPri(isDark);
    final sec = AppColors.textSec(isDark);

    return Scaffold(
      backgroundColor: AppColors.bg(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.surf(isDark),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: pri, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Guardados',
            style: TextStyle(color: pri, fontSize: 16, fontWeight: FontWeight.w600)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Divider(height: 0.5, color: AppColors.bord(isDark)),
        ),

      ),
      body: !favorites.loaded
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2))
          : favorites.savedArticles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bookmark_outline,
                          color: AppColors.textMut(isDark), size: 48),
                      const SizedBox(height: 12),
                      Text('No tienes artículos guardados',
                          style: TextStyle(color: sec, fontSize: 15)),
                      const SizedBox(height: 6),
                      Text('Pulsa el marcador en cualquier artículo para guardarlo',
                          style: TextStyle(color: AppColors.textMut(isDark), fontSize: 12),
                          textAlign: TextAlign.center),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => favorites.loadFavorites(auth.state.cookies ?? ''),
                  color: AppColors.accent,
                  backgroundColor: AppColors.surf(isDark),
                  child: ListView.builder(
                    itemCount: favorites.savedArticles.length,
                    itemBuilder: (context, index) =>
                        ArticleCard(article: favorites.savedArticles[index]),
                  ),
                ),
    );
  }
}