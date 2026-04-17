import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_notifier.dart';

/// Muestra el diálogo de paywall según el estado de autenticación
Future<void> showPaywallDialog(BuildContext context,
    {required VoidCallback onLoginTap}) {
  final auth = context.read<AuthNotifier>();
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _PaywallSheet(
      isLoggedIn: auth.state.isLoggedIn,
      onLoginTap: onLoginTap,
    ),
  );
}

class _PaywallSheet extends StatelessWidget {
  final bool isLoggedIn;
  final VoidCallback onLoginTap;

  const _PaywallSheet({required this.isLoggedIn, required this.onLoginTap});

  Future<void> _openSubscribePage() async {
    final uri = Uri.parse('https://www.descifrandolaguerra.es/suscribete/');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141414),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF333333),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 28),

          // Icono
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
          const SizedBox(height: 16),

          // Título
          const Text(
            'Contenido exclusivo',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),

          // Descripción
          Text(
            isLoggedIn
                ? 'Tu suscripción activa no incluye este contenido. Amplía tu plan para acceder a todos los artículos exclusivos.'
                : 'Este artículo es exclusivo para suscriptores de Descifrando la Guerra.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF888888),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),

          // Botón suscribirse / ampliar suscripción
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _openSubscribePage,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFC0392B),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                isLoggedIn ? 'Ampliar suscripción' : 'Suscribirme',
                style: const TextStyle(fontSize: 15, color: Colors.white),
              ),
            ),
          ),

          // Botón iniciar sesión (solo si no está logueado)
          if (!isLoggedIn) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  onLoginTap();
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

          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Ahora no',
                style: TextStyle(color: Color(0xFF555555), fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

/// InheritedWidget ligero para que widgets profundos puedan
/// decirle al MainScreen que salte a la pestaña Perfil
class TabNavigator extends InheritedWidget {
  final VoidCallback jumpToProfile;

  const TabNavigator({
    super.key,
    required this.jumpToProfile,
    required super.child,
  });

  static TabNavigator? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TabNavigator>();

  @override
  bool updateShouldNotify(TabNavigator old) => false;
}