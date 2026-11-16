import 'package:diapo/camera/camera_providers.dart';
import 'package:diapo/capture/capture_providers.dart';
import 'package:diapo/core/database/tables.dart';
import 'package:diapo/core/settings/settings_provider.dart';
import 'package:diapo/l10n/app_localizations.dart';
import 'package:diapo/platform/system_settings.dart';
import 'package:diapo/render/film_resources.dart';
import 'package:diapo/screens/viewfinder/film_carousel.dart';
import 'package:diapo/screens/viewfinder/viewfinder_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import '../support/roll_fakes.dart';
import '../support/roll_harness.dart';

/// The normal camera with a roll of [mode] open (25 frames left).
Future<(FakeRollService, FakeCaptureQueue, FakeCameraService)> _pump(
  WidgetTester tester, {
  required RollMode mode,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final service = FakeRollService();
  final queue = FakeCaptureQueue();
  final camera = FakeCameraService();
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(412, 915);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...rollOverrides(
          active: rollRow(mode: mode, length: 27, filmId: 'beta'),
          framesLeft: 25,
          service: service,
        ),
        systemSettingsProvider.overrideWithValue(FakeSystemSettings()),
        sharedPreferencesProvider.overrideWithValue(prefs),
        cameraServiceProvider.overrideWithValue(camera),
        captureQueueProvider.overrideWithValue(queue),
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
  return (service, queue, camera);
}

bool _carouselLocked(WidgetTester tester) =>
    tester.widget<FilmCarousel>(find.byType(FilmCarousel)).locked;

void main() {
  group('the camera with a disposable set aside', () {
    testWidgets('takes loose photos and leaves the disposable alone', (
      tester,
    ) async {
      final (service, queue, camera) = await _pump(
        tester,
        mode: RollMode.disposable,
      );
      await tester.tap(find.bySemanticsLabel('Take photo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(camera.pictures, 1);
      expect(queue.jobs, hasLength(1));
      expect(service.calls, isEmpty);
    });

    testWidgets('shows the film and loose photos, not the frames left', (
      tester,
    ) async {
      await _pump(tester, mode: RollMode.disposable);
      expect(find.text('LOOSE PHOTOS'), findsOneWidget);
      expect(find.text('LEFT'), findsNothing);
    });

    testWidgets('leaves the carousel free', (tester) async {
      await _pump(tester, mode: RollMode.disposable);
      expect(_carouselLocked(tester), isFalse);
    });

    testWidgets('a normal roll still takes the photo and locks the film', (
      tester,
    ) async {
      final (service, queue, _) = await _pump(tester, mode: RollMode.roll);
      expect(find.text('LEFT'), findsOneWidget);
      expect(_carouselLocked(tester), isTrue);
      await tester.tap(find.bySemanticsLabel('Take photo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(service.calls, ['capture 7']);
      expect(queue.jobs, isEmpty);
    });
  });
}
