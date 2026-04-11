import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../services/auth_service.dart';

/// WebView que carga la página de login real.
/// Cloudflare lo ve como un navegador legítimo.
/// Una vez logueado extrae las cookies y cierra.
class LoginWebView extends StatefulWidget {
  const LoginWebView({super.key});

  /// Abre el WebView y devuelve las cookies si el login fue exitoso,
  /// o null si el usuario canceló.
  static Future<String?> show(BuildContext context) {
    return Navigator.of(context).push<String?>(
      MaterialPageRoute(builder: (_) => const LoginWebView()),
    );
  }

  @override
  State<LoginWebView> createState() => _LoginWebViewState();
}

class _LoginWebViewState extends State<LoginWebView> {
  static const _loginUrl = 'https://www.descifrandolaguerra.es/accede/';
  static const _successUrl = 'https://www.descifrandolaguerra.es/mi-cuenta/';

  InAppWebViewController? _controller;
  bool _isLoading = true;
  bool _extracted = false; // evitar extraer cookies dos veces

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(null),
        ),
        title: const Text(
          'Iniciar sesión',
          style: TextStyle(color: Colors.white, fontSize: 15),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(
              url: WebUri(_loginUrl),
            ),
            initialSettings: InAppWebViewSettings(
              userAgent:
                  'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
              javaScriptEnabled: true,
              domStorageEnabled: true,
              thirdPartyCookiesEnabled: true,
              clearCache: false,
            ),
            onWebViewCreated: (controller) => _controller = controller,
            onLoadStart: (_, url) {
              setState(() => _isLoading = true);
              _checkIfLoggedIn(url?.toString() ?? '');
            },
            onLoadStop: (_, url) {
              setState(() => _isLoading = false);
              _checkIfLoggedIn(url?.toString() ?? '');
            },
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFC0392B),
                strokeWidth: 2,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _checkIfLoggedIn(String url) async {
    // Detectar que el login fue exitoso por la URL de destino
    if (_extracted) return;
    if (!url.contains('/mi-cuenta/') && !url.contains('/my-account/')) return;

    _extracted = true;

    // Extraer todas las cookies del dominio
    final cookieManager = CookieManager.instance();
    final cookies = await cookieManager.getCookies(
      url: WebUri('https://www.descifrandolaguerra.es'),
    );

    // Formatear como string para enviar en headers HTTP
    final cookieString = cookies
        .map((c) => '${c.name}=${c.value}')
        .join('; ');

    debugPrint('🍪 [WebView] Cookies extraídas: $cookieString');

    // Verificar que tenemos la cookie de autenticación de WordPress
    final hasAuthCookie = cookies.any((c) =>
        c.name.startsWith('wordpress_logged_in') ||
        c.name.startsWith('wordpress_sec'));

    if (!hasAuthCookie) {
      // Puede que aún esté cargando, esperar un poco y reintentar
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      final retry = await cookieManager.getCookies(
        url: WebUri('https://www.descifrandolaguerra.es'),
      );
      final retryCookieString = retry
          .map((c) => '${c.name}=${c.value}')
          .join('; ');
      if (mounted) Navigator.of(context).pop(retryCookieString);
      return;
    }

    if (mounted) Navigator.of(context).pop(cookieString);
  }
}
