import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/auth_state.dart';
import '../services/auth_notifier.dart';
import 'login_webview.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();

    return Scaffold(
      backgroundColor: AppProfileColors.background,
      body: SafeArea(
        child: auth.state.isLoggedIn
            ? _LoggedInView(state: auth.state)
            : _LoginView(),
      ),
    );
  }
}

// ─── Colores (reutiliza los de home o centraliza en un theme) ─────────────────
class AppProfileColors {
  static const background = Color(0xFF0D0D0D);
  static const surface = Color(0xFF1A1A1A);
  static const border = Color(0xFF242424);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF888888);
  static const textMuted = Color(0xFF555555);
  static const accent = Color(0xFFC0392B);
  static const inputBg = Color(0xFF161616);
}

// ─── Vista logueado ───────────────────────────────────────────────────────────
class _LoggedInView extends StatelessWidget {
  final AuthState state;
  const _LoggedInView({required this.state});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // ── Avatar + nombre ─────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppProfileColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppProfileColors.border, width: 0.5),
                ),
                child: Center(
                  child: Text(
                    _initials(state.userDisplayName ?? state.userEmail ?? '?'),
                    style: const TextStyle(
                      color: AppProfileColors.accent,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.userDisplayName ?? 'Usuario',
                      style: const TextStyle(
                        color: AppProfileColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (state.userEmail != null &&
                        state.userEmail!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        state.userEmail!,
                        style: const TextStyle(
                          color: AppProfileColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Tarjeta de membresía ─────────────────────────────────────────
          if (state.membership != null) ...[
            _MembershipCard(membership: state.membership!),
            const SizedBox(height: 16),
          ] else ...[
            // Badge simple si no hay datos de membresía
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppProfileColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: state.isSubscriber
                        ? const Color(0xFF2E5E2E)
                        : AppProfileColors.border,
                    width: 0.5),
              ),
              child: Row(
                children: [
                  Icon(
                    state.isSubscriber
                        ? Icons.verified_outlined
                        : Icons.lock_outline,
                    color: state.isSubscriber
                        ? const Color(0xFF4CAF50)
                        : AppProfileColors.textMuted,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    state.isSubscriber ? 'Suscriptor activo' : 'Sin suscripción',
                    style: TextStyle(
                      color: state.isSubscriber
                          ? const Color(0xFF4CAF50)
                          : AppProfileColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Botón gestionar membresía ─────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openMiCuenta,
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Gestionar membresía en la web'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppProfileColors.textSecondary,
                side: const BorderSide(
                    color: AppProfileColors.border, width: 0.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Cerrar sesión ─────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.read<AuthNotifier>().logout(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppProfileColors.accent,
                side: const BorderSide(
                    color: AppProfileColors.accent, width: 0.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Cerrar sesión'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _openMiCuenta() async {
    final uri = Uri.parse('https://www.descifrandolaguerra.es/mi-cuenta/');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

// ─── Tarjeta de membresía ─────────────────────────────────────────────────────
class _MembershipCard extends StatelessWidget {
  final MembershipInfo membership;
  const _MembershipCard({required this.membership});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppProfileColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: membership.isActive
              ? const Color(0xFF2E5E2E)
              : AppProfileColors.border,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera
          Row(
            children: [
              Icon(
                membership.isActive
                    ? Icons.verified_outlined
                    : Icons.lock_outline,
                color: membership.isActive
                    ? const Color(0xFF4CAF50)
                    : AppProfileColors.textMuted,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  membership.name,
                  style: const TextStyle(
                    color: AppProfileColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // Badge estado
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: membership.isActive
                      ? const Color(0x224CAF50)
                      : const Color(0x22888888),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  membership.status,
                  style: TextStyle(
                    color: membership.isActive
                        ? const Color(0xFF4CAF50)
                        : AppProfileColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          // Fecha de expiración
          if (membership.expiresAt != null &&
              membership.expiresAt!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(
                color: AppProfileColors.border, thickness: 0.5),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    color: AppProfileColors.textMuted, size: 13),
                const SizedBox(width: 6),
                Text(
                  'Renovación: ${membership.expiresAt}',
                  style: const TextStyle(
                    color: AppProfileColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Vista login ──────────────────────────────────────────────────────────────
class _LoginView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          const Text(
            'Iniciar sesión',
            style: TextStyle(
              color: AppProfileColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Accede a todo el contenido exclusivo de Descifrando la Guerra.',
            style: TextStyle(
              color: AppProfileColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),

          // Error
          if (auth.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x22C0392B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x55C0392B), width: 0.5),
              ),
              child: Text(
                auth.errorMessage!,
                style: const TextStyle(
                    color: AppProfileColors.accent, fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Descripción del flujo seguro
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppProfileColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppProfileColors.border, width: 0.5),
            ),
            child: Row(
              children: const [
                Icon(Icons.shield_outlined,
                    color: Color(0xFF4CAF50), size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tu contraseña nunca es vista por la app — '
                    'introduces tus datos directamente en la web segura.',
                    style: TextStyle(
                      color: AppProfileColors.textSecondary,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Botón abrir WebView
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: auth.isLoading
                  ? null
                  : () => _openLoginWebView(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppProfileColors.accent,
                disabledBackgroundColor:
                    AppProfileColors.accent.withOpacity(0.4),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: auth.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Iniciar sesión',
                      style: TextStyle(fontSize: 15, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 12),

          // Continuar sin login
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: auth.isLoading
                  ? null
                  : () => context.read<AuthNotifier>().continueAsGuest(),
              style: TextButton.styleFrom(
                foregroundColor: AppProfileColors.textSecondary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Continuar sin iniciar sesión',
                  style: TextStyle(fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openLoginWebView(BuildContext context) async {
    final cookieString = await LoginWebView.show(context);

    if (cookieString == null || cookieString.isEmpty) return;
    if (!context.mounted) return;

    await context.read<AuthNotifier>().loginWithCookies(cookieString);
  }
}