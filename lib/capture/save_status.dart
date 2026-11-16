import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../roll/roll_recovery.dart';
import '../roll/roll_providers.dart';
import 'capture_providers.dart';
import 'capture_queue.dart';
import 'error_log.dart';

/// Why photos could not be saved, in the words the camera can say. It is a
/// guess made from the error of the last failure; after a restart the reason
/// is not known any more and it is [unknown].
enum SaveProblem { storageFull, permission, unknown }

/// What went wrong, read from [error].
SaveProblem saveProblemOf(Object? error) {
  if (error is FileSystemException) {
    // ENOSPC on Android and iOS, ERROR_DISK_FULL on Windows (tests).
    final code = error.osError?.errorCode;
    if (code == 28 || code == 112) return SaveProblem.storageFull;
    if (code == 13 || code == 1 || code == 5) return SaveProblem.permission;
  }
  final text = '$error'.toLowerCase();
  if (text.contains('enospc') ||
      text.contains('no space') ||
      text.contains('not enough space') ||
      text.contains('disk full') ||
      text.contains('quota')) {
    return SaveProblem.storageFull;
  }
  if (text.contains('permission') ||
      text.contains('eacces') ||
      text.contains('eperm') ||
      text.contains('securityexception') ||
      text.contains('not_allowed') ||
      text.contains('denied')) {
    return SaveProblem.permission;
  }
  return SaveProblem.unknown;
}

/// What the camera knows about the photos it is putting away.
///
/// It counts and never shows: nothing here is a path, a thumbnail or a name.
@immutable
class SaveStatus {
  const SaveStatus({
    this.saving = 0,
    this.failed = 0,
    this.retrying = false,
    this.problem = SaveProblem.unknown,
  });

  /// The photos being processed or saved now: the queue of loose photos and
  /// the frames of a roll that go into the vault.
  final int saving;

  /// The shots waiting in `<cache>/failed/` (and the roll frames kept for
  /// recovery): what could not be saved and is still recoverable. Read from
  /// the folders, so it is the same after a restart.
  final int failed;

  /// Whether a retry asked by the user is running.
  final bool retrying;

  /// The reason of the last failure.
  final SaveProblem problem;

  /// The number the camera says it is saving: the real one, or, while a retry
  /// looks for what to save, the failed ones.
  int get savingCount => saving > 0 ? saving : (retrying ? failed : 0);

  /// Whether something is being saved.
  bool get isSaving => savingCount > 0;

  /// Whether there are photos that could not be saved and nothing is being
  /// done about them now.
  bool get hasFailures => failed > 0 && !isSaving;

  SaveStatus copyWith({
    int? saving,
    int? failed,
    bool? retrying,
    SaveProblem? problem,
  }) => SaveStatus(
    saving: saving ?? this.saving,
    failed: failed ?? this.failed,
    retrying: retrying ?? this.retrying,
    problem: problem ?? this.problem,
  );

  @override
  bool operator ==(Object other) =>
      other is SaveStatus &&
      other.saving == saving &&
      other.failed == failed &&
      other.retrying == retrying &&
      other.problem == problem;

  @override
  int get hashCode => Object.hash(saving, failed, retrying, problem);
}

/// The status of the photos being saved, for the camera.
final saveStatusProvider = NotifierProvider<SaveStatusController, SaveStatus>(
  SaveStatusController.new,
);

class SaveStatusController extends Notifier<SaveStatus> {
  late CaptureQueue _queue;
  late ValueListenable<int> _roll;
  SaveProblem? _lastProblem;
  Future<void>? _retry;
  Future<void>? _counting;
  bool _again = false;

  @override
  SaveStatus build() {
    _queue = ref.watch(captureQueueProvider);
    _roll = ref.watch(saveActivityProvider).saving;
    _queue.pending.addListener(_changed);
    _roll.addListener(_changed);
    final events = _queue.events.listen(_onEvent);
    ref.onDispose(() {
      _queue.pending.removeListener(_changed);
      _roll.removeListener(_changed);
      unawaited(events.cancel());
    });
    // What the last run left in the folders is known as soon as it is read.
    scheduleMicrotask(refresh);
    return SaveStatus(saving: _busy);
  }

  int get _busy => _queue.pending.value + _roll.value;

  void _changed() {
    if (!ref.mounted) return;
    final before = state.saving;
    state = state.copyWith(saving: _busy);
    // The line just emptied: what failed in it is in the folder now.
    if (before > 0 && _busy == 0) unawaited(refresh());
  }

  void _onEvent(CaptureEvent event) {
    if (!ref.mounted || event.ok) return;
    _lastProblem = saveProblemOf(event.error);
  }

  /// Counts the failed photos again. Nothing is counted while something is
  /// being saved: a shot that is being developed lives in the folder too.
  ///
  /// One count runs at a time. A call made while one runs asks for another
  /// one after it and completes when the last one is in the state.
  Future<void> refresh() {
    _again = true;
    return _counting ??= _count().whenComplete(() => _counting = null);
  }

  Future<void> _count() async {
    while (_again) {
      _again = false;
      if (_busy > 0) return;
      final failed = await _countFailed();
      if (!ref.mounted || _busy > 0) return;
      // Something asked again while this one read the folders: its answer
      // may already be old.
      if (_again) continue;
      state = state.copyWith(
        saving: 0,
        failed: failed,
        problem: _lastProblem ?? SaveProblem.unknown,
      );
    }
  }

  Future<int> _countFailed() async {
    var count = 0;
    try {
      count += await ref.read(failedShotsProvider).countKept();
    } on Object {
      // No cache directory (a screen under test, a failed start): there is
      // nothing to count. Errors of the folder itself are logged by it.
    }
    count += await _rollFailures();
    return count;
  }

  /// Gives the photos that could not be saved another try. One at a time: a
  /// call made while a retry runs waits for it. Never throws.
  Future<void> retry() => _retry ??= _doRetry().whenComplete(() {
    _retry = null;
  });

  Future<void> _doRetry() async {
    state = state.copyWith(retrying: true);
    try {
      // The loose photos go back to the queue, which develops them one at a
      // time; they count as saving until they are done.
      await ref.read(failedRetryProvider).run(includeExhausted: true);
      // The frames of a roll are put away by the roll service, on its own
      // serialized line.
      if (await _rollFailures() > 0) {
        await ref.read(rollServiceProvider).recoverCaptures();
      }
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('The retry of the saves failed: ${errorLogToken(error)}');
      }
    } finally {
      if (ref.mounted) state = state.copyWith(retrying: false);
    }
    if (ref.mounted) await refresh();
  }

  Future<int> _rollFailures() async {
    try {
      final activity = ref.read(saveActivityProvider);
      final entries = await RollRecovery(ref.read(cacheDirectoryProvider))
          .pending();
      return entries
          .where((e) => !activity.isActive(e.data['originalPath'] as String))
          .length;
    } on Object {
      return 0;
    }
  }
}
