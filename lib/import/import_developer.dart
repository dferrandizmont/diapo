import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../capture/capture_queue.dart';
import '../capture/film_capture_processor.dart';
import '../capture/loose_shot_recorder.dart';
import '../gallery/photo_library.dart';
import '../platform/photo_actions.dart';

/// Where an export stands.
@immutable
class ImportProgress {
  const ImportProgress({
    required this.done,
    required this.total,
    this.cancelling = false,
  });

  /// How many photos are finished (developed or failed).
  final int done;

  /// How many photos the export has.
  final int total;

  /// Whether the person cancelled and the export is stopping.
  final bool cancelling;

  /// The photo being developed, counted from 1 (never above [total]).
  int get current => done < total ? done + 1 : total;

  @override
  bool operator ==(Object other) =>
      other is ImportProgress &&
      other.done == done &&
      other.total == total &&
      other.cancelling == cancelling;

  @override
  int get hashCode => Object.hash(done, total, cancelling);
}

/// How an export ended.
@immutable
class ImportOutcome {
  const ImportOutcome({
    required this.total,
    required this.developed,
    required this.failed,
    required this.cancelled,
    this.leftover = 0,
  });

  /// How many photos the export had.
  final int total;

  /// How many photos are in the gallery now.
  final int developed;

  /// How many photos could not be developed.
  final int failed;

  /// Whether the person cancelled. A cancelled export keeps nothing: the
  /// photos developed before the cancel are deleted again, so [developed] is
  /// 0.
  final bool cancelled;

  /// How many photos could not be removed from the gallery of the system
  /// when they had to be (the export was cancelled, or a photo was saved but
  /// could not be recorded). They are still there, in Pictures/Carrete, and
  /// the person has to be told.
  final int leftover;

  /// Whether every photo was developed and nothing was left behind.
  bool get complete =>
      !cancelled && failed == 0 && leftover == 0 && developed == total;
}

/// Builds the processor that develops the photos of one export. The processor
/// must call [onSaved] once a photo is in the gallery.
typedef ProcessorFactory = CaptureProcessor Function(
  Future<void> Function(CaptureJob job, SavedStill still) onSaved,
);

/// Develops the photos of a batch one at a time, in the background, and
/// records each as a loose photo of the own gallery.
///
/// One at a time keeps the memory flat: a 50 MP photo is decoded within the
/// same bounds as a shot of the camera, developed, saved and released before
/// the next one starts.
class ImportDeveloper {
  ImportDeveloper({
    required this._processorFactory,
    required this._recorder,
    required this._library,
    required this._actions,
    @visibleForTesting this.deleteTemporary = _deleteFile,
  });

  final ProcessorFactory _processorFactory;
  final LooseShotRecorder _recorder;
  final PhotoLibrary _library;
  final PhotoActions _actions;

  /// Deletes a temporary copy. The real thing by default.
  final Future<void> Function(String path) deleteTemporary;

  /// Starts developing [jobs]. The photos of the jobs are temporary copies:
  /// each is deleted once it has been developed, and all of them are gone
  /// when the export ends, whatever its outcome.
  ImportRun start(List<CaptureJob> jobs) {
    final run = ImportRun._(
      jobs: List.unmodifiable(jobs),
      processorFactory: _processorFactory,
      recorder: _recorder,
      library: _library,
      actions: _actions,
      deleteTemporary: deleteTemporary,
    );
    unawaited(run._run());
    return run;
  }
}

/// One export in progress.
class ImportRun {
  ImportRun._({
    required this.jobs,
    required ProcessorFactory processorFactory,
    required this._recorder,
    required this._library,
    required this._actions,
    required this._deleteTemporary,
  }) : progress = ValueNotifier<ImportProgress>(
         ImportProgress(done: 0, total: jobs.length),
       ) {
    _processor = processorFactory(_onSaved);
  }

  /// The jobs of the export.
  final List<CaptureJob> jobs;

  /// Where the export stands.
  final ValueNotifier<ImportProgress> progress;

  final LooseShotRecorder _recorder;
  final PhotoLibrary _library;
  final PhotoActions _actions;
  final Future<void> Function(String path) _deleteTemporary;
  late final CaptureProcessor _processor;
  final Completer<ImportOutcome> _outcome = Completer<ImportOutcome>();
  final Map<String, _Developed> _developed = <String, _Developed>{};

  /// Photos that are in the gallery of the system but whose record is not
  /// (yet) in the database, by job. A photo is listed here before the
  /// database is touched, so a failure never loses track of it.
  final Map<String, String> _unrecorded = <String, String>{};
  int _leftover = 0;
  bool _cancelled = false;

  /// Completes when the export is over. Never fails.
  Future<ImportOutcome> get outcome => _outcome.future;

  /// Whether the export is over.
  bool get finished => _outcome.isCompleted;

  /// Stops after the photo being developed and deletes what was developed so
  /// far: a cancelled export keeps nothing.
  void cancel() {
    if (_cancelled || finished) return;
    _cancelled = true;
    progress.value = ImportProgress(
      done: progress.value.done,
      total: progress.value.total,
      cancelling: true,
    );
  }

  Future<void> _onSaved(CaptureJob job, SavedStill still) async {
    final key = job.captureId ?? job.filePath;
    _unrecorded[key] = still.uri;
    final row = await _recorder.record(job, still);
    _developed[key] = _Developed(row.id, still.uri);
    _unrecorded.remove(key);
  }

  /// Whether the photo is certainly out of the gallery of the system.
  static bool _gone(PhotoDeletion outcome) =>
      outcome == PhotoDeletion.deleted ||
      outcome == PhotoDeletion.deletedKeptOriginal ||
      outcome == PhotoDeletion.gone;

  /// Tries twice to run [attempt]; true when the photo ended up out of the
  /// gallery of the system.
  Future<bool> _removed(Future<PhotoDeletion> Function() attempt) async {
    for (var tries = 0; tries < 2; tries++) {
      try {
        if (_gone(await attempt())) return true;
      } on Object catch (error) {
        if (kDebugMode) debugPrint('Could not remove a photo: $error');
      }
    }
    return false;
  }

  /// Removes the photos that were saved but never recorded: nothing in the
  /// own gallery would ever point to them, and a retry would save them twice.
  Future<void> _removeUnrecorded() async {
    for (final uri in _unrecorded.values.toList()) {
      if (!await _removed(() => _actions.delete(uri))) _leftover++;
    }
    _unrecorded.clear();
  }

  Future<void> _run() async {
    var failed = 0;
    var done = 0;
    for (final job in jobs) {
      if (_cancelled) break;
      try {
        await _processor.process(job);
        // The processor swallows a record that failed: only a photo that was
        // recorded counts.
        if (!_developed.containsKey(job.captureId ?? job.filePath)) failed++;
      } on Object catch (error) {
        if (kDebugMode) {
          debugPrint('Could not develop an imported photo: $error');
        }
        failed++;
      }
      await _removeUnrecorded();
      await _deleteTemporary(job.filePath);
      done++;
      if (!_cancelled) {
        progress.value = ImportProgress(done: done, total: jobs.length);
      }
    }
    // Whatever was left (a cancel, an early stop) leaves nothing behind.
    for (final job in jobs) {
      await _deleteTemporary(job.filePath);
    }

    ImportOutcome outcome;
    if (_cancelled) {
      for (final photo in _developed.values) {
        final undone = await _removed(
          () => _library.delete(photo.shotId, photo.uri),
        );
        if (!undone) _leftover++;
      }
      outcome = ImportOutcome(
        total: jobs.length,
        developed: 0,
        failed: 0,
        cancelled: true,
        leftover: _leftover,
      );
    } else {
      outcome = ImportOutcome(
        total: jobs.length,
        developed: _developed.length,
        failed: failed,
        cancelled: false,
        leftover: _leftover,
      );
    }
    _outcome.complete(outcome);
  }
}

Future<void> _deleteFile(String path) async {
  try {
    await File(path).delete();
  } on FileSystemException {
    // Already gone.
  }
}

class _Developed {
  const _Developed(this.shotId, this.uri);

  final int shotId;
  final String uri;
}
