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
import '../widgets/article_card.dart';
import '../widgets/image_viewer.dart';

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
      backgroundColor: _Colors.bg(isDark),
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
          expandedHeight: 260,
          pinned: true,
          backgroundColor: _Colors.surf(isDark),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 18),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            _FavoriteButton(article: article),
            IconButton(
              icon: const Icon(Icons.share_outlined,
                  color: Colors.white, size: 20),
              onPressed: () {
                final url = article.slug.isNotEmpty
                    ? 'https://www.descifrandolaguerra.es/${article.slug}/'
                    : 'https://www.descifrandolaguerra.es/?p=${article.id}';
                SharePlus.instance
                    .share(ShareParams(text: '${article.title}\n\n$url'));
              },
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              children: [
                if (article.imageUrl.isNotEmpty)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () => showImageViewer(context, article.imageUrl),
                      child: CachedNetworkImage(
                        imageUrl: article.imageUrl,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        memCacheWidth: 800,
                        fadeInDuration: const Duration(milliseconds: 150),
                        placeholder: (_, __) =>
                            Container(color: _Colors.surf(isDark)),
                        errorWidget: (_, __, ___) =>
                            Container(color: _Colors.surf(isDark)),
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.65, 1.0],
                        colors: [
                          Colors.transparent,
                          isDark ? Colors.black : Colors.white,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ArticleCategoryBadge(category: article.category),
                    if (article.isPremium) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0x33C0392B),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.lock_outline,
                                color: Color(0xFFE57A72), size: 11),
                            SizedBox(width: 4),
                            Text('Exclusivo',
                                style: TextStyle(
                                    color: Color(0xFFE57A72), fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  article.title,
                  style: TextStyle(
                    color: _Colors.textPrimary(isDark),
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.person_outline,
                        color: _Colors.textSecondary(isDark), size: 14),
                    const SizedBox(width: 4),
                    Text(article.author,
                        style: TextStyle(
                            color: _Colors.textSecondary(isDark),
                            fontSize: 12)),
                    const SizedBox(width: 12),
                    Icon(Icons.calendar_today_outlined,
                        color: _Colors.textSecondary(isDark), size: 12),
                    const SizedBox(width: 4),
                    Text(_formatDate(article.date),
                        style: TextStyle(
                            color: _Colors.textSecondary(isDark),
                            fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 20),
                Divider(color: _Colors.bord(isDark), thickness: 0.5),
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

  String _formatDate(DateTime date) {
    const months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    return '${date.day} de ${months[date.month - 1]} de ${date.year}';
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
                        color: _Colors.surf(isDark),
                      ),
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
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
                    color: _Colors.surf(isDark),
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
              color: _Colors.textPrimary(isDark),
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
              color: _Colors.textSecondary(isDark),
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

// ─── Colores dinámicos ────────────────────────────────────────────────────────
class _Colors {
  static Color bg(bool d) => AppColors.bg(d);
  static Color surf(bool d) => AppColors.surf(d);
  static Color bord(bool d) => AppColors.bord(d);
  static Color textPrimary(bool d) => AppColors.textPri(d);
  static Color textSecondary(bool d) => AppColors.textSec(d);
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
              style: TextStyle(color: _Colors.textSecondary(isDark))),
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
  const _FavoriteButton({required this.article});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final favorites = context.watch<FavoritesService>();

    if (!auth.state.isLoggedIn) return const SizedBox.shrink();

    final isSaved = favorites.isSaved(article.id);

    return IconButton(
      icon: Icon(
        isSaved ? Icons.bookmark : Icons.bookmark_outline,
        color: isSaved ? AppColors.accent : Colors.white,
        size: 22,
      ),
      onPressed: () async {
        final cookies = auth.state.cookies ?? '';
        await favorites.toggleFavorite(article.id, cookies);
      },
    );
  }
}
