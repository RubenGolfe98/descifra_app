import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:provider/provider.dart';
import '../models/article.dart';
import '../models/article_detail.dart';
import '../repositories/article_repository.dart';
import '../services/auth_notifier.dart';
import 'paywall_dialog.dart';

class ArticleDetailScreen extends StatefulWidget {
  final Article article;

  const ArticleDetailScreen({super.key, required this.article});

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  final _repository = ArticleRepository();
  late Future<ArticleDetail> _detailFuture;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  void _loadDetail() {
    final auth = context.read<AuthNotifier>();
    _detailFuture = _repository.fetchArticleDetail(
      widget.article.id,
      cookies: auth.state.cookies,
      restNonce: auth.restNonce,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Colors.background,
      body: FutureBuilder<ArticleDetail>(
        future: _detailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _LoadingView();
          }
          if (snapshot.hasError) {
            return _ErrorView(
              onRetry: () => setState(_loadDetail),
            );
          }
          return _ArticleBody(detail: snapshot.data!);
        },
      ),
    );
  }
}

// ─── Cuerpo del artículo ──────────────────────────────────────────────────────
class _ArticleBody extends StatelessWidget {
  final ArticleDetail detail;

  const _ArticleBody({required this.detail});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final isLocked = detail.isPremium &&
        !(auth.state.isLoggedIn && auth.state.isSubscriber);

    // Si el servidor devolvió contenido, siempre mostrarlo
    // (significa que el usuario tiene acceso aunque isSubscriber esté en false)
    final hasContent = detail.content.trim().isNotEmpty;
    final showPaywall = isLocked && !hasContent;

    return CustomScrollView(
      slivers: [
        // App bar con imagen de cabecera
        SliverAppBar(
          expandedHeight: 260,
          pinned: true,
          backgroundColor: _Colors.surface,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 18),
            onPressed: () => Navigator.of(context).pop(),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                if (detail.imageUrl.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: detail.imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 800,
                    memCacheHeight: 520,
                    fadeInDuration: const Duration(milliseconds: 200),
                    placeholder: (_, __) =>
                        Container(color: _Colors.surface),
                    errorWidget: (_, __, ___) =>
                        Container(color: _Colors.surface),
                  ),
                // Gradiente para legibilidad
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.4, 1.0],
                      colors: [Colors.transparent, _Colors.background],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Contenido
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge premium
                if (detail.isPremium)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
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

                // Título
                Text(
                  detail.title,
                  style: const TextStyle(
                    color: _Colors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),

                // Meta: autor + fecha
                Row(
                  children: [
                    const Icon(Icons.person_outline,
                        color: _Colors.textMuted, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      detail.author,
                      style: const TextStyle(
                          color: _Colors.textMuted, fontSize: 12),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.calendar_today_outlined,
                        color: _Colors.textMuted, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(detail.date),
                      style: const TextStyle(
                          color: _Colors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Separador
                const Divider(color: _Colors.border, thickness: 0.5),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),

        // Contenido HTML o paywall
        SliverToBoxAdapter(
          child: showPaywall
              ? _PaywallBlock(isLoggedIn: auth.state.isLoggedIn)
              : _HtmlContent(html: detail.content),
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

// ─── Contenido HTML ───────────────────────────────────────────────────────────
class _HtmlContent extends StatelessWidget {
  final String html;

  const _HtmlContent({required this.html});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Html(
        data: html,
        style: {
          'body': Style(
            color: const Color(0xFFCCCCCC),
            fontSize: FontSize(15),
            lineHeight: const LineHeight(1.75),
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
            backgroundColor: Colors.transparent,
          ),
          'h2': Style(
            color: _Colors.textPrimary,
            fontSize: FontSize(18),
            fontWeight: FontWeight.w500,
            margin: Margins.only(top: 20, bottom: 8),
          ),
          'h3': Style(
            color: _Colors.textPrimary,
            fontSize: FontSize(16),
            fontWeight: FontWeight.w500,
            margin: Margins.only(top: 16, bottom: 6),
          ),
          'p': Style(
            margin: Margins.only(bottom: 16),
          ),
          'a': Style(
            color: const Color(0xFFC0392B),
            textDecoration: TextDecoration.none,
          ),
          'strong': Style(
            color: _Colors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          'em': Style(
            color: const Color(0xFFAAAAAA),
            fontStyle: FontStyle.italic,
          ),
          'blockquote': Style(
            color: const Color(0xFFAAAAAA),
            border: const Border(
              left: BorderSide(color: Color(0xFFC0392B), width: 3),
            ),
            padding: HtmlPaddings.only(left: 16),
            margin: Margins.symmetric(vertical: 16),
            fontStyle: FontStyle.italic,
          ),
          'figure': Style(
            margin: Margins.symmetric(vertical: 16),
          ),
          'figcaption': Style(
            color: _Colors.textMuted,
            fontSize: FontSize(12),
            textAlign: TextAlign.center,
            margin: Margins.only(top: 6),
          ),
          'ul': Style(
            margin: Margins.only(bottom: 16),
          ),
          'ol': Style(
            margin: Margins.only(bottom: 16),
          ),
          'li': Style(
            margin: Margins.only(bottom: 6),
          ),
          // Secciones personalizadas del blog
          'section': Style(
            backgroundColor: const Color(0xFF1A1A1A),
            padding: HtmlPaddings.all(12),
            margin: Margins.symmetric(vertical: 12),
          ),
        },
        extensions: [
          // Renderizador custom de imágenes con caché y límite de memoria
          TagExtension(
            tagsToExtend: {'img'},
            builder: (extensionContext) {
              final src = extensionContext.attributes['src'] ?? '';
              if (src.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: src,
                    width: screenWidth - 40,
                    fit: BoxFit.cover,
                    // Limitar resolución en memoria para evitar OOM crash
                    memCacheWidth: ((screenWidth - 40) * 2).toInt(),
                    placeholder: (_, __) => Container(
                      height: 200,
                      color: const Color(0xFF1A1A1A),
                    ),
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
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

// ─── Bloque paywall inline ────────────────────────────────────────────────────
class _PaywallBlock extends StatelessWidget {
  final bool isLoggedIn;

  const _PaywallBlock({required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        children: [
          // Texto desvanecido simulando contenido bloqueado
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
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  width: i == 4 ? 160 : double.infinity,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Icono candado
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

          const Text(
            'Contenido exclusivo para suscriptores',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _Colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Accede a análisis en profundidad y cobertura '
            'completa de la política internacional.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _Colors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),

          // Botón suscribirse
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _openSubscribe(),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC0392B),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Suscribirme',
                  style: TextStyle(fontSize: 15, color: Colors.white)),
            ),
          ),

          // Botón login si no está logueado
          if (!isLoggedIn) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  TabNavigator.of(context)?.jumpToProfile();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(
                      color: Color(0xFF333333), width: 0.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Iniciar sesión',
                    style: TextStyle(fontSize: 15)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openSubscribe() async {
    final uri =
        Uri.parse('https://www.descifrandolaguerra.es/suscribete/');
    // Usar url_launcher
    // await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

// ─── Colores ──────────────────────────────────────────────────────────────────
class _Colors {
  static const background = Color(0xFF0D0D0D);
  static const surface = Color(0xFF1A1A1A);
  static const border = Color(0xFF242424);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF888888);
  static const textMuted = Color(0xFF555555);
}

// ─── Loading / Error ──────────────────────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0D0D0D),
      body: Center(
        child: CircularProgressIndicator(
            color: Color(0xFFC0392B), strokeWidth: 2),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Error al cargar el artículo',
                style: TextStyle(color: Color(0xFF888888))),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              child: const Text('Reintentar',
                  style: TextStyle(color: Color(0xFFC0392B))),
            ),
          ],
        ),
      ),
    );
  }
}