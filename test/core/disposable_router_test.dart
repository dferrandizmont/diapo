import 'dart:async';

import 'package:carrete/camera/camera_providers.dart';
import 'package:carrete/capture/capture_providers.dart';
import 'package:carrete/core/database/app_database.dart';
import 'package:carrete/core/database/tables.dart';
import 'package:carrete/core/router.dart';
import 'package:carrete/core/settings/settings_provider.dart';
import 'package:carrete/l10n/app_localizations.dart';
import 'package:carrete/platform/system_settings.dart';
import 'package:carrete/render/film_resources.dart';
import 'package:carrete/roll/disposable.dart';
import 'package:carrete/screens/disposable/disposable_screen.dart';
import 'package:carrete/screens/roll/roll_screen.dart';
import 'package:carrete/screens/viewfinder/viewfinder_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import '../support/roll_fakes.dart';
import '../support/roll_harness.dart';

class _App {
  _App(this.container, this.rolls);

  final ProviderContainer container;
  final StreamController<RollRow?> rolls;

  GoRouter get router => container.read(routerProvider);
  String get location =>
      router.routerDelegate.currentConfiguration.last.matchedLocation;
}

/// The whole app with the real router, as it starts: [locked] says whether the
/// disposable camera was in the camera when the app last ran, and [active] is
/// what the database holds.
Future<_App> _start(
  WidgetTester tester, {
  required bool locked,
  RollRow? active,
  List<RollRow> history = const [],
}) async {
  SharedPreferences.setMockInitialValues({
    // The first-use flow was seen.
    'carrete.settings.onboardingSeen': true,
    if (locked) 'carrete.disposable.rollId': 7,
  });
  final prefs = await SharedPreferences.getInstance();
  final rolls = StreamController<RollRow?>();
  addTearDown(rolls.close);
  rolls.add(active);
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(412, 915);
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      ...rollOverrides(
        activeStream: rolls.stream,
        framesLeft: 20,
        rolls: history,
        service: FakeRollService(),
      ),
      systemSettingsProvider.overrideWithValue(FakeSystemSettings()),
      sharedPreferencesProvider.overrideWithValue(prefs),
      cameraServiceProvider.overrideWithValue(FakeCameraService()),
      captureQueueProvider.overrideWithValue(FakeCaptureQueue()),
      filmResourcesProvider.overrideWith((ref) async => null),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: ref.watch(routerProvider),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return _App(container, rolls);
}

RollRow _open() => rollRow(mode: RollMode.disposable, length: 27);

void main() {
  group('restarting with a disposable camera in the camera', () {
    testWidgets('goes straight back to it', (tester) async {
      final app = await _start(tester, locked: true, active: _open());
      expect(find.byType(DisposableScreen), findsOneWidget);
      expect(find.byType(ViewfinderScreen), findsNothing);
      expect(app.location, AppRoutes.disposable);
    });

    for (final path in [
      AppRoutes.camera,
      AppRoutes.gallery,
      AppRoutes.settings,
      AppRoutes.onboarding,
      '/roll/7',
    ]) {
      testWidgets('brings $path back to it', (tester) async {
        final app = await _start(tester, locked: true, active: _open());
        app.router.go(path);
        await tester.pumpAndSettle();
        expect(find.byType(DisposableScreen), findsOneWidget);
        expect(app.location, AppRoutes.disposable);
      });
    }

    testWidgets('a notification that opens a roll does not leave it', (
      tester,
    ) async {
      final app = await _start(tester, locked: true, active: _open());
      unawaited(app.router.push(AppRoutes.rollOf('3')));
      await tester.pumpAndSettle();
      expect(find.byType(RollScreen), findsNothing);
      expect(app.location, AppRoutes.disposable);
    });
  });

  group('without the lock', () {
    testWidgets('the app starts at the camera', (tester) async {
      final app = await _start(tester, locked: false);
      expect(find.byType(ViewfinderScreen), findsOneWidget);
      expect(app.location, AppRoutes.camera);
    });

    testWidgets('the disposable route leads back to the camera', (
      tester,
    ) async {
      final app = await _start(tester, locked: false, active: _open());
      app.router.go(AppRoutes.disposable);
      await tester.pumpAndSettle();
      expect(find.byType(DisposableScreen), findsNothing);
      expect(find.byType(ViewfinderScreen), findsOneWidget);
      expect(app.location, AppRoutes.camera);
    });

    testWidgets('taking the lock leads to the disposable camera', (
      tester,
    ) async {
      final app = await _start(tester, locked: false, active: _open());
      expect(find.byType(ViewfinderScreen), findsOneWidget);
      await app.container.read(disposableLockProvider.notifier).lock(7);
      await tester.pumpAndSettle();
      expect(find.byType(DisposableScreen), findsOneWidget);
      expect(app.location, AppRoutes.disposable);
    });
  });

  group('leaving', () {
    testWidgets('releasing the lock takes the phone back to the camera', (
      tester,
    ) async {
      final app = await _start(tester, locked: true, active: _open());
      await app.container.read(disposableLockProvider.notifier).release();
      await tester.pumpAndSettle();
      expect(find.byType(DisposableScreen), findsNothing);
      expect(find.byType(ViewfinderScreen), findsOneWidget);
      expect(app.location, AppRoutes.camera);
    });

    testWidgets('the last photo opens the roll with the camera under it', (
      tester,
    ) async {
      final closed = rollRow(
        mode: RollMode.disposable,
        length: 27,
        state: RollState.developing,
        closedAt: 1,
        developAt: DateTime(2030).millisecondsSinceEpoch,
      );
      final app = await _start(
        tester,
        locked: true,
        active: _open(),
        history: [closed],
      );
      expect(find.byType(DisposableScreen), findsOneWidget);
      // The 27th photo closes the roll.
      app.rolls.add(null);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(app.container.read(disposableLockProvider), isNull);
      expect(find.byType(DisposableScreen), findsNothing);
      expect(find.byType(RollScreen), findsOneWidget);
      expect(app.location, '/roll/7');
      // Back from the roll comes to the camera, not out of the app.
      app.router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(ViewfinderScreen), findsOneWidget);
      expect(app.location, AppRoutes.camera);
    });
  });
}
