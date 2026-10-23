import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dlg_app/widgets/appear_animation.dart';

double _opacity(WidgetTester tester) => tester
    .widget<FadeTransition>(find.descendant(
      of: find.byType(AppearAnimation),
      matching: find.byType(FadeTransition),
    ))
    .opacity
    .value;

void main() {
  testWidgets('con animate entra con fundido', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: AppearAnimation(child: Text('nuevo')),
    ));

    expect(_opacity(tester), 0);
    await tester.pump(const Duration(milliseconds: 150));
    expect(_opacity(tester), inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(_opacity(tester), 1);
  });

  testWidgets('sin animate se pinta directamente', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: AppearAnimation(animate: false, child: Text('existente')),
    ));

    expect(_opacity(tester), 1);
  });

  testWidgets('con delay espera antes de empezar', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: AppearAnimation(
        delay: Duration(milliseconds: 200),
        expand: false,
        child: Text('escalonado'),
      ),
    ));

    await tester.pump(const Duration(milliseconds: 150));
    expect(_opacity(tester), 0);
    await tester.pumpAndSettle();
    expect(_opacity(tester), 1);
  });
}
