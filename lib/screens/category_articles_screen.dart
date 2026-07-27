import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/article.dart';
import '../services/theme_notifier.dart';
import '../theme/app_colors.dart';
import '../widgets/article_card.dart';

class CategoryArticlesScreen extends StatefulWidget {
  final String title;
  final String emptyMessage;
  final Future<List<Article>> Function({
    int perPage,
    void Function(List<Article>)? onRefreshed,
  }) fetchArticles;
  final Future<List<Article>?> Function({
    required int page,
    int perPage,
  }) fetchMoreArticles;

  const CategoryArticlesScreen({
    super.key,
    required this.title,
    this.emptyMessage = 'No hay más artículos',
    required this.fetchArticles,
    required this.fetchMoreArticles,
  });

  @override
  State<CategoryArticlesScreen> createState() => _CategoryArticlesScreenState();
}

class _CategoryArticlesScreenState extends State<CategoryArticlesScreen> {
  final _scrollController = ScrollController();
  final _articles = <Article>[];

  late Future<List<Article>> _firstPageFuture;
  int _currentPage = 1;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _load() {
    _firstPageFuture = widget.fetchArticles(
      onRefreshed: (fresh) {
        if (mounted) {
          setState(() {
            _articles
              ..clear()
              ..addAll(fresh);
          });
        }
      },
    );
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadNextPage();
    }
  }

  Future<void> _loadNextPage() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    final more = await widget.fetchMoreArticles(page: _currentPage + 1);
    if (mounted) {
      setState(() {
        if (more == null) {
          // error de red — no marcar fin
        } else if (more.isEmpty) {
          _hasMore = false;
        } else {
          _articles.addAll(more);
          _currentPage++;
        }
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _currentPage = 1;
      _hasMore = true;
      _articles.clear();
      _load();
    });
    await _firstPageFuture;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeNotifier, bool>((t) => t.isDark);
    return Scaffold(
      backgroundColor: AppColors.bg(isDark),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                border: Border(
                    bottom:
                        BorderSide(color: AppColors.bord(isDark), width: 0.5)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new,
                        color: AppColors.textPri(isDark), size: 18),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text(
                    widget.title,
                    style: TextStyle(
                      color: AppColors.textPri(isDark),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Article>>(
                future: _firstPageFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      _articles.isEmpty) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accent,
                        strokeWidth: 2,
                      ),
                    );
                  }

                  if (snapshot.hasError && _articles.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Error al cargar',
                              style:
                                  TextStyle(color: AppColors.textSec(isDark))),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _refresh,
                            child: const Text('Reintentar',
                                style: TextStyle(color: AppColors.accent)),
                          ),
                        ],
                      ),
                    );
                  }

                  if (snapshot.hasData && _articles.isEmpty) {
                    _articles.addAll(snapshot.data!);
                  }
                  final displayArticles = _articles;

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    color: AppColors.accent,
                    backgroundColor: AppColors.surf(isDark),
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: displayArticles.length + 1,
                      itemBuilder: (context, index) {
                        if (index == displayArticles.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: _isLoadingMore
                                ? Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: AppColors.accent,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : _hasMore
                                    ? const SizedBox.shrink()
                                    : Center(
                                        child: Text(
                                          widget.emptyMessage,
                                          style: TextStyle(
                                            color: AppColors.textMut(isDark),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                          );
                        }
                        return ArticleCard(article: displayArticles[index]);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
