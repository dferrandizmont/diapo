import 'package:carrete/location/location_provider.dart';
import 'package:carrete/location/location_source.dart';
import 'package:carrete/location/photo_location.dart';

import 'dart:async';

import 'package:carrete/capture/cinema_bands.dart';

import 'package:carrete/roll/roll_service.dart';
import 'package:carrete/core/database/app_database.dart';
import 'package:carrete/core/database/tables.dart';
import 'package:carrete/capture/capture_queue.dart';
import 'package:carrete/camera/camera_flash.dart';
import 'package:carrete/camera/camera_providers.dart';
import 'package:carrete/camera/camera_service.dart';
import 'package:carrete/capture/capture_providers.dart';
import 'package:carrete/core/settings/film_tuning.dart';
import 'package:carrete/core/settings/film_tuning_provider.dart';
import 'package:carrete/core/settings/film_tuning_repository.dart';
import 'package:carrete/core/settings/settings_provider.dart';
import 'package:carrete/l10n/app_localizations.dart';
import 'package:carrete/platform/system_settings.dart';
import 'package:carrete/render/film_resources.dart';
import 'package:carrete/screens/viewfinder/film_carousel.dart';
import 'package:carrete/screens/viewfinder/frame_overlays.dart';
import 'package:carrete/screens/viewfinder/top_bar.dart';
import 'package:carrete/screens/viewfinder/viewfinder_screen.dart';
import 'package:carrete/screens/viewfinder/viewfinder_state.dart';
import 'package:carrete/capture/date_stamp.dart';
import 'package:carrete/ui/widgets/plastic_controls.dart';
import 'package:film_recipes/film_recipes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';

class _RollCaptureSpy implements RollService {
  final jobs = <CaptureJob>[];
  final rollIds = <int?>[];
  final pending = Completer<ShotRow>();

  @override
  Future<ShotRow> captureIntoRoll(
    CaptureJob job, {
    int? rollId,
    ShotLens lens = ShotLens.back,
  }) {
    jobs.add(job);
    rollIds.add(rollId);
    return pending.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Harness {
  _Harness(this.camera, this.queue, this.prefs);

  final FakeCameraService camera;
  final FakeCaptureQueue queue;
  final SharedPreferences prefs;

  ProviderContainer get container =>
      ProviderScope.containerOf(find.byType(ViewfinderScreen).evaluate().first);
}

Future<_Harness> _pump(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  Size size = const Size(412, 915),
  double statusBar = 0,
  FakeCameraService? camera,
  FakeSystemSettings? system,
  RollRow? roll,
  RollService? rollService,
  VoidCallback? onOpenGallery,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final preferences = await SharedPreferences.getInstance();
  final fakeCamera = camera ?? FakeCameraService();
  final queue = FakeCaptureQueue();

  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size
    ..padding = FakeViewPadding(top: statusBar)
    ..viewPadding = FakeViewPadding(top: statusBar);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeRollProvider.overrideWith((ref) => Stream.value(roll)),
        remainingFramesProvider.overrideWith(
          (ref) => Stream.value(roll?.length ?? 0),
        ),
        if (rollService != null)
          rollServiceProvider.overrideWithValue(rollService),
        systemSettingsProvider.overrideWithValue(
          system ?? FakeSystemSettings(),
        ),
        sharedPreferencesProvider.overrideWithValue(preferences),
        cameraServiceProvider.overrideWithValue(fakeCamera),
        captureQueueProvider.overrideWithValue(queue),
        recipeBookProvider.overrideWith((ref) async => testBook()),
        filmResourcesProvider.overrideWith((ref) async => null),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ViewfinderScreen(onOpenGallery: onOpenGallery),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return _Harness(fakeCamera, queue, preferences);
}

Future<void> _shoot(WidgetTester tester) async {
  await tester.tap(find.byType(ShutterButton));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  testWidgets('the camera opens when the screen does', (tester) async {
    final h = await _pump(tester);
    expect(h.camera.started, 1);
    expect(h.camera.flashes.first, CarreteFlash.off);
  });

  testWidgets(
    'cinema bands follow the format and tuning, including roll jobs',
    (tester) async {
      final spy = _RollCaptureSpy();
      final h = await _pump(
        tester,
        rollService: spy,
        roll: const RollRow(
          id: 7,
          filmId: 'alpha',
          length: 24,
          mode: RollMode.roll,
          developDelay: DevelopDelay.oneHour,
          state: RollState.open,
          createdAt: 1,
        ),
      );
      final notifier = h.container.read(filmTuningsProvider.notifier);
      for (final format in FrameFormat.values) {
        notifier.update(
          'alpha',
          (t) => t.copyWith(cinemaBands: true, format: format, dateStamp: true),
        );
        await tester.pump();
        expect(
          find.byType(CinemaBandsOverlay),
          format == FrameFormat.r16x9 ? findsOneWidget : findsNothing,
        );
        expect(
          tester
              .widget<DateStampOverlay>(find.byType(DateStampOverlay))
              .cinemaBands,
          format == FrameFormat.r16x9,
        );
        await _shoot(tester);
        expect(spy.jobs.last.cinemaBands, format == FrameFormat.r16x9);
      }
      notifier.update('alpha', (t) => t.copyWith(cinemaBands: false));
      await tester.pump();
      expect(find.byType(CinemaBandsOverlay), findsNothing);
      await _shoot(tester);
      expect(spy.jobs.last.cinemaBands, isFalse);
    },
  );

  testWidgets('loose shots keep cinema bands in the queued job', (
    tester,
  ) async {
    final h = await _pump(
      tester,
      prefs: {
        FilmTuningRepository.storageKey:
            '{"alpha":{"cinemaBands":true,"format":"16:9"}}',
      },
    );
    await _shoot(tester);
    expect(h.queue.jobs.single.cinemaBands, isTrue);
    expect(h.queue.jobs.single.look.cinemaBands, isTrue);
  });

  group('carousel', () {
    testWidgets('lists every film of the recipe book', (tester) async {
      await _pump(tester);
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('Gamma'), findsOneWidget);
    });

    testWidgets('shows the names in the language of the app', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(412, 915);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeRollProvider.overrideWith((ref) => Stream.value(null)),
            sharedPreferencesProvider.overrideWithValue(preferences),
            cameraServiceProvider.overrideWithValue(FakeCameraService()),
            captureQueueProvider.overrideWithValue(FakeCaptureQueue()),
            recipeBookProvider.overrideWith((ref) async => testBook()),
            filmResourcesProvider.overrideWith((ref) async => null),
          ],
          child: MaterialApp(
            locale: const Locale('ca'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ViewfinderScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Alpha ca'), findsOneWidget);
      expect(find.text('Gamma ca'), findsOneWidget);
    });

    testWidgets('starts on the film saved in the settings', (tester) async {
      final h = await _pump(
        tester,
        prefs: {'carrete.settings.defaultFilmId': 'beta'},
      );
      expect(h.container.read(settingsProvider).defaultFilmId, 'beta');
      // The format of Beta is 4:3.
      expect(find.text('4:3'), findsOneWidget);
    });

    testWidgets('falls back to the first film when the saved one is gone', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        prefs: {'carrete.settings.defaultFilmId': 'deleted-film'},
      );
      // Alpha is the first film, 3:2.
      expect(find.text('3:2'), findsOneWidget);
      expect(h.container.read(settingsProvider).defaultFilmId, 'deleted-film');
    });

    testWidgets('a tap changes the selection and it persists', (tester) async {
      final h = await _pump(tester);
      expect(h.container.read(settingsProvider).defaultFilmId, 'verano-98');

      await tester.tap(find.text('Beta'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(h.container.read(settingsProvider).defaultFilmId, 'beta');
      expect(
        h.prefs.getString('carrete.settings.defaultFilmId'),
        'beta',
        reason: 'the selection is stored through defaultFilmId',
      );
      // The format key now shows the format of Beta.
      expect(find.text('4:3'), findsOneWidget);

      await tester.tap(find.text('Gamma'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(h.container.read(settingsProvider).defaultFilmId, 'gamma');
      expect(find.text('1:1'), findsOneWidget);
    });
  });

  group('fine tuning panel', () {
    testWidgets('a long press opens it for that film', (tester) async {
      final h = await _pump(tester);
      expect(find.text('FINE TUNING'), findsNothing);

      await tester.longPress(find.text('Beta'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('FINE TUNING'), findsOneWidget);
      expect(find.text('Grain'), findsOneWidget);
      expect(find.text('Halation'), findsOneWidget);
      expect(find.text('Light leak'), findsOneWidget);
      expect(find.text('Vignette'), findsOneWidget);
      expect(find.text('Date imprint'), findsOneWidget);
      expect(h.container.read(viewfinderProvider).tuningFilmId, 'beta');
      expect(h.container.read(settingsProvider).defaultFilmId, 'beta');
    });

    testWidgets('the sliders start at 50 and a change persists per film', (
      tester,
    ) async {
      final h = await _pump(tester);
      await tester.longPress(find.text('Beta'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('50'), findsNWidgets(4));

      // Drag the first slider (grain) to the far left: 0.
      final grain = find.byType(PlasticSlider).first;
      await tester.drag(grain, const Offset(-400, 0));
      await tester.pump();

      expect(find.text('0'), findsOneWidget);
      final tuning = h.container.read(filmTuningsProvider)['beta']!;
      expect(tuning.grain, 0);
      expect(tuning.halation, 1);
      await tester.pump(const Duration(milliseconds: 50));

      final stored = FilmTuningRepository(h.prefs).load();
      expect(stored['beta']!.grain, 0);
      expect(stored['alpha'], isNull, reason: 'other films are untouched');
    });

    testWidgets('a slider moves to the place that is tapped', (tester) async {
      final h = await _pump(tester);
      await tester.longPress(find.text('Alpha'));
      await tester.pump(const Duration(milliseconds: 400));

      final vignette = find.byType(PlasticSlider).at(3);
      final rect = tester.getRect(vignette);
      await tester.tapAt(Offset(rect.right - 2, rect.center.dy));
      await tester.pump();
      expect(h.container.read(filmTuningsProvider)['alpha']!.vignette, 2);
    });

    testWidgets('the date switch changes the tuning and the panel has no '
        'format row', (tester) async {
      final h = await _pump(tester);
      await tester.longPress(find.text('Alpha'));
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byType(PlasticSwitch));
      await tester.pump();
      expect(h.container.read(filmTuningsProvider)['alpha']!.dateStamp, isTrue);

      // The format key beside the shutter is the only way to choose the format
      // in the camera: the panel has no row for it.
      expect(find.text('Format'), findsNothing);
      expect(find.text('16:9'), findsNothing);
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const ValueKey('format-key')));
        await tester.pump();
      }
      expect(
        h.container.read(filmTuningsProvider)['alpha']!.format,
        FrameFormat.r16x9,
      );
    });

    testWidgets(
      'the cinema bands switch shows at 16:9 and changes the tuning',
      (tester) async {
        final h = await _pump(tester);
        await tester.longPress(find.text('Alpha'));
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Cinema bands'), findsNothing);

        // 3:2, 4:3, 1:1, 16:9: the key beside the shutter cycles the formats.
        for (var i = 0; i < 3; i++) {
          await tester.tap(find.byKey(const ValueKey('format-key')));
          await tester.pump();
        }
        expect(find.text('Cinema bands'), findsOneWidget);

        await tester.tap(
          find.byWidgetPredicate(
            (w) => w is PlasticSwitch && w.label == 'Cinema bands',
          ),
        );
        await tester.pump();
        expect(
          h.container.read(filmTuningsProvider)['alpha']!.cinemaBands,
          isTrue,
        );
        expect(find.byType(CinemaBandsOverlay), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('format-key')));
        await tester.pump();
        expect(find.text('Cinema bands'), findsNothing);
        expect(find.byType(CinemaBandsOverlay), findsNothing);
      },
    );

    testWidgets('the close key closes it', (tester) async {
      final h = await _pump(tester);
      await tester.longPress(find.text('Alpha'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('FINE TUNING'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pump();
      expect(find.text('FINE TUNING'), findsNothing);
      expect(h.container.read(viewfinderProvider).tuningFilmId, isNull);
    }, skip: false);

    testWidgets('a stored tuning is applied when the screen opens', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        prefs: {
          FilmTuningRepository.storageKey:
              '{"alpha":{"grain":0.2,"format":"16:9"}}',
        },
      );
      expect(h.container.read(filmTuningsProvider)['alpha']!.grain, 0.2);
      // The format key shows the tuned format of the first film.
      expect(find.text('16:9'), findsOneWidget);
    });
  });

  group('format key', () {
    testWidgets('cycles 3:2, 4:3, 1:1, 16:9 and back, per film', (
      tester,
    ) async {
      final h = await _pump(tester);
      expect(find.text('3:2'), findsOneWidget);

      final seen = <String>['3:2'];
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(const ValueKey('format-key')));
        await tester.pump();
        final label = [
          '3:2',
          '4:3',
          '1:1',
          '16:9',
        ].firstWhere((t) => find.text(t).evaluate().isNotEmpty);
        seen.add(label);
      }
      expect(seen, ['3:2', '4:3', '1:1', '16:9', '3:2']);
      expect(
        h.container.read(filmTuningsProvider)['alpha']!.format,
        FrameFormat.r3x2,
      );

      // Another film has its own format.
      await tester.tap(find.text('Beta'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('4:3'), findsOneWidget);
    });
  });

  group('shutter', () {
    testWidgets(
      'routes roll shots without waiting for encryption or developing',
      (tester) async {
        final spy = _RollCaptureSpy();
        final h = await _pump(
          tester,
          rollService: spy,
          roll: const RollRow(
            id: 7,
            filmId: 'alpha',
            length: 24,
            mode: RollMode.roll,
            developDelay: DevelopDelay.oneHour,
            state: RollState.open,
            createdAt: 1,
          ),
        );
        await _shoot(tester);
        await _shoot(tester);
        expect(h.camera.pictures, 2);
        expect(spy.jobs, hasLength(2));
        expect(spy.rollIds, [7, 7]);
        expect(h.queue.jobs, isEmpty);
        expect(spy.pending.isCompleted, isFalse);
      },
    );

    testWidgets('hands the photo to the capture queue', (tester) async {
      final h = await _pump(tester);
      expect(h.queue.jobs, isEmpty);

      await _shoot(tester);

      expect(h.camera.pictures, 1);
      expect(h.queue.jobs, hasLength(1));
      final job = h.queue.jobs.single;
      expect(job.filePath, 'photo_1.jpg');
      expect(job.filmId, 'alpha');
      expect(job.format, FrameFormat.r3x2);
      expect(job.stampText, isNull);
      expect(job.whiteFrame, isFalse);
      expect(job.fieldAspect, closeTo(1080 / 1920, 1e-9));
      expect(h.container.read(viewfinderProvider).shots, 1);
    });

    testWidgets('the job remembers the lens that took the photo', (
      tester,
    ) async {
      final h = await _pump(tester);
      await _shoot(tester);
      await tester.tap(find.bySemanticsLabel('Switch camera'));
      await tester.pump();
      await _shoot(tester);

      expect(h.queue.jobs.map((job) => job.lens), [
        ShotLens.back,
        ShotLens.front,
      ]);
    });

    testWidgets('can queue a second photo right away', (tester) async {
      final h = await _pump(tester);
      await _shoot(tester);
      await _shoot(tester);
      expect(h.queue.jobs, hasLength(2));
      expect(h.container.read(viewfinderProvider).shots, 2);
    });

    testWidgets('the original is kept only when the setting is on', (
      tester,
    ) async {
      final h = await _pump(tester);
      await _shoot(tester);
      expect(h.queue.jobs.single.saveOriginal, isFalse, reason: 'default');

      h.container.read(settingsProvider.notifier).setSaveOriginal(true);
      await tester.pump();
      await _shoot(tester);
      expect(h.queue.jobs.last.saveOriginal, isTrue);

      h.container.read(settingsProvider.notifier).setSaveOriginal(false);
      await tester.pump();
      await _shoot(tester);
      expect(h.queue.jobs.last.saveOriginal, isFalse);
    });

    testWidgets(
      'the location goes into the photo only when the setting is on',
      (tester) async {
        final h = await _pump(tester);
        await _shoot(tester);
        expect(h.queue.jobs.single.includeLocation, isFalse, reason: 'default');

        h.container.read(settingsProvider.notifier).setSaveLocation(true);
        await tester.pump();
        await _shoot(tester);
        expect(
          h.queue.jobs.last.includeLocation,
          isFalse,
          reason: 'no usable fix',
        );

        final location = PhotoLocation(
          latitude: 40,
          longitude: -3,
          accuracy: 10,
          time: DateTime.now(),
        );
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(NativeLocationSource.channel, (
          call,
        ) async {
          return switch (call.method) {
            'permission' => 'granted',
            'current' => {'permission': 'granted', 'fix': location.toJson()},
            _ => null,
          };
        });
        addTearDown(
          () => messenger.setMockMethodCallHandler(
            NativeLocationSource.channel,
            null,
          ),
        );
        final controller = h.container.read(locationControllerProvider);
        controller.setActive(true);
        await tester.pump();
        await _shoot(tester);
        expect(h.queue.jobs.last.includeLocation, isTrue);
        expect(h.queue.jobs.last.location!.toJson(), location.toJson());
        controller.setActive(false);

        h.container.read(settingsProvider.notifier).setSaveLocation(false);
        await tester.pump();
        await _shoot(tester);
        expect(h.queue.jobs.last.includeLocation, isFalse);
        // The job also carries what rebuilds its look after a restart.
        expect(h.queue.jobs.last.tuning, FilmTuning.defaults);
        expect(h.queue.jobs.last.flash, CarreteFlash.off);
      },
    );

    testWidgets('the photo uses the film, tuning and format of the moment', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        prefs: {
          'carrete.settings.defaultFilmId': 'gamma',
          'carrete.settings.dateStampStyle': 'd m yy',
        },
      );
      await _shoot(tester);
      final job = h.queue.jobs.single;
      expect(job.filmId, 'gamma');
      expect(job.format, FrameFormat.r1x1);
      expect(job.whiteFrame, isTrue, reason: 'a 1:1 film with a white frame');
      // Day first: "<d> <m> '<yy>".
      expect(job.stampText, matches(r"^\d{1,2} \d{1,2} '\d{2}$"));
      expect(job.takenAt, isNotNull);
    });

    testWidgets('the white frame needs the square format', (tester) async {
      final h = await _pump(
        tester,
        prefs: {'carrete.settings.defaultFilmId': 'gamma'},
      );
      expect(find.text('White frame when saved'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('format-key')));
      await tester.pump();
      await _shoot(tester);
      expect(h.queue.jobs.single.whiteFrame, isFalse);
      expect(find.text('White frame when saved'), findsNothing);
    });

    testWidgets('the party flash burns the look of the photo', (tester) async {
      final h = await _pump(tester);
      await _shoot(tester);
      final plain = h.queue.jobs.single.look;

      // Off -> auto -> on -> party: three presses of the one flash key.
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const ValueKey('flash-key')));
        await tester.pump();
      }
      expect(h.camera.flashes.last, CarreteFlash.party);
      await _shoot(tester);

      final party = h.queue.jobs.last.look;
      expect(party.exposure, closeTo(plain.exposure + 0.3, 1e-9));
      expect(party.halationAmount, closeTo(plain.halationAmount * 1.5, 1e-9));
    });

    testWidgets('does nothing while the camera is not ready', (tester) async {
      final h = await _pump(
        tester,
        camera: FakeCameraService(state: const CameraServiceState()),
      );
      await tester.tap(find.byType(ShutterButton));
      await tester.pump();
      expect(h.camera.pictures, 0);
      expect(h.queue.jobs, isEmpty);
    });
  });

  group('other controls', () {
    testWidgets('the flash key cycles the flash of the camera', (tester) async {
      final h = await _pump(tester);
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(const ValueKey('flash-key')));
        await tester.pump();
      }
      expect(h.camera.flashes.skip(1), [
        CarreteFlash.auto,
        CarreteFlash.on,
        CarreteFlash.party,
        CarreteFlash.off,
      ]);
    });

    testWidgets('the camera key switches the lens', (tester) async {
      final h = await _pump(tester);
      await tester.tap(find.bySemanticsLabel('Switch camera'));
      await tester.pump();
      expect(h.camera.lensSwitches, 1);
    });

    testWidgets('the gallery key opens the gallery', (tester) async {
      var opened = 0;
      await _pump(tester, onOpenGallery: () => opened++);

      await tester.tap(find.bySemanticsLabel('Gallery'));
      await tester.pump();

      expect(opened, 1);
    });

    testWidgets('the gallery key and the camera key sit left of the shutter', (
      tester,
    ) async {
      await _pump(tester);
      final shutter = tester.getCenter(find.byType(ShutterButton));
      final gallery = tester.getCenter(
        find.byKey(const ValueKey('gallery-key')),
      );
      final flip = tester.getCenter(find.bySemanticsLabel('Switch camera'));
      final format = tester.getCenter(find.byKey(const ValueKey('format-key')));

      expect(gallery.dx, lessThan(flip.dx));
      expect(flip.dx, lessThan(shutter.dx));
      expect(format.dx, greaterThan(shutter.dx));
      // The shutter stays in the middle of the screen.
      expect(shutter.dx, closeTo(206, 0.5));
    });

    testWidgets('a tap on the frame locks focus, a second one releases it', (
      tester,
    ) async {
      final h = await _pump(tester);
      await tester.tapAt(const Offset(206, 400));
      await tester.pump();
      expect(h.camera.focusPoints, hasLength(1));
      expect(h.camera.focusPoints.single, isNotNull);

      await tester.tapAt(const Offset(206, 400));
      await tester.pump();
      expect(h.camera.focusPoints.last, isNull);
    });

    testWidgets('pauses and resumes the camera with the app', (tester) async {
      final h = await _pump(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(h.camera.paused, 1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(h.camera.resumed, 1);
    });

    testWidgets('shows the problem and a retry key when the camera fails', (
      tester,
    ) async {
      final h = await _pump(
        tester,
        camera: FakeCameraService(
          state: const CameraServiceState(
            failure: CameraFailure.permissionDenied,
          ),
        ),
      );
      expect(find.textContaining('Camera permission'), findsOneWidget);
      expect(find.textContaining('Carrete'), findsNothing);
      final started = h.camera.started;
      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(h.camera.started, started + 1);
    });
  });

  group('the frame is fully visible', () {
    // The OnePlus 10T is 1080 x 2412 px at 2.625 (about 411 x 919 dp, with a
    // status bar of 32 dp). The short screen is a small old phone.
    const screens = <(String, Size, double)>[
      ('OnePlus 10T', Size(411, 915), 32),
      ('small phone', Size(360, 640), 24),
    ];

    Rect frameOf(WidgetTester tester) =>
        tester.getRect(find.byKey(const ValueKey('viewfinder-frame')));

    void expectFits(WidgetTester tester, String reason) {
      final frame = frameOf(tester);
      final topBar = tester.getRect(find.byType(ViewfinderTopBar));
      final carousel = tester.getRect(find.byType(FilmCarousel));
      expect(
        frame.top,
        greaterThanOrEqualTo(topBar.bottom - 0.01),
        reason: reason,
      );
      expect(
        frame.bottom,
        lessThanOrEqualTo(carousel.top + 0.01),
        reason: reason,
      );
      expect(frame.left, greaterThanOrEqualTo(0), reason: reason);
      expect(
        frame.center.dx,
        closeTo(tester.view.physicalSize.width / 2, 0.01),
      );
    }

    for (final (name, size, statusBar) in screens) {
      testWidgets('sits between the top bar and the carousel in every format '
          'on the $name', (tester) async {
        await _pump(tester, size: size, statusBar: statusBar);
        const aspects = [2 / 3, 3 / 4, 1.0, 9 / 16];
        for (final aspect in aspects) {
          expectFits(tester, 'aspect $aspect');
          final frame = frameOf(tester);
          expect(frame.width / frame.height, closeTo(aspect, 0.002));
          // The corner marks are drawn on the corners of the visible frame.
          expect(tester.getRect(find.byType(FrameCorners)), frame);
          expect(tester.takeException(), isNull);
          await tester.tap(find.byKey(const ValueKey('format-key')));
          await tester.pump();
        }
      });
    }

    testWidgets('shrinks the 9:16 frame and leaves black sides', (
      tester,
    ) async {
      await _pump(tester, size: const Size(411, 915), statusBar: 32);
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const ValueKey('format-key')));
        await tester.pump();
      }
      expect(find.text('16:9'), findsOneWidget);
      final frame = frameOf(tester);
      expect(frame.width, lessThan(411));
      expect(frame.left, greaterThan(0));
    });

    testWidgets('the overlays follow the fitted frame', (tester) async {
      // Gamma is square, imprints the date and has a white frame.
      await _pump(
        tester,
        size: const Size(360, 640),
        statusBar: 24,
        prefs: {
          'carrete.settings.defaultFilmId': 'gamma',
          'carrete.settings.grid': true,
        },
      );
      final frame = frameOf(tester);
      expect(tester.getRect(find.byType(ThirdsGrid)), frame);
      expect(tester.getRect(find.byType(DateStampOverlay)), frame);
      final hint = tester.getRect(find.text('White frame when saved'));
      expect(frame.contains(hint.topLeft), isTrue);
      expect(frame.contains(hint.bottomRight), isTrue);
    });

    testWidgets('the focus indicator is on the tapped point of the frame', (
      tester,
    ) async {
      final h = await _pump(tester, size: const Size(411, 915), statusBar: 32);
      final frame = frameOf(tester);
      final point = frame.center;
      await tester.tapAt(point);
      await tester.pump();
      final lock = tester.getRect(find.byType(FocusLockIndicator));
      expect(lock.center.dx, closeTo(point.dx, 0.01));
      expect(lock.center.dy, closeTo(point.dy, 0.01));
      expect(h.camera.focusPoints.single, isNotNull);

      // A tap in the corner keeps the indicator inside the frame.
      await tester.tapAt(frame.topLeft + const Offset(2, 2));
      await tester.pump();
      final corner = tester.getRect(find.byType(FocusLockIndicator));
      expect(corner.left, greaterThanOrEqualTo(frame.left));
      expect(corner.top, greaterThanOrEqualTo(frame.top));
    });

    testWidgets('tap to focus is mapped through the fitted frame', (
      tester,
    ) async {
      // The fake preview is 9:16. In the 9:16 format the frame has the same
      // aspect, so a point of the frame is the same point of the preview.
      final h = await _pump(tester, size: const Size(411, 915), statusBar: 32);
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const ValueKey('format-key')));
        await tester.pump();
      }
      final frame = frameOf(tester);
      await tester.tapAt(
        Offset(
          frame.left + frame.width * 0.25,
          frame.top + frame.height * 0.75,
        ),
      );
      await tester.pump();
      final point = h.camera.focusPoints.single!;
      expect(point.dx, closeTo(0.25, 0.002));
      expect(point.dy, closeTo(0.75, 0.002));
    });

    testWidgets('tap to focus crops the preview in a wider format', (
      tester,
    ) async {
      // In 3:2 the frame is wider than the 9:16 preview: the top and bottom
      // of the preview are cropped.
      final h = await _pump(tester, size: const Size(411, 915), statusBar: 32);
      final frame = frameOf(tester);
      await tester.tapAt(
        Offset(
          frame.left + frame.width * 0.25,
          frame.top + frame.height * 0.25,
        ),
      );
      await tester.pump();
      final point = h.camera.focusPoints.single!;
      const visible = (9 / 16) / (2 / 3);
      expect(point.dx, closeTo(0.25, 0.002));
      expect(point.dy, closeTo((1 - visible) / 2 + 0.25 * visible, 0.002));
    });
  });

  group('camera permission', () {
    CameraServiceState failed(CameraFailure failure) =>
        CameraServiceState(failure: failure);

    testWidgets('offers to open the settings of the system', (tester) async {
      final system = FakeSystemSettings();
      await _pump(
        tester,
        system: system,
        camera: FakeCameraService(
          state: failed(CameraFailure.permissionDenied),
        ),
      );
      expect(find.text('Open settings'), findsOneWidget);
      await tester.tap(find.text('Open settings'));
      await tester.pump();
      expect(system.opened, 1);
    });

    testWidgets('is text only where the settings cannot be opened', (
      tester,
    ) async {
      await _pump(
        tester,
        system: FakeSystemSettings(available: false),
        camera: FakeCameraService(
          state: failed(CameraFailure.permissionDenied),
        ),
      );
      expect(find.text('Open settings'), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('another failure has no settings key', (tester) async {
      await _pump(
        tester,
        camera: FakeCameraService(state: failed(CameraFailure.unavailable)),
      );
      expect(find.text('Open settings'), findsNothing);
    });
  });

  group('labels and tokens', () {
    testWidgets('the small labels are printed in capitals', (tester) async {
      await _pump(tester);
      expect(find.text('LOOSE PHOTOS'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('flash-key')),
          matching: find.text('OFF'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the zoom pill is a live region', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      final centre = tester.getCenter(
        find.byKey(const ValueKey('viewfinder-frame')),
      );
      final a = await tester.startGesture(centre - const Offset(20, 0));
      final b = await tester.startGesture(centre + const Offset(20, 0));
      await tester.pump();
      await a.moveBy(const Offset(-30, 0));
      await b.moveBy(const Offset(30, 0));
      await tester.pump();
      final pill = find.bySemanticsLabel(RegExp(r'^\d\.\dx$'));
      expect(pill, findsOneWidget);
      expect(tester.getSemantics(pill).flagsCollection.isLiveRegion, isTrue);
      await a.up();
      await b.up();
      await tester.pump(const Duration(seconds: 1));
      handle.dispose();
    });
  });

  group('layout and accessibility', () {
    testWidgets('fits a narrow phone without overflow', (tester) async {
      await _pump(tester, size: const Size(360, 640));
      expect(tester.takeException(), isNull);
    });

    for (final width in [320.0, 360.0, 412.0]) {
      testWidgets('the shutter row keeps every key at 44 dp on $width dp', (
        tester,
      ) async {
        await _pump(tester, size: Size(width, 700));
        expect(tester.takeException(), isNull);

        // getRect applies the transforms: a key scaled down shows here.
        final keys = {
          'gallery': find.byKey(const ValueKey('gallery-key')),
          'camera': find.bySemanticsLabel('Switch camera'),
          'format': find.byKey(const ValueKey('format-key')),
          'shutter': find.byType(ShutterButton),
        };
        for (final entry in keys.entries) {
          final rect = tester.getRect(entry.value.first);
          expect(rect.width, greaterThanOrEqualTo(44), reason: entry.key);
          expect(rect.height, greaterThanOrEqualTo(44), reason: entry.key);
          expect(rect.left, greaterThanOrEqualTo(0), reason: entry.key);
          expect(rect.right, lessThanOrEqualTo(width), reason: entry.key);
        }
        // Nothing overlaps the shutter and it stays in the middle.
        final shutter = tester.getRect(keys['shutter']!);
        expect(shutter.center.dx, closeTo(width / 2, 0.5));
        expect(
          tester.getRect(keys['camera']!).right,
          lessThanOrEqualTo(shutter.left),
        );
        expect(
          tester.getRect(keys['format']!).left,
          greaterThanOrEqualTo(shutter.right),
        );
      });
    }

    testWidgets('fits a tall phone in every format', (tester) async {
      await _pump(tester, size: const Size(412, 915));
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byKey(const ValueKey('format-key')));
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('every control is at least 44 x 44', (tester) async {
      await _pump(tester);
      for (final finder in [
        find.bySemanticsLabel('Switch camera'),
        find.bySemanticsLabel('Gallery'),
        find.bySemanticsLabel('Settings'),
        find.bySemanticsLabel('Flash: Off'),
        find.bySemanticsLabel('Format 3:2'),
        find.byType(ShutterButton),
      ]) {
        final size = tester.getSize(finder.first);
        expect(size.width, greaterThanOrEqualTo(44), reason: '$finder');
        expect(size.height, greaterThanOrEqualTo(44), reason: '$finder');
      }
    });

    testWidgets('gives every control a semantic label', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      for (final label in [
        'Take photo',
        'Switch camera',
        'Gallery',
        'Settings',
        'Flash: Off',
        'Format 3:2',
        'Alpha',
        'Beta',
        'Gamma',
        'Films',
        'Camera viewfinder',
      ]) {
        expect(find.bySemanticsLabel(label), findsWidgets, reason: label);
      }
      handle.dispose();
    });

    testWidgets('no animation runs when animations are disabled', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final queue = FakeCaptureQueue();
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(412, 915);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeRollProvider.overrideWith((ref) => Stream.value(null)),
            sharedPreferencesProvider.overrideWithValue(preferences),
            cameraServiceProvider.overrideWithValue(FakeCameraService()),
            captureQueueProvider.overrideWithValue(queue),
            recipeBookProvider.overrideWith((ref) async => testBook()),
            filmResourcesProvider.overrideWith((ref) async => null),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: const ViewfinderScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byType(ShutterButton));
      await tester.pump();
      // The photo is queued and no frames are pending for the film advance.
      expect(queue.jobs, hasLength(1));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  test('the cartridge band is the colour the recipe names', () {
    const recipe = Recipe(
      id: 'named',
      name: LocalizedText(es: 'a', ca: 'b', en: 'c'),
      description: LocalizedText(es: 'a', ca: 'b', en: 'c'),
      bandColor: '#1FA88C',
    );
    expect(filmBandColor(recipe), const Color(0xFF1FA88C));
    // A band colour that is not a hex colour falls back to the derived one.
    const broken = Recipe(
      id: 'broken',
      name: LocalizedText(es: 'a', ca: 'b', en: 'c'),
      description: LocalizedText(es: 'a', ca: 'b', en: 'c'),
      bandColor: 'teal',
    );
    expect(filmBandColor(broken).a, 1);
  });

  test('the cartridge band comes from the recipe', () {
    final book = testBook();
    final colour = filmBandColor(book.recipes.first);
    expect(colour.a, 1);
    final bw = filmBandColor(book.byId('beta')!);
    expect(bw.r, closeTo(bw.g, 1e-9));
    expect(bw.g, closeTo(bw.b, 1e-9));
    expect(FilmTuning.defaults.isDefault, isTrue);
  });
}
