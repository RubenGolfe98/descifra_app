import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/article.dart';
import '../repositories/article_repository.dart';
import '../services/auth_notifier.dart';
import 'article_detail_screen.dart';
import 'paywall_dialog.dart';

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
        if (more.isEmpty) {
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
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Text(
                'Análisis',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // Lista
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
                          const Text('Error al cargar los análisis',
                              style: TextStyle(color: Color(0xFF888888))),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _refresh,
                            child: const Text('Reintentar',
                                style: TextStyle(color: Color(0xFFC0392B))),
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
                    color: const Color(0xFFC0392B),
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
                                    : const Center(
                                        child: Text(
                                          'No hay más análisis',
                                          style: TextStyle(
                                            color: Color(0xFF555555),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                          );
                        }
                        return _AnalysisCard(article: _articles[index]);
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

class _AnalysisCard extends StatelessWidget {
  final Article article;
  const _AnalysisCard({required this.article});

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFF242424), width: 0.5),
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
                width: 90,
                height: 72,
                fit: BoxFit.cover,
                memCacheWidth: 180,
                placeholder: (_, __) => Container(
                  width: 90,
                  height: 72,
                  color: const Color(0xFF1A1A1A),
                ),
                errorWidget: (_, __, ___) => Container(
                  width: 90,
                  height: 72,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    article.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF888888),
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          article.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF555555),
                            fontSize: 10,
                          ),
                        ),
                      ),
                      if (article.isPremium)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x33C0392B),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.lock_outline,
                                  color: Color(0xFFE57A72), size: 8),
                              SizedBox(width: 3),
                              Text(
                                'Premium',
                                style: TextStyle(
                                  color: Color(0xFFE57A72),
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
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
