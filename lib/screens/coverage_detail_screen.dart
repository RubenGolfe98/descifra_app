import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/coverage.dart';
import '../repositories/coverage_repository.dart';
import '../services/auth_notifier.dart';
import '../services/theme_notifier.dart';
import '../theme/app_colors.dart';
import '../widgets/image_viewer.dart';
import 'article_detail_screen.dart';
import '../repositories/article_repository.dart';

class CoverageDetailScreen extends StatefulWidget {
  final Coverage coverage;
  const CoverageDetailScreen({super.key, required this.coverage});

  @override
  State<CoverageDetailScreen> createState() => _CoverageDetailScreenState();
}

class _CoverageDetailScreenState extends State<CoverageDetailScreen> {
  final _repo = CoverageRepository();
  final _articleRepo = ArticleRepository();

  CoverageDetail? _detail;
  bool _loadingDetail = true;

  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    final detail = await _repo.fetchCoverageDetail(widget.coverage.id);
    if (!mounted) return;
    setState(() {
      _detail = detail;
      _loadingDetail = false;
    });
  }

  static String _strip(String html) =>
      html.replaceAll(RegExp(r'<[^>]*>'), '').trim();

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDark;
    final bg   = AppColors.bg(isDark);
    final surf = AppColors.surf(isDark);
    final bord = AppColors.bord(isDark);
    final pri  = AppColors.textPri(isDark);
    final sec  = AppColors.textSec(isDark);
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // ── AppBar con imagen de portada ──────────────────────────────
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: surf,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  Positioned.fill(
                    child: widget.coverage.imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: widget.coverage.imageUrl,
                            fit: BoxFit.cover,
                            memCacheWidth: 800,
                          )
                        : Container(color: Colors.black),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.4, 1.0],
                          colors: [Colors.transparent, isDark ? Colors.black : Colors.white],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Título ────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accentDim,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Cobertura',
                      style: TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 8),
                  Text(widget.coverage.title,
                    style: TextStyle(color: pri, fontSize: 22, fontWeight: FontWeight.w700, height: 1.3)),
                  if (widget.coverage.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(widget.coverage.description,
                      style: TextStyle(color: sec, fontSize: 14, height: 1.5)),
                  ],
                  const SizedBox(height: 16),
                  Divider(color: bord, thickness: 0.5),
                ],
              ),
            ),
          ),

          // ── Contenido HTML ────────────────────────────────────────────
          if (_loadingDetail)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2)),
              ),
            )
          else if (_detail != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Html(
                  data: _detail!.contentHtml,
                  onLinkTap: (url, _, __) async {
                    if (url == null || url.isEmpty) return;
                    final uri = Uri.tryParse(url);
                    if (uri == null) return;
                    final isInternal = uri.host.contains('descifrandolaguerra.es');
                    if (isInternal) {
                      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
                      if (segments.isNotEmpty) {
                        final slug = segments.last;
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Cargando artículo...', style: TextStyle(color: Colors.white)),
                              duration: Duration(seconds: 2),
                              backgroundColor: Color(0xFF2A2A2A),
                            ),
                          );
                        }
                        final cookies = context.read<AuthNotifier>().state.cookies ?? '';
                        final article = await _articleRepo.fetchArticleBySlug(slug, cookies: cookies);
                        if (context.mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        if (article != null && context.mounted) {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => ArticleDetailScreen(article: article),
                          ));
                          return;
                        }
                      }
                    }
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  style: {
                    'body': Style(
                      color: isDark ? const Color(0xFFCCCCCC) : const Color(0xFF333333),
                      fontSize: FontSize(15),
                      lineHeight: const LineHeight(1.75),
                      margin: Margins.zero,
                      padding: HtmlPaddings.zero,
                      backgroundColor: Colors.transparent,
                    ),
                    'h2': Style(
                      color: pri,
                      fontSize: FontSize(18),
                      fontWeight: FontWeight.w500,
                      margin: Margins.only(top: 20, bottom: 8),
                    ),
                    'h3': Style(
                      color: pri,
                      fontSize: FontSize(16),
                      fontWeight: FontWeight.w500,
                      margin: Margins.only(top: 16, bottom: 6),
                    ),
                    'p': Style(margin: Margins.only(bottom: 16)),
                    'a': Style(color: AppColors.accent, textDecoration: TextDecoration.none),
                    'strong': Style(color: pri, fontWeight: FontWeight.w500),
                    'em': Style(
                      color: isDark ? const Color(0xFFAAAAAA) : const Color(0xFF666666),
                      fontStyle: FontStyle.italic,
                    ),
                    'blockquote': Style(
                      color: isDark ? const Color(0xFFAAAAAA) : const Color(0xFF666666),
                      border: const Border(left: BorderSide(color: AppColors.accent, width: 3)),
                      padding: HtmlPaddings.only(left: 16),
                      margin: Margins.symmetric(vertical: 16),
                      fontStyle: FontStyle.italic,
                    ),
                    'figure': Style(margin: Margins.symmetric(vertical: 12)),
                    'figcaption': Style(
                      color: AppColors.textMut(isDark),
                      fontSize: FontSize(12),
                      textAlign: TextAlign.center,
                      margin: Margins.only(top: 6),
                      fontStyle: FontStyle.italic,
                    ),
                    'ul': Style(margin: Margins.only(bottom: 16)),
                    'ol': Style(margin: Margins.only(bottom: 16)),
                    'li': Style(margin: Margins.only(bottom: 6)),
                    'section': Style(
                      backgroundColor: surf,
                      padding: HtmlPaddings.all(12),
                      margin: Margins.symmetric(vertical: 12),
                    ),
                  },
                  extensions: [
                    TagExtension(
                      tagsToExtend: {'img'},
                      builder: (extensionContext) {
                        final src = extensionContext.attributes['src'] ?? '';
                        if (src.isEmpty) return const SizedBox.shrink();
                        final srcset = extensionContext.attributes['srcset'] ?? '';
                        String imgUrl = src;
                        if (srcset.isNotEmpty) {
                          final match = RegExp(r'(https?://\S+)\s+600w').firstMatch(srcset);
                          if (match != null) imgUrl = match.group(1)!;
                        }
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: GestureDetector(
                            onTap: () => showImageViewer(context, src),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: imgUrl,
                                width: screenWidth - 40,
                                fit: BoxFit.cover,
                                memCacheWidth: (screenWidth * 2).toInt(),
                                placeholder: (_, __) => Container(height: 180, color: surf),
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
                        return GestureDetector(
                          onTap: () async {
                            final uri = Uri.tryParse(src);
                            if (uri != null && await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 12),
                            height: 120,
                            decoration: BoxDecoration(
                              color: surf,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.accent.withOpacity(0.4)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.map_outlined, color: AppColors.accent, size: 28),
                                const SizedBox(width: 12),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text('Ver mapa interactivo',
                                      style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 14)),
                                    SizedBox(height: 2),
                                    Text('Se abrirá en el navegador',
                                      style: TextStyle(color: Colors.grey, fontSize: 11)),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.open_in_new, color: Colors.grey, size: 14),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

          // ── Padding final ─────────────────────────────────────────────
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}