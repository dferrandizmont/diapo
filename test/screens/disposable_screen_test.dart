import 'dart:async';

import 'package:diapo/camera/camera_flash.dart';
import 'package:diapo/camera/camera_providers.dart';
import 'package:diapo/camera/camera_service.dart';
import 'package:diapo/core/database/app_database.dart';
import 'package:diapo/core/database/tables.dart';
import 'package:diapo/core/settings/settings_provider.dart';
import 'package:diapo/platform/camera_sounds.dart';
import 'package:diapo/platform/system_settings.dart';
import 'package:diapo/l10n/app_localizations.dart';
import 'package:diapo/render/film_resources.dart';
import 'package:diapo/roll/disposable.dart';
import 'package:diapo/roll/roll_providers.dart';
import 'package:film_recipes/film_recipes.dart';
import 'package:diapo/screens/disposable/disposable_parts.dart';
import 'package:diapo/screens/disposable/disposable_screen.dart';
import 'package:diapo/screens/viewfinder/film_carousel.dart';
import 'package:diapo/screens/viewfinder/level_overlay.dart';
import 'package:diapo/screens/viewfinder/top_bar.dart';
import 'package:diapo/ui/theme/disposable_tokens.dart';
import 'package:diapo/ui/widgets/plastic_key.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import '../support/roll_fakes.dart';
import '../support/roll_harness.dart';

class _Harness {
  _Harness({
    required this.rolls,
    required this.service,
    required this.camera,
    required this.prefs,
    required this.container,
    required this.events,
  });

  final StreamController<RollRow?> rolls;
  final FakeRollService service;
  final FakeCameraService camera;
  final SharedPreferences prefs;
  final ProviderContainer container;

  /// What the callbacks of the screen reported.
  final List<String> events;
}

RollRow _disposable({int length = 27, String filmId = 'beta'}) =>
    rollRow(length: length, filmId: filmId, mode: RollMode.disposable);

Future<_Harness> _pump(
  WidgetTester tester, {
  int framesLeft = 27,
  bool locked = true,
  bool reduced = false,
  double textScale = 1,
  Size size = const Size(412, 915),
  Stream<int>? framesStream,
  Future<RecipeBook> Function()? book,
  FakeCameraSounds? sounds,
  bool cameraSounds = true,
  CameraServiceState? cameraState,
  FakeSystemSettings? system,
}) async {
  SharedPreferences.setMockInitialValues({
    if (locked) 'carrete.disposable.rollId': 7,
    'carrete.settings.cameraSounds': cameraSounds,
    // The disposable never shows it, whatever the setting says.
    'carrete.settings.level': true,
  });
  final prefs = await SharedPreferences.getInstance();
  final controller = StreamController<RollRow?>();
  addTearDown(controller.close);
  final service = FakeRollService();
  final camera = cameraState == null
      ? FakeCameraService()
      : FakeCameraService(state: cameraState);
  final events = <String>[];
  controller.add(_disposable());
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size;
  addTearDown(tester.view.reset);

  final base = ProviderContainer(
    overrides: [
      ...rollOverrides(
        activeStream: controller.stream,
        framesLeft: framesLeft,
        service: service,
      ),
      sharedPreferencesProvider.overrideWithValue(prefs),
      cameraServiceProvider.overrideWithValue(camera),
      systemSettingsProvider.overrideWithValue(system ?? FakeSystemSettings()),
      if (sounds != null) cameraSoundsProvider.overrideWithValue(sounds),
      filmResourcesProvider.overrideWith((ref) async => null),
    ],
  );
  addTearDown(base.dispose);
  // A child container replaces what a test needs to control.
  final container = ProviderContainer(
    parent: base,
    overrides: [
      if (framesStream != null)
        remainingFramesProvider.overrideWith((ref) => framesStream),
      if (book != null) recipeBookProvider.overrideWith((ref) => book()),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reduced,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => unawaited(
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DisposableScreen(
                        onLeft: () => events.add('left'),
                        onFinished: (id) => events.add('finished $id'),
                      ),
                    ),
                  ),
                ),
                child: const Text('start'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('start'));
  await tester.pumpAndSettle();
  return _Harness(
    rolls: controller,
    service: service,
    camera: camera,
    prefs: prefs,
    container: container,
    events: events,
  );
}

/// Presses the exit stamp and holds it for [time]. The first frame starts the
/// clock of the animation, so it comes before the wait.
Future<TestGesture> _hold(WidgetTester tester, Duration time) async {
  final press = await tester.startGesture(
    tester.getCenter(find.byType(ExitStamp)),
  );
  await tester.pump();
  await tester.pump(time);
  return press;
}

void main() {
  Finder shutter() => find.byType(DisposableShutter);
  Finder stamp() => find.byType(ExitStamp);

  group('the screen of the mode', () {
    testWidgets('has the viewfinder, shutter, flash, counter and exit only', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester);
      expect(find.byKey(const ValueKey('disposable-frame')), findsOneWidget);
      expect(shutter(), findsOneWidget);
      expect(find.byType(FlashSwitch), findsOneWidget);
      expect(find.byType(StickerCounter), findsOneWidget);
      expect(stamp(), findsOneWidget);
      expect(find.byType(ThumbWheel), findsOneWidget);

      // What is on the camera of design A and must not be here.
      expect(find.byType(FilmCarousel), findsNothing);
      expect(find.byType(ViewfinderTopBar), findsNothing);
      expect(find.byType(PlasticKey), findsNothing);
      for (final key in ['gallery-key', 'format-key', 'roll-key']) {
        expect(find.byKey(ValueKey(key)), findsNothing);
      }
      for (final label in [
        'Gallery',
        'Settings',
        'Switch camera',
        'Load roll',
        'Films',
        'Close',
      ]) {
        expect(find.bySemanticsLabel(label), findsNothing, reason: label);
      }
      expect(find.bySemanticsLabel(RegExp('^Format ')), findsNothing);
      expect(find.byType(Image), findsNothing);
      semantics.dispose();
    });

    testWidgets('every control has a label for a screen reader', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, framesLeft: 12);
      expect(find.bySemanticsLabel('Take photo'), findsOneWidget);
      expect(find.bySemanticsLabel('Flash'), findsOneWidget);
      expect(find.bySemanticsLabel('12 frames left'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Leave the disposable camera. Hold down for two seconds.',
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Camera viewfinder'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('counts the photos left on a sticker', (tester) async {
      await _pump(tester, framesLeft: 27);
      expect(
        find.descendant(
          of: find.byType(StickerCounter),
          matching: find.text('27'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the camera is the back one, with the flash on automatic', (
      tester,
    ) async {
      final h = await _pump(tester);
      expect(h.camera.started, 1);
      expect(h.camera.flashes.last, CarreteFlash.auto);
      expect(h.camera.lensSwitches, 0);
    });
  });

  group('the camera permission', () {
    const settingsKey = ValueKey('disposable-open-settings');

    testWidgets('a denied permission offers to open the system settings', (
      tester,
    ) async {
      final system = FakeSystemSettings();
      await _pump(
        tester,
        system: system,
        cameraState: const CameraServiceState(
          failure: CameraFailure.permissionDenied,
        ),
      );
      expect(find.byKey(settingsKey), findsOneWidget);
      expect(find.text('OPEN SETTINGS'), findsOneWidget);
      expect(find.text('TRY AGAIN'), findsOneWidget);
      await tester.tap(find.byKey(settingsKey));
      await tester.pump();
      expect(system.opened, 1);
    });

    testWidgets('the key is not there where the settings cannot be opened', (
      tester,
    ) async {
      await _pump(
        tester,
        system: FakeSystemSettings(available: false),
        cameraState: const CameraServiceState(
          failure: CameraFailure.permissionDenied,
        ),
      );
      expect(find.byKey(settingsKey), findsNothing);
      expect(find.text('TRY AGAIN'), findsOneWidget);
    });

    testWidgets('both keys fit large text', (tester) async {
      await _pump(
        tester,
        textScale: 2,
        cameraState: const CameraServiceState(
          failure: CameraFailure.permissionDenied,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(settingsKey), findsOneWidget);
      final screen = tester.view.physicalSize;
      final rect = tester.getRect(find.byKey(settingsKey));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(screen.width));
      expect(rect.height, greaterThanOrEqualTo(44));
    });

    testWidgets('another failure has no settings key', (tester) async {
      await _pump(
        tester,
        cameraState: const CameraServiceState(
          failure: CameraFailure.unavailable,
        ),
      );
      expect(find.byKey(settingsKey), findsNothing);
    });
  });

  group('the camera sounds', () {
    testWidgets('the shutter plays them once per shot', (tester) async {
      final sounds = FakeCameraSounds();
      await _pump(tester, sounds: sounds);
      expect(sounds.preloads, 1);
      expect(sounds.shots, 0);

      await tester.tap(shutter());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(sounds.shots, 1);
    });

    testWidgets('are silent, and not even loaded, when the setting is off', (
      tester,
    ) async {
      final sounds = FakeCameraSounds();
      final h = await _pump(tester, sounds: sounds, cameraSounds: false);
      await tester.tap(shutter());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(h.camera.pictures, 1);
      expect(sounds.shots, 0);
      expect(sounds.preloads, 0);
    });

    testWidgets('the disposable has no level, even when it is turned on', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.byType(LevelOverlay), findsNothing);
    });
  });

  group('the shutter', () {
    testWidgets('takes a photo into the roll with the fixed 3:2 look', (
      tester,
    ) async {
      final h = await _pump(tester);
      await tester.tap(shutter());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(h.camera.pictures, 1);
      // The roll it belongs to, its film and the frame the film does not
      // choose: the book's film is square, the disposable is always 3:2.
      expect(h.service.calls, ['capture 7']);
      expect(h.service.jobs.single.filmId, 'beta');
      expect(h.service.jobs.single.format.wireName, '3:2');
    });

    testWidgets('the last photo is the last, however fast the taps come', (
      tester,
    ) async {
      final h = await _pump(tester, framesLeft: 1);
      h.service.capturing = Completer<void>();
      await tester.tap(shutter());
      await tester.pump();
      // The photo is on its way: the sticker already says none left.
      expect(
        find.descendant(
          of: find.byType(StickerCounter),
          matching: find.text('0'),
        ),
        findsOneWidget,
      );
      await tester.tap(shutter());
      await tester.pump();
      expect(h.camera.pictures, 1);
      expect(h.service.calls, hasLength(1));
      h.service.capturing!.complete();
      await tester.pump();
    });

    testWidgets('does nothing when there are no frames left', (tester) async {
      final h = await _pump(tester, framesLeft: 0);
      await tester.tap(shutter());
      await tester.pump();
      expect(h.camera.pictures, 0);
      expect(h.service.calls, isEmpty);
    });

    testWidgets('a failure to save says so and gives the frame back', (
      tester,
    ) async {
      final h = await _pump(tester, framesLeft: 5);
      h.service.failWith = StateError('disk full');
      await tester.tap(shutter());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('The photo could not be saved.'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(StickerCounter),
          matching: find.text('5'),
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('turns the thumb wheel in steps after each photo', (
      tester,
    ) async {
      await _pump(tester);
      ThumbWheel wheel() => tester.widget<ThumbWheel>(find.byType(ThumbWheel));
      expect(wheel().advances, 0);
      await tester.tap(shutter());
      await tester.pump();
      expect(wheel().advances, 1);
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('has no animation when the system asks for none', (
      tester,
    ) async {
      await _pump(tester, reduced: true);
      await tester.tap(shutter());
      await tester.pump();
      final wheel = tester.widget<ThumbWheel>(find.byType(ThumbWheel));
      expect(wheel.animation, isNull);
      expect(wheel.advances, 1);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('the flash', () {
    testWidgets('switches between automatic and off', (tester) async {
      final h = await _pump(tester);
      await tester.tap(find.byType(FlashSwitch));
      await tester.pump();
      expect(h.camera.flashes.last, CarreteFlash.off);
      await tester.tap(find.byType(FlashSwitch));
      await tester.pump();
      expect(h.camera.flashes.last, CarreteFlash.auto);
    });
  });

  group('leaving', () {
    testWidgets('a tap on the stamp does nothing', (tester) async {
      final h = await _pump(tester);
      await tester.tap(stamp());
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Leave the disposable camera?'), findsNothing);
      expect(h.container.read(disposableLockProvider), 7);
    });

    testWidgets('holding for less than two seconds does nothing', (
      tester,
    ) async {
      final h = await _pump(tester);
      final press = await _hold(tester, const Duration(milliseconds: 1500));
      await press.up();
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Leave the disposable camera?'), findsNothing);
      expect(h.container.read(disposableLockProvider), 7);
    });

    testWidgets('letting go starts the hold again from nothing', (
      tester,
    ) async {
      await _pump(tester);
      var press = await _hold(tester, const Duration(milliseconds: 1500));
      await press.up();
      press = await _hold(tester, const Duration(milliseconds: 1500));
      expect(find.text('Leave the disposable camera?'), findsNothing);
      await press.up();
      await tester.pump();
    });

    testWidgets('holding for two seconds asks, and the photos stay', (
      tester,
    ) async {
      await _pump(tester, framesLeft: 20);
      final press = await _hold(
        tester,
        DisposableDurations.exitHold + const Duration(milliseconds: 50),
      );
      await tester.pump();
      await press.up();
      await tester.pumpAndSettle();
      expect(find.text('Leave the disposable camera?'), findsOneWidget);
      expect(
        find.text(
          '20 photos are left and are kept for later. '
          'You can carry on from the roll key.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('staying keeps the mode', (tester) async {
      final h = await _pump(tester);
      final press = await _hold(tester, const Duration(milliseconds: 2100));
      await press.up();
      await tester.pumpAndSettle();
      await tester.tap(find.text('STAY'));
      await tester.pumpAndSettle();
      expect(find.text('Leave the disposable camera?'), findsNothing);
      expect(find.byType(DisposableScreen), findsOneWidget);
      expect(h.container.read(disposableLockProvider), 7);
      expect(h.prefs.getInt('carrete.disposable.rollId'), 7);
    });

    testWidgets('confirming releases the lock and leaves the roll open', (
      tester,
    ) async {
      final h = await _pump(tester);
      final press = await _hold(tester, const Duration(milliseconds: 2100));
      await press.up();
      await tester.pumpAndSettle();
      await tester.tap(find.text('LEAVE'));
      await tester.pumpAndSettle();
      expect(h.container.read(disposableLockProvider), isNull);
      expect(h.prefs.getInt('carrete.disposable.rollId'), isNull);
      // The roll is not closed, thrown away or developed.
      expect(h.service.calls, isEmpty);
      expect(h.events, ['left']);
    });

    testWidgets('system back does not leave the mode', (tester) async {
      final h = await _pump(tester);
      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(handled, isTrue);
      expect(find.byType(DisposableScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('disposable-frame')), findsOneWidget);
      expect(h.container.read(disposableLockProvider), 7);
    });
  });

  group('the end of the roll', () {
    testWidgets('says so, releases the lock and hands the roll over', (
      tester,
    ) async {
      final h = await _pump(tester, framesLeft: 1);
      // The 27th photo closes the roll: it is not the open one any more.
      h.rolls.add(null);
      await tester.pump();
      await tester.pump();
      expect(find.text('The disposable is finished'), findsOneWidget);
      expect(h.container.read(disposableLockProvider), 7);
      expect(h.events, isEmpty);
      await tester.pump(DisposableDurations.doneNotice);
      await tester.pump();
      expect(h.container.read(disposableLockProvider), isNull);
      expect(h.events, ['finished 7']);
    });

    testWidgets('a roll the database has not reported yet is not an end', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'carrete.disposable.rollId': 7});
      final prefs = await SharedPreferences.getInstance();
      final controller = StreamController<RollRow?>();
      addTearDown(controller.close);
      controller.add(null);
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(412, 915);
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: [
          ...rollOverrides(activeStream: controller.stream, framesLeft: 0),
          sharedPreferencesProvider.overrideWithValue(prefs),
          cameraServiceProvider.overrideWithValue(FakeCameraService()),
          filmResourcesProvider.overrideWith((ref) async => null),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const DisposableScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(DisposableDurations.doneNotice);
      expect(find.text('The disposable is finished'), findsNothing);
      expect(container.read(disposableLockProvider), 7);
      // The roll shows up afterwards and the screen works.
      controller.add(_disposable());
      await tester.pump();
      await tester.pump();
      expect(shutter(), findsOneWidget);
    });
  });

  group('the films do not load', () {
    testWidgets('the exit stamp is there while they load', (tester) async {
      final never = Completer<RecipeBook>();
      final h = await _pump(tester, book: () => never.future);
      expect(shutter(), findsNothing);
      expect(stamp(), findsOneWidget);
      final press = await _hold(tester, const Duration(milliseconds: 2100));
      await press.up();
      await tester.pumpAndSettle();
      await tester.tap(find.text('LEAVE'));
      await tester.pumpAndSettle();
      expect(h.container.read(disposableLockProvider), isNull);
      expect(h.events, ['left']);
    });

    testWidgets('the exit stamp is there when they fail, with a notice', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        book: () async => throw StateError('no films'),
      );
      expect(find.text('The films could not be loaded.'), findsOneWidget);
      expect(shutter(), findsNothing);
      final press = await _hold(tester, const Duration(milliseconds: 2100));
      await press.up();
      await tester.pumpAndSettle();
      expect(find.text('Leave the disposable camera?'), findsOneWidget);
      await tester.tap(find.text('LEAVE'));
      await tester.pumpAndSettle();
      expect(h.events, ['left']);
      expect(h.container.read(disposableLockProvider), isNull);
    });
  });

  group('the hold with reduced motion', () {
    testWidgets('still takes two seconds', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await _pump(tester, reduced: true);
      var press = await _hold(tester, const Duration(milliseconds: 1500));
      expect(find.text('Leave the disposable camera?'), findsNothing);
      await press.up();
      await tester.pump();
      press = await _hold(tester, const Duration(milliseconds: 2100));
      await press.up();
      await tester.pumpAndSettle();
      expect(find.text('Leave the disposable camera?'), findsOneWidget);
    });
  });

  group('the counter and the database', () {
    testWidgets('never goes back up while a photo is going in', (tester) async {
      final frames = StreamController<int>();
      addTearDown(frames.close);
      final h = await _pump(tester, framesStream: frames.stream);
      frames.add(2);
      await tester.pump();
      await tester.pump();
      String counter() => tester
          .widget<Text>(
            find
                .descendant(
                  of: find.byType(StickerCounter),
                  matching: find.byType(Text),
                )
                .first,
          )
          .data!;
      expect(counter(), '2');
      h.service.capturing = Completer<void>();
      await tester.tap(shutter());
      await tester.pump();
      expect(counter(), '1');
      // The photo is inserted: the database says 1 while it is still pending.
      frames.add(1);
      await tester.pump();
      await tester.pump();
      expect(counter(), '1');
      expect(tester.widget<DisposableShutter>(shutter()).onPressed, isNotNull);
      // It finishes before the database has told: still 1, not 2.
      h.service.capturing!.complete();
      await tester.pump();
      await tester.pump();
      expect(counter(), '1');
      frames.add(1);
      await tester.pump();
      await tester.pump();
      expect(counter(), '1');
      // The next photo counts from there.
      h.service.capturing = null;
      await tester.tap(shutter());
      await tester.pump();
      expect(counter(), '0');
      frames.add(0);
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(counter(), '0');
    });

    testWidgets('a photo that fails gives its frame back', (tester) async {
      final frames = StreamController<int>();
      addTearDown(frames.close);
      final h = await _pump(tester, framesStream: frames.stream);
      frames.add(2);
      await tester.pump();
      await tester.pump();
      h.service.failWith = StateError('disk full');
      await tester.tap(shutter());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.descendant(
          of: find.byType(StickerCounter),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 4));
    });
  });

  group('the leave dialog', () {
    testWidgets('fits large text on a small screen and scrolls to its keys', (
      tester,
    ) async {
      await _pump(tester, textScale: 2, size: const Size(320, 480));
      final press = await _hold(tester, const Duration(milliseconds: 2100));
      await press.up();
      await tester.pumpAndSettle();
      expect(find.text('Leave the disposable camera?'), findsOneWidget);
      expect(tester.takeException(), isNull);
      final leave = find.text('LEAVE');
      await tester.ensureVisible(leave);
      await tester.pumpAndSettle();
      final box = tester.getRect(leave);
      expect(box.bottom, lessThanOrEqualTo(480));
      expect(box.top, greaterThanOrEqualTo(0));
      await tester.tap(leave);
      await tester.pumpAndSettle();
      expect(find.text('Leave the disposable camera?'), findsNothing);
    });
  });

  group('large text', () {
    testWidgets('fits at twice the size', (tester) async {
      await _pump(tester, textScale: 2);
      expect(tester.takeException(), isNull);
      expect(shutter(), findsOneWidget);
      expect(stamp(), findsOneWidget);
    });
  });
}
