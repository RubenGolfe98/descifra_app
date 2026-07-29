import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/onboarding_service.dart';
import '../../services/theme_notifier.dart';
import '../../theme/app_colors.dart';
import '../settings/widgets/settings_selectors.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinished;
  const OnboardingScreen({super.key, required this.onFinished});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _totalPages = 4;
  static const _repoUrl = 'https://github.com/RubenGolfe98/descifra_app';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _totalPages - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _back() => _controller.previousPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );

  Future<void> _finish() async {
    await OnboardingService.complete();
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeNotifier, bool>((t) => t.isDark);

    return Scaffold(
      backgroundColor: AppColors.bg(isDark),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _WelcomePage(isDark: isDark, repoUrl: _repoUrl),
                  const _StepPage(
                    step: 1,
                    title: 'Elige tu apariencia',
                    subtitle:
                        'Puedes cambiar entre modo claro y oscuro según prefieras.',
                    child: ThemeSelector(),
                  ),
                  const _StepPage(
                    step: 2,
                    title: 'Ajusta el texto',
                    subtitle:
                        'Elige el tamaño de letra que te resulte más cómodo para leer.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FontSizeSelector(),
                        SizedBox(height: 20),
                        JustifiedTextToggle(),
                      ],
                    ),
                  ),
                  const _StepPage(
                    step: 3,
                    title: 'Escoge la tipografía',
                    subtitle:
                        'Cada tipo de letra da un carácter distinto a la lectura.',
                    child: FontFamilySelector(),
                  ),
                ],
              ),
            ),
            _BottomBar(
              page: _page,
              totalPages: _totalPages,
              isDark: isDark,
              onNext: _next,
              onBack: _back,
              onSkip: _finish,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Página de bienvenida ─────────────────────────────────────────────────────
class _WelcomePage extends StatefulWidget {
  final bool isDark;
  final String repoUrl;

  const _WelcomePage({required this.isDark, required this.repoUrl});

  @override
  State<_WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<_WelcomePage> {
  late final TapGestureRecognizer _repoTap;

  @override
  void initState() {
    super.initState();
    _repoTap = TapGestureRecognizer()..onTap = () => _openRepo(widget.repoUrl);
  }

  @override
  void dispose() {
    _repoTap.dispose();
    super.dispose();
  }

  Future<void> _openRepo(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final pri = AppColors.textPri(isDark);
    final sec = AppColors.textSec(isDark);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: ClipOval(
              child: Image.asset(
                isDark
                    ? 'assets/images/logo_dlg_dark.png'
                    : 'assets/images/logo_dlg.png',
                width: 72,
                height: 72,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 24),
          MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.noScaling),
            child: Text(
              '¡Bienvenido/a a la app de\nDescifrando la Guerra! 🌍',
              style: TextStyle(
                color: pri,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Queremos darte las gracias de corazón por descargar nuestra '
            'aplicación y por tu apoyo constante. Gracias a lectores como tú '
            'podemos seguir trabajando día a día para ofrecerte la mejor '
            'información y el análisis internacional más riguroso.',
            style: TextStyle(color: sec, fontSize: 14, height: 1.65),
          ),
          const SizedBox(height: 24),
          _WelcomeBlock(
            title: 'Proyecto hecho por y para la comunidad 💻',
            isDark: isDark,
            child: Text.rich(
              TextSpan(
                style: TextStyle(color: sec, fontSize: 14, height: 1.65),
                children: [
                  const TextSpan(
                    text:
                        'Esta aplicación es de código abierto y ha sido desarrollada '
                        'de forma colaborativa por nuestra propia comunidad. Si te gusta '
                        'la programación y tienes ideas de mejora, puedes aportar tu '
                        'granito de arena al proyecto a través de nuestro ',
                  ),
                  TextSpan(
                    text: 'repositorio en GitHub',
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                    recognizer: _repoTap,
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _WelcomeBlock(
            title: '¿Nos echas una mano? ⭐',
            isDark: isDark,
            child: Text(
              'Si la aplicación te resulta útil para mantenerte informado, nos '
              'ayudaría un montón que dedicaras un minuto a dejarnos una '
              'valoración positiva en la tienda de aplicaciones. Ese pequeño '
              'gesto nos da muchísima visibilidad y permite que el proyecto '
              'siga creciendo.',
              style: TextStyle(color: sec, fontSize: 14, height: 1.65),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '¡Gracias por estar al otro lado de la pantalla y acompáñanos a '
            'seguir descifrando el mundo!',
            style: TextStyle(
              color: pri,
              fontSize: 14,
              height: 1.65,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bloque con título dentro de la bienvenida ────────────────────────────────
class _WelcomeBlock extends StatelessWidget {
  final String title;
  final Widget child;
  final bool isDark;

  const _WelcomeBlock({
    required this.title,
    required this.child,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surf(isDark),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.bord(isDark), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppColors.textPri(isDark),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

// ─── Página de configuración ──────────────────────────────────────────────────
class _StepPage extends StatelessWidget {
  final int step;
  final String title;
  final String subtitle;
  final Widget child;

  const _StepPage({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<ThemeNotifier, bool>((t) => t.isDark);
    final pri = AppColors.textPri(isDark);
    final sec = AppColors.textSec(isDark);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(label: 'Paso $step de 3'),
          const SizedBox(height: 12),
          MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.noScaling),
            child: Text(
              title,
              style: TextStyle(
                color: pri,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: sec, fontSize: 14, height: 1.6),
          ),
          const SizedBox(height: 24),
          child,
          const SizedBox(height: 20),
          _SettingsHint(isDark: isDark),
        ],
      ),
    );
  }
}

// ─── Aviso de que se puede cambiar luego en Ajustes ───────────────────────────
class _SettingsHint extends StatelessWidget {
  final bool isDark;
  const _SettingsHint({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.accentDim,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Puedes cambiar esto cuando quieras desde Ajustes, '
              'dentro de tu perfil.',
              style: TextStyle(
                color: AppColors.textSec(isDark),
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Barra inferior: indicador + botones ──────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final int page;
  final int totalPages;
  final bool isDark;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  const _BottomBar({
    required this.page,
    required this.totalPages,
    required this.isDark,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final isFirst = page == 0;
    final isLast = page == totalPages - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.bord(isDark), width: 0.5),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(totalPages, (i) {
              final active = i == page;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? AppColors.accent : AppColors.bord(isDark),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 88,
                child: isFirst
                    ? const SizedBox.shrink()
                    : TextButton(
                        onPressed: onBack,
                        child: Text(
                          'Atrás',
                          style: TextStyle(
                            color: AppColors.textSec(isDark),
                            fontSize: 14,
                          ),
                        ),
                      ),
              ),
              Expanded(
                child: FilledButton(
                  onPressed: onNext,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    isFirst
                        ? 'Configurar la app'
                        : isLast
                            ? 'Empezar a leer'
                            : 'Continuar',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 88,
                child: isLast
                    ? const SizedBox.shrink()
                    : TextButton(
                        onPressed: onSkip,
                        child: Text(
                          'Omitir',
                          style: TextStyle(
                            color: AppColors.textSec(isDark),
                            fontSize: 14,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
