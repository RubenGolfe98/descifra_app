import 'package:flutter/material.dart';
import '../repositories/article_repository.dart';
import 'category_articles_screen.dart';

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = ArticleRepository();
    return CategoryArticlesScreen(
      title: 'Análisis',
      emptyMessage: 'No hay más análisis',
      fetchArticles: ({perPage = 10, onRefreshed}) =>
          repo.fetchAnalysisArticles(perPage: perPage, onRefreshed: onRefreshed),
      fetchMoreArticles: ({required page, perPage = 10}) =>
          repo.fetchMoreAnalysisArticles(page: page, perPage: perPage),
    );
  }
}
