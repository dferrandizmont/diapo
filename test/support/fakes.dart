import 'dart:async';

import 'package:carrete/camera/camera_flash.dart';
import 'package:carrete/camera/camera_service.dart';
import 'package:carrete/camera/level_tilt.dart';
import 'package:carrete/capture/capture_queue.dart';
import 'package:carrete/platform/camera_sounds.dart';
import 'package:carrete/platform/haptics.dart';
import 'package:carrete/platform/system_settings.dart';
import 'package:film_recipes/film_recipes.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The system settings of the device, counting how many times they are opened.
class FakeSystemSettings implements SystemSettings {
  FakeSystemSettings({this.available = true});

  /// What [canOpen] answers.
  final bool available;

  /// How many times [open] was called.
  int opened = 0;

  @override
  bool get canOpen => available;

  @override
  Future<bool> open() async {
    opened++;
    return true;
  }

  @override
  Future<bool?> cameraPermissionGranted() async => null;
}

/// The camera sounds, counting the shots that asked for them.
class FakeCameraSounds implements CameraSounds {
  /// How many times [playShot] was called.
  int shots = 0;

  /// How many times [preload] was called.
  int preloads = 0;

  @override
  Duration get advanceDelay => Duration.zero;

  @override
  Future<void> preload() async => preloads++;

  @override
  Future<void> playShot() async => shots++;

  /// The names of the roll-handling sounds played, in order.
  final List<String> effects = <String>[];

  @override
  bool Function()? get soundsEnabled => null;

  @override
  Future<void> playCartridge() async => effects.add('cartridge');

  @override
  Future<void> playLoad() async => effects.add('load');

  @override
  Future<void> playRewind() async => effects.add('rewind');

  @override
  Future<RingerMode?> ringerMode() async => RingerMode.normal;

  @override
  void dispose() {}
}

/// The haptics of the camera, written down instead of played.
class FakeHaptics implements Haptics {
  /// What was played, in order: `selection`, `medium` or `light`.
  final List<String> events = <String>[];

  @override
  bool Function() get enabled =>
      () => true;

  @override
  Future<RingerMode?> Function() get ringerMode =>
      () async => RingerMode.normal;

  @override
  Future<void> selectionClick() async => events.add('selection');

  @override
  Future<void> mediumImpact() async => events.add('medium');

  @override
  Future<void> lightImpact() async => events.add('light');
}

/// A level that shows the tilts a test pushes into it.
class FakeLevelSource implements LevelSource {
  final StreamController<LevelTilt?> controller =
      StreamController<LevelTilt?>.broadcast(sync: true);

  /// Whether someone is listening.
  bool get listening => controller.hasListener;

  @override
  Stream<LevelTilt?> get tilts => controller.stream;
}

/// A camera that records what it is asked and shows a flat colour.
class FakeCameraService implements CameraService {
  FakeCameraService({
    CameraServiceState state = const CameraServiceState(
      ready: true,
      previewSize: Size(1080, 1920),
      maxZoom: 2,
    ),
  }) : _state = ValueNotifier<CameraServiceState>(state);

  final ValueNotifier<CameraServiceState> _state;
  final List<CarreteFlash> flashes = <CarreteFlash>[];
  final List<Offset?> focusPoints = <Offset?>[];
  int started = 0;
  int paused = 0;
  int resumed = 0;
  int pictures = 0;
  int lensSwitches = 0;

  @override
  ValueListenable<CameraServiceState> get state => _state;

  @override
  Future<void> start({CameraLens lens = CameraLens.back}) async {
    started++;
  }

  @override
  Future<void> pause() async {
    paused++;
  }

  @override
  Future<void> resume() async {
    resumed++;
  }

  @override
  Future<void> switchLens() async {
    lensSwitches++;
    _state.value = _state.value.copyWith(lens: _state.value.lens.other);
  }

  @override
  Future<void> setFlash(CarreteFlash flash) async {
    flashes.add(flash);
  }

  @override
  Future<void> setZoom(double zoom) async {
    _state.value = _state.value.copyWith(zoom: zoom);
  }

  @override
  Future<void> focusAt(Offset? point) async {
    focusPoints.add(point);
  }

  @override
  Future<CapturedPhoto> takePicture() async {
    pictures++;
    return CapturedPhoto(path: 'photo_$pictures.jpg');
  }

  @override
  Widget buildPreview(BuildContext context) =>
      const ColoredBox(color: Color(0xFF336699));

  @override
  Future<void> dispose() async {}
}

/// A queue that only keeps the jobs it is given.
class FakeCaptureQueue implements CaptureQueue {
  final List<CaptureJob> jobs = <CaptureJob>[];
  final ValueNotifier<int> _pending = ValueNotifier<int>(0);
  final StreamController<CaptureEvent> _events =
      StreamController<CaptureEvent>.broadcast();

  @override
  void enqueue(CaptureJob job) => jobs.add(job);

  @override
  bool holds(String filePath) {
    final name = fileNameOf(filePath);
    return jobs.any((job) => fileNameOf(job.filePath) == name);
  }

  @override
  ValueListenable<int> get pending => _pending;

  /// Sets how many jobs the queue says are waiting or being processed.
  set pendingCount(int value) => _pending.value = value;

  @override
  Stream<CaptureEvent> get events => _events.stream;

  /// Says that [job] was saved, as the queue does when it is done with it. An
  /// explicit [uri] stands for where the photo landed in the gallery.
  void saved(CaptureJob job, [String? uri = 'content://saved']) =>
      _events.add(CaptureEvent.saved(job, uri));

  /// Says that [job] could not be saved, with [error] as the reason.
  void failed(CaptureJob job, [Object? error]) =>
      _events.add(CaptureEvent.failed(job, error ?? StateError('save failed')));
}

LocalizedText _named(String en) =>
    LocalizedText(es: '$en es', ca: '$en ca', en: en);

/// Three films for the widget tests: two plain ones and one square instant
/// film with the date imprint and the white frame on.
RecipeBook testBook() => RecipeBook(
  schemaVersion: 1,
  recipesVersion: '2026.11.1',
  recipes: [
    Recipe(
      id: 'alpha',
      name: _named('Alpha'),
      description: _named('First film'),
      exposure: 0.1,
      halation: const HalationSettings(amount: 0.4),
    ),
    Recipe(
      id: 'beta',
      name: _named('Beta'),
      description: _named('Second film'),
      kind: FilmKind.bw,
      defaults: const RecipeDefaults(format: FrameFormat.r4x3),
    ),
    Recipe(
      id: 'gamma',
      name: _named('Gamma'),
      description: _named('Third film'),
      defaults: const RecipeDefaults(
        format: FrameFormat.r1x1,
        dateStamp: true,
        whiteFrame: true,
      ),
    ),
  ],
);
