import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:film_recipes/film_recipes.dart';
import 'package:flutter/foundation.dart';

import '../camera/camera_flash.dart';
import '../core/database/tables.dart' show ShotLens;
import '../core/settings/film_tuning.dart';
import '../location/photo_location.dart';

import 'error_log.dart';

/// Everything needed to turn the JPEG the camera wrote into the finished photo.
/// It is a snapshot taken when the shutter was pressed: later changes of the
/// film, the format, the flash or the settings do not touch a photo already in
/// the queue.
@immutable
class CaptureJob {
  const CaptureJob({
    required this.filePath,
    required this.filmId,
    required this.look,
    required this.format,
    required this.seed,
    required this.takenAt,
    DateTime? shutterInstant,
    bool hasShutterInstant = true,
    this.tuning = FilmTuning.defaults,
    this.flash = CarreteFlash.off,
    this.fieldAspect,
    this.stampText,
    this.whiteFrame = false,
    this.cinemaBands = false,
    this.includeLocation = false,
    this.location,
    this.saveOriginal = false,
    this.retried = false,
    this.displayName,
    this.lens = ShotLens.back,
    this.captureId,
  }) : shutterInstant = hasShutterInstant ? (shutterInstant ?? takenAt) : null;

  /// The JPEG written by the camera, in the cache of the app.
  final String filePath;

  /// The film of the shot.
  final String filmId;

  /// The look, with the tuning of the user and the flash already applied. The
  /// same values the viewfinder was showing.
  final ResolvedLook look;

  /// The tuning of the film at the shutter: with [flash] and [filmId] it
  /// rebuilds [look] when a failed shot is retried after a restart.
  final FilmTuning tuning;

  /// The flash mode at the shutter.
  final CarreteFlash flash;

  /// The frame format the photo is cropped to.
  final FrameFormat format;

  /// The grain seed of the shot: fixed, so the photo does not change if it is
  /// processed again.
  final double seed;

  /// When the shutter was pressed.
  final DateTime takenAt;

  /// The unambiguous shutter instant used to validate GPS age at export.
  /// Keep [takenAt]'s original calendar fields for names and recovery sorting.
  /// Null for legacy snapshots that only retain local calendar fields.
  final DateTime? shutterInstant;

  /// Width divided by height (portrait) of the preview that was on screen, to
  /// keep the same field of view. Null when it is not known.
  final double? fieldAspect;

  /// The date imprint to burn into the photo, or null for none.
  final String? stampText;

  /// Whether the instant white border goes around the photo (only applies to
  /// the 1:1 format).
  final bool whiteFrame;

  /// Whether cinema bands are burned in (16:9 only).
  final bool cinemaBands;

  /// Whether this export may contain GPS. Camera shots require both opt-in
  /// and a usable shutter fix; imports copy source GPS when opted in.
  /// Off by default: every GPS tag is stripped.
  final bool includeLocation;

  /// The valid fix at the shutter, never a position obtained at development.
  /// Null for imports, whose source GPS follows includeLocation instead.
  final PhotoLocation? location;

  /// Whether the untouched camera original is also saved, next to the
  /// developed photo (the "also save the original" setting at the shutter).
  /// For a roll frame it happens when the roll develops, never before.
  final bool saveOriginal;

  /// Whether this job is a retry of a shot that failed to save in an earlier
  /// run. It was counted on the viewfinder then, not now.
  final bool retried;

  /// Stable export identity for a roll frame; loose shots use their date.
  final String? displayName;

  /// The lens that took the photo (kept in the gallery record of the shot).
  final ShotLens lens;

  /// The identity of this shot, made when the shutter was pressed and kept
  /// through every retry. It names the exported file and tells the gallery
  /// record of a shot from that of another one taken at the same moment. Null
  /// for shots that did not get one (roll frames, sidecars of old versions).
  final String? captureId;

  /// The same job with another frame: the look, format, tuning and white
  /// border are replaced, everything else is kept.
  CaptureJob withFrame({
    required ResolvedLook look,
    required FrameFormat format,
    required FilmTuning tuning,
    required bool whiteFrame,
  }) => CaptureJob(
    filePath: filePath,
    filmId: filmId,
    look: look,
    format: format,
    seed: seed,
    takenAt: takenAt,
    shutterInstant: shutterInstant,
    hasShutterInstant: shutterInstant != null,
    tuning: tuning,
    flash: flash,
    fieldAspect: fieldAspect,
    stampText: stampText,
    whiteFrame: whiteFrame,
    cinemaBands: look.cinemaBands && format == FrameFormat.r16x9,
    includeLocation: includeLocation,
    location: location,
    saveOriginal: saveOriginal,
    retried: retried,
    displayName: displayName,
    lens: lens,
    captureId: captureId,
  );

  /// The same job, reading the camera original from [filePath].
  CaptureJob withFile(
    String filePath, {
    bool? retried,
    String? displayName,
    bool? saveOriginal,
  }) => CaptureJob(
    filePath: filePath,
    filmId: filmId,
    look: look,
    format: format,
    seed: seed,
    takenAt: takenAt,
    shutterInstant: shutterInstant,
    hasShutterInstant: shutterInstant != null,
    tuning: tuning,
    flash: flash,
    fieldAspect: fieldAspect,
    stampText: stampText,
    whiteFrame: whiteFrame,
    cinemaBands: cinemaBands,
    includeLocation: includeLocation,
    location: location,
    saveOriginal: saveOriginal ?? this.saveOriginal,
    retried: retried ?? this.retried,
    displayName: displayName ?? this.displayName,
    lens: lens,
    captureId: captureId,
  );
}

/// The name of the file at [path], without its folder.
String fileNameOf(String path) {
  final slash = path.lastIndexOf(RegExp(r'[\\/]'));
  return slash < 0 ? path : path.substring(slash + 1);
}

/// A new identity for a shot (see [CaptureJob.captureId]): 40 random bits in
/// hexadecimal.
String newCaptureId([Random? random]) {
  final source = random ?? Random.secure();
  final bits = (source.nextInt(1 << 20) << 20) | source.nextInt(1 << 20);
  return bits.toRadixString(16).padLeft(10, '0');
}

/// What happened to one job.
@immutable
class CaptureEvent {
  const CaptureEvent.saved(this.job, this.uri) : error = null;
  const CaptureEvent.failed(this.job, this.error) : uri = null;

  /// The job.
  final CaptureJob job;

  /// Where the photo was saved, for a job that worked.
  final String? uri;

  /// What went wrong, for a job that failed.
  final Object? error;

  /// Whether the photo was saved.
  bool get ok => error == null;
}

/// Turns a job into a saved photo.
abstract interface class CaptureProcessor {
  /// Processes [job] and returns where the photo was saved.
  Future<String?> process(CaptureJob job);
}

/// The line of photos waiting to be developed. The shutter never waits for
/// it: [enqueue] returns at once.
abstract interface class CaptureQueue {
  /// Adds [job] to the line.
  void enqueue(CaptureJob job);

  /// How many jobs are waiting or being processed.
  ValueListenable<int> get pending;

  /// Whether a job whose camera original is called like [filePath] (the file
  /// name, wherever it lives) is waiting or being processed. A shot moves to
  /// `<cache>/failed/` as soon as it is processed, so a job is told apart by
  /// the name of its file, never by the folder.
  bool holds(String filePath);

  /// One event for every job, when it finishes.
  Stream<CaptureEvent> get events;
}

/// A queue that processes one job at a time, in order. A shot can be queued
/// while another one is being processed.
class SequentialCaptureQueue implements CaptureQueue {
  SequentialCaptureQueue(this._processor);

  final CaptureProcessor _processor;
  final Queue<CaptureJob> _waiting = Queue<CaptureJob>();
  final List<String> _names = <String>[];
  final ValueNotifier<int> _pending = ValueNotifier<int>(0);
  final StreamController<CaptureEvent> _events =
      StreamController<CaptureEvent>.broadcast();
  bool _running = false;
  bool _disposed = false;

  @override
  ValueListenable<int> get pending => _pending;

  @override
  Stream<CaptureEvent> get events => _events.stream;

  @override
  bool holds(String filePath) => _names.contains(fileNameOf(filePath));

  @override
  void enqueue(CaptureJob job) {
    if (_disposed) return;
    _names.add(fileNameOf(job.filePath));
    _waiting.add(job);
    _pending.value++;
    if (!_running) unawaited(_drain());
  }

  Future<void> _drain() async {
    _running = true;
    try {
      while (_waiting.isNotEmpty) {
        final job = _waiting.removeFirst();
        CaptureEvent event;
        try {
          event = CaptureEvent.saved(job, await _processor.process(job));
        } on Object catch (error) {
          if (kDebugMode) {
            debugPrint('Capture failed: ${errorLogToken(error)}');
          }
          event = CaptureEvent.failed(job, error);
        }
        if (_disposed) return;
        _names.remove(fileNameOf(job.filePath));
        _pending.value--;
        _events.add(event);
      }
    } finally {
      _running = false;
    }
  }

  /// Stops reporting. A job in progress finishes without a report.
  void dispose() {
    _disposed = true;
    _waiting.clear();
    _names.clear();
    unawaited(_events.close());
    _pending.dispose();
  }
}
