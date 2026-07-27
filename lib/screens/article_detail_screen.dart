import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/article.dart';
import '../models/article_detail.dart';
import '../repositories/article_repository.dart';
import '../services/auth_notifier.dart';
import '../services/favorites_service.dart';
import '../services/theme_notifier.dart';
import '../theme/app_colors.dart';
import '../utils/date_formatter.dart';
import 'filtered_articles_screen.dart';
import 'analysis_screen.dart';
import 'interviews_screen.dart';
import '../services/tag_service.dart';
import '../widgets/shimmer.dart';
import '../widgets/article_content_html.dart';
import '../widgets/article_paywall.dart';

class ArticleDetailScreen extends StatefulWidget {
  final Article article;

  const ArticleDetailScreen({super.key, required this.article});

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  final _repository = ArticleRepository();
  late Future<ArticleDetail> _detailFuture;
  bool _refreshing = false;
  int _loadVersion = 0;

  late ScrollController _scrollController;
  final ValueNotifier<double> _scrollProgress = ValueNotifier(0.0);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _detailFuture = _startLoad();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    if (max <= 0) {
      if (_scrollProgress.value != 0.0) _scrollProgress.value = 0.0;
      return;
    }
    final progress = (_scrollController.offset / max).clamp(0.0, 1.0);
    if ((progress - _scrollProgress.value).abs() > 0.005) {
      _scrollProgress.value = progress;
    }
  }

  /// Siempre asigna [_detailFuture] — nunca deja la variable sin inicializar.
  Future<ArticleDetail> _startLoad({bool forceRefresh = false}) async {
    final version = ++_loadVersion;
    // Diferimos el setState al microtask queue porque initState
    // está en medio del ciclo de montaje y no permite setState directo.
    Future.microtask(() {
      if (mounted && version == _loadVersion) {
        setState(() => _refreshing = true);
      }
    });

    try {
      final auth = context.read<AuthNotifier>();

      // Si el artículo es premium y el nonce no ha llegado, esperarlo.
      // El nonce se carga en paralelo durante AuthNotifier.initialize(),
      // así que normalmente ya está disponible aquí.
      if (widget.article.isPremium &&
          auth.state.isLoggedIn &&
          auth.restNonce == null) {
        if (kDebugMode) {
          debugPrint('⏳ [Detail] Esperando nonce para artículo premium...');
        }
        await _waitForNonce();
        if (!mounted) throw 'Widget disposed before nonce arrived';
      }

      final detail = await _repository.fetchArticleDetail(
        widget.article.id,
        cookies: auth.state.cookies,
        restNonce: auth.restNonce,
        forceRefresh: forceRefresh,
        onNonceExpired: () => context.read<AuthNotifier>().renewRestNonce(),
        onRefreshed: (fresh) {
          if (mounted && version == _loadVersion) {
            setState(() {
              _detailFuture = Future.value(fresh);
              _refreshing = false;
            });
          }
        },
      );
      return detail;
    } finally {
      if (mounted && version == _loadVersion) {
        setState(() => _refreshing = false);
      }
    }
  }

  Future<void> _waitForNonce() async {
    final auth = context.read<AuthNotifier>();
    if (auth.restNonce != null) return;

    final completer = Completer<void>();
    void listener() {
      if (!completer.isCompleted &&
          context.read<AuthNotifier>().restNonce != null) {
        completer.complete();
      }
    }

    auth.addListener(listener);
    try {
      await completer.future.timeout(const Duration(seconds: 10));
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint('⏳ [Detail] Timeout esperando nonce — continuando');
      }
    } finally {
      auth.removeListener(listener);
    }
  }

  void _retry() {
    setState(() {
      _detailFuture = _startLoad(forceRefresh: true);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollProgress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeNotifier, bool>((t) => t.isDark);


    return Scaffold(
      backgroundColor: AppColors.bg(isDark),
      body: _ArticleShell(
        article: widget.article,
        detailFuture: _detailFuture,
        onRetry: _retry,
        isDark: isDark,
        refreshing: _refreshing,
        repository: _repository,
        scrollController: _scrollController,
        scrollProgressNotifier: _scrollProgress,
      ),
    );
  }
}

// ─── Shell: cabecera inmediata + contenido async ──────────────────────────────
class _ArticleShell extends StatelessWidget {
  final Article article;
  final Future<ArticleDetail> detailFuture;
  final VoidCallback onRetry;
  final bool isDark;
  final bool refreshing;
  final ArticleRepository repository;
  final ScrollController scrollController;
  final ValueNotifier<double> scrollProgressNotifier;

  const _ArticleShell({
    required this.article,
    required this.detailFuture,
    required this.onRetry,
    required this.isDark,
    this.refreshing = false,
    required this.repository,
    required this.scrollController,
    required this.scrollProgressNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverAppBar(
          expandedHeight: 0,
          pinned: true,
          backgroundColor: AppColors.surf(isDark),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new,
                color: AppColors.textPri(isDark), size: 18),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            _FavoriteButton(article: article, isDark: isDark),
            IconButton(
              icon: Icon(Icons.share_outlined,
                  color: AppColors.textPri(isDark), size: 20),
              onPressed: () {
                final url = article.slug.isNotEmpty
                    ? 'https://www.descifrandolaguerra.es/${article.slug}/'
                    : 'https://www.descifrandolaguerra.es/?p=${article.id}';
                SharePlus.instance
                    .share(ShareParams(text: '${article.title}\n\n$url'));
              },
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(2),
            child: ValueListenableBuilder<double>(
              valueListenable: scrollProgressNotifier,
              builder: (context, progress, _) => AnimatedOpacity(
                opacity: progress > 0.01 ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 150),
                child: SizedBox(
                  height: 2,
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.bord(isDark),
                    valueColor: AlwaysStoppedAnimation(AppColors.accent),
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── Título y meta — disponibles AL INSTANTE ───────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Text(
                  article.title,
                  style: TextStyle(
                    color: AppColors.textPri(isDark),
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ClickableBadge(
                      label: article.category == ArticleCategory.analisis
                          ? 'Análisis'
                          : article.category == ArticleCategory.entrevista
                              ? 'Entrevista'
                              : 'Noticia',
                      bg: article.category == ArticleCategory.analisis
                          ? AppColors.analysisBg(isDark)
                          : article.category == ArticleCategory.entrevista
                              ? AppColors.interviewBg(isDark)
                              : AppColors.newsBg(isDark),
                      fg: article.category == ArticleCategory.analisis
                          ? AppColors.analysisText(isDark)
                          : article.category == ArticleCategory.entrevista
                              ? AppColors.interviewText(isDark)
                              : AppColors.newsText(isDark),
                      onTap: () {
                        if (article.category == ArticleCategory.noticia) {
                          Navigator.of(context)
                              .popUntil((route) => route.isFirst);
                        } else if (article.category ==
                            ArticleCategory.analisis) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const AnalysisScreen()),
                          );
                        } else {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const InterviewsScreen()),
                          );
                        }
                      },
                    ),
                    for (final slug in article.tagSlugs)
                      Builder(builder: (context) {
                        final name = TagService.getTagName('tag-$slug');
                        if (name == null) return const SizedBox.shrink();
                        return _ClickableBadge(
                          label: name,
                          bg: AppColors.tagBg(isDark),
                          fg: AppColors.tagText(isDark),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FilteredArticlesScreen(
                                name: slug,
                                displayName: name,
                                filterType: FilterType.tag,
                              ),
                            ),
                          ),
                        );
                      }),
                    if (article.isPremium)
                      _ClickableBadge(
                        label: 'Exclusivo',
                        bg: AppColors.premiumBg(isDark),
                        fg: AppColors.premiumText(isDark),
                        icon: Icons.lock_outline,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.person_outline,
                        color: AppColors.textSec(isDark), size: 14),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FilteredArticlesScreen(
                            name: article.author,
                            filterType: FilterType.author,
                          ),
                        ),
                      ),
                      child: Text(article.author,
                          style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.calendar_today_outlined,
                        color: AppColors.textSec(isDark), size: 12),
                    const SizedBox(width: 4),
                    Text(DateFormatter.long(article.date),
                        style: TextStyle(
                            color: AppColors.textSec(isDark),
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 20),
                Divider(color: AppColors.bord(isDark), thickness: 0.5),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),

        // ── Contenido — widget separado que solo se reconstruye
        //    cuando cambia AuthNotifier (no al cambiar ThemeNotifier) ──────
        _ArticleContent(
          article: article,
          detailFuture: detailFuture,
          onRetry: onRetry,
          refreshing: refreshing,
          repository: repository,
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }
}

// ─── Contenido del artículo (FutureBuilder + paywall) ─────────────────────────
// Widget extraído explícitamente para que solo él se reconstruya cuando
// cambie AuthNotifier, sin arrastrar el SliverAppBar ni el título.
class _ArticleContent extends StatelessWidget {
  final Article article;
  final Future<ArticleDetail> detailFuture;
  final VoidCallback onRetry;
  final bool refreshing;
  final ArticleRepository repository;

  const _ArticleContent({
    required this.article,
    required this.detailFuture,
    required this.onRetry,
    required this.refreshing,
    required this.repository,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();

    return SliverToBoxAdapter(
      child: FutureBuilder<ArticleDetail>(
        future: detailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _ContentSkeleton();
          }
          if (snapshot.hasError) {
            return _ContentError(onRetry: onRetry);
          }

          final detail = snapshot.data!;
          final hasContent = detail.content.trim().isNotEmpty;
          final isLocked = article.isPremium &&
              !(auth.state.isLoggedIn && auth.state.isSubscriber);
          final showPaywall = isLocked && !hasContent;

          if (!hasContent && refreshing) {
            return const _ContentSkeleton();
          }

          if (showPaywall) {
            return ArticlePaywall(isLoggedIn: auth.state.isLoggedIn);
          }
          return ArticleContentHtml(
            html: detail.content,
            repository: repository,
            onLinkArticle: (article) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ArticleDetailScreen(article: article),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
// ─── Contenido exclusivo inline ─────────────────────────────────────────────
class _ContentSkeleton extends StatelessWidget {
  const _ContentSkeleton();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...List.generate(12, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ShimmerWidget(
                height: 13,
                width: i % 4 == 3 ? screenWidth * 0.6 : double.infinity,
              ),
            );
          }),
          const SizedBox(height: 20),
          const ShimmerWidget(height: 200, borderRadius: 8),
          const SizedBox(height: 20),
          ...List.generate(
              8,
              (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ShimmerWidget(
                      height: 13,
                      width: i % 3 == 2 ? screenWidth * 0.5 : double.infinity,
                    ),
                  )),
        ],
      ),
    );
  }
}

// ─── Error inline ─────────────────────────────────────────────────────────────
class _ContentError extends StatelessWidget {
  final VoidCallback onRetry;
  const _ContentError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeNotifier, bool>((t) => t.isDark);


    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text('Error al cargar el contenido',
              style: TextStyle(color: AppColors.textSec(isDark))),
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

// ─── Botón de favorito ────────────────────────────────────────────────────────
class _FavoriteButton extends StatelessWidget {
  final Article article;
  final bool isDark;
  const _FavoriteButton({required this.article, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final favorites = context.watch<FavoritesService>();

    if (!auth.state.isLoggedIn) return const SizedBox.shrink();

    final isSaved = favorites.isSaved(article.id);

    return IconButton(
      icon: Icon(
        isSaved ? Icons.bookmark : Icons.bookmark_outline,
        color: isSaved ? AppColors.accent : AppColors.textPri(isDark),
        size: 22,
      ),
      onPressed: () async {
        final cookies = auth.state.cookies ?? '';
        await favorites.toggleFavorite(article.id, cookies);
      },
    );
  }
}

// ─── Badge clickable ──────────────────────────────────────────────────────────
class _ClickableBadge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  final IconData? icon;
  final VoidCallback? onTap;

  const _ClickableBadge({
    required this.label,
    required this.bg,
    required this.fg,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: fg, size: 12),
              const SizedBox(width: 4),
            ],
            Text(label,
                style: TextStyle(
                  color: fg,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                )),
          ],
        ),
      ),
    );
  }
}
