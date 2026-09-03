import 'dart:math' show exp;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/auth_state.dart';
import '../../services/auth_notifier.dart';
import '../../services/theme_notifier.dart';
import '../../theme/app_colors.dart';
import 'login_webview.dart';
import '../newsletter/newsletter_screen.dart';
import '../articles/saved_articles_screen.dart';
import '../settings/settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final isDark = context.select<ThemeNotifier, bool>((t) => t.isDark);

    // Si la sesión ha expirado, mostrar un mensaje y redirigir al login
    if (auth.sessionExpired) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        auth.clearSessionExpired();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Tu sesión ha caducado. Por favor, inicia sesión de nuevo.'),
            duration: Duration(seconds: 4),
          ),
        );
      });
    }

    return Scaffold(
      backgroundColor: AppColors.bg(isDark),
      body: SafeArea(
        child: auth.state.isLoggedIn
            ? _LoggedInView(state: auth.state, isDark: isDark)
            : _LoginView(isDark: isDark),
      ),
    );
  }
}

// ─── Vista logueado ───────────────────────────────────────────────────────────
class _LoggedInView extends StatelessWidget {
  final AuthState state;
  final bool isDark;
  const _LoggedInView({required this.state, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final surf = AppColors.surf(isDark);
    final bord = AppColors.bord(isDark);
    final pri = AppColors.textPri(isDark);
    final sec = AppColors.textSec(isDark);
    final mut = AppColors.textMut(isDark);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // Avatar + nombre + botón ajustes
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: surf,
                  shape: BoxShape.circle,
                  border: Border.all(color: bord, width: 0.5),
                ),
                child: Center(
                  child: _buildAvatar(
                      state.userDisplayName ?? state.userEmail ?? ''),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.userDisplayName ?? 'Usuario',
                      style: TextStyle(
                        color: pri,
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (state.userEmail != null &&
                        state.userEmail!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(state.userEmail!,
                          style: TextStyle(color: sec, fontSize: 13)),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.settings_outlined, color: sec, size: 22),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Membresía
          if (state.membership != null) ...[
            _MembershipCard(membership: state.membership!, isDark: isDark),
            const SizedBox(height: 16),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: surf,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: state.isSubscriber ? AppColors.subscriberBorder : bord,
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    state.isSubscriber
                        ? Icons.verified_outlined
                        : Icons.lock_outline,
                    color: state.isSubscriber ? AppColors.subscriberText : mut,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    state.isSubscriber
                        ? 'Suscriptor activo'
                        : 'Sin suscripción',
                    style: TextStyle(
                      color:
                          state.isSubscriber ? AppColors.subscriberText : sec,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Gestionar membresía
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _openMiCuenta,
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Gestionar membresía en la web'),
              style: OutlinedButton.styleFrom(
                foregroundColor: pri,
                side: BorderSide(color: sec, width: 0.8),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Artículos guardados
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SavedArticlesScreen()),
              ),
              icon: const Icon(Icons.bookmark_outline, size: 16),
              label: const Text('Artículos guardados'),
              style: OutlinedButton.styleFrom(
                foregroundColor: pri,
                side: BorderSide(color: sec, width: 0.8),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Newsletter (solo si tiene membresía cargada)
          if (state.membership != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        NewsletterScreen(membership: state.membership!),
                  ),
                ),
                icon: const Icon(Icons.mail_outline, size: 16),
                label: const Text('Newsletter'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: pri,
                  side: BorderSide(color: sec, width: 0.8),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Redes sociales
          _buildSocialRow(bord, sec),
          const SizedBox(height: 12),

          // Cerrar sesión
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.read<AuthNotifier>().logout(),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: const BorderSide(color: AppColors.accent, width: 0.5),
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

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildSocialRow(Color bord, Color sec) {
    final socials = [
      _Social('Instagram', 'assets/icons/instagram.svg',
          'https://www.instagram.com/descifraguerra/'),
      _Social('Twitter', 'assets/icons/twitter.svg',
          'https://twitter.com/descifraguerra'),
      _Social('Telegram', 'assets/icons/telegram.svg',
          'https://t.me/descifrandolaguerra'),
      _Social('TikTok', 'assets/icons/tiktok.svg',
          'https://www.tiktok.com/@descifraguerra'),
      _Social('Twitch', 'assets/icons/twitch.svg',
          'https://www.twitch.tv/descifrandolaguerra'),
      _Social('YouTube', 'assets/icons/youtube.svg',
          'https://www.youtube.com/channel/UCvLrMnloIn_RqITF4Ly5ZEA'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: bord, width: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Síguenos',
            style: TextStyle(
              color: sec,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: socials
                .map((s) =>
                    _SocialButton(social: s, onTap: () => _openUrl(s.url)))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String name) {
    final initials = _initials(name);
    if (initials.isEmpty || initials == '?') {
      return Icon(Icons.person_outline, color: AppColors.accent, size: 28);
    }
    return Text(
      initials,
      style: TextStyle(
        color: AppColors.accent,
        fontSize: 20,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  String _initials(String name) {
    if (name.trim().isEmpty) return '';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name[0].toUpperCase();
  }
}

// ─── Tarjeta de membresía ─────────────────────────────────────────────────────
class _MembershipCard extends StatelessWidget {
  final MembershipInfo membership;
  final bool isDark;
  const _MembershipCard({required this.membership, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final surf = AppColors.surf(isDark);
    final bord = AppColors.bord(isDark);
    final pri = AppColors.textPri(isDark);
    final sec = AppColors.textSec(isDark);
    final mut = AppColors.textMut(isDark);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: membership.isActive ? AppColors.subscriberBorder : bord,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                membership.isActive
                    ? Icons.verified_outlined
                    : Icons.lock_outline,
                color: membership.isActive ? AppColors.subscriberText : mut,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  membership.name,
                  style: TextStyle(
                    color: pri,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: membership.isActive
                      ? AppColors.subscriberBg
                      : const Color(0x22888888),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  membership.status,
                  style: TextStyle(
                    color: membership.isActive ? AppColors.subscriberText : sec,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          if (membership.expiresAt != null &&
              membership.expiresAt!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(color: bord, thickness: 0.5),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, color: sec, size: 13),
                const SizedBox(width: 6),
                Text(
                  'Renovación: ${membership.expiresAt}',
                  style: TextStyle(color: pri, fontSize: 12),
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
  final bool isDark;
  const _LoginView({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final surf = AppColors.surf(isDark);
    final bord = AppColors.bord(isDark);
    final pri = AppColors.textPri(isDark);
    final sec = AppColors.textSec(isDark);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Iniciar sesión',
                style: TextStyle(
                    color: pri, fontSize: 24, fontWeight: FontWeight.w500),
              ),
              IconButton(
                icon: Icon(Icons.settings_outlined, color: sec, size: 22),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Accede a todo el contenido exclusivo de Descifrando la Guerra.',
            style: TextStyle(color: pri, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 32),
          if (auth.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x22C0392B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x55C0392B), width: 0.5),
              ),
              child: Text(auth.errorMessage!,
                  style:
                      const TextStyle(color: AppColors.accent, fontSize: 13)),
            ),
            const SizedBox(height: 16),
          ],
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surf,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: bord, width: 0.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined,
                    color: Color(0xFF4CAF50), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tu contraseña nunca es vista por la app — '
                    'introduces tus datos directamente en la web segura.',
                    style: TextStyle(color: pri, fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed:
                  auth.isLoading ? null : () => _openLoginWebView(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                disabledBackgroundColor:
                    AppColors.accent.withValues(alpha: 0.4),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Iniciar sesión',
                  style: TextStyle(fontSize: 15, color: Colors.white)),
            ),
          ),
          if (auth.isLoading) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: _SmoothProgressBar(target: auth.loginProgress),
            ),
            const SizedBox(height: 10),
            if (auth.loginStep != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                        width: 16, height: 16, child: _LoadingIcon()),
                    const SizedBox(width: 8),
                    Text(
                      auth.loginStep!,
                      style: TextStyle(
                        color: sec,
                        fontSize: 13,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Un momento. Estamos preparándolo todo para ti',
                style: TextStyle(
                  color: sec.withValues(alpha: 0.7),
                  fontSize: 12,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          const SizedBox(height: 24),
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

// ─── Icono de carga animado ─────────────────────────────────────────────

class _LoadingIcon extends StatefulWidget {
  const _LoadingIcon();

  @override
  State<_LoadingIcon> createState() => _LoadingIconState();
}

class _LoadingIconState extends State<_LoadingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: Tween<double>(begin: 0, end: 1).animate(_controller),
      child: Icon(
        Icons.refresh_rounded,
        size: 16,
        color: AppColors.accent,
      ),
    );
  }
}

// ─── Barra de progreso suave ─────────────────────────────────────────────────

/// Muestra el progreso del login avanzando continuamente hacia el objetivo.
///
/// Mientras espera las respuestas de red, la barra sigue avanzando muy
/// despacio hacia un techo situado un poco por encima del último punto de
/// control confirmado, de modo que nunca se queda congelada pero tampoco
/// reclama como completado un paso que aún está en curso. Cuando llega un
/// nuevo punto de control, la distancia restante crece y la barra acelera de
/// forma natural (aproximación exponencial con velocidad adaptativa según el
/// hueco restante), sin saltos.
class _SmoothProgressBar extends StatefulWidget {
  /// Punto de control confirmado por el proceso de login (0.33, 0.66, 1.0).
  final double target;

  const _SmoothProgressBar({required this.target});

  @override
  State<_SmoothProgressBar> createState() => _SmoothProgressBarState();
}

class _SmoothProgressBarState extends State<_SmoothProgressBar>
    with SingleTickerProviderStateMixin {
  /// Fracción del recorrido restante que se añade como margen de arrastre.
  static const double _creepMargin = 0.22;

  /// Velocidad de aproximación en arrastre, cerca del techo (1/s).
  static const double _kNormal = 0.6;

  /// Velocidad máxima al alcanzar un nuevo punto de control confirmado (1/s).
  static const double _kCatchUp = 0.5;

  /// Hueco a partir del cual se alcanza la velocidad máxima de alcance.
  static const double _catchUpGap = 0.08;

  /// Velocidad de aproximación en el tramo final, al cerrar el 100% (1/s).
  static const double _kFinal = 6.0;

  late final Ticker _ticker;
  double _value = 0.0;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    // dt en segundos, acotado para absorber jank puntual.
    final dt = ((elapsed - _lastElapsed).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _lastElapsed = elapsed;
    if (dt == 0) return;

    final target = widget.target.clamp(0.0, 1.0);
    // El techo de arrastre queda por encima del punto confirmado, pero nunca
    // alcanza el siguiente punto de control.
    final effective =
        target >= 1.0 ? 1.0 : target + (1.0 - target) * _creepMargin;

    final diff = effective - _value;
    if (diff <= 0) return; // nunca retrocede

    // Velocidad adaptativa: si la red confirma un nuevo punto de control y
    // el hueco es grande, acelerar para alcanzarlo; cerca del techo, seguir
    // con el arrastre lento.
    final double k;
    if (target >= 1.0) {
      k = _kFinal;
    } else {
      final t = (diff / _catchUpGap).clamp(0.0, 1.0);
      k = _kNormal + (_kCatchUp - _kNormal) * t;
    }
    var next = _value + diff * (1 - exp(-k * dt));

    // Snap al valor exacto cuando ya está prácticamente cerrado.
    if (target >= 1.0 && 1.0 - next < 0.02) next = 1.0;

    if (next != _value) setState(() => _value = next);
  }

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: _value,
      minHeight: 6,
      backgroundColor: const Color(0x33C0392B),
      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFC0392B)),
    );
  }
}

// ─── Social helpers ───────────────────────────────────────────────────────────

class _Social {
  final String label;
  final String iconAsset;
  final String url;
  const _Social(this.label, this.iconAsset, this.url);
}

class _SocialButton extends StatelessWidget {
  final _Social social;
  final VoidCallback onTap;
  const _SocialButton({required this.social, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: social.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: SvgPicture.asset(
            social.iconAsset,
            width: 22,
            height: 22,
            colorFilter: const ColorFilter.mode(
              AppColors.accent,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}
