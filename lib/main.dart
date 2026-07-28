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
import 'screens/main_screen.dart';
import 'theme/app_colors.dart';
import 'services/author_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  PaintingBinding.instance.imageCache.maximumSize = 500;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 * 1024 * 1024;

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
        ChangeNotifierProvider(
            create: (_) => FavoritesService(client: SharedHttp.bgClient)),
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
  bool _minTimeElapsed = false;
  bool _taxonomiesStarted = false;

  @override
  void initState() {
    super.initState();

    // Mínimo de permanencia de la splash para branding
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _minTimeElapsed = true);
    });
  }

  Future<void> _loadTaxonomies() async {
    await Future.wait([
      TagService.initialize(client: SharedHttp.bgClient),
      AuthorService.initialize(client: SharedHttp.bgClient),
    ]).timeout(const Duration(seconds: 8), onTimeout: () => []);

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
            favorites.loadFavorites(auth.state.cookies ?? '');
          }
        } else {
          favorites.clear();
        }

        // Tags y autores se cargan en segundo plano DESPUÉS de que MainScreen
        // y la petición de artículos ya se hayan lanzado.
        // Así no compiten por ancho de banda con el contenido principal.
        if (!_taxonomiesStarted) {
          _taxonomiesStarted = true;
          _loadTaxonomies();
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

    return const MainScreen();
  }
}
