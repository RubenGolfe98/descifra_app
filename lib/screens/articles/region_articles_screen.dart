import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../models/article.dart';
import '../../models/region.dart';
import '../../repositories/article_repository.dart';
import '../../services/theme_notifier.dart';
import '../../theme/app_colors.dart';
import '../../utils/article_list_merge.dart';
import '../../widgets/appear_animation.dart';
import '../../widgets/article_card.dart';
import '../../widgets/bounce_on_tap.dart';

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
    _firstPageFuture = _repository.fetchArticlesByRegion(
      widget.region.id,
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
    final bg = AppColors.bg(isDark);
    final surf = AppColors.surf(isDark);
    final pri = AppColors.textPri(isDark);
    final sec = AppColors.textSec(isDark);
    final mut = AppColors.textMut(isDark);

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
              leading: BounceOnTap(
                child: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new, color: pri, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: SvgPicture.asset(
                        widget.region.imageUrl,
                        fit: BoxFit.contain,
                        colorFilter: const ColorFilter.mode(
                            AppColors.accent, BlendMode.srcIn),
                      ),
                    ),
                    Positioned(
                      bottom: 16,
                      left: 20,
                      right: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.region.name,
                            style: TextStyle(
                                color: pri,
                                fontSize: 20,
                                fontWeight: FontWeight.w600),
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
                if (snapshot.connectionState == ConnectionState.waiting &&
                    _articles.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.accent, strokeWidth: 2)),
                    ),
                  );
                }
                if (snapshot.hasError && _articles.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Text('Error al cargar artículos',
                              style: TextStyle(color: sec)),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => setState(_load),
                            child: const Text('Reintentar',
                                style: TextStyle(color: AppColors.accent)),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (snapshot.hasData && _articles.isEmpty) {
                  _absorbFresh(snapshot.data!);
                }
                final displayArticles = _articles;
                if (displayArticles.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('No hay artículos en esta región',
                          style: TextStyle(color: sec)),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final article = displayArticles[index];
                        return AppearAnimation(
                          key: ValueKey(article.id),
                          animate: _justAdded.contains(article.id),
                          expand: !_staggered,
                          delay: _staggered
                              ? AppearAnimation.staggerDelay(index)
                              : Duration.zero,
                          child: Padding(
                            padding: EdgeInsets.only(
                                bottom: index == displayArticles.length - 1
                                    ? 0
                                    : 12),
                            child: ArticleCard(article: article),
                          ),
                        );
                      },
                      childCount: displayArticles.length,
                      findChildIndexCallback: (key) {
                        if (key is! ValueKey<int>) return null;
                        final id = key.value;
                        final i = displayArticles.indexWhere((a) => a.id == id);
                        return i < 0 ? null : i;
                      },
                    ),
                  ),
                );
              },
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: _isLoadingMore
                    ? const Center(
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: AppColors.accent, strokeWidth: 2)))
                    : _hasMore
                        ? const SizedBox.shrink()
                        : Center(
                            child: Text('No hay más artículos',
                                style: TextStyle(color: mut, fontSize: 12))),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}
