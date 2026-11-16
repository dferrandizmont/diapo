import 'dart:io';
import 'dart:ui' as ui;

import 'package:film_recipes/film_recipes.dart' show FrameFormat;
import 'package:flutter/foundation.dart';

import '../location/photo_location.dart';
import '../platform/media_store.dart';
import '../render/look_adjust.dart';
import 'capture_queue.dart';
import 'error_log.dart';
import 'failed_shots.dart';
import 'film_still_renderer.dart';
import 'still_bounds.dart';

/// A still that was saved in the gallery: where, and how big.
class SavedStill {
  const SavedStill(this.uri, {this.width, this.height});

  /// The place of the photo in the gallery of the system.
  final String uri;
  final int? width;
  final int? height;
}

/// The real [CaptureProcessor]: reads the JPEG of the camera, develops it
/// with the film shader at full resolution and saves it in the gallery.
///
/// With [failedShots] a shot is made durable before anything else: its camera
/// original moves to `<cache>/failed/` with a sidecar of its job. The original
/// and the sidecar go only when the photo is in the gallery **and** [onSaved]
/// has recorded it; whatever stops before that (an error, the process dying)
/// leaves them there, and the retry on the next start finds the photo already
/// saved (see [findSaved]) and only records it, instead of saving it twice.
class FilmCaptureProcessor implements CaptureProcessor {
  FilmCaptureProcessor({
    required this.loadProgram,
    this.failedShots,
    this.onSaved,
    this.findSaved,
    this.findSavedOriginal = MediaStore.findSavedOriginal,
    this.saveOriginal = _saveOriginalNative,
    @visibleForTesting this.save,
  });

  /// Gives the compiled film shader. Called for every job: the result is
  /// cached by whoever provides it.
  final Future<ui.FragmentProgram> Function() loadProgram;

  /// Where the shots wait until they are recorded. Null makes nothing durable
  /// (the original stays where the camera wrote it until the save works).
  final FailedShots? failedShots;

  /// Called once the photo is in the gallery, with its location and size. The
  /// shot counts as recorded when this completes; if it throws, the photo
  /// stays saved but the original and the sidecar are kept, so the next start
  /// records it.
  final Future<void> Function(CaptureJob job, SavedStill still)? onSaved;

  /// Finds a photo with the export name [name] already in the gallery. When it
  /// is there the shot is not rendered and saved again.
  final Future<String?> Function(String name)? findSaved;

  /// Finds the original of a shot already saved under [name] (the
  /// `_original` name). The real thing by default.
  final Future<String?> Function(String name) findSavedOriginal;

  /// Saves the camera JPEG at `sourcePath` as the original [name]. The real
  /// thing by default.
  final Future<String> Function({
    required String sourcePath,
    required String name,
    required bool includeLocation,
    PhotoLocation? location,
    DateTime? takenAt,
  })
  saveOriginal;

  static Future<String> _saveOriginalNative({
    required String sourcePath,
    required String name,
    required bool includeLocation,
    PhotoLocation? location,
    DateTime? takenAt,
  }) => MediaStore.saveOriginal(
    sourcePath: sourcePath,
    displayName: name,
    includeLocation: includeLocation,
    location: location,
    takenAt: takenAt,
  );

  /// Renders and saves the still of the job. The real thing by default.
  final Future<SavedStill> Function(CaptureJob job)? save;

  // Both loose captures and roll development use the same native pixel
  // channel, which supports one save at a time. Bound GPU memory as well.
  static Future<void> _tail = Future.value();

  @override
  Future<String?> process(CaptureJob job) {
    final result = _tail.then((_) => _process(job));
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<String?> _process(CaptureJob queued) async {
    final failed = failedShots;
    // Durable first: from here on the shot survives anything.
    var job = failed == null
        ? queued
        : (await failed.keep(queued, countAttempt: false) ?? queued);

    // The original goes first, and it is best effort: it is attempted once
    // and a failure is only logged. It never keeps the files of the shot, never
    // retries and never changes what happens to the developed photo, so a
    // failed original can not bring back a photo the user deleted. Its name is
    // fixed by the shot, so when the shot is processed again for the sake of
    // its photo, the original is found instead of saved twice.
    if (job.saveOriginal) {
      await _saveOriginalOf(job);
      // Attempted: whatever happened, a retry of the photo does not try again.
      await failed?.markOriginalTried(job);
      // The rest of this run writes the sidecar with that mark too.
      job = job.withFile(job.filePath, saveOriginal: false);
    }

    final lookup = findSaved;
    final existing = lookup == null ? null : await lookup(exportNameOf(job));
    final SavedStill still;
    if (existing != null) {
      still = SavedStill(existing);
    } else {
      // Only a real render and save counts against the limit of attempts.
      await failed?.countAttempt(job);
      still = await (save ?? _renderAndSave)(job);
    }

    var recorded = true;
    final report = onSaved;
    if (report != null) {
      try {
        await report(job, still);
      } on Object catch (error) {
        recorded = false;
        await failed?.countRecordFailure(job);
        if (kDebugMode) {
          debugPrint(
            'Could not record the saved shot: ${errorLogToken(error)}',
          );
        }
      }
    }
    if (recorded) {
      // Saved and recorded: the original has done its job.
      await failed?.discard(job);
      try {
        await File(job.filePath).delete();
      } on FileSystemException {
        // Already gone.
      }
    }
    return still.uri;
  }

  /// Saves the camera original of [job] unless it is already there. Never
  /// throws: a failure is logged in debug and the original is dropped.
  Future<void> _saveOriginalOf(CaptureJob job) async {
    final name = originalNameOf(job);
    try {
      if (await findSavedOriginal(name) != null) return;
      if (!await File(job.filePath).exists()) return;
      await saveOriginal(
        sourcePath: job.filePath,
        name: name,
        includeLocation: job.includeLocation,
        location: job.location,
        takenAt: job.shutterInstant,
      );
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('Could not save the original: ${errorLogToken(error)}');
      }
    }
  }

  Future<SavedStill> _renderAndSave(CaptureJob job) async {
    final total = Stopwatch()..start();
    ui.Image? curve;
    int? tileToken;
    try {
      final file = File(job.filePath);
      if (await file.length() > StillBounds.maxFileBytes) {
        throw StateError('The original is too large to be developed');
      }
      final jpeg = await file.readAsBytes();
      final renderer = FilmStillRenderer(await loadProgram());
      curve = await curveImageOf(job.look);
      Map<String, Object?>? saved;
      var singlePass = false;
      final still = await renderer.renderTiles(
        jpeg: jpeg,
        look: job.look,
        curve: curve,
        format: job.format,
        seed: job.seed,
        fieldAspect: job.fieldAspect,
        stampText: job.stampText,
        whiteFrame: job.whiteFrame,
        cinemaBands: job.cinemaBands,
        onSinglePass: (rgba, width, height) async {
          singlePass = true;
          saved = await MediaStore.saveRgbaAsJpeg(
            rgba: rgba,
            width: width,
            height: height,
            displayName: exportNameOf(job),
            sourcePath: job.filePath,
            includeLocation: job.includeLocation,
            location: job.location,
            takenAt: job.shutterInstant,
          );
        },
        onBegin: (width, height) async {
          tileToken = await MediaStore.beginTiledSave(
            width: width,
            height: height,
            tileSize: FilmStillRenderer.tileSide,
            displayName: exportNameOf(job),
            sourcePath: job.filePath,
            includeLocation: job.includeLocation,
            location: job.location,
            takenAt: job.shutterInstant,
            framed: job.whiteFrame && job.format == FrameFormat.r1x1,
          );
        },
        onTile: (tile) async {
          saved = await MediaStore.saveTile(
            token: tileToken!,
            x: tile.x,
            y: tile.y,
            width: tile.width,
            height: tile.height,
            rgba: tile.rgba,
          );
        },
      );
      if (kProfileMode || kDebugMode) {
        debugPrint(
          'CARRETE_PERF capture ${still.width}x${still.height} '
          '${singlePass ? 'single' : 'tiled'} '
          '${still.timings} total ${total.elapsedMilliseconds} ms',
        );
      }
      final uri = saved?['uri'] as String?;
      if (uri == null) throw StateError('The gallery gave no place for it');
      return SavedStill(uri, width: still.width, height: still.height);
    } finally {
      if (tileToken != null) {
        try {
          await MediaStore.cancelTiledSave(tileToken!);
        } on Object catch (error) {
          if (kDebugMode) {
            debugPrint('Could not release tile save: ${errorLogToken(error)}');
          }
        }
      }
      curve?.dispose();
    }
  }

  /// The file name of the photo taken at [takenAt], without extension.
  static String displayNameOf(DateTime takenAt) {
    String two(int n) => n.toString().padLeft(2, '0');
    final ms = takenAt.millisecond.toString().padLeft(3, '0');
    return 'CARRETE_${takenAt.year}${two(takenAt.month)}${two(takenAt.day)}'
        '_${two(takenAt.hour)}${two(takenAt.minute)}${two(takenAt.second)}'
        '_$ms';
  }

  /// The name of the original of [job], without extension: the export name of
  /// its developed photo plus `_original`.
  static String originalNameOf(CaptureJob job) =>
      '${exportNameOf(job)}$originalSuffix';

  /// What the name of an original adds to the name of its developed photo.
  static const String originalSuffix = '_original';

  /// The export name of [job], without extension: the one it was given
  /// (roll frames), or its time followed by its capture id, so two shots of
  /// the same millisecond never share a file.
  static String exportNameOf(CaptureJob job) {
    final given = job.displayName;
    if (given != null) return given;
    final id = job.captureId;
    final base = displayNameOf(job.takenAt);
    return id == null ? base : '${base}_$id';
  }
}

/// The grain seed of a shot taken at [takenAt]: different for every photo,
/// the same every time that photo is processed.
double grainSeedOf(DateTime takenAt) =>
    (takenAt.millisecondsSinceEpoch % 9973) / 101.0;
