import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../models/article.dart';
import '../models/region.dart';
import '../repositories/article_repository.dart';
import '../services/theme_notifier.dart';
import '../theme/app_colors.dart';
import '../widgets/article_card.dart';

class RegionArticlesScreen extends StatefulWidget {
  final Region region;
  const RegionArticlesScreen({super.key, required this.region});

  @override
  State<RegionArticlesScreen> createState() => _RegionArticlesScreenState();
}

class _RegionArticlesScreenState extends State<RegionArticlesScreen> {
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
    _firstPageFuture = _repository.fetchArticlesByRegion(
      widget.region.id,
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
    final more = await _repository.fetchMoreArticlesByRegion(
      regionId: widget.region.id,
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
      _articles.clear();
      _currentPage = 1;
      _hasMore = true;
      _initialized = false;
      _load();
    });
    await _firstPageFuture;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDark;
    final bg   = AppColors.bg(isDark);
    final surf = AppColors.surf(isDark);
    final pri  = AppColors.textPri(isDark);
    final sec  = AppColors.textSec(isDark);
    final mut  = AppColors.textMut(isDark);

    return Scaffold(
      backgroundColor: bg,
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.accent,
        backgroundColor: surf,
        child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: surf,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: pri, size: 18),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: SvgPicture.network(
                      widget.region.imageUrl,
                      fit: BoxFit.contain,
                      colorFilter: const ColorFilter.mode(Color(0x44C0392B), BlendMode.srcIn),
                      placeholderBuilder: (_) => const SizedBox.shrink(),
                    ),
                  ),
                  Positioned(
                    bottom: 16, left: 20, right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.region.name,
                          style: TextStyle(color: pri, fontSize: 20, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${widget.region.count} artículos',
                          style: TextStyle(color: pri, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          FutureBuilder<List<Article>>(
            future: _firstPageFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && _articles.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
                  ),
                );
              }
              if (snapshot.hasError && _articles.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text('Error al cargar artículos', style: TextStyle(color: sec)),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => setState(_load),
                          child: const Text('Reintentar', style: TextStyle(color: AppColors.accent)),
                        ),
                      ],
                    ),
                  ),
                );
              }
              if (!_initialized && snapshot.data != null && _articles.isEmpty) {
                _initialized = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _articles.isEmpty) setState(() => _articles.addAll(snapshot.data!));
                });
              }
              if (_articles.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('No hay artículos en esta región', style: TextStyle(color: sec)),
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => ArticleCard(article: _articles[index]),
                  childCount: _articles.length,
                ),
              );
            },
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: _isLoadingMore
                  ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)))
                  : _hasMore
                      ? const SizedBox.shrink()
                      : Center(child: Text('No hay más artículos', style: TextStyle(color: mut, fontSize: 12))),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
        ),
      ),
    );
  }
}