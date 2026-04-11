import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/auth_notifier.dart';
import 'screens/main_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const DlgApp());
}

class DlgApp extends StatelessWidget {
  const DlgApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthNotifier()..initialize(),
      child: MaterialApp(
        title: 'Descifrando la Guerra',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0D0D0D),
          fontFamily: 'Roboto',
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
        ),
        home: const _AppGate(),
      ),
    );
  }
}

/// Decide qué mostrar según el estado de sesión al arrancar.
/// Solo bloquea mientras lee el storage por primera vez (milisegundos).
/// El isLoading del login NO afecta aquí — evita redirecciones no deseadas.
class _AppGate extends StatelessWidget {
  const _AppGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();

    if (auth.initializing) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D0D),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFC0392B),
            strokeWidth: 2,
          ),
        ),
      );
    }

    return const MainScreen();
  }
}