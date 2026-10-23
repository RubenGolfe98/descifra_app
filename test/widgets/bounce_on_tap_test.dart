import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dlg_app/widgets/bounce_on_tap.dart';

double _scale(WidgetTester tester) => tester
    .widget<ScaleTransition>(find.descendant(
      of: find.byType(BounceOnTap),
      matching: find.byType(ScaleTransition),
    ))
    .scale
    .value;

void main() {
  Future<int> pumpButton(WidgetTester tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: BounceOnTap(
            child: IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => taps++,
            ),
          ),
        ),
      ),
    ));
    return taps;
  }

  testWidgets('rebota al tocar y el botón sigue recibiendo el tap',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: BounceOnTap(
            child: IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => taps++,
            ),
          ),
        ),
      ),
    ));

    expect(_scale(tester), 1);
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(_scale(tester), lessThan(1));
    await tester.pumpAndSettle();
    expect(_scale(tester), 1);
    expect(taps, 1);
  });

  testWidgets('no rebota si el dedo se desplaza', (tester) async {
    await pumpButton(tester);

    await tester.drag(find.byType(IconButton), const Offset(0, 60));
    await tester.pump();
    expect(_scale(tester), 1);
  });
}
