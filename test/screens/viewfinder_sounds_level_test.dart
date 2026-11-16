import 'dart:async';

import 'package:carrete/camera/camera_providers.dart';
import 'package:carrete/camera/level_tilt.dart';
import 'package:carrete/capture/capture_providers.dart';
import 'package:carrete/core/settings/settings_provider.dart';
import 'package:carrete/l10n/app_localizations.dart';
import 'package:carrete/platform/camera_sounds.dart';
import 'package:carrete/platform/system_settings.dart';
import 'package:carrete/render/film_resources.dart';
import 'package:carrete/screens/viewfinder/level_overlay.dart';
import 'package:carrete/screens/viewfinder/viewfinder_screen.dart';
import 'package:carrete/ui/theme/carrete_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import '../support/roll_harness.dart';

class _Harness {
  _Harness(this.sounds, this.level, this.camera, this.queue);

  final FakeCameraSounds sounds;
  final FakeLevelSource level;
  final FakeCameraService camera;
  final FakeCaptureQueue queue;
}

/// The normal camera with no roll loaded, with the settings in [prefs].
Future<_Harness> _pump(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  bool reduced = false,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final preferences = await SharedPreferences.getInstance();
  final sounds = FakeCameraSounds();
  final level = FakeLevelSource();
  addTearDown(level.controller.close);
  final camera = FakeCameraService();
  final queue = FakeCaptureQueue();
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(412, 915);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...rollOverrides(framesLeft: 0),
        systemSettingsProvider.overrideWithValue(FakeSystemSettings()),
        sharedPreferencesProvider.overrideWithValue(preferences),
        cameraServiceProvider.overrideWithValue(camera),
        captureQueueProvider.overrideWithValue(queue),
        cameraSoundsProvider.overrideWithValue(sounds),
        levelSourceProvider.overrideWithValue(level),
        filmResourcesProvider.overrideWith((ref) async => null),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: child!,
        ),
        home: const ViewfinderScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return _Harness(sounds, level, camera, queue);
}

Future<void> _shoot(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Take photo'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

LevelPainter? _painter(WidgetTester tester) {
  final paints = find.descendant(
    of: find.byType(LevelOverlay),
    matching: find.byType(CustomPaint),
  );
  if (paints.evaluate().isEmpty) return null;
  return tester.widget<CustomPaint>(paints.first).painter as LevelPainter;
}

void main() {
  group('the shutter sounds', () {
    testWidgets('are on by default and play once per shot', (tester) async {
      final h = await _pump(tester);
      expect(h.sounds.preloads, 1);

      await _shoot(tester);
      expect(h.camera.pictures, 1);
      expect(h.sounds.shots, 1);

      await _shoot(tester);
      expect(h.sounds.shots, 2);
    });

    testWidgets('are not played, nor loaded, when the setting is off', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        prefs: {'carrete.settings.cameraSounds': false},
      );
      await _shoot(tester);
      expect(h.camera.pictures, 1);
      expect(h.queue.jobs, hasLength(1));
      expect(h.sounds.shots, 0);
      expect(h.sounds.preloads, 0);
    });
  });

  group('the sound loading', () {
    testWidgets('starts when the setting is turned on with the camera open', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        prefs: {'carrete.settings.cameraSounds': false},
      );
      expect(h.sounds.preloads, 0);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ViewfinderScreen)),
      );
      container.read(settingsProvider.notifier).setCameraSounds(true);
      await tester.pump();

      expect(h.sounds.preloads, 1);
    });
  });

  group('the level', () {
    testWidgets('does not listen behind a pushed route, and comes back', (
      tester,
    ) async {
      final h = await _pump(tester, prefs: {'carrete.settings.level': true});
      expect(h.level.listening, isTrue);

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('settings')),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('settings'), findsOneWidget);
      expect(h.level.listening, isFalse);

      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('settings'), findsNothing);
      expect(h.level.listening, isTrue);
    });

    testWidgets('is off by default and does not listen to the sensor', (
      tester,
    ) async {
      final h = await _pump(tester);
      expect(find.byType(LevelOverlay), findsNothing);
      expect(h.level.listening, isFalse);
    });

    testWidgets('is shown when the setting is on, once there is a reading', (
      tester,
    ) async {
      final h = await _pump(tester, prefs: {'carrete.settings.level': true});
      expect(find.byType(LevelOverlay), findsOneWidget);
      expect(h.level.listening, isTrue);
      // Nothing to draw before the first reading.
      expect(_painter(tester), isNull);

      h.level.controller.add(const LevelTilt(6));
      await tester.pump();
      expect(_painter(tester), isNotNull);
    });

    testWidgets('reads level on its side, with the ticks turned', (
      tester,
    ) async {
      final h = await _pump(tester, prefs: {'carrete.settings.level': true});

      h.level.controller.add(const LevelTilt(89.5));
      await tester.pump();
      expect(_painter(tester)!.landscape, isTrue);
      expect(_painter(tester)!.level, isTrue);
      expect(_painter(tester)!.color, CarreteColors.levelAligned);

      h.level.controller.add(const LevelTilt(6));
      await tester.pump();
      expect(_painter(tester)!.landscape, isFalse);
      expect(_painter(tester)!.level, isFalse);
      expect(_painter(tester)!.color, CarreteColors.frameMark);
    });

    testWidgets('is white when tilted and the accent when level', (
      tester,
    ) async {
      final h = await _pump(tester, prefs: {'carrete.settings.level': true});

      h.level.controller.add(const LevelTilt(6.2));
      await tester.pump();
      expect(_painter(tester)!.degrees, 6.2);
      expect(_painter(tester)!.level, isFalse);
      expect(_painter(tester)!.color, CarreteColors.frameMark);

      h.level.controller.add(const LevelTilt(0.8));
      await tester.pump();
      expect(_painter(tester)!.level, isTrue);
      expect(_painter(tester)!.color, CarreteColors.levelAligned);

      // 1.3 degrees is outside 1, but the colour holds once it is level.
      h.level.controller.add(const LevelTilt(1.3));
      await tester.pump();
      expect(_painter(tester)!.level, isTrue);

      h.level.controller.add(const LevelTilt(1.7));
      await tester.pump();
      expect(_painter(tester)!.level, isFalse);
    });

    testWidgets('hides when the phone lies flat', (tester) async {
      final h = await _pump(tester, prefs: {'carrete.settings.level': true});
      h.level.controller.add(const LevelTilt(2));
      await tester.pump();
      expect(_painter(tester), isNotNull);

      h.level.controller.add(null);
      await tester.pump();
      expect(_painter(tester), isNull);
    });

    testWidgets('moves without any animation under reduced motion', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        prefs: {'carrete.settings.level': true},
        reduced: true,
      );
      h.level.controller.add(const LevelTilt(10));
      await tester.pump();
      expect(_painter(tester)!.degrees, 10);
      h.level.controller.add(const LevelTilt(-4));
      await tester.pump();
      // The very next frame already shows the new value: no easing.
      expect(_painter(tester)!.degrees, -4);
    });

    testWidgets('stops listening when it is turned off', (tester) async {
      final h = await _pump(tester, prefs: {'carrete.settings.level': true});
      expect(h.level.listening, isTrue);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ViewfinderScreen)),
      );
      container.read(settingsProvider.notifier).setLevel(false);
      await tester.pump();

      expect(find.byType(LevelOverlay), findsNothing);
      expect(h.level.listening, isFalse);
    });

    testWidgets('pauses with the app in the background', (tester) async {
      final h = await _pump(tester, prefs: {'carrete.settings.level': true});
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(h.level.listening, isFalse);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(h.level.listening, isTrue);
    });
  });

  group('the painter', () {
    test('repaints only when the tilt or the colour changes', () {
      const base = LevelPainter(degrees: 3, level: false);
      expect(
        base.shouldRepaint(const LevelPainter(degrees: 3, level: false)),
        isFalse,
      );
      expect(
        base.shouldRepaint(const LevelPainter(degrees: 4, level: false)),
        isTrue,
      );
      expect(
        base.shouldRepaint(const LevelPainter(degrees: 3, level: true)),
        isTrue,
      );
      expect(
        base.shouldRepaint(
          const LevelPainter(degrees: 3, level: false, landscape: true),
        ),
        isTrue,
      );
    });
  });
}
