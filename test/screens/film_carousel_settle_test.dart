import 'package:carrete/l10n/app_localizations.dart';
import 'package:carrete/screens/viewfinder/film_carousel.dart';
import 'package:film_recipes/film_recipes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Recipe _film(int i) => Recipe(
  id: 'film$i',
  name: LocalizedText(es: 'Film $i', ca: 'Film $i', en: 'Film $i'),
  description: LocalizedText(es: 'd', ca: 'd', en: 'd'),
);

class _Harness {
  int settled = 0;
  String selected = 'film0';

  /// Chooses a film as the camera does, not by a tap on the list.
  late void Function(String id) select;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  bool reducedMotion = false,
}) async {
  final h = _Harness();
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(412, 915);
  addTearDown(tester.view.reset);
  if (reducedMotion) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) {
            h.select = (id) => setState(() => h.selected = id);
            return Align(
              alignment: Alignment.bottomCenter,
              child: FilmCarousel(
                recipes: [for (var i = 0; i < 12; i++) _film(i)],
                selectedId: h.selected,
                onSelected: (r) => setState(() => h.selected = r.id),
                onTune: (_) {},
                onSettled: () => h.settled++,
                thumbnailBuilder: (context, recipe) => const SizedBox(),
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return h;
}

void main() {
  testWidgets('a tap settles the cartridge once, when the move ends', (
    tester,
  ) async {
    final h = await _pump(tester);
    await tester.tap(find.text('Film 4'));
    await tester.pump();
    // The list is moving: nothing yet.
    expect(h.settled, 0);
    await tester.pump(const Duration(milliseconds: 600));
    expect(h.settled, 1);
    // Nothing more once it is still.
    await tester.pump(const Duration(seconds: 1));
    expect(h.settled, 1);
  });

  testWidgets('a tap on the cartridge that is already selected settles '
      'nothing', (tester) async {
    final h = await _pump(tester);
    await tester.tap(find.text('Film 0'));
    await tester.pump(const Duration(seconds: 1));
    expect(h.settled, 0);
  });

  testWidgets('a film chosen by the camera, not by a tap, settles nothing', (
    tester,
  ) async {
    final h = await _pump(tester);
    h.select('film4');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(h.selected, 'film4');
    expect(h.settled, 0);
  });

  testWidgets('a swipe settles once when the list stops, not per pixel', (
    tester,
  ) async {
    final h = await _pump(tester);
    final gesture = await tester.startGesture(const Offset(300, 860));
    for (var i = 0; i < 12; i++) {
      await gesture.moveBy(const Offset(-30, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(h.settled, 0, reason: 'the finger is still on the list');
    await gesture.up();
    await tester.pumpAndSettle();
    expect(h.settled, 1);
    // A swipe does not choose a film.
    expect(h.selected, 'film0');
  });

  testWidgets('a nudge that hardly moves the list settles nothing', (
    tester,
  ) async {
    final h = await _pump(tester);
    final gesture = await tester.startGesture(const Offset(300, 860));
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(h.settled, 0);
  });

  testWidgets('with reduced motion a tap settles at once, once', (
    tester,
  ) async {
    final h = await _pump(tester, reducedMotion: true);
    await tester.tap(find.text('Film 4'));
    await tester.pump();
    expect(h.settled, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(h.settled, 1);
  });

  testWidgets(
    'a drag that interrupts a tap settles once, after the drag ends',
    (tester) async {
      final h = await _pump(tester);
      await tester.tap(find.text('Film 4'));
      await tester.pump(Duration.zero);

      final gesture = await tester.startGesture(const Offset(300, 860));
      await gesture.moveBy(const Offset(-80, 0));
      await tester.pump();

      await gesture.up();
      await tester.pumpAndSettle();
      expect(h.settled, 1);
    },
  );
}
