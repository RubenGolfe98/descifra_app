import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_html/flutter_html.dart' show Html, TagExtension;
import 'package:url_launcher/url_launcher.dart';
import '../../models/seminar.dart';
import '../../repositories/seminar_repository.dart';
import '../../services/auth_notifier.dart';
import '../../services/theme_notifier.dart';
import '../../theme/app_colors.dart';
import '../../theme/html_styles.dart';
import '../../widgets/dlg_app_bar.dart';
import 'seminar_session_screen.dart';

class SeminarDetailScreen extends StatefulWidget {
  final Seminar seminar;
  const SeminarDetailScreen({super.key, required this.seminar});

  @override
  State<SeminarDetailScreen> createState() => _SeminarDetailScreenState();
}

class _SeminarDetailScreenState extends State<SeminarDetailScreen> {
  final _repository = SeminarRepository();
  late Future<List<SeminarSession>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final cookies = context.read<AuthNotifier>().state.cookies ?? '';
    _future = _fetchWithRetry(cookies);
  }

  Future<List<SeminarSession>> _fetchWithRetry(String cookies,
      {int attempt = 1}) async {
    final sessions =
        await _repository.fetchSessions(widget.seminar.link, cookies);
    if (sessions.isEmpty && attempt < 3) {
      final wait = Duration(seconds: attempt * 3);
      if (kDebugMode) {
        debugPrint(
            '📚 [Seminar] Sin sesiones, reintentando en ${wait.inSeconds}s');
      }
      await Future.delayed(wait);
      return _fetchWithRetry(cookies, attempt: attempt + 1);
    }
    if (sessions.isNotEmpty) {
      _repository.prefetchSessionDetails(sessions, cookies);
    }
    return sessions;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeNotifier, bool>((t) => t.isDark);
    final bg = AppColors.bg(isDark);
    final surf = AppColors.surf(isDark);
    final bord = AppColors.bord(isDark);
    final pri = AppColors.textPri(isDark);
    final sec = AppColors.textSec(isDark);

    return Scaffold(
      backgroundColor: bg,
      appBar: DlgAppBar(title: '', isDark: isDark),
      body: FutureBuilder<List<SeminarSession>>(
        future: _future,
        builder: (context, snapshot) {
          return CustomScrollView(
            slivers: [
              // ── Cabecera: título y descripción ──────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.seminar.title,
                          style: TextStyle(
                              color: pri,
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              height: 1.3)),
                      if (widget.seminar.description.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(widget.seminar.description,
                            style: TextStyle(
                                color: sec, fontSize: 14, height: 1.6)),
                      ],
                      const SizedBox(height: 20),
                      Text('Sesiones',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          )),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),

              // ── Listado de sesiones ─────────────────────────────────────
              if (snapshot.connectionState == ConnectionState.waiting)
                const SliverToBoxAdapter(
                  child: Center(
                      child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(
                        color: AppColors.accent, strokeWidth: 2),
                  )),
                )
              else if (!snapshot.hasData || snapshot.data!.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wifi_off_outlined,
                            color: AppColors.accent, size: 40),
                        const SizedBox(height: 16),
                        Text('No se pudieron cargar las sesiones',
                            style: TextStyle(color: sec, fontSize: 15),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: () => setState(_load),
                          style: FilledButton.styleFrom(
                              backgroundColor: AppColors.accent),
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final session = snapshot.data![index];
                      return _SessionTile(
                        session: session,
                        index: index + 1,
                        isDark: isDark,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SeminarSessionScreen(
                              sessionUrl: session.url,
                              sessionTitle: session.title,
                              seminarTitle: widget.seminar.title,
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: snapshot.data!.length,
                  ),
                ),

              // ── Contenido HTML del seminario ────────────────────────────
              if (widget.seminar.contentHtml.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(color: bord, thickness: 0.5),
                        Builder(builder: (context) {
                          final screenWidth = MediaQuery.of(context).size.width;
                          return Html(
                            data: widget.seminar.contentHtml,
                            onLinkTap: (url, _, __) async {
                              if (url == null) return;
                              final uri = Uri.tryParse(url);
                              if (uri != null && await canLaunchUrl(uri)) {
                                await launchUrl(uri,
                                    mode: LaunchMode.externalApplication);
                              }
                            },
                            style: articleHtmlStyles(isDark),
                            extensions: [
                              TagExtension(
                                tagsToExtend: {'img'},
                                builder: (extensionContext) {
                                  final src =
                                      extensionContext.attributes['src'] ?? '';
                                  if (src.isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CachedNetworkImage(
                                        imageUrl: src,
                                        width: screenWidth - 40,
                                        fit: BoxFit.cover,
                                        memCacheWidth:
                                            ((screenWidth - 40) * 2).toInt(),
                                        placeholder: (_, __) => Container(
                                          height: 200,
                                          color: surf,
                                        ),
                                        errorWidget: (_, __, ___) =>
                                            const SizedBox.shrink(),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }
}

// ─── Tile de sesión ───────────────────────────────────────────────────────────
class _SessionTile extends StatelessWidget {
  final SeminarSession session;
  final int index;
  final bool isDark;
  final VoidCallback onTap;

  const _SessionTile(
      {required this.session,
      required this.index,
      required this.isDark,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final surf = AppColors.surf(isDark);
    final bord = AppColors.bord(isDark);
    final pri = AppColors.textPri(isDark);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: bord, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.accentDim,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text('$index',
                    style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(session.title,
                  style: TextStyle(
                      color: pri,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.3)),
            ),
            Icon(Icons.play_circle_outline, color: AppColors.accent, size: 22),
          ],
        ),
      ),
    );
  }
}
