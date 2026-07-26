import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart' show Html, TagExtension;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/article.dart';
import '../models/article_detail.dart';
import '../repositories/article_repository.dart';
import '../services/auth_notifier.dart';
import '../services/favorites_service.dart';
import '../services/theme_notifier.dart';
import '../theme/app_colors.dart';
import '../theme/html_styles.dart';
import '../utils/date_formatter.dart';
import '../widgets/image_viewer.dart';
import 'filtered_articles_screen.dart';
import 'analysis_screen.dart';
import 'interviews_screen.dart';
import '../services/tag_service.dart';

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

  @override
  void initState() {
    super.initState();
    // Asignamos inmediatamente para evitar LateInitializationError;
    // el primer await difiere la ejecución real al microtask queue.
    _detailFuture = _startLoad();
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
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDark;
    return Scaffold(
      backgroundColor: AppColors.bg(isDark),
      body: _ArticleShell(
        article: widget.article,
        detailFuture: _detailFuture,
        onRetry: _retry,
        isDark: isDark,
        refreshing: _refreshing,
        repository: _repository,
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

  const _ArticleShell({
    required this.article,
    required this.detailFuture,
    required this.onRetry,
    required this.isDark,
    this.refreshing = false,
    required this.repository,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
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
            return _PaywallBlock(isLoggedIn: auth.state.isLoggedIn);
          }
          return _HtmlContent(html: detail.content, repository: repository);
        },
      ),
    );
  }
}

// ─── Contenido HTML ───────────────────────────────────────────────────────────
class _HtmlContent extends StatelessWidget {
  final String html;
  final ArticleRepository repository;

  const _HtmlContent({required this.html, required this.repository});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDark;
    final screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Html(
        data: html,
        onLinkTap: (url, _, __) async {
          if (url == null || url.isEmpty) return;
          final uri = Uri.tryParse(url);
          if (uri == null) return;

          final isInternal = uri.host.contains('descifrandolaguerra.es');

          if (isInternal) {
            final segments =
                uri.pathSegments.where((s) => s.isNotEmpty).toList();

            if (segments.isNotEmpty) {
              final slug = segments.last;

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Cargando artículo...',
                      style: TextStyle(color: Colors.white),
                    ),
                    duration: Duration(seconds: 2),
                    backgroundColor: Color(0xFF2A2A2A),
                  ),
                );
              }

              final article = await repository.fetchArticleBySlug(slug);

              if (context.mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              }

              if (article != null && context.mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ArticleDetailScreen(article: article),
                  ),
                );
                return;
              }
            }
          }

          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        style: articleHtmlStyles(isDark),
        extensions: [
          TagExtension(
            tagsToExtend: {'img'},
            builder: (extensionContext) {
              final src = extensionContext.attributes['src'] ?? '';
              if (src.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: GestureDetector(
                  onTap: () => showImageViewer(context, src),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: src,
                      width: screenWidth - 40,
                      fit: BoxFit.cover,
                      memCacheWidth: ((screenWidth - 40) * 2).toInt(),
                      placeholder: (_, __) => Container(
                        height: 200,
                        color: AppColors.surf(isDark),
                      ),
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              );
            },
          ),
          TagExtension(
            tagsToExtend: {'iframe'},
            builder: (extensionContext) {
              final src = extensionContext.attributes['src'] ?? '';
              if (src.isEmpty) return const SizedBox.shrink();

              final ytMatch = RegExp(r'youtube\.com/embed/([a-zA-Z0-9_-]+)')
                  .firstMatch(src);

              if (ytMatch != null) {
                final videoId = ytMatch.group(1)!;
                final thumbUrl =
                    'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: GestureDetector(
                    onTap: () async {
                      final uri =
                          Uri.parse('https://www.youtube.com/watch?v=$videoId');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CachedNetworkImage(
                            imageUrl: thumbUrl,
                            width: screenWidth - 40,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              height: 200,
                              color: AppColors.surf(isDark),
                            ),
                            errorWidget: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.play_arrow,
                                color: Colors.white, size: 32),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              // Spotify
              final spotifyMatch = RegExp(
                r'open\.spotify\.com/embed/(episode|show|track|playlist)/([a-zA-Z0-9]+)',
              ).firstMatch(src);

              if (spotifyMatch != null) {
                final type = spotifyMatch.group(1)!;
                final id = spotifyMatch.group(2)!;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: GestureDetector(
                    onTap: () async {
                      final uri =
                          Uri.parse('https://open.spotify.com/$type/$id');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Container(
                      width: screenWidth - 40,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1DB954).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF1DB954).withValues(alpha: 0.3),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1DB954),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.play_arrow,
                                color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  type == 'episode'
                                      ? 'Escuchar podcast'
                                      : 'Escuchar en Spotify',
                                  style: const TextStyle(
                                    color: Color(0xFF1DB954),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Abrir en Spotify',
                                  style: TextStyle(
                                    color: AppColors.textSec(isDark),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.open_in_new,
                              color: AppColors.textMut(isDark), size: 18),
                        ],
                      ),
                    ),
                  ),
                );
              }

              // Otros iframes — fallback
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: GestureDetector(
                  onTap: () async {
                    final uri = Uri.tryParse(src);
                    if (uri != null && await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Container(
                    width: screenWidth - 40,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.surf(isDark),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_circle_outline,
                            color: AppColors.accent, size: 24),
                        const SizedBox(width: 8),
                        Text('Ver vídeo',
                            style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Contenido exclusivo inline ─────────────────────────────────────────────
class _PaywallBlock extends StatelessWidget {
  final bool isLoggedIn;

  const _PaywallBlock({required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFAAAAAA), Colors.transparent],
              stops: [0.0, 0.8],
            ).createShader(bounds),
            blendMode: BlendMode.dstIn,
            child: Column(
              children: List.generate(
                5,
                (i) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.surf(isDark),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  width: i == 4 ? 160 : double.infinity,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0x22C0392B),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_outline,
                color: Color(0xFFC0392B), size: 26),
          ),
          const SizedBox(height: 14),
          Text(
            'Contenido exclusivo para suscriptores',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPri(isDark),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Accede a análisis en profundidad y cobertura '
            'completa de la política internacional.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSec(isDark),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          if (!isLoggedIn) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFC0392B),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Iniciar sesión',
                    style: TextStyle(fontSize: 15, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 10),
          ],
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar',
                style: TextStyle(color: Color(0xFF555555), fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

// ─── Skeleton del contenido mientras carga ────────────────────────────────────
class _ContentSkeleton extends StatelessWidget {
  const _ContentSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDark;
    final skeletonColor =
        isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE0D9CF);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...List.generate(12, (i) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              height: 13,
              decoration: BoxDecoration(
                  color: skeletonColor, borderRadius: BorderRadius.circular(4)),
              width: i % 4 == 3
                  ? MediaQuery.of(context).size.width * 0.6
                  : double.infinity,
            );
          }),
          const SizedBox(height: 20),
          Container(
            height: 200,
            decoration: BoxDecoration(
                color: skeletonColor, borderRadius: BorderRadius.circular(8)),
          ),
          const SizedBox(height: 20),
          ...List.generate(
              8,
              (i) => Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    height: 13,
                    decoration: BoxDecoration(
                        color: skeletonColor,
                        borderRadius: BorderRadius.circular(4)),
                    width: i % 3 == 2
                        ? MediaQuery.of(context).size.width * 0.5
                        : double.infinity,
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
    final isDark = context.watch<ThemeNotifier>().isDark;
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
    return GestureDetector(
      onTap: onTap,
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
