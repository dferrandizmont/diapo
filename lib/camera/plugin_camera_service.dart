import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../platform/system_settings.dart';
import 'camera_flash.dart';
import 'camera_service.dart';

/// The [CameraService] that talks to the `camera` plugin.
///
/// The preview uses [ResolutionPreset.max]: the preview comes out at about
/// 1080p and the stills at the full resolution of the sensor.
class PluginCameraService implements CameraService {
  /// [permissionGranted], [controllerFactory] and [openTimeout] exist for the
  /// tests; the defaults are what the app uses.
  PluginCameraService({
    Future<List<CameraDescription>> Function()? listCameras,
    Future<bool?> Function()? permissionGranted,
    CameraController Function(CameraDescription description)? controllerFactory,
    this.openTimeout = const Duration(seconds: 20),
  }) : _listCameras = listCameras ?? availableCameras,
       _permissionGranted =
           permissionGranted ?? const SystemSettings().cameraPermissionGranted,
       _controllerFactory = controllerFactory ?? _defaultController;

  static CameraController _defaultController(CameraDescription description) =>
      CameraController(
        description,
        ResolutionPreset.max,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

  /// How long an open may take, with the app in the foreground, before it
  /// ends as a failure instead of leaving the screen black. The permission
  /// dialog does not count: the app is paused while it is shown.
  final Duration openTimeout;

  final Future<List<CameraDescription>> Function() _listCameras;

  /// Whether the system says the camera permission is granted; null when it
  /// cannot tell (not Android).
  final Future<bool?> Function() _permissionGranted;
  final CameraController Function(CameraDescription description)
  _controllerFactory;
  final ValueNotifier<CameraServiceState> _state =
      ValueNotifier<CameraServiceState>(const CameraServiceState());

  CameraController? _controller;
  CameraLens _lens = CameraLens.back;
  CarreteFlash _flash = CarreteFlash.off;
  bool _paused = false;
  bool _disposed = false;
  Timer? _watchdog;

  /// Whether the last open ended because the permission was refused, even if
  /// the answer came when nothing was waiting for it any more (the permission
  /// dialog pauses the app, and a pause makes the open outdated).
  bool _lastOpenDenied = false;

  /// Set when a resume reopened the camera although the system could not say
  /// whether the permission is granted (iOS); cleared when that open ends.
  /// Stops a reopen after every resume if each open pauses the app again.
  bool _unverifiedReopen = false;

  /// The controller of an open that has not finished: it is not yet
  /// [_controller], but it holds the camera and must be released on a pause,
  /// a timeout or a dispose.
  CameraController? _pending;

  /// Bumped on every open so a slow, outdated open can tell it was replaced.
  int _generation = 0;

  @override
  ValueListenable<CameraServiceState> get state => _state;

  @override
  Future<void> start({CameraLens lens = CameraLens.back}) {
    _lens = lens;
    _paused = false;
    _unverifiedReopen = false;
    return _open();
  }

  @override
  Future<void> pause() async {
    if (_paused) return;
    _paused = true;
    final generation = ++_generation;
    _watchdog?.cancel();
    await _release();
    // A newer operation (resume, Retry) may have published meanwhile.
    if (_isStale(generation)) return;
    _emit(_state.value.copyWith(ready: false));
  }

  @override
  Future<void> resume() async {
    if (!_paused) return;
    _paused = false;
    // The permission dialog pauses the app, and the app is resumed when it is
    // answered. Opening again here would ask a second time at once (and a
    // refused permission that cannot be asked any more flickers the system
    // dialog and pauses the app again, for ever). So: when the permission is
    // not granted, say so and wait for the user to press Retry.
    //
    // Where the system cannot tell (iOS), a denial seen before is not proof:
    // the user may have granted it in the Settings. The camera is opened once
    // and the plugin answers (it does not show a dialog again there).
    //
    // The generation makes a slow answer harmless: a pause, a Retry or
    // another resume while the system is asked outdates this one.
    final generation = ++_generation;
    final granted = await _permissionGranted();
    if (_isStale(generation) || _paused) return;
    final blocked =
        granted == false ||
        (granted == null && _lastOpenDenied && _unverifiedReopen);
    if (blocked) {
      _watchdog?.cancel();
      await _release();
      if (_isStale(generation) || _paused) return;
      _unverifiedReopen = false;
      _fail(CameraFailure.permissionDenied);
      return;
    }
    if (granted == null && _lastOpenDenied) _unverifiedReopen = true;
    return _open();
  }

  @override
  Future<void> switchLens() {
    _lens = _lens.other;
    return _open();
  }

  @override
  Future<void> setFlash(CarreteFlash flash) async {
    _flash = flash;
    await _applyFlash();
  }

  @override
  Future<void> setZoom(double zoom) async {
    final current = _state.value;
    final value = zoom.clamp(current.minZoom, current.maxZoom);
    if (value == current.zoom) return;
    _emit(current.copyWith(zoom: value));
    try {
      await _controller?.setZoomLevel(value);
    } on CameraException catch (e) {
      if (kDebugMode) debugPrint('setZoomLevel failed: ${e.code}');
    }
  }

  @override
  Future<void> focusAt(Offset? point) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      if (point == null) {
        await controller.setFocusMode(FocusMode.auto);
        await controller.setExposureMode(ExposureMode.auto);
        await controller.setFocusPoint(null);
        await controller.setExposurePoint(null);
        return;
      }
      await controller.setExposurePoint(point);
      await controller.setFocusPoint(point);
      await controller.setFocusMode(FocusMode.locked);
      await controller.setExposureMode(ExposureMode.locked);
    } on CameraException catch (e) {
      // Some lenses (the front one, often) cannot focus: the lock indicator
      // still shows, the photo is simply taken with the automatic focus.
      if (kDebugMode) debugPrint('focusAt failed: ${e.code}');
    }
  }

  @override
  Future<CapturedPhoto> takePicture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      throw StateError('The camera is not ready.');
    }
    await _applyFlash();
    final file = await controller.takePicture();
    return CapturedPhoto(path: file.path);
  }

  @override
  Widget buildPreview(BuildContext context) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return CameraPreview(controller);
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _generation++;
    _watchdog?.cancel();
    await _release();
    _state.dispose();
  }

  /// How many times an open that failed as unavailable is retried. Right
  /// after the permission dialog the previous controller may still be
  /// releasing the camera, and the system answers "in use" (seen on a
  /// OnePlus 8T, 2026-11-13).
  static const int _openRetries = 2;

  Future<void> _open({int attempt = 0}) async {
    final generation = ++_generation;
    // Started before the release: a close that never ends (a blocked
    // initialize that is being closed) must not leave the screen black.
    _startWatchdog(generation);
    await _release();
    if (_isStale(generation)) return;
    // Back to a blank state while it opens (the old failure is cleared).
    _emit(CameraServiceState(lens: _lens));

    CameraController? controller;
    try {
      final cameras = await _listCameras();
      if (_isStale(generation)) return;
      final wanted = _lens == CameraLens.back
          ? CameraLensDirection.back
          : CameraLensDirection.front;
      final description = cameras.where((c) => c.lensDirection == wanted);
      if (cameras.isEmpty) {
        _fail(CameraFailure.unavailable);
        return;
      }
      // A device without the wanted lens falls back to the first camera.
      controller = _controllerFactory(
        description.isEmpty ? cameras.first : description.first,
      );
      _pending = controller;
      await controller.initialize();
      if (_isStale(generation)) {
        _dropPending(controller);
        await controller.dispose();
        return;
      }
      await _safely(
        () => controller!.lockCaptureOrientation(DeviceOrientation.portraitUp),
      );
      final deviceMin = await controller.getMinZoomLevel();
      final deviceMax = await controller.getMaxZoomLevel();
      final (minZoom, maxZoom) = zoomRange(deviceMin, deviceMax);
      await _safely(() => controller!.setZoomLevel(minZoom));
      if (_isStale(generation)) {
        _dropPending(controller);
        await controller.dispose();
        return;
      }
      _pending = null;
      _controller = controller;
      await _applyFlash();
      if (_isStale(generation)) {
        // Outdated while the flash was set (or timed out): not published.
        if (identical(_controller, controller)) _controller = null;
        await controller.dispose();
        return;
      }
      _lastOpenDenied = false;
      _unverifiedReopen = false;
      _watchdog?.cancel();
      final raw = controller.value.previewSize;
      _emit(
        CameraServiceState(
          ready: true,
          lens: _lens,
          // The plugin reports the preview in the orientation of the sensor
          // (landscape): the screen is portrait.
          previewSize: raw == null
              ? null
              : Size(
                  raw.width < raw.height ? raw.width : raw.height,
                  raw.width < raw.height ? raw.height : raw.width,
                ),
          zoom: minZoom,
          minZoom: minZoom,
          maxZoom: maxZoom,
        ),
      );
    } on CameraException catch (e) {
      _dropPending(controller);
      await _safely(() async => controller?.dispose());
      final denied =
          e.code.startsWith('CameraAccessDenied') ||
          e.code == 'CameraAccessRestricted';
      // Remembered even when the open is outdated: the answer of the dialog
      // usually comes after the pause that the dialog caused.
      if (denied && !_disposed) _lastOpenDenied = true;
      if (_isStale(generation)) return;
      if (!denied && await _retryOpen(generation, attempt)) return;
      _fail(
        denied ? CameraFailure.permissionDenied : CameraFailure.unavailable,
      );
    } on Object catch (e) {
      if (kDebugMode) debugPrint('The camera could not be opened: $e');
      _dropPending(controller);
      await _safely(() async => controller?.dispose());
      if (_isStale(generation)) return;
      if (await _retryOpen(generation, attempt)) return;
      _fail(CameraFailure.unavailable);
    }
  }

  /// Opens again after a short wait when [attempt] still has retries left
  /// and nothing newer (pause, lens switch, dispose) happened meanwhile.
  /// Returns whether a retry took over.
  Future<bool> _retryOpen(int generation, int attempt) async {
    if (attempt >= _openRetries || _paused) return false;
    await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
    if (_isStale(generation) || _paused) return true;
    await _open(attempt: attempt + 1);
    return true;
  }

  /// Ends an open that takes too long as a failure. The timer is cancelled by
  /// every way out of the open and while the app is paused.
  void _startWatchdog(int generation) {
    _watchdog?.cancel();
    _watchdog = Timer(openTimeout, () {
      if (_isStale(generation) || _paused) return;
      // Outdates the open that hangs: if it ever answers, it is released.
      _generation++;
      unawaited(_release());
      _fail(CameraFailure.unavailable);
    });
  }

  bool _isStale(int generation) => _disposed || generation != _generation;

  /// Forgets [controller] as the pending one, when it still is.
  void _dropPending(CameraController? controller) {
    if (controller != null && identical(_pending, controller)) _pending = null;
  }

  void _fail(CameraFailure failure) {
    _watchdog?.cancel();
    _unverifiedReopen = false;
    _emit(CameraServiceState(lens: _lens, failure: failure));
  }

  /// The close in flight. The real controller waits for its `initialize()`
  /// before it closes, and CameraX unbinds every use case on close: a new
  /// camera must not be bound before the old one has finished closing.
  Future<void> _releasing = Future<void>.value();

  /// Closes the controllers in use, after the closes already in flight, and
  /// completes when they are done. Whoever opens awaits it.
  Future<void> _release() {
    final controller = _controller;
    final pending = _pending;
    _controller = null;
    _pending = null;
    final before = _releasing;
    Future<void> close() async {
      // Bounded: a close that never ends must not block every later open.
      try {
        await before.timeout(openTimeout);
      } on TimeoutException {
        if (kDebugMode) debugPrint('A camera close is taking too long.');
      }
      if (controller != null) {
        await _safely(controller.dispose);
      }
      if (pending != null && !identical(pending, controller)) {
        await _safely(pending.dispose);
      }
    }

    return _releasing = close();
  }

  Future<void> _applyFlash() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final mode = switch (_flash) {
      CarreteFlash.off => FlashMode.off,
      CarreteFlash.auto => FlashMode.auto,
      CarreteFlash.on || CarreteFlash.party => FlashMode.always,
    };
    // The front camera has no flash on most phones: the call may fail.
    await _safely(() => controller.setFlashMode(mode));
  }

  Future<void> _safely(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (e) {
      if (kDebugMode) debugPrint('Camera call failed: $e');
    }
  }

  void _emit(CameraServiceState next) {
    if (_disposed) return;
    _state.value = next;
  }
}
