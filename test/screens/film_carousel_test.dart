import 'package:diapo/l10n/app_localizations.dart';
import 'package:diapo/screens/viewfinder/film_carousel.dart';
import 'package:film_recipes/film_recipes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Recipe _film(int i) => Recipe(
  id: 'film$i',
  name: LocalizedText(es: 'Film $i', ca: 'Film $i', en: 'Film $i'),
  description: LocalizedText(es: 'd', ca: 'd', en: 'd'),
);

List<Recipe> _films(int count) => [for (var i = 0; i < count; i++) _film(i)];

Future<void> _pump(
  WidgetTester tester,
  List<Recipe> recipes, {
  String? selectedId,
  double width = 412,
  double textScale = 1,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = Size(width, 915);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: FilmCarousel(
            recipes: recipes,
            selectedId: selectedId ?? recipes.first.id,
            onSelected: (_) {},
            onTune: (_) {},
            thumbnailBuilder: (context, recipe) =>
                SizedBox(key: ValueKey('live-${recipe.id}')),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

/// The cartridges in the cache of the list are built but not on screen, so
/// the finders look at the off-stage ones too.
Finder _live(int i) => find.byKey(ValueKey('live-film$i'), skipOffstage: false);

Finder _built(int i) => find.text('Film $i', skipOffstage: false);

/// A cartridge that exists but whose window is dark.
void _expectDark(int i) {
  expect(_built(i), findsOneWidget, reason: 'film$i is not built');
  expect(_live(i), findsNothing, reason: 'film$i should be dark');
}

void _expectLive(int i) {
  expect(_built(i), findsOneWidget, reason: 'film$i is not built');
  expect(_live(i), findsOneWidget, reason: 'film$i should be live');
}

void _scrollTo(WidgetTester tester, double offset) {
  tester
      .state<ScrollableState>(find.byType(Scrollable))
      .position
      .jumpTo(offset);
}

void main() {
  testWidgets(
    'ten films: the cartridges beyond the margin are built but dark',
    (tester) async {
      await _pump(tester, _films(10));

      // 412 px hold the cartridges 0..5 (a step is 76 px, the margin 16); one
      // more on the right is live, and the cache builds two more that are dark.
      for (var i = 0; i <= 6; i++) {
        _expectLive(i);
      }
      _expectDark(7);
      _expectDark(8);
      expect(_built(9), findsNothing);
    },
  );

  testWidgets('a cartridge goes live and dark as it crosses the boundary', (
    tester,
  ) async {
    await _pump(tester, _films(10));
    _expectDark(7);

    // One step on: the 8th is now the margin of the screen.
    _scrollTo(tester, 76);
    await tester.pump();
    await tester.pump();
    _expectLive(7);
    _expectDark(8);

    // Three steps on: the first cartridge is beyond the margin on the left but
    // still inside the cache, so it is built and dark.
    _scrollTo(tester, 228);
    await tester.pump();
    await tester.pump();
    _expectDark(0);
    _expectLive(1);

    // And back.
    _scrollTo(tester, 0);
    await tester.pump();
    await tester.pump();
    _expectLive(0);
    _expectDark(7);
  });

  testWidgets('the end of the list is live and the start is gone', (
    tester,
  ) async {
    await _pump(tester, _films(10));

    await tester.drag(find.byType(FilmCarousel), const Offset(-2000, 0));
    await tester.pumpAndSettle();

    expect(_live(9), findsOneWidget);
    expect(_live(0), findsNothing);
  });

  testWidgets('a bigger screen without scrolling lights the new cartridges', (
    tester,
  ) async {
    await _pump(tester, _films(10));
    _expectDark(7);

    tester.view.physicalSize = const Size(700, 915);
    await tester.pump();
    await tester.pump();

    for (var i = 0; i < 10; i++) {
      expect(_live(i), findsOneWidget, reason: 'film$i');
    }

    tester.view.physicalSize = const Size(412, 915);
    await tester.pump();
    await tester.pump();

    _expectLive(6);
    _expectDark(7);
  });

  testWidgets('a selection that starts off screen is centred and live', (
    tester,
  ) async {
    await _pump(tester, _films(10), selectedId: 'film9');

    _expectLive(9);
    _expectLive(8);
    // The list ends at the offset 374: the cartridges 3..9 are live, the 2nd
    // is built in the cache but dark, and the first ones are gone.
    _expectLive(3);
    _expectDark(2);
    expect(_live(0), findsNothing);
  });

  testWidgets('large text does not change which cartridges are live', (
    tester,
  ) async {
    await _pump(tester, _films(10), textScale: 2);

    expect(tester.takeException(), isNull);
    _expectLive(6);
    _expectDark(7);
  });

  testWidgets('lists of one and two films are live', (tester) async {
    await _pump(tester, _films(1));
    _expectLive(0);

    await _pump(tester, _films(2), width: 360);
    _expectLive(0);
    _expectLive(1);
    expect(tester.takeException(), isNull);
  });
}
