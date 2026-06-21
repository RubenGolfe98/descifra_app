import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'repositories/article_repository.dart';
import 'services/auth_notifier.dart';
import 'services/favorites_service.dart';
import 'services/connectivity_service.dart';
import 'services/theme_notifier.dart';
import 'screens/main_screen.dart';
import 'theme/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Aumentamos el límite de la caché de imágenes para reducir
  // evicciones prematuras al hacer scroll o abrir detalle.
  PaintingBinding.instance.imageCache.maximumSize = 500;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 100 * 1024 * 1024;

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

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  @override
  void dispose() {
    SharedHttp.dispose();
    super.dispose();
  }

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
  bool _favoritesHandled = false;

  @override
  void initState() {
    super.initState();
    // Escuchar cambios en AuthNotifier para cargar favoritos tras inicializar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthNotifier>().addListener(_onAuthChanged);
      // Comprobar si ya está inicializado
      _onAuthChanged();
    });
  }

  @override
  void dispose() {
    // No podemos acceder a context tras dispose, pero el notifier
    // vivirá mientras el provider exista; ignoramos errores silenciosamente.
    try {
      context.read<AuthNotifier>().removeListener(_onAuthChanged);
    } catch (_) {}
    super.dispose();
  }

  void _onAuthChanged() {
    if (_favoritesHandled) return;
    final auth = context.read<AuthNotifier>();
    if (auth.initializing) return;
    _favoritesHandled = true;

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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();

    if (auth.initializing) {
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