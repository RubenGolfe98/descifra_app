import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/article.dart';
import '../../repositories/article_repository.dart';
import '../../services/theme_notifier.dart';
import '../../theme/app_colors.dart';
import '../../widgets/article_card.dart';
import '../search/search_screen.dart';
import '../../utils/access_helper.dart';
import '../../utils/date_formatter.dart';

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

    final featuredArticle = articles.first;
    final restArticles = articles.skip(1).toList();

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
              child: _FeaturedArticle(article: featuredArticle, isDark: isDark),
            ),
          ),
          SliverToBoxAdapter(
              child: _SectionTitle(title: 'Lo último', isDark: isDark)),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => ArticleCard(article: restArticles[index]),
              childCount: restArticles.length,
            ),
          ),
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

// ─── Tarjeta destacada ────────────────────────────────────────────────────────
class _FeaturedArticle extends StatelessWidget {
  final Article article;
  final bool isDark;

  const _FeaturedArticle({required this.article, required this.isDark});

  void _handleTap(BuildContext context) {
    openArticle(context, article);
  }

  @override
  Widget build(BuildContext context) {
    final justified =
        context.select<ThemeNotifier, bool>((t) => t.justifiedText);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Material(
        type: MaterialType.card,
        elevation: 0,
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleTap(context),
          child: SizedBox(
            height: 210,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _ArticleImage(
                    url: article.imageUrl, height: 210, isDark: isDark),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.0, 0.45, 1.0],
                      colors: [
                        Colors.transparent,
                        Color(0x33000000),
                        Color(0xE0000000)
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(4)),
                              child: const Text('DESTACADO',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.8)),
                            ),
                            const SizedBox(width: 6),
                            ArticleCategoryBadge(
                                category: article.category, overlay: true),
                            if (article.isPremium) ...[
                              const SizedBox(width: 6),
                              const ArticlePremiumBadge(overlay: true),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          article.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign:
                              justified ? TextAlign.justify : TextAlign.start,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              height: 1.35),
                        ),
                        const SizedBox(height: 6),
                        _ArticleMeta(
                            author: article.author,
                            date: article.date,
                            isDark: isDark),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Imagen con caché y placeholder ──────────────────────────────────────────
class _ArticleImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final bool isDark;

  const _ArticleImage({required this.url, this.height, required this.isDark})
      : width = null;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final cacheWidth = width != null
        ? (width! * dpr).toInt()
        : (MediaQuery.of(context).size.width * dpr).toInt().clamp(0, 1200);
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      memCacheWidth: cacheWidth,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, __) => Container(
          width: width, height: height, color: AppColors.surf(isDark)),
      errorWidget: (_, __, ___) => Container(
        width: width,
        height: height,
        color: AppColors.surf(isDark),
        child: Icon(Icons.image_not_supported,
            color: AppColors.textMut(isDark), size: 20),
      ),
    );
  }
}

// ─── Meta (autor + fecha) ─────────────────────────────────────────────────────
class _ArticleMeta extends StatelessWidget {
  final String author;
  final DateTime date;
  final bool isDark;

  const _ArticleMeta(
      {required this.author, required this.date, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final mut = AppColors.textPri(isDark);
    return Row(
      children: [
        Flexible(
            child: Text(author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: mut, fontSize: 10))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Container(
              width: 2,
              height: 2,
              decoration: BoxDecoration(color: mut, shape: BoxShape.circle)),
        ),
        Text(DateFormatter.short(date),
            style: TextStyle(color: mut, fontSize: 10)),
      ],
    );
  }
}

// ─── Widgets auxiliares ───────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  final bool isDark;
  const _SectionTitle({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
            color: AppColors.textSec(isDark),
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 1),
      ),
    );
  }
}

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
