import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../core/database/database_provider.dart';
import '../platform/media_store.dart';
import '../render/film_resources.dart';
import 'capture_queue.dart';
import 'error_log.dart';
import 'failed_shots.dart';
import 'film_capture_processor.dart';
import 'loose_shot_recorder.dart';
import 'save_activity.dart';

/// The cache directory of the app. `main` overrides it with the real one
/// before the app starts; the tests with a temporary directory.
final cacheDirectoryProvider = Provider<Directory>(
  (ref) => throw UnimplementedError(
    'cacheDirectoryProvider must be overridden with the cache directory.',
  ),
);

/// The shots that could not be saved, kept in `<cache>/failed/`.
final failedShotsProvider = Provider<FailedShots>(
  (ref) => FailedShots(
    Directory('${ref.watch(cacheDirectoryProvider).path}/failed'),
  ),
);

/// Writes the loose photos into the database. Overridden in the tests.
final looseShotRecorderProvider = Provider<LooseShotRecorder>(
  (ref) => LooseShotRecorder(ref.watch(shotsDaoProvider)),
);

/// Develops the photos. Overridden in the tests.
final captureProcessorProvider = Provider<CaptureProcessor>(
  (ref) => FilmCaptureProcessor(
    loadProgram: () async {
      final resources = await ref.read(filmResourcesProvider.future);
      if (resources == null) {
        throw StateError('The film shader is not available.');
      }
      return resources.program;
    },
    failedShots: ref.watch(failedShotsProvider),
    onSaved: (job, still) =>
        ref.read(looseShotRecorderProvider).record(job, still),
    // A shot saved before the process died is recorded, not saved again.
    findSaved: MediaStore.findSaved,
  ),
);

/// The line of photos waiting to be developed.
final captureQueueProvider = Provider<CaptureQueue>((ref) {
  final queue = SequentialCaptureQueue(ref.watch(captureProcessorProvider));
  ref.onDispose(queue.dispose);
  return queue;
});

/// The roll frames being saved right now. The roll service reports them; the
/// status of the camera counts them.
final saveActivityProvider = Provider<SaveActivity>((ref) {
  final activity = SaveActivity();
  ref.onDispose(activity.dispose);
  return activity;
});

/// The single door through which the shots that failed to save go back to the
/// queue (the start of the app and the retry of the user): two retries never
/// run at once.
final failedRetryProvider = Provider<FailedRetry>(
  (ref) => FailedRetry(ref.read),
);

/// Gives the shots that failed to save in an earlier run another try: each
/// one goes to the queue once. Returns how many were queued. Never throws.
Future<int> retryFailedShots(ProviderContainer container) =>
    container.read(failedRetryProvider).run();

/// Puts the failed shots back in the capture queue, one retry at a time.
class FailedRetry {
  FailedRetry(this._read);

  final T Function<T>(ProviderListenable<T> provider) _read;
  Future<int>? _running;

  /// A follow-up pass with [includeExhausted] requested while one is running.
  /// Several requests coalesce into a single one.
  bool _queuedExhausted = false;
  Completer<int>? _queued;

  /// Whether a retry is running.
  bool get running => _running != null;

  /// Retries the failed shots. A call made while another retry runs gets the
  /// answer of that one: nothing is queued twice. When a manual retry asks for
  /// [includeExhausted] while a start-up pass (without it) is running, the
  /// request is remembered and one more pass with [includeExhausted] runs after
  /// the current one; several such requests coalesce. Returns how many were
  /// queued. Never throws.
  Future<int> run({bool includeExhausted = false}) {
    final current = _running;
    if (current != null) {
      if (!includeExhausted) return current;
      // Remember the broader request and give the caller the future of the
      // follow-up pass that will honour it.
      _queued ??= Completer<int>();
      _queuedExhausted = true;
      // Make sure the follow-up is launched when the current pass ends. If it
      // ends before this listener is attached the future is already complete
      // and the listener still fires.
      current.whenComplete(_launchFollowUpIfNeeded);
      return _queued!.future;
    }
    return _start(includeExhausted);
  }

  Future<int> _start(bool includeExhausted) {
    final future = _retry(includeExhausted);
    _running = future;
    future.whenComplete(() {
      if (_running == future) _running = null;
    });
    return future;
  }

  void _launchFollowUpIfNeeded() {
    if (!_queuedExhausted || _queued == null) return;
    final completer = _queued!;
    _queued = null;
    _queuedExhausted = false;
    final future = _retry(true);
    _running = future;
    future.then(completer.complete, onError: completer.completeError);
    future.whenComplete(() {
      if (_running == future) _running = null;
    });
  }

  Future<int> _retry(bool includeExhausted) async {
    try {
      final book = await _read(recipeBookProvider.future);
      final failed = _read(failedShotsProvider);
      final queue = _read(captureQueueProvider);
      final found = await failed.pending(
        book,
        includeExhausted: includeExhausted,
        // A shot that used up its attempts is retried if its photo is
        // already in the gallery: it only has to be recorded.
        published: (job) async =>
            await MediaStore.findSaved(
              FilmCaptureProcessor.exportNameOf(job),
            ) !=
            null,
      );
      // A shot that is being developed lives in the folder too: it is not a
      // failure, and it must not be queued a second time.
      final jobs = [
        for (final job in found)
          if (!queue.holds(job.filePath)) job,
      ];
      if (jobs.isEmpty) return 0;
      if (kDebugMode) {
        queue.events.where((event) => event.job.retried).take(jobs.length).listen(
          (event) {
            debugPrint(
              event.ok
                  ? 'Retried shot saved'
                  : 'Retried shot failed again: ${errorLogToken(event.error!)}',
            );
          },
        );
      }
      for (final job in jobs) {
        queue.enqueue(job);
      }
      if (kDebugMode) debugPrint('Retrying ${jobs.length} failed shot(s).');
      return jobs.length;
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('Could not retry the failed shots: ${errorLogToken(error)}');
      }
      return 0;
    }
  }
}
