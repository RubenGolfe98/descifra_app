import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/article.dart';
import '../../services/theme_notifier.dart';
import '../../theme/app_colors.dart';
import '../../utils/article_list_merge.dart';
import '../../widgets/appear_animation.dart';
import '../../widgets/article_card.dart';

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

  // Ids añadidos en el último refresco, que entran con animación
  Set<int> _justAdded = {};
  bool _staggered = false;

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
        if (mounted) _mergeFresh(fresh);
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
          appendNewArticles(_articles, more);
          _currentPage++;
        }
        _isLoadingMore = false;
      });
    }
  }

  /// Pull-to-refresh: mantiene los cards visibles y solo anima los nuevos.
  Future<void> _refresh() async {
    if (_articles.isEmpty) {
      setState(_load);
      await _firstPageFuture;
      return;
    }
    _load();
    final result = await _firstPageFuture;
    if (mounted && result.isNotEmpty) _mergeFresh(result);
  }

  void _mergeFresh(List<Article> fresh) => setState(() => _absorbFresh(fresh));

  /// Fusiona sin setState (en la carga inicial se llama desde build). Si el
  /// listado estaba vacío, todos los cards entran escalonados.
  void _absorbFresh(List<Article> fresh) {
    final wasEmpty = _articles.isEmpty;
    final added = mergeFreshArticles(_articles, fresh);
    if (added.isEmpty) return;
    _justAdded = added;
    _staggered = wasEmpty;
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _justAdded = {});
    });
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
                    _absorbFresh(snapshot.data!);
                  }
                  final displayArticles = _articles;

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    color: AppColors.accent,
                    backgroundColor: AppColors.surf(isDark),
                    child: ListView.separated(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: displayArticles.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        if (index == displayArticles.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
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
                        final article = displayArticles[index];
                        return AppearAnimation(
                          key: ValueKey(article.id),
                          animate: _justAdded.contains(article.id),
                          expand: !_staggered,
                          delay: _staggered
                              ? AppearAnimation.staggerDelay(index)
                              : Duration.zero,
                          child: ArticleCard(article: article),
                        );
                      },
                      findItemIndexCallback: (key) {
                        if (key is! ValueKey<int>) return null;
                        final i = displayArticles
                            .indexWhere((a) => a.id == key.value);
                        return i < 0 ? null : i;
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
