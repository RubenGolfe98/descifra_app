import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/article.dart';
import '../../repositories/article_repository.dart';
import '../../services/theme_notifier.dart';
import '../../theme/app_colors.dart';
import '../../utils/access_helper.dart';
import '../../utils/date_formatter.dart';
import '../../utils/image_url.dart';
import '../../widgets/article_card.dart';
import '../../widgets/content_card.dart';
import '../search/search_screen.dart';

// ─── Pantalla principal ───────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repository = ArticleRepository();
  final _scrollController = ScrollController();
  final _articles = <Article>[];

  late Future<List<Article>> _firstPageFuture;
  int _currentPage = 1;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _initialized = false;

  // Estado del banner de refresco
  _RefreshStatus _refreshStatus = _RefreshStatus.idle;
  VoidCallback? _scrollListener;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollListener = () {
        final notifier = context.read<ValueNotifier<int?>>();
        if (notifier.value == 0 && mounted) {
          _scrollController.animateTo(0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut);
        }
      };
      context.read<ValueNotifier<int?>>().addListener(_scrollListener!);
    });
    _firstPageFuture = _repository.fetchLatestArticles(
      onBackgroundRefreshStarted: () {
        if (mounted) setState(() => _refreshStatus = _RefreshStatus.refreshing);
      },
      onBackgroundRefreshFailed: () {
        if (mounted) {
          setState(() => _refreshStatus = _RefreshStatus.idle);
        }
      },
      onRefreshed: (fresh) {
        if (mounted) {
          final hasNewContent = fresh.isNotEmpty &&
              (_articles.isEmpty || fresh.first.id != _articles.first.id);
          setState(() {
            _articles
              ..clear()
              ..addAll(fresh);
            _refreshStatus = hasNewContent
                ? _RefreshStatus.updated
                : _RefreshStatus.upToDate;
          });
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) setState(() => _refreshStatus = _RefreshStatus.idle);
          });
        }
      },
    );
  }

  @override
  void dispose() {
    if (_scrollListener != null) {
      try {
        context.read<ValueNotifier<int?>>().removeListener(_scrollListener!);
      } catch (_) {}
    }
    _scrollController.dispose();
    super.dispose();
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
    final more = await _repository.fetchMoreArticles(page: _currentPage + 1);
    if (mounted) {
      setState(() {
        if (more == null) {
          // Error de red — no marcar fin, permitir reintentar
          if (kDebugMode) {
            debugPrint(
                '📦 [Home] Error cargando página ${_currentPage + 1} — manteniendo hasMore');
          }
        } else if (more.isEmpty) {
          _hasMore = false; // fin real del listado
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
      _firstPageFuture = _repository.fetchLatestArticles();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeNotifier, bool>((t) => t.isDark);
    return Scaffold(
      backgroundColor: AppColors.bg(isDark),
      body: SafeArea(
        child: Column(
          children: [
            _AppHeader(isDark: isDark),
            _RefreshBanner(status: _refreshStatus, isDark: isDark),
            Expanded(
              child: FutureBuilder<List<Article>>(
                future: _firstPageFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      _articles.isEmpty) {
                    return _LoadingView(isDark: isDark);
                  }
                  if (snapshot.hasError && _articles.isEmpty) {
                    return _ErrorView(onRetry: _refresh, isDark: isDark);
                  }
                  if (!_initialized && snapshot.data != null) {
                    _initialized = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && _articles.isEmpty) {
                        setState(() => _articles.addAll(snapshot.data!));
                      }
                    });
                  }
                  return _ArticleFeed(
                    articles: _articles,
                    onRefresh: _refresh,
                    scrollController: _scrollController,
                    isLoadingMore: _isLoadingMore,
                    hasMore: _hasMore,
                    isDark: isDark,
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

// ─── Header ───────────────────────────────────────────────────────────────────
class _AppHeader extends StatelessWidget {
  final bool isDark;
  const _AppHeader({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: AppColors.bord(isDark), width: 0.5)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Centro — logo + título
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipOval(
                  child: Image.asset(
                    isDark
                        ? 'assets/images/logo_dlg_dark.png'
                        : 'assets/images/logo_dlg.png',
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
                MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.noScaling,
                  ),
                  child: Text(
                    'DESCIFRANDO LA GUERRA',
                    style: context.read<ThemeNotifier>().font.style(
                          color: AppColors.accent,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                  ),
                ),
              ],
            ),
            // Derecha — lupa
            Positioned(
              right: 0,
              child: IconButton(
                icon:
                    const Icon(Icons.search, color: AppColors.accent, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SearchScreen()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Feed ─────────────────────────────────────────────────────────────────────
class _ArticleFeed extends StatelessWidget {
  final List<Article> articles;
  final Future<void> Function() onRefresh;
  final ScrollController scrollController;
  final bool isLoadingMore;
  final bool hasMore;
  final bool isDark;

  const _ArticleFeed({
    required this.articles,
    required this.onRefresh,
    required this.scrollController,
    required this.isLoadingMore,
    required this.hasMore,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (articles.isEmpty) {
      return Center(
        child: Text('No hay noticias disponibles',
            style: TextStyle(color: AppColors.textSec(isDark))),
      );
    }

    final rest = articles.skip(1).toList();

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.accent,
      backgroundColor: AppColors.surf(isDark),
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: _FeaturedArticle(
                article: articles.first,
                isDark: isDark,
              ),
            ),
          ),
          if (rest.isNotEmpty) ...[
            SliverToBoxAdapter(
                child: _SectionTitle(title: 'Lo último', isDark: isDark)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index.isOdd) return const SizedBox(height: 12);
                    return ArticleCard(article: rest[index ~/ 2]);
                  },
                  childCount: rest.length * 2 - 1,
                ),
              ),
            ),
          ],
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: isLoadingMore
                  ? const Center(
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: AppColors.accent, strokeWidth: 2)))
                  : hasMore
                      ? const SizedBox.shrink()
                      : Center(
                          child: Text('No hay más artículos',
                              style: TextStyle(
                                  color: AppColors.textMut(isDark),
                                  fontSize: 12))),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tarjeta destacada (hero) ─────────────────────────────────────────────────
class _FeaturedArticle extends StatelessWidget {
  final Article article;
  final bool isDark;

  const _FeaturedArticle({required this.article, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final justified =
        context.select<ThemeNotifier, bool>((t) => t.justifiedText);
    final (categoryColor, categoryLabel) = _badgeFor(article.category);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: isDark ? 0.35 : 0.22),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.50)
                : AppColors.accent.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Material(
          type: MaterialType.card,
          elevation: 0,
          color: AppColors.surf(isDark),
          child: InkWell(
            onTap: () => openArticle(context, article),
            child: Stack(
              children: [
                Positioned.fill(
                  child: _HeroImage(
                    url: article.imageUrl,
                    sizes: article.imageSizes,
                    isDark: isDark,
                  ),
                ),
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: [0.0, 0.25, 0.55, 1.0],
                        colors: [
                          Colors.transparent,
                          Color(0x2B000000),
                          Color(0xCC000000),
                          Color(0xFA000000),
                        ],
                      ),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 160), // Espacio visible de la imagen
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              const CardBadge(
                                label: 'DESTACADO',
                                background: AppColors.accent,
                                foreground: Colors.white,
                                icon: Icons.star_rounded,
                              ),
                              CardBadge(
                                label: categoryLabel,
                                background: categoryColor,
                                foreground: Colors.white,
                              ),
                              if (article.isPremium) ...[
                                const CardBadge(
                                  label: 'Exclusivo',
                                  background: Color(0xFFC0392B),
                                  foreground: Colors.white,
                                  icon: Icons.lock_outline,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            article.title,
                            textAlign:
                                justified ? TextAlign.justify : TextAlign.start,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              height: 1.28,
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (article.description.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              article.description,
                              textAlign: justified
                                  ? TextAlign.justify
                                  : TextAlign.start,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.88),
                                fontSize: 13.5,
                                height: 1.42,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 13,
                                color: Colors.white.withValues(alpha: 0.72),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                DateFormatter.short(article.date),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Colores fijos del badge de categoría sobre el gradiente del hero.
  static (Color, String) _badgeFor(ArticleCategory category) {
    switch (category) {
      case ArticleCategory.analisis:
        return (const Color(0xFF185FA5), 'Análisis');
      case ArticleCategory.entrevista:
        return (const Color(0xFFA0522D), 'Entrevista');
      case ArticleCategory.noticia:
        return (const Color(0xFF1D9E75), 'Noticia');
    }
  }
}

// ─── Imagen del hero con caché por DPR ───────────────────────────────────────
class _HeroImage extends StatelessWidget {
  final String url;
  final Map<int, String> sizes;
  final bool isDark;

  const _HeroImage(
      {required this.url, required this.sizes, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(color: AppColors.surf(isDark));
    }
    final cacheWidth = imageCacheWidth(context);
    final resolvedUrl =
        bestImageUrl(sizes: sizes, fallbackUrl: url, targetWidth: cacheWidth);
    return CachedNetworkImage(
      imageUrl: resolvedUrl,
      width: double.infinity,
      fit: BoxFit.cover,
      memCacheWidth: cacheWidth,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, __) => Container(color: AppColors.surf(isDark)),
      errorWidget: (_, __, ___) => Container(
        color: AppColors.surf(isDark),
        child: Icon(Icons.image_not_supported,
            color: AppColors.textMut(isDark), size: 20),
      ),
    );
  }
}

// ─── Título de sección ────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  final bool isDark;

  const _SectionTitle({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 13,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: AppColors.textPri(isDark),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              color: AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Widgets auxiliares ───────────────────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  final bool isDark;
  const _LoadingView({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return const Center(
        child: CircularProgressIndicator(color: AppColors.accent));
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  final bool isDark;
  const _ErrorView({required this.onRetry, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Error al cargar las noticias',
              style: TextStyle(color: AppColors.textSec(isDark))),
          const SizedBox(height: 12),
          TextButton(
              onPressed: onRetry,
              child: const Text('Reintentar',
                  style: TextStyle(color: AppColors.accent))),
        ],
      ),
    );
  }
}

// ─── Banner de refresco ──────────────────────────────────────────────────────

enum _RefreshStatus { idle, refreshing, upToDate, updated }

class _RefreshBanner extends StatelessWidget {
  final _RefreshStatus status;
  final bool isDark;

  const _RefreshBanner({required this.status, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (status == _RefreshStatus.idle) return const SizedBox.shrink();

    final Color bg;
    final Color textColor;
    final IconData icon;
    final String text;

    switch (status) {
      case _RefreshStatus.refreshing:
        bg = isDark ? const Color(0xFF1A1A2E) : const Color(0xFFE8EAF6);
        textColor = isDark ? const Color(0xFF90CAF9) : const Color(0xFF1565C0);
        icon = Icons.sync;
        text = 'Buscando novedades...';
      case _RefreshStatus.upToDate:
        bg = isDark ? const Color(0xFF1A2E1A) : const Color(0xFFE8F5E9);
        textColor = isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32);
        icon = Icons.check_circle_outline;
        text = '¡Estás al día!';
      case _RefreshStatus.updated:
        bg = isDark ? const Color(0xFF1A2E1A) : const Color(0xFFE8F5E9);
        textColor = isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32);
        icon = Icons.new_releases_outlined;
        text = 'Nuevos artículos disponibles';
      default:
        return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: bg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (status == _RefreshStatus.refreshing)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                color: textColor,
                strokeWidth: 2,
              ),
            )
          else
            Icon(icon, color: textColor, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
