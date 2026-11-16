import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'camera_flash.dart';

/// Which camera of the device is in use.
enum CameraLens {
  /// The main camera, on the back.
  back,

  /// The selfie camera, on the front.
  front;

  /// The other lens.
  CameraLens get other => this == back ? front : back;
}

/// Why the camera cannot be used.
enum CameraFailure {
  /// The user refused the camera permission.
  permissionDenied,

  /// The device has no camera, or it could not be opened.
  unavailable,
}

/// What the screens need to know about the camera.
@immutable
class CameraServiceState {
  const CameraServiceState({
    this.ready = false,
    this.lens = CameraLens.back,
    this.previewSize,
    this.zoom = 1,
    this.minZoom = 1,
    this.maxZoom = 1,
    this.failure,
  });

  /// Whether the preview is running.
  final bool ready;

  /// The lens in use.
  final CameraLens lens;

  /// The size of the preview in portrait (width smaller than height), or null
  /// until it is running.
  final Size? previewSize;

  /// The current zoom, 1 meaning no zoom.
  final double zoom;

  /// The smallest zoom the screen allows.
  final double minZoom;

  /// The biggest zoom the screen allows (never above [kMaxZoom]).
  final double maxZoom;

  /// Why the camera is not available, when it is not.
  final CameraFailure? failure;

  /// Width divided by height of the preview in portrait, or null.
  double? get previewAspect {
    final size = previewSize;
    if (size == null || size.height == 0) return null;
    return size.width / size.height;
  }

  /// The same state with the given fields changed.
  CameraServiceState copyWith({
    bool? ready,
    CameraLens? lens,
    Size? previewSize,
    double? zoom,
    double? minZoom,
    double? maxZoom,
    CameraFailure? failure,
    bool clearFailure = false,
    bool clearPreviewSize = false,
  }) => CameraServiceState(
    ready: ready ?? this.ready,
    lens: lens ?? this.lens,
    previewSize: clearPreviewSize ? null : (previewSize ?? this.previewSize),
    zoom: zoom ?? this.zoom,
    minZoom: minZoom ?? this.minZoom,
    maxZoom: maxZoom ?? this.maxZoom,
    failure: clearFailure ? null : (failure ?? this.failure),
  );

  @override
  bool operator ==(Object other) =>
      other is CameraServiceState &&
      other.ready == ready &&
      other.lens == lens &&
      other.previewSize == previewSize &&
      other.zoom == zoom &&
      other.minZoom == minZoom &&
      other.maxZoom == maxZoom &&
      other.failure == failure;

  @override
  int get hashCode =>
      Object.hash(ready, lens, previewSize, zoom, minZoom, maxZoom, failure);
}

/// The most the pinch zoom goes to, whatever the device allows.
const double kMaxZoom = 2;

/// The zoom range the screen offers on a device that allows [deviceMin] to
/// [deviceMax]: 1x to 2x, narrowed to what the device can do.
(double, double) zoomRange(double deviceMin, double deviceMax) {
  final low = deviceMin > 1 ? deviceMin : 1.0;
  var high = deviceMax < kMaxZoom ? deviceMax : kMaxZoom;
  if (high < low) high = low;
  return (low, high);
}

/// A photo the camera has just taken, still in the cache of the app.
class CapturedPhoto {
  const CapturedPhoto({required this.path});

  /// The JPEG file, at the full resolution of the sensor.
  final String path;
}

/// The camera, as the viewfinder uses it.
///
/// The interface exists so the widget tests can run with a fake and so the
/// `camera` plugin stays in one place ([PluginCameraService]).
abstract interface class CameraService {
  /// The state of the camera. Notifies on every change.
  ValueListenable<CameraServiceState> get state;

  /// Opens the camera on [lens]. Safe to call again; it reopens.
  Future<void> start({CameraLens lens = CameraLens.back});

  /// Releases the camera while the app is in the background, remembering the
  /// lens and the flash.
  Future<void> pause();

  /// Opens the camera again after [pause].
  Future<void> resume();

  /// Switches between the back and the front camera.
  Future<void> switchLens();

  /// Sets the flash for the next photo.
  Future<void> setFlash(CarreteFlash flash);

  /// Sets the zoom, clamped to the range of the screen and of the device.
  Future<void> setZoom(double zoom);

  /// Focuses and meters the exposure on [point] (0..1 over the preview, in
  /// portrait) and locks both. A null point returns to automatic.
  Future<void> focusAt(Offset? point);

  /// Takes a photo. Returns as soon as the file is written; the processing
  /// happens elsewhere.
  Future<CapturedPhoto> takePicture();

  /// The raw preview (no film look), which expands to fill its parent. Lay it
  /// out at the portrait size of [CameraServiceState.previewSize]. It can be
  /// built several times at once: the viewfinder and every film thumbnail show
  /// the same camera texture.
  Widget buildPreview(BuildContext context);

  /// Releases everything.
  Future<void> dispose();
}
