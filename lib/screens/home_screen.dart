import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/article.dart';
import '../repositories/article_repository.dart';
import '../services/auth_notifier.dart';
import 'article_detail_screen.dart';
import 'paywall_dialog.dart';

// ─── Colores de la app ────────────────────────────────────────────────────────
class AppColors {
  static const background = Color(0xFF0D0D0D);
  static const surface = Color(0xFF1A1A1A);
  static const border = Color(0xFF242424);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF888888);
  static const textMuted = Color(0xFF555555);
  static const accent = Color(0xFFC0392B);
  static const premiumBg = Color(0x33C0392B);
  static const premiumText = Color(0xFFE57A72);
}

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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _firstPageFuture = _repository.fetchLatestArticles(
      onRefreshed: (fresh) {
        if (mounted) setState(() {
          _articles
            ..clear()
            ..addAll(fresh);
        });
      },
    );
  }

  @override
  void dispose() {
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
      _firstPageFuture = _repository.fetchLatestArticles();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const _AppHeader(),
            Expanded(
              child: FutureBuilder<List<Article>>(
                future: _firstPageFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      _articles.isEmpty) {
                    return const _LoadingView();
                  }
                  if (snapshot.hasError && _articles.isEmpty) {
                    return _ErrorView(onRetry: _refresh);
                  }
                  // Inicializar _articles con la primera página
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
  const _AppHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipOval(
            child: CachedNetworkImage(
              imageUrl:
                  'https://www.descifrandolaguerra.es/wp-content/uploads/2023/01/logotipo-dlg-300x300-1.png',
              width: 32,
              height: 32,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: 32,
                height: 32,
                color: AppColors.surface,
              ),
              errorWidget: (_, __, ___) => Container(
                width: 32,
                height: 32,
                color: AppColors.surface,
                child: const Center(
                  child: Text('DLG',
                      style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 9,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Descifrando la Guerra',
            style: GoogleFonts.raleway(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
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

  const _ArticleFeed({
    required this.articles,
    required this.onRefresh,
    required this.scrollController,
    required this.isLoadingMore,
    required this.hasMore,
  });

  @override
  Widget build(BuildContext context) {
    if (articles.isEmpty) {
      return const Center(
        child: Text('No hay noticias disponibles',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    final featuredArticle = articles.first;
    final restArticles = articles.skip(1).toList();

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: _FeaturedArticle(article: featuredArticle),
            ),
          ),
          const SliverToBoxAdapter(child: _SectionTitle(title: 'Lo último')),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _ArticleCard(article: restArticles[index]),
              childCount: restArticles.length,
            ),
          ),
          // Indicador de carga al final
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: isLoadingMore
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: AppColors.accent,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : hasMore
                      ? const SizedBox.shrink()
                      : const Center(
                          child: Text(
                            'No hay más artículos',
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 12),
                          ),
                        ),
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

  const _FeaturedArticle({required this.article});

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
      child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 210,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _ArticleImage(url: article.imageUrl, height: 210),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.45, 1.0],
                  colors: [
                    Colors.transparent,
                    Color(0x33000000),
                    Color(0xE0000000),
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
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'DESTACADO',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.8),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _CategoryBadge(category: article.category),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _ArticleMeta(author: article.author, date: article.date),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ), // GestureDetector
    );
  }
}

// ─── Tarjeta de lista ─────────────────────────────────────────────────────────
class _ArticleCard extends StatelessWidget {
  final Article article;

  const _ArticleCard({required this.article});

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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _ArticleImage(url: article.imageUrl, width: 80, height: 64),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    article.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      _CategoryBadge(category: article.category),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _ArticleMeta(
                            author: article.author, date: article.date),
                      ),
                      if (article.isPremium) const _PremiumBadge(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ); // GestureDetector
  }
}

// ─── Imagen con caché y placeholder ──────────────────────────────────────────
class _ArticleImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;

  const _ArticleImage({required this.url, this.width, this.height});

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      memCacheWidth: width != null ? (width! * 2).toInt() : 400,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (_, __) => Container(
        width: width,
        height: height,
        color: AppColors.surface,
      ),
      errorWidget: (_, __, ___) => Container(
        width: width,
        height: height,
        color: AppColors.surface,
        child: const Icon(Icons.image_not_supported,
            color: AppColors.textMuted, size: 20),
      ),
    );
  }
}

// ─── Meta (autor + fecha) ─────────────────────────────────────────────────────
class _ArticleMeta extends StatelessWidget {
  final String author;
  final DateTime date;

  const _ArticleMeta({required this.author, required this.date});

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Hoy';
    if (diff.inDays == 1) return 'Ayer';
    return '${date.day} ${_months[date.month - 1]}';
  }

  static const _months = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 5),
          child: _Dot(),
        ),
        Text(
          _formatDate(date),
          style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
        ),
      ],
    );
  }
}

// ─── Widgets auxiliares ───────────────────────────────────────────────────────
class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 2,
      height: 2,
      decoration: const BoxDecoration(
        color: AppColors.textMuted,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _PremiumBadge extends StatelessWidget {
  const _PremiumBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.premiumBg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.lock_outline, color: AppColors.premiumText, size: 8),
          SizedBox(width: 3),
          Text('Premium',
              style: TextStyle(color: AppColors.premiumText, fontSize: 9)),
        ],
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final ArticleCategory category;
  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    final isAnalysis = category == ArticleCategory.analisis;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: isAnalysis
            ? const Color(0x22185FA5)
            : const Color(0x221D9E75),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isAnalysis ? 'Análisis' : 'Noticia',
        style: TextStyle(
          color: isAnalysis
              ? const Color(0xFF85B7EB)
              : const Color(0xFF5DCAA5),
          fontSize: 9,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.accent),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Error al cargar las noticias',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: const Text('Reintentar',
                style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }
}