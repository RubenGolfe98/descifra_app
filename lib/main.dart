import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'repositories/article_repository.dart';
import 'services/auth_notifier.dart';
import 'services/favorites_service.dart';
import 'services/connectivity_service.dart';
import 'services/tag_service.dart';
import 'services/theme_notifier.dart';
import 'screens/home/main_screen.dart';
import 'theme/app_colors.dart';
import 'services/author_service.dart';
import 'services/onboarding_service.dart';
import 'screens/onboarding/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  PaintingBinding.instance.imageCache.maximumSize = 500;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024;

  // Estado del onboarding — lectura local, instantánea
  await OnboardingService.initialize();

  runApp(const DlgApp());
}

class DlgApp extends StatelessWidget {
  const DlgApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthNotifier()..initialize()),
        ChangeNotifierProvider(create: (_) => ThemeNotifier()..initialize()),
        ChangeNotifierProvider(create: (_) => ConnectivityService()),
        // Los favoritos son datos del usuario, no una tarea de fondo: van por
        // el pool principal para no competir con tags y autores.
        ChangeNotifierProvider(create: (_) => FavoritesService()),
      ],
      child: const _AppRoot(),
    );
  }
}

class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeNotifier>();
    final isDark = theme.isDark;
    final scale = theme.fontSize.scale;

    // Ajustar tasa de refresco
    if (theme.refreshRate == AppRefreshRate.high) {
      timeDilation = 1.0; // sin ralentización de animaciones
    }

    return MaterialApp(
      title: 'Descifrando la Guerra',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        // Aplicar escala de fuente global
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        );
      },
      theme: ThemeData(
        brightness: isDark ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: AppColors.bg(isDark),
        textTheme: theme.font.textTheme(
          isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
        ),
      ),
      home: _AppGate(isDark: isDark, font: theme.font),
    );
  }
}

class _AppGate extends StatefulWidget {
  final bool isDark;
  final AppFont font;
  const _AppGate({required this.isDark, required this.font});

  @override
  State<_AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<_AppGate> {
  /// Margen tras el arranque antes de lanzar las taxonomías, para que el
  /// listado de artículos —que es lo que el usuario está esperando— tenga
  /// la red para él solo.
  static const _taxonomiesDelay = Duration(seconds: 3);

  bool _minTimeElapsed = false;
  bool _taxonomiesStarted = false;
  bool _showOnboarding = !OnboardingService.completed;

  @override
  void initState() {
    super.initState();

    // Mínimo de permanencia de la splash para branding
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _minTimeElapsed = true);
    });
  }

  Future<void> _loadTaxonomies() async {
    // Secuencial a propósito: ambas comparten el pool de fondo, que solo
    // admite dos conexiones. Lanzarlas en paralelo hacía que se bloquearan
    // mutuamente y agotaran su plazo sin llegar a salir.
    await TagService.initialize(client: SharedHttp.bgClient);
    await AuthorService.initialize(client: SharedHttp.bgClient);

    // Forzar reconstrucción para que ArticleTagBadge y ArticleDetailScreen
    // recojan los tags cargados (si aún no se habían cargado antes).
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final ready = !auth.initializing && _minTimeElapsed;

    // Cargar favoritos cuando el usuario está logueado — fuera del build
    if (ready) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final favorites = context.read<FavoritesService>();
        if (auth.state.isLoggedIn) {
          if (!favorites.loaded) {
            // Si ya hay una carga en vuelo, el servicio la reutiliza.
            favorites.loadFavorites(auth.state.cookies ?? '');
          }
        } else {
          favorites.clear();
        }

        // Tags y autores se cargan en segundo plano DESPUÉS de que MainScreen
        // y la petición de artículos ya se hayan lanzado.
        if (!_taxonomiesStarted) {
          _taxonomiesStarted = true;
          Future.delayed(_taxonomiesDelay, () {
            if (mounted) _loadTaxonomies();
          });
        }
      });
    }

    if (!ready) {
      return Scaffold(
        backgroundColor: AppColors.bg(widget.isDark),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(
                child: Image(
                  image: AssetImage(widget.isDark
                      ? 'assets/images/logo_dlg_dark.png'
                      : 'assets/images/logo_dlg.png'),
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'DESCIFRANDO LA GUERRA',
                style: widget.font.style(
                  color: AppColors.textPri(widget.isDark),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 32),
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: AppColors.accent,
                  strokeWidth: 2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Primera vez que se abre la app — bienvenida y configuración inicial.
    // Va después del gate para que favoritos y taxonomías ya se estén
    // cargando en segundo plano mientras el usuario lee la bienvenida.
    if (_showOnboarding) {
      return OnboardingScreen(
        onFinished: () {
          if (mounted) setState(() => _showOnboarding = false);
        },
      );
    }

    return const MainScreen();
  }
}
