import 'package:carrete/core/settings/film_tuning.dart';
import 'package:carrete/l10n/app_localizations.dart';
import 'package:carrete/screens/viewfinder/tuning_panel.dart';
import 'package:carrete/ui/widgets/plastic_controls.dart';
import 'package:film_recipes/film_recipes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Recipe _film({bool cinemaBands = false, FrameFormat? format}) => Recipe(
  id: 'film',
  name: const LocalizedText(es: 'Peli', ca: 'Peli', en: 'Film'),
  description: const LocalizedText(es: 'Peli', ca: 'Peli', en: 'Film'),
  defaults: RecipeDefaults(
    format: format ?? FrameFormat.r3x2,
    cinemaBands: cinemaBands,
  ),
);

/// Pumps the panel the way the screens do: the format and the bands in force
/// come from the recipe and the tuning, and a change is applied to the tuning.
Future<ValueNotifier<FilmTuning>> _pump(
  WidgetTester tester,
  Recipe recipe, {
  FilmTuning tuning = FilmTuning.defaults,
  Locale locale = const Locale('en'),
  bool showFormat = true,
}) async {
  final current = ValueNotifier(tuning);
  addTearDown(current.dispose);
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(412, 915);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ValueListenableBuilder<FilmTuning>(
          valueListenable: current,
          builder: (context, tuning, _) {
            final look = resolve(recipe, overrides: tuning.overrides);
            return FilmTuningPanel(
              recipe: recipe,
              tuning: tuning,
              effectiveFormat: look.format,
              effectiveDateStamp: look.dateStamp,
              effectiveCinemaBands: cinemaBandsFor(recipe, tuning),
              sampleStamp: '26 11 15',
              showFormat: showFormat,
              onChanged: (change) => current.value = change(current.value),
              onClose: () {},
            );
          },
        ),
      ),
    ),
  );
  await tester.pump();
  return current;
}

void main() {
  testWidgets('the switch is shown at 16:9 only', (tester) async {
    await _pump(tester, _film(format: FrameFormat.r3x2));
    expect(find.text('Cinema bands'), findsNothing);
    expect(find.byType(PlasticSwitch), findsOneWidget);

    await _pump(tester, _film(format: FrameFormat.r16x9));
    expect(find.text('Cinema bands'), findsOneWidget);
    expect(find.byType(PlasticSwitch), findsNWidgets(2));
  });

  testWidgets('it follows the format chosen in the panel', (tester) async {
    final tuning = await _pump(
      tester,
      _film(),
      tuning: const FilmTuning(cinemaBands: true),
    );
    expect(find.text('Cinema bands'), findsNothing);

    await tester.tap(find.text('16:9'));
    await tester.pump();
    expect(find.text('Cinema bands'), findsOneWidget);

    await tester.tap(find.text('3:2'));
    await tester.pump();
    expect(find.text('Cinema bands'), findsNothing);
    // The stored choice stays for when the format comes back.
    expect(tuning.value.cinemaBands, isTrue);
  });

  testWidgets('toggling the switch changes the tuning', (tester) async {
    final tuning = await _pump(tester, _film(format: FrameFormat.r16x9));
    expect(tuning.value.cinemaBands, isNull);
    final bands = find.byWidgetPredicate(
      (w) => w is PlasticSwitch && w.label == 'Cinema bands',
    );
    expect(tester.widget<PlasticSwitch>(bands).value, isFalse);

    await tester.tap(bands);
    await tester.pump();
    expect(tuning.value.cinemaBands, isTrue);
    expect(tester.widget<PlasticSwitch>(bands).value, isTrue);

    await tester.tap(bands);
    await tester.pump();
    expect(tuning.value.cinemaBands, isFalse);
    expect(tester.widget<PlasticSwitch>(bands).value, isFalse);
  });

  testWidgets('a film with bands in its recipe starts with the switch on', (
    tester,
  ) async {
    final tuning = await _pump(
      tester,
      _film(cinemaBands: true, format: FrameFormat.r16x9),
    );
    final bands = find.byWidgetPredicate(
      (w) => w is PlasticSwitch && w.label == 'Cinema bands',
    );
    expect(tester.widget<PlasticSwitch>(bands).value, isTrue);
    expect(tuning.value.cinemaBands, isNull);

    await tester.tap(bands);
    await tester.pump();
    expect(tuning.value.cinemaBands, isFalse);
    expect(tester.widget<PlasticSwitch>(bands).value, isFalse);
  });

  testWidgets('the label is translated', (tester) async {
    await _pump(
      tester,
      _film(format: FrameFormat.r16x9),
      locale: const Locale('es'),
    );
    expect(find.text('Bandas de cine'), findsOneWidget);
    await _pump(
      tester,
      _film(format: FrameFormat.r16x9),
      locale: const Locale('ca'),
    );
    expect(find.text('Bandes de cinema'), findsOneWidget);
  });
}
