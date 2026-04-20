import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'services/analytics_service.dart';
import 'services/auth_notifier.dart';
import 'services/favorites_service.dart';
import 'services/connectivity_service.dart';
import 'services/theme_notifier.dart';
import 'repositories/coverage_repository.dart';
import 'repositories/seminar_repository.dart';
import 'screens/main_screen.dart';
import 'theme/app_colors.dart';

// Este import solo existe si has ejecutado `flutterfire configure`
// Si no existe, Firebase simplemente no se inicializa y la app funciona igual
import 'firebase_options.dart' as fb_options
    // ignore: uri_does_not_exist
    if (dart.library.io) 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Firebase de forma opcional — si no hay configuración, la app
  // sigue funcionando sin Analytics (útil para contribuidores sin credenciales)
  try {
    await Firebase.initializeApp(
      options: fb_options.DefaultFirebaseOptions.currentPlatform,
    );
    AnalyticsService.init(FirebaseAnalytics.instance);
  } catch (e) {
    debugPrint('📊 [Analytics] Firebase no configurado — desactivado: $e');
  }

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  PaintingBinding.instance.imageCache.maximumSize = 100;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024;

  // Precarga en background al arrancar — no bloquea el inicio de la app
  CoverageRepository.prefetch();
  SeminarRepository.prefetch();

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
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
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
  bool _minTimeElapsed = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _minTimeElapsed = true);
    });
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
            favorites.loadFavorites(auth.state.cookies ?? '');
          }
        } else {
          favorites.clear();
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
                  image: AssetImage(widget.isDark ? 'assets/images/logo_dlg_dark.png' : 'assets/images/logo_dlg.png'),
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

    return const MainScreen();
  }
}