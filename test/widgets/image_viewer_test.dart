import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dlg_app/widgets/image_viewer.dart';

/// Monta un botón que abre el visor en modo galería con los items dados.
Widget buildHarness(List<GalleryItem> items, {int initialIndex = 0}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showImageGalleryViewer(
            context,
            items: items,
            initialIndex: initialIndex,
          ),
          child: const Text('Abrir'),
        ),
      ),
    ),
  );
}

/// Monta un botón que abre el visor en modo galería agrupada.
Widget buildGroupedHarness(List<GalleryItem> items, {int initialIndex = 0}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showImageGroupedGalleryViewer(
            context,
            items: items,
            initialIndex: initialIndex,
          ),
          child: const Text('Abrir'),
        ),
      ),
    ),
  );
}

const item1 = (
  url: 'https://example.com/mapa1.jpg',
  caption: 'Mapa uno',
  group: null,
);
const item2 = (
  url: 'https://example.com/mapa2.jpg',
  caption: 'Mapa dos',
  group: null,
);
const item3 = (
  url: 'https://example.com/mapa3.jpg',
  caption: 'Mapa tres',
  group: null,
);

Future<void> openGallery(WidgetTester tester, List<GalleryItem> items,
    {int initialIndex = 0}) async {
  await tester.pumpWidget(buildHarness(items, initialIndex: initialIndex));
  await tester.tap(find.text('Abrir'));
  // La imagen de red nunca se resuelve en tests, así que no se puede usar
  // pumpAndSettle: basta con bombear la animación de entrada de la ruta.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> openGroupedGallery(WidgetTester tester, List<GalleryItem> items,
    {int initialIndex = 0}) async {
  await tester
      .pumpWidget(buildGroupedHarness(items, initialIndex: initialIndex));
  await tester.tap(find.text('Abrir'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Bombea la animación de cambio de página tras un fling.
Future<void> settlePageView(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// Devuelve el [TransformationController] del [InteractiveViewer] visible.
TransformationController _transformationControllerOf(WidgetTester tester) {
  final viewer = tester.widget<InteractiveViewer>(
    find.byType(InteractiveViewer).first,
  );
  return viewer.transformationController!;
}

void main() {
  group('Visor en modo galería', () {
    testWidgets('muestra el contador con la posición inicial', (tester) async {
      await openGallery(tester, [item1, item2, item3]);

      expect(find.text('1 / 3'), findsOneWidget);
    });

    testWidgets('muestra el título del mapa actual', (tester) async {
      await openGallery(tester, [item1, item2, item3]);

      expect(find.text('Mapa uno'), findsOneWidget);
    });

    testWidgets('respeta el índice inicial', (tester) async {
      await openGallery(tester, [item1, item2, item3], initialIndex: 2);

      expect(find.text('3 / 3'), findsOneWidget);
      expect(find.text('Mapa tres'), findsOneWidget);
    });

    testWidgets('deslizar a la izquierda avanza al mapa siguiente',
        (tester) async {
      await openGallery(tester, [item1, item2, item3]);

      await tester.fling(
          find.byType(PageView), const Offset(-400, 0), 1000);
      await settlePageView(tester);

      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('Mapa dos'), findsOneWidget);
    });

    testWidgets('deslizar a la derecha vuelve al mapa anterior',
        (tester) async {
      await openGallery(tester, [item1, item2, item3], initialIndex: 1);

      await tester.fling(
          find.byType(PageView), const Offset(400, 0), 1000);
      await settlePageView(tester);

      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.text('Mapa uno'), findsOneWidget);
    });

    testWidgets('no avanza más allá del último mapa', (tester) async {
      await openGallery(tester, [item1, item2], initialIndex: 1);

      await tester.fling(
          find.byType(PageView), const Offset(-400, 0), 1000);
      await settlePageView(tester);

      expect(find.text('2 / 2'), findsOneWidget);
    });

    testWidgets('omite el caption cuando el mapa no tiene título',
        (tester) async {
      await openGallery(tester, [
        (url: 'https://example.com/mapa1.jpg', caption: null, group: null),
        item2,
      ]);

      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.text('Mapa dos'), findsNothing);
    });

    testWidgets('con zoom activo el swipe no cambia de mapa', (tester) async {
      await openGallery(tester, [item1, item2, item3]);

      // Ampliar la imagen actual (escala x3).
      final controller = _transformationControllerOf(tester);
      controller.value = Matrix4.diagonal3Values(3.0, 3.0, 1.0);
      await tester.pump();

      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await settlePageView(tester);

      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.text('Mapa uno'), findsOneWidget);
    });

    testWidgets('al quitar el zoom el swipe vuelve a cambiar de mapa',
        (tester) async {
      await openGallery(tester, [item1, item2, item3]);

      final controller = _transformationControllerOf(tester);
      controller.value = Matrix4.diagonal3Values(3.0, 3.0, 1.0);
      await tester.pump();
      controller.value = Matrix4.identity();
      await tester.pump();

      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await settlePageView(tester);

      expect(find.text('2 / 3'), findsOneWidget);
      expect(find.text('Mapa dos'), findsOneWidget);
    });
  });

  group('Visor en modo galería agrupada', () {
    const europa1 = (
      url: 'https://example.com/eu1.jpg',
      caption: 'Mapa Europa 1',
      group: 'Europa',
    );
    const europa2 = (
      url: 'https://example.com/eu2.jpg',
      caption: 'Mapa Europa 2',
      group: 'Europa',
    );
    const asia1 = (
      url: 'https://example.com/as1.jpg',
      caption: 'Mapa Asia 1',
      group: 'Asia-Pacífico',
    );
    const asia2 = (
      url: 'https://example.com/as2.jpg',
      caption: 'Mapa Asia 2',
      group: 'Asia-Pacífico',
    );
    const asia3 = (
      url: 'https://example.com/as3.jpg',
      caption: 'Mapa Asia 3',
      group: 'Asia-Pacífico',
    );
    const groupedItems = [europa1, europa2, asia1, asia2, asia3];

    testWidgets('muestra la región y la posición dentro de ella',
        (tester) async {
      await openGroupedGallery(tester, groupedItems);

      expect(find.text('Europa 1/2'), findsOneWidget);
      expect(find.text('Mapa Europa 1'), findsOneWidget);
    });

    testWidgets('respeta el índice inicial en medio del segundo grupo',
        (tester) async {
      await openGroupedGallery(tester, groupedItems, initialIndex: 3);

      expect(find.text('Asia-Pacífico 2/3'), findsOneWidget);
      expect(find.text('Mapa Asia 2'), findsOneWidget);
    });

    testWidgets('al cruzar de región cambia el nombre y se reinicia el número',
        (tester) async {
      await openGroupedGallery(tester, groupedItems, initialIndex: 1);

      // Último mapa de Europa.
      expect(find.text('Europa 2/2'), findsOneWidget);

      // Swipe: primer mapa de Asia-Pacífico.
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await settlePageView(tester);

      expect(find.text('Asia-Pacífico 1/3'), findsOneWidget);
      expect(find.text('Mapa Asia 1'), findsOneWidget);
    });

    testWidgets('con zoom activo el swipe no cambia de mapa', (tester) async {
      await openGroupedGallery(tester, groupedItems);

      final controller = _transformationControllerOf(tester);
      controller.value = Matrix4.diagonal3Values(3.0, 3.0, 1.0);
      await tester.pump();

      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await settlePageView(tester);

      expect(find.text('Europa 1/2'), findsOneWidget);
    });
  });

  group('Visor de imagen única', () {
    testWidgets('no muestra contador con una sola imagen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () =>
                    showImageViewer(context, 'https://example.com/mapa1.jpg'),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('1 / 1'), findsNothing);
    });
  });
}
