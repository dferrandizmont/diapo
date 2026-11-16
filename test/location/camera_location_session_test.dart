import 'dart:async';

import 'package:diapo/app.dart';
import 'package:diapo/camera/camera_providers.dart';
import 'package:diapo/camera/camera_service.dart';
import 'package:diapo/capture/capture_providers.dart';
import 'package:diapo/core/router.dart';
import 'package:diapo/core/settings/settings_provider.dart';
import 'package:diapo/location/camera_location_session.dart';
import 'package:diapo/location/location_provider.dart';
import 'package:diapo/render/film_resources.dart';
import 'package:diapo/roll/roll_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import 'location_provider_test.dart' show FakeLocationSource;

void main() {
  testWidgets('real router push, pop and resume use the visible top route', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final router = buildRouter();
    final source = FakeLocationSource();
    var now = DateTime.utc(2026, 11, 14, 12);
    final controller = LocationController(source, clock: () => now);
    final camera = ValueNotifier(const CameraServiceState(ready: true));
    final session = CameraLocationSession(
      controller,
      camera,
      router.routerDelegate,
    );
    final fakeCamera = FakeCameraService();
    final queue = FakeCaptureQueue();
    addTearDown(() {
      session.dispose();
      controller.dispose();
      camera.dispose();
      fakeCamera.dispose();
      router.dispose();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          routerProvider.overrideWithValue(router),
          cameraServiceProvider.overrideWithValue(fakeCamera),
          captureQueueProvider.overrideWithValue(queue),
          activeRollProvider.overrideWith((ref) => Stream.value(null)),
          remainingFramesProvider.overrideWith((ref) => Stream.value(0)),
          recipeBookProvider.overrideWith((ref) async => testBook()),
          filmResourcesProvider.overrideWith((ref) async => null),
        ],
        child: const CarreteApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(source.updates, 0, reason: 'off by default');
    session.enabled = true;
    session.sync();
    await tester.pump();
    expect(source.updates, 1);
    expect(source.starts, 1);

    unawaited(router.push<void>(AppRoutes.settings));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(source.stops, 1, reason: 'pushed settings cover the camera');
    // Reproduce resyncs while the URL still says camera.
    session.sync();
    session.didChangeAppLifecycleState(AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 35));
    await tester.pump(const Duration(seconds: 35));
    session.didChangeAppLifecycleState(AppLifecycleState.resumed);
    camera.value = const CameraServiceState(ready: true, maxZoom: 3);
    await tester.pump();
    expect(source.updates, 1, reason: 'resume behind settings stays inactive');

    router.pop();
    await tester.pumpAndSettle();
    expect(source.updates, 2, reason: 'pop exposes the camera');
    session.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect(source.stops, 2);
    now = now.add(const Duration(seconds: 35));
    await tester.pump(const Duration(seconds: 35));
    expect(source.updates, 2, reason: 'no background timer');
    session.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(source.updates, 3);
    session.enabled = false;
    session.sync();
    expect(source.stops, 3);
    session.enabled = true;
    camera.value = const CameraServiceState(ready: false);
    await tester.pump();
    expect(source.starts, 3, reason: 'camera must be ready before starting');
    camera.value = const CameraServiceState(ready: true);
    await tester.pump();
    expect(source.starts, 4);
    camera.value = const CameraServiceState(ready: false);
    expect(source.stops, 4, reason: 'losing camera readiness stops updates');
    expect(source.requests, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
