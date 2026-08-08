import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/theme_notifier.dart';
import '../theme/app_colors.dart';

/// Mapa interactivo de Google Maps para una cobertura.
/// Se muestra dentro de un WebView con la altura fijada; el gesto de
/// arrastre se cede al mapa para poder desplazarse por él sin que la
/// pantalla haga scroll.
class CoverageMap extends StatefulWidget {
  final String mapUrl;
  final double height;

  const CoverageMap({
    super.key,
    required this.mapUrl,
    this.height = 420,
  });

  @override
  State<CoverageMap> createState() => _CoverageMapState();
}

class _CoverageMapState extends State<CoverageMap>
    with AutomaticKeepAliveClientMixin {
  bool _loading = true;
  bool _failed = false;

  @override
  bool get wantKeepAlive => true;

  Future<void> _openInBrowser() async {
    final uri = Uri.parse(widget.mapUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = context.select<ThemeNotifier, bool>((t) => t.isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Row(
            children: [
              const Icon(Icons.map_outlined, color: AppColors.accent, size: 18),
              const SizedBox(width: 8),
              Text(
                'Mapa interactivo',
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _openInBrowser,
                child:
                    Icon(Icons.open_in_new, color: AppColors.accent, size: 22),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: widget.height,
              child: _failed
                  ? _MapError(isDark: isDark, onRetry: _openInBrowser)
                  : Stack(
                      children: [
                        InAppWebView(
                          initialUrlRequest:
                              URLRequest(url: WebUri(widget.mapUrl)),
                          initialSettings: InAppWebViewSettings(
                            transparentBackground: true,
                            supportZoom: true,
                            javaScriptEnabled: true,
                            useHybridComposition: true,
                            useShouldOverrideUrlLoading: true,
                          ),
                          // El mapa se queda con los gestos de arrastre para
                          // que se pueda desplazar sin mover la pantalla.
                          gestureRecognizers: {
                            Factory<OneSequenceGestureRecognizer>(
                              () => EagerGestureRecognizer(),
                            ),
                          },
                          shouldOverrideUrlLoading: (_, action) async {
                            final url = action.request.url?.toString() ?? '';
                            // Solo se permite navegar dentro del propio mapa.
                            if (url.contains('google.com/maps/d/')) {
                              return NavigationActionPolicy.ALLOW;
                            }
                            return NavigationActionPolicy.CANCEL;
                          },
                          onLoadStop: (_, __) {
                            if (mounted) setState(() => _loading = false);
                          },
                          onReceivedError: (_, request, __) {
                            // Solo interesa el fallo de la propia página: las
                            // teselas del mapa fallan a menudo y se reintentan
                            // solas sin afectar a la navegación.
                            if (request.isForMainFrame != true) return;
                            if (mounted) {
                              setState(() {
                                _loading = false;
                                _failed = true;
                              });
                            }
                          },
                        ),
                        if (_loading)
                          Container(
                            color: AppColors.surf(isDark),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.accent,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Text(
            'Desliza y amplía para explorar el mapa.',
            style: TextStyle(
              color: AppColors.textMut(isDark),
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Error de carga ───────────────────────────────────────────────────────────
class _MapError extends StatelessWidget {
  final bool isDark;
  final VoidCallback onRetry;

  const _MapError({required this.isDark, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surf(isDark),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, color: AppColors.bord(isDark), size: 40),
            const SizedBox(height: 12),
            Text(
              'No se pudo cargar el mapa',
              style: TextStyle(color: AppColors.textSec(isDark), fontSize: 14),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Abrir en el navegador'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: const BorderSide(color: AppColors.accent, width: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
