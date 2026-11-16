import 'package:diapo/ui/theme/carrete_tokens.dart';
import 'package:diapo/ui/widgets/plastic_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The top edge of the painted face of the key with [label].
double _faceTop(WidgetTester tester, String label) => tester
    .getRect(
      find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is PlasticKey && w.semanticLabel == label,
        ),
        matching: find.byType(CustomPaint),
      ),
    )
    .top;

void main() {
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PlasticKey(
                  semanticLabel: 'on',
                  selected: true,
                  onPressed: () {},
                  child: const Text('A'),
                ),
                PlasticKey(
                  semanticLabel: 'off',
                  selected: false,
                  onPressed: () {},
                  child: const Text('B'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a selected key stays level with its neighbours', (tester) async {
    await pump(tester);

    expect(_faceTop(tester, 'on'), _faceTop(tester, 'off'));
  });

  testWidgets('a key moves down only while the finger is on it', (
    tester,
  ) async {
    await pump(tester);
    final rest = _faceTop(tester, 'off');

    final gesture = await tester.startGesture(tester.getCenter(find.text('B')));
    await tester.pumpAndSettle();
    expect(
      _faceTop(tester, 'off'),
      closeTo(rest + CarreteSizes.keySink * CarreteSpacing.minTouch, 0.01),
    );

    await gesture.up();
    await tester.pumpAndSettle();
    expect(_faceTop(tester, 'off'), rest);
  });
}
