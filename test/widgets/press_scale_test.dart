import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dlg_app/widgets/press_scale.dart';

double _scale(WidgetTester tester) =>
    tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

void main() {
  testWidgets('encoge mientras está pulsado y vuelve al soltar',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PressScale(
          builder: (onHighlightChanged) => InkWell(
            onTap: () {},
            onHighlightChanged: onHighlightChanged,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      ),
    ));

    expect(_scale(tester), 1);
    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(InkWell)));
    await tester.pump();
    expect(_scale(tester), 0.98);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(_scale(tester), 1);
  });

  testWidgets('en un toque rápido mantiene el encogido un mínimo',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PressScale(
          builder: (onPressedChanged) => GestureDetector(
            onTapDown: (_) => onPressedChanged(true),
            onTapUp: (_) => onPressedChanged(false),
            onTap: () {},
            child: const ColoredBox(
              color: Colors.blue,
              child: SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.byType(ColoredBox).last);
    await tester.pump();
    expect(_scale(tester), 0.98);
    await tester.pumpAndSettle();
    expect(_scale(tester), 1);
  });
}
