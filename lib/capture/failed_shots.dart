import 'dart:convert';
import 'dart:io';

import 'error_log.dart';

import 'package:film_recipes/film_recipes.dart';
import 'package:flutter/foundation.dart';

import '../camera/camera_flash.dart';
import '../core/database/tables.dart' show ShotLens;
import '../core/settings/film_tuning.dart';
import '../location/photo_location.dart';
import 'capture_queue.dart';
import 'resolved_look_json.dart';

/// The shots that could not be saved.
///
/// A failed save never deletes the only copy of the photo: the camera original
/// moves to `<cache>/failed/` with a sidecar JSON of its job, and the next
/// start of the app tries again. After [maxAttempts] tries the files stay
/// there (never lost) but are not retried any more.
class FailedShots {
  FailedShots(this.directory);

  /// Where the originals and the sidecars live (`<cache>/failed/`).
  final Directory directory;

  /// How many saves are tried for one shot, the first one included.
  static const int maxAttempts = 3;

  /// v2 adds an exact look snapshot; v1 remains readable for old retries.
  static const int jobVersion = 2;

  /// The sidecar of the original at [path].
  static String sidecarOf(String path) => '$path.json';

  /// Whether [path] is already a kept original.
  bool owns(String path) =>
      File(path).parent.absolute.path == directory.absolute.path;

  /// Keeps the original of [job] in the directory (unless it is already
  /// there), with a sidecar of its job. Returns the job pointing at the kept
  /// file, or null when nothing could be kept (the original is gone, or the
  /// directory cannot be written); then the original is where it was. Never
  /// throws.
  ///
  /// The sidecar is written **before** the original moves, so a file in the
  /// directory always has its recovery record, and a failure at either step
  /// leaves the original where the camera wrote it. The sidecar counts one
  /// more render attempt with [countAttempt]; a shot that only waits to be
  /// recorded does not use up attempts.
  Future<CaptureJob?> keep(CaptureJob job, {bool countAttempt = true}) async {
    try {
      final source = File(job.filePath);
      if (!await source.exists()) return null;
      await directory.create(recursive: true);
      final keptOwned = owns(job.filePath);
      final kept = keptOwned
          ? source
          : File('${directory.path}/${_baseName(job.filePath)}');
      final keptJob = job.withFile(kept.path);
      final sidecar = await _readSidecar(kept.path);
      await _writeSidecar(
        kept.path,
        keptJob,
        attempts: _count(sidecar, 'attempts') + (countAttempt ? 1 : 0),
        recordFailures: _count(sidecar, 'recordFailures'),
      );
      if (!keptOwned) {
        try {
          await _move(source, kept);
        } on Object {
          // The original did not move: no record without a file.
          await _deleteQuietly(sidecarOf(kept.path));
          rethrow;
        }
      }
      return keptJob;
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('Could not keep the failed shot: ${errorLogToken(error)}');
      }
      return null;
    }
  }

  /// Counts one more render attempt of the kept shot [job] (a no-op for a shot
  /// that is not kept). Never throws.
  Future<void> countAttempt(CaptureJob job) => _bump(job, 'attempts');

  /// Counts one more failure to record the saved photo of [job] (a no-op for a
  /// shot that is not kept). After [maxAttempts] of them the files stay, as
  /// for any shot that gave up, and the shot is not retried. Never throws.
  Future<void> countRecordFailure(CaptureJob job) =>
      _bump(job, 'recordFailures');

  /// Writes in the sidecar of the kept shot [job] that its original was
  /// already attempted, so no retry of the photo tries it again (a no-op for
  /// a shot that is not kept). Never throws.
  Future<void> markOriginalTried(CaptureJob job) async {
    if (!owns(job.filePath)) return;
    try {
      final sidecar = await _readSidecar(job.filePath);
      await _writeSidecar(
        job.filePath,
        job.withFile(job.filePath, saveOriginal: false),
        attempts: _count(sidecar, 'attempts'),
        recordFailures: _count(sidecar, 'recordFailures'),
      );
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('Could not mark the original: ${errorLogToken(error)}');
      }
    }
  }

  Future<void> _bump(CaptureJob job, String key) async {
    if (!owns(job.filePath)) return;
    try {
      final sidecar = await _readSidecar(job.filePath);
      await _writeSidecar(
        job.filePath,
        job,
        attempts: _count(sidecar, 'attempts') + (key == 'attempts' ? 1 : 0),
        recordFailures:
            _count(sidecar, 'recordFailures') +
            (key == 'recordFailures' ? 1 : 0),
      );
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint(
          'Could not count on the failed shot: ${errorLogToken(error)}',
        );
      }
    }
  }

  /// Removes the kept original of [job] and its sidecar, when it is one.
  Future<void> discard(CaptureJob job) async {
    if (!owns(job.filePath)) return;
    for (final path in [
      job.filePath,
      sidecarOf(job.filePath),
      '${sidecarOf(job.filePath)}.tmp',
    ]) {
      try {
        await File(path).delete();
      } on FileSystemException {
        // Already gone.
      }
    }
  }

  /// The shots waiting for another try, read from the sidecars. A shot whose
  /// original is missing, whose sidecar is unreadable, that failed to be
  /// recorded [maxAttempts] times or that reached [maxAttempts] render
  /// attempts is left out (its files stay).
  ///
  /// A shot that used up its render attempts is still listed when [published]
  /// says its photo is already in the gallery: it only has to be recorded, and
  /// that never counts against the render limit.
  ///
  /// With [includeExhausted] (a retry the user asked for) the limits of
  /// attempts are ignored: every shot whose sidecar can be read is listed.
  Future<List<CaptureJob>> pending(
    RecipeBook book, {
    Future<bool> Function(CaptureJob job)? published,
    bool includeExhausted = false,
  }) async {
    if (!await directory.exists()) return const [];
    final jobs = <CaptureJob>[];
    await for (final entry in directory.list()) {
      if (entry is! File || !entry.path.endsWith('.json')) continue;
      final original = entry.path.substring(0, entry.path.length - 5);
      if (!await File(original).exists()) continue;
      try {
        final json = jsonDecode(await entry.readAsString());
        if (json is! Map) continue;
        if (!includeExhausted &&
            _count(json, 'recordFailures') >= maxAttempts) {
          continue;
        }
        final job = decode(Map<String, Object?>.from(json), book, original);
        if (job == null) continue;
        if (!includeExhausted && _count(json, 'attempts') >= maxAttempts) {
          var saved = false;
          try {
            saved = published != null && await published(job);
          } on Object {
            saved = false;
          }
          if (!saved) continue;
        }
        jobs.add(job);
      } on Object {
        // An unreadable sidecar: the original stays, the job is skipped.
      }
    }
    jobs.sort((a, b) => a.takenAt.compareTo(b.takenAt));
    return jobs;
  }

  /// How many shots wait in the directory: an original whose sidecar is a
  /// readable record. It counts what the folder holds, so it is the same after
  /// a restart, and it does not look at the attempts: a shot that gave up is
  /// still a photo that is not saved. Only meaningful while no shot is being
  /// processed, because a shot that is being developed lives here too. Never
  /// throws.
  Future<int> countKept() async {
    try {
      if (!await directory.exists()) return 0;
      var count = 0;
      await for (final entry in directory.list(followLinks: false)) {
        if (entry is! File || !entry.path.endsWith('.json')) continue;
        final original = entry.path.substring(0, entry.path.length - 5);
        if (!await File(original).exists()) continue;
        try {
          if (jsonDecode(await entry.readAsString()) is Map) count++;
        } on Object {
          // An unreadable sidecar is not a shot that can be retried.
        }
      }
      return count;
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('Could not count the failed shots: ${errorLogToken(error)}');
      }
      return 0;
    }
  }

  /// The versioned sidecar of [job], including its exact look at the shutter.
  /// Location is memory-only for loose shots and is dropped on retry. Callers
  /// writing an encrypted payload must add the location explicitly.
  static Map<String, Object?> encode(
    CaptureJob job, {
    required int attempts,
    int recordFailures = 0,
  }) => <String, Object?>{
    'version': jobVersion,
    'attempts': attempts,
    'recordFailures': recordFailures,
    'filmId': job.filmId,
    'tuning': job.tuning.toJson(),
    'flash': job.flash.name,
    'format': job.format.wireName,
    'seed': job.seed,
    'takenAt': job.takenAt.toIso8601String(),
    if (job.shutterInstant case final instant?)
      'takenAtMs': instant.millisecondsSinceEpoch,
    'fieldAspect': job.fieldAspect,
    'stampText': job.stampText,
    'whiteFrame': job.whiteFrame,
    'cinemaBands': job.cinemaBands,
    'includeLocation': job.includeLocation,
    'saveOriginal': job.saveOriginal,
    'lens': job.lens.name,
    'captureId': job.captureId,
    'look': encodeResolvedLook(job.look),
  };

  /// The job of a sidecar, reading the original from [filePath]. Null when the
  /// sidecar is not one of ours. Legacy v1 jobs rebuild their look from the
  /// film, tuning and flash, falling back to the first recipe if needed.
  static CaptureJob? decode(
    Map<String, Object?> json,
    RecipeBook book,
    String filePath,
  ) {
    final version = json['version'] ?? 1;
    if (version != 1 && version != jobVersion) return null;
    final filmId = json['filmId'];
    final takenAt = json['takenAt'];
    if (filmId is! String || takenAt is! String) return null;
    final when = DateTime.tryParse(takenAt);
    if (when == null) return null;
    final takenAtMs = json['takenAtMs'];
    DateTime? instant;
    if (takenAtMs is int) {
      try {
        instant = DateTime.fromMillisecondsSinceEpoch(takenAtMs, isUtc: true);
      } on ArgumentError {
        return null;
      }
    } else if (takenAtMs != null) {
      return null;
    }
    final rawTuning = json['tuning'];
    final tuning = rawTuning is Map
        ? FilmTuning.fromJson(Map<String, Object?>.from(rawTuning))
        : FilmTuning.defaults;
    final flash =
        CarreteFlash.values.asNameMap()[json['flash']] ?? CarreteFlash.off;
    final recipe = book.byId(filmId) ?? book.recipes.first;
    var look = lookWithFlash(
      // Legacy jobs must not acquire bands from a newer recipe default.
      resolve(
        recipe,
        overrides: tuning
            .copyWith(cinemaBands: json['cinemaBands'] == true)
            .overrides,
      ),
      flash,
    );
    if (version == jobVersion) {
      final snapshot = json['look'];
      if (snapshot is! Map) return null;
      try {
        look = decodeResolvedLook(Map<String, Object?>.from(snapshot));
      } on Object {
        return null;
      }
    }
    final rawFormat = json['format'];
    final format =
        (rawFormat is String ? FrameFormat.tryParse(rawFormat) : null) ??
        look.format;
    final seed = json['seed'];
    final aspect = json['fieldAspect'];
    final stamp = json['stampText'];
    return CaptureJob(
      filePath: filePath,
      filmId: version == jobVersion ? filmId : recipe.id,
      look: look,
      format: format,
      seed: seed is num ? seed.toDouble() : 0,
      takenAt: when,
      shutterInstant: instant,
      hasShutterInstant: instant != null,
      tuning: tuning,
      flash: flash,
      fieldAspect: aspect is num ? aspect.toDouble() : null,
      stampText: stamp is String ? stamp : null,
      whiteFrame: json['whiteFrame'] == true,
      cinemaBands: json['cinemaBands'] == true,
      includeLocation: json['includeLocation'] == true,
      location: json['includeLocation'] == true
          ? PhotoLocation.fromJson(json['location'])
          : null,
      saveOriginal: json['saveOriginal'] == true,
      // Sidecars written before the gallery have no lens: the back one.
      lens: ShotLens.values.asNameMap()[json['lens']] ?? ShotLens.back,
      captureId: json['captureId'] is String
          ? json['captureId'] as String
          : null,
      retried: true,
    );
  }

  /// The sidecar of the original at [path] as a map, or null when there is
  /// none or it cannot be read.
  Future<Map<Object?, Object?>?> _readSidecar(String path) async {
    try {
      final json = jsonDecode(await File(sidecarOf(path)).readAsString());
      return json is Map ? json : null;
    } on Object {
      return null;
    }
  }

  static int _count(Map<Object?, Object?>? json, String key) {
    final value = json == null ? null : json[key];
    return value is int ? value : 0;
  }

  /// Writes the sidecar whole or not at all: to a temporary file first, then
  /// renamed over the real one.
  Future<void> _writeSidecar(
    String path,
    CaptureJob job, {
    required int attempts,
    required int recordFailures,
  }) async {
    final text = jsonEncode(
      encode(job, attempts: attempts, recordFailures: recordFailures),
    );
    final sidecar = sidecarOf(path);
    final temporary = File('$sidecar.tmp');
    await temporary.writeAsString(text, flush: true);
    try {
      await temporary.rename(sidecar);
    } on Object {
      await _deleteQuietly(temporary.path);
      rethrow;
    }
  }

  static Future<void> _deleteQuietly(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // Already gone.
    }
  }

  static Future<void> _move(File from, File to) async {
    try {
      await from.rename(to.path);
    } on FileSystemException {
      // Another volume: copy, then delete.
      await from.copy(to.path);
      await from.delete();
    }
  }

  static String _baseName(String path) {
    final slash = path.lastIndexOf(RegExp(r'[\\/]'));
    return slash < 0 ? path : path.substring(slash + 1);
  }
}

/// Deletes disposable encoder files (`CARRETE_*.jpg`) at the top of [cacheDir].
/// Camera originals are never presumed saved: a failed staging operation may
/// have left the only copy there. Only the capture owner may remove them after
/// a durable save or explicit discard. Subdirectories stay untouched, except
/// [originalTempFolder], where the native side stages the copy of an original
/// on its way to the gallery: whatever is there at start is a leftover.
Future<int> cleanCaptureLeftovers(Directory cacheDir) async {
  var deleted = 0;
  try {
    if (!await cacheDir.exists()) return 0;
    deleted += await _sweepOriginalTemp(
      Directory('${cacheDir.path}/$originalTempFolder'),
    );
    await for (final entry in cacheDir.list(followLinks: false)) {
      if (entry is! File) continue;
      final name = entry.uri.pathSegments.last;
      if (!_leftover.hasMatch(name)) continue;
      try {
        await entry.delete();
        deleted++;
      } on FileSystemException {
        // In use or already gone.
      }
    }
  } on Object catch (error) {
    if (kDebugMode) {
      debugPrint('Could not clean the capture cache: ${errorLogToken(error)}');
    }
  }
  return deleted;
}

/// The folder of the cache where the native side stages an original (a copy
/// of the camera JPEG) before it is published. Nothing else lives there.
const String originalTempFolder = 'original-tmp';

Future<int> _sweepOriginalTemp(Directory folder) async {
  var deleted = 0;
  if (!await folder.exists()) return 0;
  await for (final entry in folder.list(followLinks: false)) {
    if (entry is! File) continue;
    try {
      await entry.delete();
      deleted++;
    } on FileSystemException {
      // In use or already gone.
    }
  }
  return deleted;
}

final RegExp _leftover = RegExp(
  r'^CARRETE_.*\.(jpg|jpeg)$',
  caseSensitive: false,
);
