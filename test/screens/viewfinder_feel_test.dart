import 'dart:async';

import 'package:diapo/camera/camera_providers.dart';
import 'package:diapo/capture/capture_providers.dart';
import 'package:diapo/core/database/app_database.dart';
import 'package:diapo/core/settings/settings_provider.dart';
import 'package:diapo/l10n/app_localizations.dart';
import 'package:diapo/platform/camera_sounds.dart';
import 'package:diapo/platform/haptics.dart';
import 'package:diapo/platform/system_settings.dart';
import 'package:diapo/render/film_resources.dart';
import 'package:diapo/screens/roll/roll_sheet.dart';
import 'package:diapo/screens/viewfinder/viewfinder_screen.dart';
import 'package:diapo/ui/widgets/plastic_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import '../support/roll_fakes.dart';
import '../support/roll_harness.dart';

class _Harness {
  _Harness(this.sounds, this.haptics, this.service, this.active, this.opened);

  final FakeCameraSounds sounds;
  final FakeHaptics haptics;
  final FakeRollService service;

  /// Feeds the roll in the camera: a roll, or null when it ends.
  final StreamController<RollRow?> active;

  /// The rolls the camera asked to show.
  final List<int> opened;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  RollRow? roll,
  int? framesLeft,
  bool reducedMotion = false,
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues({
    // The tutorial was seen: no hint over the carousel.
    'carrete.settings.onboardingSeen': true,
    ...prefs,
  });
  final preferences = await SharedPreferences.getInstance();
  final sounds = FakeCameraSounds();
  final haptics = FakeHaptics();
  final service = FakeRollService();
  final active = StreamController<RollRow?>();
  addTearDown(() => unawaited(active.close()));
  active.add(roll);
  final opened = <int>[];
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
    ProviderScope(
      overrides: [
        ...rollOverrides(
          activeStream: active.stream,
          framesLeft: framesLeft ?? roll?.length,
          service: service,
        ),
        cameraSoundsProvider.overrideWithValue(sounds),
        hapticsProvider.overrideWithValue(haptics),
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
  return _Harness(sounds, haptics, service, active, opened);
}

final _sheetLoadKey = find.descendant(
  of: find.byType(RollSheet),
  matching: find.text('Load roll'),
);

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('roll-key')));
  await tester.pumpAndSettle();
}

void main() {
  group('a cartridge settling', () {
    testWidgets('clicks and ticks once when a tap changes the film', (
      tester,
    ) async {
      final h = await _pump(tester);
      await tester.tap(find.text('Beta'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(h.sounds.effects, ['cartridge']);
      expect(h.haptics.events, ['selection']);
      await tester.pump(const Duration(seconds: 1));
      expect(h.sounds.effects, ['cartridge']);
    });

    testWidgets('does nothing for the film that is already selected', (
      tester,
    ) async {
      final h = await _pump(tester);
      await tester.tap(find.text('Alpha'));
      await tester.pump(const Duration(seconds: 1));
      expect(h.sounds.effects, isEmpty);
      expect(h.haptics.events, isEmpty);
    });
  });

  group('a roll loaded', () {
    testWidgets('from the sheet thuds and gives a medium tap', (tester) async {
      final h = await _pump(tester);
      await _openSheet(tester);
      await tester.tap(_sheetLoadKey);
      await tester.pumpAndSettle();
      expect(h.service.calls, ['open 24 oneHour alpha']);
      expect(h.sounds.effects, ['load']);
      expect(h.haptics.events, ['medium']);
    });

    testWidgets('that failed to load makes no sound', (tester) async {
      final h = await _pump(tester);
      h.service.failWith = StateError('no');
      await _openSheet(tester);
      await tester.tap(_sheetLoadKey);
      await tester.pumpAndSettle();
      expect(h.sounds.effects, isEmpty);
      expect(h.haptics.events, isEmpty);
    });

    testWidgets('a sheet closed with nothing chosen makes no sound', (
      tester,
    ) async {
      final h = await _pump(tester);
      await _openSheet(tester);
      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pumpAndSettle();
      expect(h.sounds.effects, isEmpty);
      expect(h.haptics.events, isEmpty);
    });

    testWidgets('the disposable camera started from the sheet thuds too', (
      tester,
    ) async {
      final h = await _pump(tester);
      await _openSheet(tester);
      final key = find.byKey(const ValueKey('disposable-key'));
      await tester.ensureVisible(key);
      await tester.pumpAndSettle();
      await tester.tap(key);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      expect(h.service.calls.single, startsWith('openDisposable'));
      expect(h.sounds.effects, ['load']);
      expect(h.haptics.events, ['medium']);
    });

    testWidgets('closing the roll in the camera is not a load', (tester) async {
      final roll = rollRow(id: 7, length: 24, filmId: 'beta');
      final h = await _pump(tester, roll: roll, framesLeft: 5);
      await _openSheet(tester);
      await tester.tap(find.text('Close roll'));
      await tester.pumpAndSettle();
      expect(h.sounds.effects, isNot(contains('load')));
      expect(h.haptics.events, isNot(contains('medium')));
    });
  });

  group('the last frame of a roll', () {
    final roll = rollRow(id: 7, length: 24, filmId: 'beta');

    testWidgets('rewinds: a sound, a light tap and the LCD rewinds', (
      tester,
    ) async {
      final h = await _pump(tester, roll: roll, framesLeft: 1);
      expect(find.byKey(const ValueKey('lcd-rewind-strip')), findsNothing);

      // The last frame is secured and the roll closes by itself.
      h.active.add(null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(h.sounds.effects, ['rewind']);
      expect(h.haptics.events, ['light']);
      // The film runs backwards in the LCD, which still shows the roll.
      expect(find.byKey(const ValueKey('lcd-rewind-strip')), findsOneWidget);
      expect(find.text('LEFT'), findsOneWidget);
      // The message stays.
      expect(find.text('Roll finished'), findsOneWidget);

      // When the rewind ends the LCD is back to the film.
      await tester.pump(const Duration(milliseconds: 1300));
      expect(find.byKey(const ValueKey('lcd-rewind-strip')), findsNothing);
      expect(find.text('LEFT'), findsNothing);
      expect(find.text('LOOSE PHOTOS'), findsOneWidget);
      // Once, not once per pump.
      expect(h.sounds.effects, ['rewind']);
      await tester.pump(const Duration(seconds: 3));
      expect(h.opened, [7]);
    });

    testWidgets('with reduced motion: the sound and the tap, no animation', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        roll: roll,
        framesLeft: 1,
        reducedMotion: true,
      );
      h.active.add(null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(h.sounds.effects, ['rewind']);
      expect(h.haptics.events, ['light']);
      expect(find.byKey(const ValueKey('lcd-rewind-strip')), findsNothing);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('a roll the user closes does not rewind', (tester) async {
      final h = await _pump(tester, roll: roll, framesLeft: 5);
      await _openSheet(tester);
      await tester.tap(find.text('Close roll'));
      await tester.pumpAndSettle();
      h.active.add(null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(h.sounds.effects, isNot(contains('rewind')));
      expect(h.haptics.events, isNot(contains('light')));
    });
  });

  group('the shutter, with the real haptics', () {
    final vibrations = <Object?>[];

    setUp(() {
      vibrations.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'HapticFeedback.vibrate') {
              vibrations.add(call.arguments);
            }
            return null;
          });
    });
    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    Future<void> shoot(WidgetTester tester, Map<String, Object> prefs) async {
      SharedPreferences.setMockInitialValues({
        'carrete.settings.onboardingSeen': true,
        ...prefs,
      });
      final preferences = await SharedPreferences.getInstance();
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(412, 915);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...rollOverrides(),
            cameraSoundsProvider.overrideWithValue(FakeCameraSounds()),
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
            home: const ViewfinderScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byType(ShutterButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
    }

    testWidgets('vibrates with the setting on', (tester) async {
      await shoot(tester, const {});
      expect(vibrations, ['HapticFeedbackType.selectionClick']);
    });

    testWidgets('does not vibrate with the setting off', (tester) async {
      await shoot(tester, const {'carrete.settings.haptics': false});
      expect(vibrations, isEmpty);
    });

    testWidgets('the sounds off do not turn the vibration off', (tester) async {
      await shoot(tester, const {'carrete.settings.cameraSounds': false});
      expect(vibrations, ['HapticFeedbackType.selectionClick']);
    });
  });
}
