import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/seminar.dart';
import '../repositories/seminar_repository.dart';
import '../services/auth_notifier.dart';
import '../services/theme_notifier.dart';
import '../theme/app_colors.dart';

class SeminarSessionScreen extends StatefulWidget {
  final String sessionUrl;
  final String sessionTitle;
  final String seminarTitle;

  const SeminarSessionScreen({
    super.key,
    required this.sessionUrl,
    required this.sessionTitle,
    required this.seminarTitle,
  });

  @override
  State<SeminarSessionScreen> createState() => _SeminarSessionScreenState();
}

class _SeminarSessionScreenState extends State<SeminarSessionScreen> {
  final _repository = SeminarRepository();
  SeminarSessionDetail? _detail;
  bool _loading = true;
  bool _videoVisible = false;

  bool _hasCookies = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Si las cookies llegaron después de que cargamos sin contenido, recargar
    final auth = context.watch<AuthNotifier>();
    final hasCookies = auth.state.cookies != null && auth.state.cookies!.isNotEmpty;
    if (hasCookies && !_hasCookies && !_loading && _detail == null) {
      _hasCookies = hasCookies;
      _loadDetail();
    }
    _hasCookies = hasCookies;
  }

  Future<void> _loadDetail({int attempt = 1}) async {
    if (!mounted) return;
    setState(() => _loading = true);
    final cookies = context.read<AuthNotifier>().state.cookies ?? '';
    final detail = await _repository.fetchSessionDetail(widget.sessionUrl, cookies);
    if (!mounted) return;
    if (detail == null && attempt < 3) {
      final wait = Duration(seconds: attempt * 3);
      if (kDebugMode) debugPrint('📚 [Session] Reintentando en ${wait.inSeconds}s (intento $attempt)');
      await Future.delayed(wait);
      return _loadDetail(attempt: attempt + 1);
    }
    setState(() {
      _detail = detail;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDark;
    final bg   = AppColors.bg(isDark);
    final surf = AppColors.surf(isDark);
    final bord = AppColors.bord(isDark);
    final pri  = AppColors.textPri(isDark);
    final sec  = AppColors.textSec(isDark);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surf,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: pri, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            const Icon(Icons.school_outlined, size: 14, color: AppColors.accent),
            const SizedBox(width: 6),
            const Text('Seminarios',
              style: TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Divider(height: 0.5, color: bord),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2))
          : _detail == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wifi_off_outlined, color: AppColors.accent, size: 40),
                        const SizedBox(height: 16),
                        Text('No se pudo cargar la sesión',
                          style: TextStyle(color: sec, fontSize: 15),
                          textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _loadDetail,
                          style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Vídeo Vimeo
                      if (_detail!.vimeoUrl.isNotEmpty)
                        _VideoPlayer(
                          vimeoUrl: _detail!.vimeoUrl,
                          isDark: isDark,
                          visible: _videoVisible,
                          onPlay: () => setState(() => _videoVisible = true),
                        ),

                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Nombre del seminario
                            Text(widget.seminarTitle,
                              style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                            const SizedBox(height: 8),
                            // Título sesión
                            Text(widget.sessionTitle,
                              style: TextStyle(color: pri, fontSize: 18, fontWeight: FontWeight.w700, height: 1.3)),
                            const SizedBox(height: 16),

                            // Materiales
                            if (_detail!.materials.isNotEmpty) ...[
                              Text('Materiales',
                                style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)),
                              const SizedBox(height: 10),
                              ..._detail!.materials.map((m) => _MaterialTile(material: m, isDark: isDark)),
                              const SizedBox(height: 20),
                            ],

                            // Descripción
                            if (_detail!.description.isNotEmpty) ...[
                              Text('Sobre esta sesión',
                                style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)),
                              const SizedBox(height: 10),
                              Text(_detail!.description,
                                style: TextStyle(color: sec, fontSize: 14, height: 1.7)),
                              const SizedBox(height: 20),
                            ],

                            // Otras sesiones
                            if (_detail!.allSessions.isNotEmpty) ...[
                              Divider(color: bord, thickness: 0.5),
                              const SizedBox(height: 16),
                              Text('Otras sesiones',
                                style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)),
                              const SizedBox(height: 10),
                              ..._detail!.allSessions.map((s) => _OtherSessionTile(
                                session: s,
                                isDark: isDark,
                                isCurrentSession: s.url == widget.sessionUrl,
                                seminarTitle: widget.seminarTitle,
                              )),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

// ─── Reproductor de vídeo Vimeo ───────────────────────────────────────────────
class _VideoPlayer extends StatelessWidget {
  final String vimeoUrl;
  final bool isDark;
  final bool visible;
  final VoidCallback onPlay;

  const _VideoPlayer({required this.vimeoUrl, required this.isDark, required this.visible, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 220,
      color: Colors.black,
      child: visible
          ? InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(vimeoUrl)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                mediaPlaybackRequiresUserGesture: false,
                allowsInlineMediaPlayback: true,
              ),
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                final url = navigationAction.request.url?.toString() ?? '';
                // Permitir solo URLs del player de Vimeo
                // Cualquier otra navegación (like, login, etc.) → navegador externo
                if (url.startsWith('https://player.vimeo.com')) {
                  return NavigationActionPolicy.ALLOW;
                }
                final uri = Uri.tryParse(url);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
                return NavigationActionPolicy.CANCEL;
              },
            )
          : GestureDetector(
              onTap: onPlay,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(color: Colors.black),
                  Container(
                    width: 64, height: 64,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
                  ),
                ],
              ),
            ),
    );
  }
}

// ─── Tile de material PDF ─────────────────────────────────────────────────────
class _MaterialTile extends StatelessWidget {
  final SeminarMaterial material;
  final bool isDark;

  const _MaterialTile({required this.material, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final surf = AppColors.surf(isDark);
    final bord = AppColors.bord(isDark);
    final pri  = AppColors.textPri(isDark);

    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(material.url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: bord, width: 0.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.picture_as_pdf_outlined, color: AppColors.accent, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(material.name, style: TextStyle(color: pri, fontSize: 13))),
            Icon(Icons.download_outlined, color: AppColors.textSec(isDark), size: 18),
          ],
        ),
      ),
    );
  }
}

// ─── Tile de otras sesiones ───────────────────────────────────────────────────
class _OtherSessionTile extends StatelessWidget {
  final SeminarSession session;
  final bool isDark;
  final bool isCurrentSession;
  final String seminarTitle;

  const _OtherSessionTile({
    required this.session,
    required this.isDark,
    required this.isCurrentSession,
    required this.seminarTitle,
  });

  @override
  Widget build(BuildContext context) {
    final surf = AppColors.surf(isDark);
    final bord = AppColors.bord(isDark);
    final pri  = AppColors.textPri(isDark);
    final sec  = AppColors.textSec(isDark);

    return GestureDetector(
      onTap: isCurrentSession ? null : () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => SeminarSessionScreen(
              sessionUrl: session.url,
              sessionTitle: session.title,
              seminarTitle: seminarTitle,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isCurrentSession ? AppColors.accentDim : surf,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isCurrentSession ? AppColors.accent : bord,
            width: isCurrentSession ? 1 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isCurrentSession ? Icons.play_circle : Icons.play_circle_outline,
              color: isCurrentSession ? AppColors.accent : sec,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(session.title,
                style: TextStyle(
                  color: isCurrentSession ? AppColors.accent : pri,
                  fontSize: 13,
                  fontWeight: isCurrentSession ? FontWeight.w600 : FontWeight.normal,
                )),
            ),
          ],
        ),
      ),
    );
  }
}