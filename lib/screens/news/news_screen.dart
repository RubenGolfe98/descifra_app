import 'package:flutter/material.dart';
import '../../repositories/article_repository.dart';
import '../articles/category_articles_screen.dart';

class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = ArticleRepository();
    return CategoryArticlesScreen(
      title: 'Noticias',
      emptyMessage: 'No hay más noticias',
      fetchArticles: ({perPage = 10, onRefreshed}) =>
          repo.fetchNewsArticles(perPage: perPage, onRefreshed: onRefreshed),
      fetchMoreArticles: ({required page, perPage = 10}) =>
          repo.fetchMoreNewsArticles(page: page, perPage: perPage),
    );
  }
}
