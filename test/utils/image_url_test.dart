import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dlg_app/utils/image_url.dart';

void main() {
  group('bestImageUrl', () {
    const sizes = {
      300: 'https://e.com/img-300.jpg',
      768: 'https://e.com/img-768.jpg',
      1024: 'https://e.com/img-1024.jpg',
      2048: 'https://e.com/img-2048.jpg',
    };
    const fallback = 'https://e.com/img-full.jpg';

    test('elige el menor tamaño que cubre el objetivo', () {
      expect(
        bestImageUrl(sizes: sizes, fallbackUrl: fallback, targetWidth: 500),
        'https://e.com/img-768.jpg',
      );
      expect(
        bestImageUrl(sizes: sizes, fallbackUrl: fallback, targetWidth: 1024),
        'https://e.com/img-1024.jpg',
      );
    });

    test('usa el original si ningún tamaño llega al objetivo', () {
      expect(
        bestImageUrl(sizes: sizes, fallbackUrl: fallback, targetWidth: 3000),
        fallback,
      );
    });

    test('usa el original si no hay tamaños', () {
      expect(
        bestImageUrl(sizes: const {}, fallbackUrl: fallback, targetWidth: 500),
        fallback,
      );
    });
  });

  group('imageCacheWidth', () {
    testWidgets('devuelve ancho lógico × DPR', (tester) async {
      late int result;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
              size: Size(390, 844), devicePixelRatio: 3.0),
          child: Builder(
            builder: (context) {
              result = imageCacheWidth(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(result, 1170);
    });

    testWidgets('respeta el ancho explícito', (tester) async {
      late int result;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
              size: Size(390, 844), devicePixelRatio: 2.0),
          child: Builder(
            builder: (context) {
              result = imageCacheWidth(context, width: 350);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(result, 700);
    });

    testWidgets('aplica el clamp superior en pantallas enormes', (tester) async {
      late int result;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
              size: Size(2000, 3000), devicePixelRatio: 2.0),
          child: Builder(
            builder: (context) {
              result = imageCacheWidth(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(result, 2560);
    });
  });
}
