import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../models/article.dart';
import '../repositories/article_repository.dart';
import '../services/theme_notifier.dart';
import '../theme/app_colors.dart';
import '../widgets/article_card.dart';
import '../widgets/access_dialog.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final _repository = ArticleRepository();
  final _scrollController = ScrollController();
  final _articles = <Article>[];

  late Future<List<Article>> _firstPageFuture;
  int _currentPage = 1;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _initialized = false;

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
    _firstPageFuture = _repository.fetchAnalysisArticles(
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
    final more = await _repository.fetchMoreAnalysisArticles(
      page: _currentPage + 1,
    );
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
      _initialized = false;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDark;
    return Scaffold(
      backgroundColor: AppColors.bg(isDark),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Text(
                'Análisis',
                style: TextStyle(
                  color: AppColors.textPri(isDark),
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Article>>(
                future: _firstPageFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      _articles.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFC0392B),
                        strokeWidth: 2,
                      ),
                    );
                  }

                  if (snapshot.hasError && _articles.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Error al cargar los análisis',
                              style: TextStyle(color: AppColors.textSec(isDark))),
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

                  if (!_initialized &&
                      snapshot.data != null &&
                      _articles.isEmpty) {
                    _initialized = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && _articles.isEmpty) {
                        setState(() => _articles.addAll(snapshot.data!));
                      }
                    });
                  }

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    color: AppColors.accent,
                    backgroundColor: const Color(0xFF1A1A1A),
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: _articles.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _articles.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: _isLoadingMore
                                ? const Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Color(0xFFC0392B),
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : _hasMore
                                    ? const SizedBox.shrink()
                                    : Center(
                                        child: Text(
                                          'No hay más análisis',
                                          style: TextStyle(
                                            color: AppColors.textMut(isDark),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                          );
                        }
                        return ArticleCard(article: _articles[index]);
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