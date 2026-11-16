import 'package:diapo/core/settings/film_tuning.dart';
import 'package:diapo/l10n/app_localizations.dart';
import 'package:diapo/screens/viewfinder/tuning_panel.dart';
import 'package:film_recipes/film_recipes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _film = Recipe(
  id: 'film',
  name: LocalizedText(es: 'Peli', ca: 'Peli', en: 'Film'),
  description: LocalizedText(es: 'Peli', ca: 'Peli', en: 'Film'),
  defaults: RecipeDefaults(format: FrameFormat.r3x2),
);

/// Pumps the panel. [camera] builds it the way the camera does, with no
/// argument for the format row; otherwise the way the import screen does.
Future<List<FilmTuning>> _pump(
  WidgetTester tester, {
  required bool camera,
}) async {
  final changes = <FilmTuning>[];
  void onChanged(FilmTuning Function(FilmTuning) change) =>
      changes.add(change(FilmTuning.defaults));
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(412, 915);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: camera
            ? FilmTuningPanel(
                recipe: _film,
                tuning: FilmTuning.defaults,
                effectiveFormat: FrameFormat.r3x2,
                effectiveDateStamp: true,
                effectiveCinemaBands: false,
                sampleStamp: '26 11 15',
                onChanged: onChanged,
                onClose: () {},
              )
            : FilmTuningPanel(
                recipe: _film,
                tuning: FilmTuning.defaults,
                effectiveFormat: FrameFormat.r3x2,
                showFormat: true,
                effectiveDateStamp: true,
                effectiveCinemaBands: false,
                sampleStamp: '26 11 15',
                onChanged: onChanged,
                onClose: () {},
              ),
      ),
    ),
  );
  await tester.pump();
  return changes;
}

void main() {
  testWidgets('the camera panel has no format row: the key beside the shutter '
      'is the only one', (tester) async {
    await _pump(tester, camera: true);
    expect(find.text('Format'), findsNothing);
    expect(find.text('16:9'), findsNothing);
    expect(find.text('1:1'), findsNothing);
    // The rest of the panel is still there.
    expect(find.text('Date imprint'), findsOneWidget);
    expect(find.text('Grain'), findsOneWidget);
  });

  testWidgets('the import panel keeps the format row and it works', (
    tester,
  ) async {
    final changes = await _pump(tester, camera: false);
    expect(find.text('Format'), findsOneWidget);
    expect(find.text('3:2'), findsOneWidget);
    await tester.tap(find.text('16:9'));
    await tester.pump();
    expect(changes.single.format, FrameFormat.r16x9);
  });
}
