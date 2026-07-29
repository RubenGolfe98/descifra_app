import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/article.dart';
import '../screens/articles/article_detail_screen.dart';
import '../services/auth_notifier.dart';
import '../widgets/access_dialog.dart';

void openArticle(BuildContext context, Article article) {
  final auth = context.read<AuthNotifier>();
  final canAccess = !article.isPremium ||
      (auth.state.isLoggedIn && auth.state.isSubscriber);

  if (!canAccess) {
    showAccessDialog(
      context,
      onLoginTap: () => TabNavigator.of(context)?.jumpToProfile(),
      source: 'article',
    );
    return;
  }

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ArticleDetailScreen(article: article),
    ),
  );
}
