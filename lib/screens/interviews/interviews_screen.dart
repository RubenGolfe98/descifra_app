import 'package:flutter/material.dart';
import '../../repositories/article_repository.dart';
import '../articles/category_articles_screen.dart';

class InterviewsScreen extends StatelessWidget {
  const InterviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = ArticleRepository();
    return CategoryArticlesScreen(
      title: 'Entrevistas',
      emptyMessage: 'No hay más entrevistas',
      fetchArticles: ({perPage = 10, onRefreshed}) =>
          repo.fetchInterviewArticles(perPage: perPage, onRefreshed: onRefreshed),
      fetchMoreArticles: ({required page, perPage = 10}) =>
          repo.fetchMoreInterviewArticles(page: page, perPage: perPage),
    );
  }
}
