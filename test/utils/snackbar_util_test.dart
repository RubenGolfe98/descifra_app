import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:dlg_app/services/theme_notifier.dart';
import 'package:dlg_app/theme/app_colors.dart';
import 'package:dlg_app/utils/snackbar_utils.dart';

/// ThemeNotifier con el tema fijado, sin pasar por el almacenamiento.
class FakeThemeNotifier extends ThemeNotifier {
  FakeThemeNotifier(this._mode);

  final AppThemeMode _mode;

  @override
  AppThemeMode get themeMode => _mode;

  @override
  bool get isDark => _mode == AppThemeMode.dark;
}

/// Monta un botón que lanza el aviso con el tema indicado.
Widget buildHarness({AppThemeMode mode = AppThemeMode.light}) {
  return ChangeNotifierProvider<ThemeNotifier>.value(
    value: FakeThemeNotifier(mode),
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showArticleLoadingSnackBar(context),
            child: const Text('Lanzar'),
          ),
        ),
      ),
    ),
  );
}

/// Devuelve el SnackBar visible en pantalla.
SnackBar snackBarOf(WidgetTester tester) =>
    tester.widget<SnackBar>(find.byType(SnackBar));

void main() {
  group('Contenido del aviso', () {
    testWidgets('muestra el texto de carga', (tester) async {
      await tester.pumpWidget(buildHarness());

      await tester.tap(find.text('Lanzar'));
      await tester.pump();

      expect(find.text('Cargando artículo...'), findsOneWidget);
    });

    testWidgets('muestra un indicador de progreso', (tester) async {
      await tester.pumpWidget(buildHarness());

      await tester.tap(find.text('Lanzar'));
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
    });

    testWidgets('el indicador usa el color de acento', (tester) async {
      await tester.pumpWidget(buildHarness());

      await tester.tap(find.text('Lanzar'));
      await tester.pump();

      final indicador = tester.widget<CircularProgressIndicator>(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.byType(CircularProgressIndicator),
        ),
      );

      expect(indicador.color, AppColors.accent);
      expect(indicador.strokeWidth, 2);
    });
  });

  group('Duración', () {
    testWidgets('permanece visible dos segundos', (tester) async {
      await tester.pumpWidget(buildHarness());

      await tester.tap(find.text('Lanzar'));
      await tester.pump();

      expect(snackBarOf(tester).duration, const Duration(seconds: 2));
    });

    testWidgets('desaparece por sí solo al cumplirse el plazo', (tester) async {
      await tester.pumpWidget(buildHarness());

      await tester.tap(find.text('Lanzar'));
      await tester.pump();
      expect(find.text('Cargando artículo...'), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      expect(find.text('Cargando artículo...'), findsNothing);
    });

    testWidgets('sigue visible antes de que expire', (tester) async {
      await tester.pumpWidget(buildHarness());

      await tester.tap(find.text('Lanzar'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Cargando artículo...'), findsOneWidget);
    });
  });

  group('Adaptación al tema', () {
    testWidgets('usa los colores del tema claro', (tester) async {
      await tester.pumpWidget(buildHarness(mode: AppThemeMode.light));

      await tester.tap(find.text('Lanzar'));
      await tester.pump();

      expect(snackBarOf(tester).backgroundColor, AppColors.surf(false));

      final texto = tester.widget<Text>(find.text('Cargando artículo...'));
      expect(texto.style?.color, AppColors.textPri(false));
    });

    testWidgets('usa los colores del tema oscuro', (tester) async {
      await tester.pumpWidget(buildHarness(mode: AppThemeMode.dark));

      await tester.tap(find.text('Lanzar'));
      await tester.pump();

      expect(snackBarOf(tester).backgroundColor, AppColors.surf(true));

      final texto = tester.widget<Text>(find.text('Cargando artículo...'));
      expect(texto.style?.color, AppColors.textPri(true));
    });

    testWidgets('el fondo cambia según el tema', (tester) async {
      await tester.pumpWidget(buildHarness(mode: AppThemeMode.light));
      await tester.tap(find.text('Lanzar'));
      await tester.pump();
      final claro = snackBarOf(tester).backgroundColor;

      await tester.pumpWidget(buildHarness(mode: AppThemeMode.dark));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lanzar'));
      await tester.pump();
      final oscuro = snackBarOf(tester).backgroundColor;

      expect(claro, isNot(oscuro));
    });
  });

  group('Llamadas repetidas', () {
    testWidgets('se puede lanzar varias veces seguidas', (tester) async {
      await tester.pumpWidget(buildHarness());

      await tester.tap(find.text('Lanzar'));
      await tester.pump();
      await tester.tap(find.text('Lanzar'));
      await tester.pump();

      // El segundo aviso se encola tras el primero.
      expect(find.byType(SnackBar), findsWidgets);
    });

    testWidgets('no lanza excepción al invocarse dos veces', (tester) async {
      await tester.pumpWidget(buildHarness());

      await tester.tap(find.text('Lanzar'));
      await tester.pump();
      await tester.tap(find.text('Lanzar'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
