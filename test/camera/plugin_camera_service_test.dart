import 'dart:async';

import 'package:camera/camera.dart';
import 'package:carrete/camera/camera_service.dart';
import 'package:carrete/camera/plugin_camera_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A controller whose `initialize` is answered by the test, like the plugin
/// answers it after the permission dialog.
class _FakeController extends CameraController {
  _FakeController(CameraDescription description)
    : super(description, ResolutionPreset.max);

  final Completer<void> answer = Completer<void>();
  bool released = false;

  /// When set, the call waits for it (a hang of the plugin).
  Completer<void>? zoomGate;
  Completer<void>? flashGate;

  /// When set, the close waits for it, like the real controller's dispose
  /// waits for its initialize.
  Completer<void>? disposeGate;

  @override
  Future<void> initialize() async {
    await answer.future;
    value = value.copyWith(
      isInitialized: true,
      previewSize: const Size(1920, 1080),
    );
  }

  @override
  Future<void> lockCaptureOrientation([DeviceOrientation? orientation]) async {}

  @override
  Future<double> getMinZoomLevel() async {
    await zoomGate?.future;
    return 1;
  }

  @override
  Future<double> getMaxZoomLevel() async => 4;

  @override
  Future<void> setZoomLevel(double zoom) async {}

  @override
  Future<void> setFlashMode(FlashMode mode) async {
    await flashGate?.future;
  }

  // The plugin's own dispose would talk to the platform.
  @override
  // ignore: must_call_super
  Future<void> dispose() async {
    await disposeGate?.future;
    released = true;
  }

  void deny([String code = 'CameraAccessDenied']) =>
      answer.completeError(CameraException(code, 'denied'));

  void grant() => answer.complete();
}

const _back = CameraDescription(
  name: 'back',
  lensDirection: CameraLensDirection.back,
  sensorOrientation: 90,
);

void main() {
  late List<_FakeController> controllers;
  bool? permission;

  /// The answers of the permission query that the test holds back, in order.
  late List<Completer<bool?>> permissionCalls;
  bool holdPermission = false;

  /// Zoom and flash gates given to every controller the factory makes.
  Completer<void>? zoomGate;
  Completer<void>? flashGate;

  PluginCameraService service({
    Duration openTimeout = const Duration(seconds: 20),
  }) => PluginCameraService(
    listCameras: () async => [_back],
    permissionGranted: () {
      if (!holdPermission) return Future<bool?>.value(permission);
      final call = Completer<bool?>();
      permissionCalls.add(call);
      return call.future;
    },
    controllerFactory: (description) {
      final controller = _FakeController(description)
        ..zoomGate = zoomGate
        ..flashGate = flashGate;
      controllers.add(controller);
      return controller;
    },
    openTimeout: openTimeout,
  );

  /// Lets the open run up to the point where it waits for the plugin.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  setUp(() {
    controllers = [];
    permissionCalls = [];
    holdPermission = false;
    zoomGate = null;
    flashGate = null;
    permission = null;
  });

  test('a refused permission ends as permissionDenied', () async {
    final camera = service();
    unawaited(camera.start());
    await settle();
    controllers.single.deny();
    await settle();
    expect(camera.state.value.failure, CameraFailure.permissionDenied);
    expect(controllers, hasLength(1));
    await camera.dispose();
  });

  test('a restricted camera also ends as permissionDenied', () async {
    final camera = service();
    unawaited(camera.start());
    await settle();
    controllers.single.deny('CameraAccessRestricted');
    await settle();
    expect(camera.state.value.failure, CameraFailure.permissionDenied);
    await camera.dispose();
  });

  test('the denial that arrives while the dialog has the app paused does not '
      'ask again on resume', () async {
    permission = false;
    final camera = service();
    unawaited(camera.start());
    await settle();
    // The permission dialog covers the app.
    await camera.pause();
    controllers.single.deny();
    await settle();
    await camera.resume();
    await settle();
    expect(controllers, hasLength(1), reason: 'no second prompt');
    expect(camera.state.value.failure, CameraFailure.permissionDenied);
    await camera.dispose();
  });

  test(
    'a resume that comes before the denial does not ask again either',
    () async {
      permission = false;
      final camera = service();
      unawaited(camera.start());
      await settle();
      await camera.pause();
      await camera.resume();
      await settle();
      expect(camera.state.value.failure, CameraFailure.permissionDenied);
      // The answer of the dialog comes late and changes nothing.
      controllers.single.deny();
      await settle();
      expect(controllers, hasLength(1));
      expect(camera.state.value.failure, CameraFailure.permissionDenied);
      await camera.dispose();
    },
  );

  test('where the system cannot tell, a denial seen while paused is checked by '
      'one reopen, and the plugin answers', () async {
    permission = null;
    final camera = service();
    unawaited(camera.start());
    await settle();
    await camera.pause();
    controllers.single.deny();
    await settle();
    final resumed = camera.resume();
    await settle();
    expect(controllers, hasLength(2));
    controllers.last.deny();
    await resumed;
    expect(camera.state.value.failure, CameraFailure.permissionDenied);
    await camera.dispose();
  });

  test(
    'where the system cannot tell, granting in the settings recovers',
    () async {
      permission = null;
      final camera = service();
      unawaited(camera.start());
      await settle();
      controllers.single.deny();
      await settle();
      expect(camera.state.value.failure, CameraFailure.permissionDenied);
      // The user grants the permission in the Settings and comes back.
      await camera.pause();
      final resumed = camera.resume();
      await settle();
      expect(controllers, hasLength(2));
      controllers.last.grant();
      await resumed;
      expect(camera.state.value.ready, isTrue);
      expect(camera.state.value.failure, isNull);
      await camera.dispose();
    },
  );

  test('where the system cannot tell, outdated denials do not loop', () async {
    permission = null;
    final camera = service();
    unawaited(camera.start());
    await settle();
    await camera.pause();
    controllers.single.deny();
    await settle();
    // Every open is paused by the system again before it can answer.
    unawaited(camera.resume());
    await settle();
    expect(controllers, hasLength(2));
    await camera.pause();
    controllers.last.deny();
    await settle();
    await camera.resume();
    await settle();
    expect(controllers, hasLength(2), reason: 'no third open');
    expect(camera.state.value.failure, CameraFailure.permissionDenied);
    await camera.dispose();
  });

  test(
    'a late answer of an old resume does not close the new camera',
    () async {
      holdPermission = true;
      final camera = service();
      unawaited(camera.start());
      await settle();
      controllers.single.deny();
      await settle();
      await camera.pause();
      final resumed = camera.resume();
      await settle();
      expect(permissionCalls, hasLength(1));
      // Retry takes over while the system is still being asked.
      final retry = camera.start();
      await settle();
      controllers.last.grant();
      await retry;
      expect(camera.state.value.ready, isTrue);
      // The old answer arrives late.
      permissionCalls.single.complete(false);
      await resumed;
      await settle();
      expect(camera.state.value.ready, isTrue);
      expect(camera.state.value.failure, isNull);
      expect(controllers.last.released, isFalse);
      await camera.dispose();
    },
  );

  test('a pause while the system is asked cancels the resume', () async {
    holdPermission = true;
    final camera = service();
    unawaited(camera.start());
    await settle();
    controllers.single.deny();
    await settle();
    await camera.pause();
    final resumed = camera.resume();
    await settle();
    await camera.pause();
    permissionCalls.single.complete(true);
    await resumed;
    await settle();
    expect(controllers, hasLength(1), reason: 'nothing opened');
    expect(camera.state.value.ready, isFalse);
    await camera.dispose();
  });

  test('two overlapping resumes open the camera once', () async {
    holdPermission = true;
    final camera = service();
    unawaited(camera.start());
    await settle();
    controllers.single.deny();
    await settle();
    await camera.pause();
    final first = camera.resume();
    await settle();
    await camera.pause();
    final second = camera.resume();
    await settle();
    expect(permissionCalls, hasLength(2));
    permissionCalls.first.complete(true);
    permissionCalls.last.complete(true);
    await settle();
    expect(controllers, hasLength(2));
    controllers.last.grant();
    await Future.wait([first, second]);
    expect(camera.state.value.ready, isTrue);
    await camera.dispose();
  });

  test('a permanent denial stays on every later resume', () async {
    permission = false;
    final camera = service();
    unawaited(camera.start());
    await settle();
    controllers.single.deny();
    await settle();
    for (var i = 0; i < 3; i++) {
      await camera.pause();
      await camera.resume();
      await settle();
    }
    expect(controllers, hasLength(1));
    expect(camera.state.value.failure, CameraFailure.permissionDenied);
    await camera.dispose();
  });

  test('Retry asks again', () async {
    permission = false;
    final camera = service();
    unawaited(camera.start());
    await settle();
    controllers.single.deny();
    await settle();
    unawaited(camera.start());
    await settle();
    expect(controllers, hasLength(2));
    expect(camera.state.value.failure, isNull);
    controllers.last.deny();
    await settle();
    expect(camera.state.value.failure, CameraFailure.permissionDenied);
    await camera.dispose();
  });

  test('granting the permission in the settings brings the camera back on '
      'resume', () async {
    permission = false;
    final camera = service();
    unawaited(camera.start());
    await settle();
    controllers.single.deny();
    await settle();
    // The user goes to the settings of the app and grants it.
    await camera.pause();
    permission = true;
    final resumed = camera.resume();
    await settle();
    expect(controllers, hasLength(2));
    controllers.last.grant();
    await resumed;
    expect(camera.state.value.ready, isTrue);
    expect(camera.state.value.failure, isNull);
    await camera.dispose();
  });

  test(
    'a normal pause and resume with the permission granted reopens',
    () async {
      permission = true;
      final camera = service();
      unawaited(camera.start());
      await settle();
      controllers.single.grant();
      await settle();
      expect(camera.state.value.ready, isTrue);
      await camera.pause();
      expect(camera.state.value.ready, isFalse);
      final resumed = camera.resume();
      await settle();
      controllers.last.grant();
      await resumed;
      expect(controllers, hasLength(2));
      expect(camera.state.value.ready, isTrue);
      await camera.dispose();
    },
  );

  test('an open that never answers ends as unavailable', () async {
    final camera = service(openTimeout: const Duration(milliseconds: 50));
    unawaited(camera.start());
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(camera.state.value.failure, CameraFailure.unavailable);
    // If the plugin answers much later, the camera is released and the
    // failure stays.
    controllers.single.grant();
    await settle();
    expect(camera.state.value.failure, CameraFailure.unavailable);
    expect(controllers.single.released, isTrue);
    await camera.dispose();
  });

  test(
    'the wait for the permission dialog is not timed out while paused',
    () async {
      final camera = service(openTimeout: const Duration(milliseconds: 50));
      unawaited(camera.start());
      await settle();
      await camera.pause();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(camera.state.value.failure, isNull);
      await camera.dispose();
    },
  );

  test('a quick open is not cut by the timeout', () async {
    final camera = service(openTimeout: const Duration(milliseconds: 80));
    unawaited(camera.start());
    await settle();
    controllers.single.grant();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(camera.state.value.ready, isTrue);
    expect(camera.state.value.failure, isNull);
    await camera.dispose();
  });

  test('the timeout stays until the flash is set, and an outdated open is '
      'not published', () async {
    flashGate = Completer<void>();
    final camera = service(openTimeout: const Duration(milliseconds: 50));
    unawaited(camera.start());
    await settle();
    controllers.single.grant();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(camera.state.value.failure, CameraFailure.unavailable);
    expect(controllers.single.released, isTrue);
    flashGate!.complete();
    await settle();
    expect(camera.state.value.ready, isFalse);
    expect(camera.state.value.failure, CameraFailure.unavailable);
    await camera.dispose();
  });

  test(
    'an open that hangs after initialize is released by the timeout',
    () async {
      zoomGate = Completer<void>();
      final camera = service(openTimeout: const Duration(milliseconds: 50));
      unawaited(camera.start());
      await settle();
      controllers.single.grant();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(camera.state.value.failure, CameraFailure.unavailable);
      expect(controllers.single.released, isTrue);
      zoomGate!.complete();
      await settle();
      expect(camera.state.value.ready, isFalse);
      await camera.dispose();
    },
  );

  test('releasing the hung open leaves the next one alone', () async {
    zoomGate = Completer<void>();
    final camera = service(openTimeout: const Duration(milliseconds: 50));
    unawaited(camera.start());
    await settle();
    controllers.first.grant();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    zoomGate = null;
    unawaited(camera.start());
    await settle();
    controllers.last.grant();
    await settle();
    expect(camera.state.value.ready, isTrue);
    expect(controllers.last.released, isFalse);
    await camera.dispose();
  });

  test('a dispose releases an open that has not finished', () async {
    zoomGate = Completer<void>();
    final camera = service();
    unawaited(camera.start());
    await settle();
    controllers.single.grant();
    await settle();
    await camera.dispose();
    expect(controllers.single.released, isTrue);
  });

  test('the timeout after a dispose does nothing', () async {
    final camera = service(openTimeout: const Duration(milliseconds: 50));
    unawaited(camera.start());
    await settle();
    await camera.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(controllers.single.released, isTrue);
  });

  test('a new open waits for the close in flight', () async {
    final camera = service();
    unawaited(camera.start());
    await settle();
    controllers.single.grant();
    await settle();
    controllers.single.disposeGate = Completer<void>();
    final retry = camera.start();
    await settle();
    expect(
      controllers,
      hasLength(1),
      reason: 'the old camera is still closing',
    );
    controllers.single.disposeGate!.complete();
    await settle();
    expect(controllers, hasLength(2));
    controllers.last.grant();
    await retry;
    expect(camera.state.value.ready, isTrue);
    await camera.dispose();
  });

  test('a resume waits for the close of the pause', () async {
    permission = true;
    final camera = service();
    unawaited(camera.start());
    await settle();
    controllers.single.grant();
    await settle();
    controllers.single.disposeGate = Completer<void>();
    final paused = camera.pause();
    final resumed = camera.resume();
    await settle();
    expect(controllers, hasLength(1));
    controllers.single.disposeGate!.complete();
    await settle();
    expect(controllers, hasLength(2));
    controllers.last.grant();
    await Future.wait([paused, resumed]);
    // The old pause does not publish "not ready" over the recovery.
    expect(camera.state.value.ready, isTrue);
    await camera.dispose();
  });

  test('a close that never ends does not leave the screen black', () async {
    final camera = service(openTimeout: const Duration(milliseconds: 50));
    unawaited(camera.start());
    await settle();
    // The first open is blocked in initialize and its close never ends.
    controllers.single.disposeGate = Completer<void>();
    unawaited(camera.switchLens());
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(camera.state.value.failure, CameraFailure.unavailable);
    await camera.dispose();
  });
}
