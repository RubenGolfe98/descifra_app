import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:dlg_app/services/theme_notifier.dart';
import 'package:dlg_app/widgets/content_card.dart';

Widget buildHarness({required Widget child}) {
  return ChangeNotifierProvider<ThemeNotifier>(
    create: (_) => ThemeNotifier(),
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets('renderiza título, descripción, badges y meta', (tester) async {
    await tester.pumpWidget(buildHarness(
      child: const ContentCard(
        imageUrl: '',
        title: 'Título de prueba',
        description: 'Descripción de prueba',
        meta: '12 feb 2026',
        badges: [
          CardBadge(
            label: 'Análisis',
            background: Colors.red,
            foreground: Colors.white,
          ),
        ],
        onTap: _noOp,
      ),
    ));

    expect(find.text('Título de prueba'), findsOneWidget);
    expect(find.text('Descripción de prueba'), findsOneWidget);
    expect(find.text('12 feb 2026'), findsOneWidget);
    expect(find.text('Análisis'), findsOneWidget);
  });

  testWidgets('omite las secciones vacías (descripción y meta)',
      (tester) async {
    await tester.pumpWidget(buildHarness(
      child: const ContentCard(
        imageUrl: '',
        title: 'Solo título',
        description: '',
        onTap: _noOp,
      ),
    ));

    expect(find.text('Solo título'), findsOneWidget);
    // Solo un Text: título, sin descripción ni meta
    expect(find.byType(Text), findsNWidgets(1));
  });

  testWidgets('ejecuta onTap al pulsar', (tester) async {
    var taps = 0;
    await tester.pumpWidget(buildHarness(
      child: ContentCard(
        imageUrl: '',
        title: 'Púlsame',
        description: '',
        onTap: () => taps++,
      ),
    ));

    await tester.tap(find.text('Púlsame'));
    expect(taps, 1);
  });

  testWidgets(
      'muestra portada con AspectRatio 16:9 cuando imageUrl no está vacía',
      (tester) async {
    await tester.pumpWidget(buildHarness(
      child: const ContentCard(
        imageUrl: 'https://example.com/portada.jpg',
        title: 'Artículo con imagen',
        description: 'Descripción',
        onTap: _noOp,
      ),
    ));

    final aspectRatioFinder = find.byType(AspectRatio);
    expect(aspectRatioFinder, findsOneWidget);
    final aspectRatioWidget = tester.widget<AspectRatio>(aspectRatioFinder);
    expect(aspectRatioWidget.aspectRatio, closeTo(16 / 9, 0.001));
  });
}

void _noOp() {}
