import 'dart:async';

import 'package:diapo/camera/camera_providers.dart';
import 'package:diapo/capture/capture_providers.dart';
import 'package:diapo/core/database/app_database.dart';
import 'package:diapo/core/database/tables.dart';
import 'package:diapo/core/settings/settings_provider.dart';
import 'package:diapo/l10n/app_localizations.dart';
import 'package:diapo/platform/system_settings.dart';
import 'package:diapo/render/film_resources.dart';
import 'package:diapo/screens/roll/roll_sheet.dart';
import 'package:diapo/screens/viewfinder/top_bar.dart';
import 'package:diapo/screens/viewfinder/viewfinder_screen.dart';
import 'package:diapo/ui/widgets/plastic_controls.dart';
import 'package:diapo/ui/widgets/seven_segment.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import '../support/roll_fakes.dart';
import '../support/roll_harness.dart';

class _Harness {
  _Harness(this.rolls, this.service, this.opened, this.prefs);

  /// Feeds the roll in the camera: a roll, or null when it ends.
  final StreamController<RollRow?> rolls;
  final FakeRollService service;

  /// The rolls the camera asked to show.
  final List<int> opened;
  final SharedPreferences prefs;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  RollRow? roll,
  int? framesLeft,
  List<RollRow> history = const [],
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final preferences = await SharedPreferences.getInstance();
  final controller = StreamController<RollRow?>();
  addTearDown(controller.close);
  final service = FakeRollService();
  final opened = <int>[];
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(412, 915);
  addTearDown(tester.view.reset);

  controller.add(roll);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...rollOverrides(
          activeStream: controller.stream,
          framesLeft: framesLeft ?? roll?.length,
          rolls: history,
          service: service,
        ),
        systemSettingsProvider.overrideWithValue(FakeSystemSettings()),
        sharedPreferencesProvider.overrideWithValue(preferences),
        cameraServiceProvider.overrideWithValue(FakeCameraService()),
        captureQueueProvider.overrideWithValue(FakeCaptureQueue()),
        filmResourcesProvider.overrideWith((ref) async => null),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ViewfinderScreen(onOpenRoll: opened.add),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return _Harness(controller, service, opened, preferences);
}

/// The semantics label of the LCD counter.
String? _counterLabel(WidgetTester tester) {
  final semantics = find.descendant(
    of: find.byType(LcdCounter),
    matching: find.byType(Semantics),
  );
  for (final e in semantics.evaluate()) {
    final label = (e.widget as Semantics).properties.label;
    if (label != null) return label;
  }
  return null;
}

/// The key of the sheet that loads the roll (the control of the top bar has
/// the same words).
final _sheetLoadKey = find.descendant(
  of: find.byType(RollSheet),
  matching: find.text('Load roll'),
);

void main() {
  final roll = rollRow(id: 7, length: 24, filmId: 'beta');

  group('without a roll', () {
    testWidgets('the LCD counts the photos taken and the key loads a roll', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text('LOOSE PHOTOS'), findsOneWidget);
      expect(find.text('LEFT'), findsNothing);
      // The LCD names the film, with no count of photos.
      expect(find.byKey(const ValueKey('lcd-film-name')), findsOneWidget);
      expect(find.byType(SevenSegmentText), findsNothing);
      expect(_counterLabel(tester), 'Alpha, loose photos');
      expect(find.bySemanticsLabel('Load roll'), findsOneWidget);
    });

    testWidgets('the roll control says "Load roll" in words', (tester) async {
      await _pump(tester);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('roll-key')),
          matching: find.text('Load roll'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the roll key opens the sheet with the film of the camera', (
      tester,
    ) async {
      await _pump(tester);
      await tester.tap(find.byKey(const ValueKey('roll-key')));
      await tester.pumpAndSettle();
      expect(_sheetLoadKey, findsOneWidget);
      // The first film of the book is the one the camera has selected.
      expect(find.text('Alpha'), findsWidgets);
    });

    testWidgets('loading a roll hands it the length, delay and film', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        prefs: {'carrete.settings.defaultFilmId': 'gamma'},
      );
      await tester.tap(find.byKey(const ValueKey('roll-key')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('12'));
      await tester.pump();
      await tester.tap(find.text('3 days'));
      await tester.pump();
      await tester.tap(_sheetLoadKey);
      await tester.pumpAndSettle();
      expect(h.service.calls, ['open 12 threeDays gamma']);
    });

    testWidgets('a failure to load says so', (tester) async {
      final h = await _pump(tester);
      h.service.failWith = StateError('no');
      await tester.tap(find.byKey(const ValueKey('roll-key')));
      await tester.pumpAndSettle();
      await tester.tap(_sheetLoadKey);
      await tester.pumpAndSettle();
      expect(find.text('That did not work. Try again.'), findsOneWidget);
    });

    testWidgets('the film can be changed freely', (tester) async {
      await _pump(tester);
      await tester.tap(find.text('Beta'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('4:3'), findsOneWidget);
    });
  });

  group('with a roll loaded', () {
    testWidgets('the LCD counts the frames left, down', (tester) async {
      await _pump(tester, roll: roll, framesLeft: 17);
      expect(find.text('LEFT'), findsOneWidget);
      expect(find.text('LOOSE PHOTOS'), findsNothing);
      expect(_counterLabel(tester), '17 frames left');
      expect(
        tester.widget<SevenSegmentText>(find.byType(SevenSegmentText)).text,
        '17',
      );
    });

    testWidgets('the roll control shows the film and the frames left', (
      tester,
    ) async {
      await _pump(tester, roll: roll, framesLeft: 8);
      final key = find.byKey(const ValueKey('roll-key'));
      expect(
        find.descendant(of: key, matching: find.text('Beta')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: key, matching: find.text('Left 08')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: key, matching: find.text('Load roll')),
        findsNothing,
      );
    });

    testWidgets('a paused disposable shows on the roll control while the '
        'camera shoots loose photos', (tester) async {
      await _pump(
        tester,
        roll: rollRow(
          id: 9,
          length: 27,
          filmId: 'beta',
          mode: RollMode.disposable,
        ),
        framesLeft: 12,
      );
      final key = find.byKey(const ValueKey('roll-key'));
      expect(
        find.descendant(of: key, matching: find.text('Disposable paused')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: key, matching: find.text('Left 12')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Disposable camera paused, 12 frames left'),
        findsOneWidget,
      );
      // The LCD counts loose photos.
      expect(find.text('LOOSE PHOTOS'), findsOneWidget);
    });

    testWidgets('the roll key shows the mode is on', (tester) async {
      await _pump(tester, roll: roll, framesLeft: 17);
      expect(
        find.bySemanticsLabel('Roll loaded, 17 frames left'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Load roll'), findsNothing);
    });

    testWidgets('the counter follows the frames as they are shot', (
      tester,
    ) async {
      // A fresh harness cannot change the count; shooting is covered by the
      // viewfinder tests. Here the key of one frame left reads in singular.
      await _pump(tester, roll: roll, framesLeft: 1);
      expect(_counterLabel(tester), 'One frame left');
    });

    testWidgets('the camera shoots with the film of the roll', (tester) async {
      await _pump(tester, roll: roll);
      // Beta is 4:3 and the camera would otherwise be on Alpha (3:2).
      expect(find.text('4:3'), findsOneWidget);
      expect(find.text('3:2'), findsNothing);
    });

    testWidgets('the other films cannot be chosen', (tester) async {
      final h = await _pump(tester, roll: roll);
      await tester.tap(find.text('Gamma'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('4:3'), findsOneWidget);
      expect(find.text('1:1'), findsNothing);
      expect(h.prefs.getString('carrete.settings.defaultFilmId'), isNull);
    });

    testWidgets('a roll photo is not counted as a photo of the session', (
      tester,
    ) async {
      final h = await _pump(tester, roll: roll, framesLeft: 17);
      await tester.tap(find.byType(ShutterButton));
      await tester.pump(const Duration(milliseconds: 400));
      // The roll ends: the LCD rewinds, still on the roll...
      h.rolls.add(null);
      await tester.pump();
      await tester.pump();
      expect(_counterLabel(tester), 'No frames left');
      // ...and then goes back to the loose photos.
      await tester.pump(const Duration(milliseconds: 1300));
      expect(_counterLabel(tester), 'Alpha, loose photos');
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('no photo is shown anywhere', (tester) async {
      await _pump(tester, roll: roll);
      expect(find.byType(Image), findsNothing);
      expect(find.byType(RawImage), findsNothing);
      expect(find.byTooltip('Gallery'), findsNothing);
    });

    testWidgets('the key opens the roll sheet instead of the form', (
      tester,
    ) async {
      await _pump(tester, roll: roll, framesLeft: 5);
      await tester.tap(find.byKey(const ValueKey('roll-key')));
      await tester.pumpAndSettle();
      expect(find.text('5 frames left'), findsWidgets);
      expect(find.text('Close roll'), findsOneWidget);
      expect(find.text('Load roll'), findsNothing);
    });

    testWidgets('closing the roll shows its screen once it has closed', (
      tester,
    ) async {
      final h = await _pump(tester, roll: roll);
      await tester.tap(find.byKey(const ValueKey('roll-key')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close roll'));
      await tester.pumpAndSettle();
      expect(h.service.calls, ['close 7']);
      expect(h.opened, isEmpty);

      h.rolls.add(null);
      await tester.pump();
      await tester.pump();
      expect(h.opened, [7]);
      // The user closed it: no notice about it.
      expect(find.text('Roll finished'), findsNothing);
    });

    testWidgets('developing now needs the warning and opens the roll', (
      tester,
    ) async {
      final h = await _pump(tester, roll: roll);
      h.service.developing = Completer<void>();
      addTearDown(() {
        if (!h.service.developing!.isCompleted) {
          h.service.developing!.complete();
        }
      });
      await tester.tap(find.byKey(const ValueKey('roll-key')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Develop now'));
      await tester.pumpAndSettle();
      expect(h.service.calls, isEmpty);
      await tester.tap(find.text('Develop now').last);
      await tester.pumpAndSettle();
      expect(h.service.calls, ['developNow 7']);

      h.rolls.add(null);
      await tester.pump();
      await tester.pump();
      expect(h.opened, [7]);
    });

    testWidgets('throwing the roll away does not open it', (tester) async {
      final h = await _pump(tester, roll: roll);
      await tester.tap(find.byKey(const ValueKey('roll-key')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Throw away the roll'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Throw away'));
      await tester.pumpAndSettle();
      expect(h.service.calls, ['discard 7']);

      h.rolls.add(null);
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));
      expect(h.opened, isEmpty);
      expect(find.text('Roll finished'), findsNothing);
    });

    testWidgets('the last frame closes the roll: a notice, then its screen', (
      tester,
    ) async {
      final h = await _pump(tester, roll: roll, framesLeft: 1);
      // The roll closes by itself and leaves the camera.
      h.rolls.add(null);
      await tester.pump();
      await tester.pump();
      expect(find.text('Roll finished'), findsOneWidget);
      expect(h.opened, isEmpty);

      await tester.pump(const Duration(seconds: 2));
      expect(h.opened, [7]);
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('Roll finished'), findsNothing);
    });

    testWidgets('a failed close says so and does not open anything', (
      tester,
    ) async {
      final h = await _pump(tester, roll: roll);
      h.service.failWith = StateError('no');
      await tester.tap(find.byKey(const ValueKey('roll-key')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close roll'));
      await tester.pumpAndSettle();
      expect(find.text('That did not work. Try again.'), findsOneWidget);
      expect(h.opened, isEmpty);
    });
  });

  group('the recent rolls', () {
    testWidgets('a roll of the list opens its screen', (tester) async {
      final h = await _pump(
        tester,
        history: [
          rollRow(
            id: 4,
            state: RollState.developed,
            developedAt: DateTime(2026, 11, 1).millisecondsSinceEpoch,
          ),
        ],
      );
      await tester.tap(find.byKey(const ValueKey('roll-key')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Developed'));
      await tester.pumpAndSettle();
      expect(h.opened, [4]);
    });
  });
}
