import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../capture/capture_queue.dart';
import '../capture/failed_shots.dart';
import '../capture/save_activity.dart';
import '../core/database/app_database.dart';
import '../core/database/converters.dart';
import '../core/database/rolls_dao.dart';
import '../core/database/shots_dao.dart';
import '../core/database/shot_vault.dart';
import '../core/database/tables.dart';
import 'disposable.dart';
import 'roll_developer.dart';
import 'roll_notifications.dart';
import 'roll_operations.dart';
import 'roll_name.dart';
import 'roll_recovery.dart';
import 'roll_vault_payload.dart';

export 'roll_providers.dart';

class OpenRollExistsException implements Exception {
  const OpenRollExistsException(this.rollId);
  final int rollId;
}

class NoActiveRollException implements Exception {
  const NoActiveRollException();
}

/// Roll originals never enter FailedShots.pending, which publishes loose photos.
/// They are moved into roll-recovery before encryption and retained on failure.
class RollService {
  RollService({
    required this.database,
    required this.vault,
    required this.notifications,
    required this.developer,
    required this.operations,
    required this.cache,
    required this.clock,
    required this.defaultFilm,
    SaveActivity? activity,
  }) : activity = activity ?? SaveActivity();

  final AppDatabase database;
  final ShotVault vault;
  final RollNotifications notifications;
  final RollDeveloper developer;
  final RollOperations operations;
  final Directory cache;
  final DateTime Function() clock;
  final String Function() defaultFilm;

  /// The frames being saved, for the status of the camera.
  final SaveActivity activity;
  final _notificationErrors = StreamController<Object>.broadcast();
  Stream<Object> get notificationErrors => _notificationErrors.stream;
  void dispose() => unawaited(_notificationErrors.close());
  RollsDao get _rolls => RollsDao(database);

  RollRecovery get _recovery => RollRecovery(cache, vault: vault);

  /// Startup/resume reconciliation runs on the same queue as shutter work.
  Future<void> recoverCaptures() => operations.run(() async {
    for (final entry in await _recovery.pending()) {
      final originalPath = entry.data['originalPath'] as String;
      if (activity.isActive(originalPath)) continue;
      try {
        final roll = entry.rollId == null
            ? null
            : await _rolls.rollById(entry.rollId!);
        if (roll == null) {
          // No roll can ever take this frame: drop its plaintext now.
          await _recovery.removeBestEffort(entry);
          continue;
        }
        if (roll.state == RollState.discarded) {
          await _finishDiscard(roll.id);
          continue;
        }
        final committed = (await _rolls.shotsOf(roll.id)).any(
          (shot) =>
              shot.captureJobJson != null &&
              (jsonDecode(shot.captureJobJson!) as Map)['captureId'] ==
                  entry.id,
        );
        if (committed || roll.state == RollState.developed) {
          await _recovery.removeBestEffort(entry);
        } else if (roll.state == RollState.open &&
            await _rolls.remainingFrames(roll.id) > 0) {
          // Report the frame as being saved, including the cleanup and error
          // paths, so the camera's saving count stays honest.
          activity.begin(originalPath);
          try {
            final source = await entry.source();
            if (source == null) continue;
            final job = FailedShots.decode(
              await _recovery.snapshotOf(entry),
              await developer.loadBook(),
              source.path,
            );
            if (job != null) {
              await _commitCapture(job, entry, recovering: true);
            }
          } finally {
            activity.end(originalPath);
          }
        } else {
          // A closed, full or lost roll cannot accept another frame and
          // developing never uses it, so its plaintext original is removed
          // now rather than kept for the whole develop delay.
          await _recovery.removeBestEffort(entry);
        }
      } on Object catch (error) {
        if (!_notificationErrors.isClosed) _notificationErrors.add(error);
      }
    }
    // A discard can fail before its first recovery record is visited, or have
    // no recovery records at all. Its durable state still requests cleanup.
    for (final roll in await _rolls.allRolls()) {
      if (roll.state == RollState.discarded) {
        try {
          await _finishDiscard(roll.id);
        } on Object catch (error) {
          if (!_notificationErrors.isClosed) _notificationErrors.add(error);
        }
      }
    }
  });

  Stream<RollRow?> get activeRoll => _rolls.watchActiveRoll();
  Stream<int> get remainingFrames => _rolls.watchRemainingFrames();
  Stream<List<RollRow>> get rolls => _rolls.watchRolls();
  Stream<List<ShotRow>> shotsOf(int id) => _rolls.watchShots(id);

  Future<RollRow> openRoll(
    int length,
    DevelopDelay delay, {
    String? filmId,
  }) async {
    if (![12, 24, 36].contains(length)) {
      throw ArgumentError.value(length, 'length');
    }
    return _open(length, delay, filmId, RollMode.roll);
  }

  /// Opens a disposable camera: a roll of [kDisposableFrames] frames. It
  /// develops like any roll once it closes; the screen that locks the camera
  /// is a matter of the UI (see `DisposableLock`).
  Future<RollRow> openDisposable(DevelopDelay delay, {String? filmId}) =>
      _open(kDisposableFrames, delay, filmId, RollMode.disposable);

  Future<RollRow> _open(
    int length,
    DevelopDelay delay,
    String? filmId,
    RollMode mode,
  ) => operations.run(() async {
    final roll = await database.transaction(() async {
      final open = await _rolls.activeRoll();
      if (open != null) throw OpenRollExistsException(open.id);
      return _rolls.openRoll(
        filmId: filmId ?? defaultFilm(),
        length: length,
        mode: mode,
        developDelay: delay,
        now: clock(),
      );
    });
    if (delay != DevelopDelay.instant) {
      await _notify(notifications.requestPermission);
    }
    return roll;
  });

  /// [rollId] binds a shutter press to its roll, even if the UI goes away or
  /// another roll opens while the camera answers. Heavy work is asynchronous.
  Future<ShotRow> captureIntoRoll(
    CaptureJob job, {
    int? rollId,
    ShotLens lens = ShotLens.back,
  }) {
    // Stage immediately, even while another roll is developing. A queued
    // camera original must not remain in startup's CAP*.jpg cleanup area.
    activity.begin(job.filePath);
    final prepared = _protectOriginal(job, rollId, lens);
    unawaited(prepared.then<void>((_) {}, onError: (Object _) {}));
    return operations.run(() async {
      try {
        final (entry, staged) = await prepared;
        return await _commitCapture(staged, entry);
      } finally {
        activity.end(job.filePath);
      }
    });
  }

  Future<ShotRow> _commitCapture(
    CaptureJob captured,
    RecoveryCapture entry, {
    bool recovering = false,
  }) async {
    final source = await entry.source();
    final roll = entry.rollId == null
        ? null
        : await _rolls.rollById(entry.rollId!);
    if (roll == null) {
      // The frame can never be committed: do not keep its plaintext.
      await _recovery.removeBestEffort(entry);
      throw const NoActiveRollException();
    }
    if (source == null) throw FileSystemException('Missing capture original');
    // Whatever the path (a new shot or one recovered from an earlier run), a
    // frame of a disposable is the fixed 3:2 one, in the record as well.
    final disposable = roll.mode == RollMode.disposable;
    final job = disposable
        ? disposableFrame(captured, await developer.loadBook())
        : captured;
    final snapshot = FailedShots.encode(job, attempts: 0);
    if (job.includeLocation && job.location != null) {
      snapshot['includeLocation'] = true;
      snapshot['location'] = job.location!.toJson();
    }
    String? path;
    late final ShotRow shot;
    try {
      final jpeg = await source.readAsBytes();
      final hasLocation = job.includeLocation && job.location != null;
      path = await vault.store(
        hasLocation ? RollVaultPayload.encode(jpeg, snapshot) : jpeg,
      );
      final publicSnapshot = {...snapshot}..remove('location');
      if (hasLocation) publicSnapshot['vaultJob'] = true;
      // Insertion and auto-close are one transaction, including after a crash.
      shot = await database.transaction(() async {
        final added = await ShotsDao(database).addShot(
          rollId: roll.id,
          filmId: job.filmId,
          format: ShotFormat.fromStorage(job.format.wireName),
          lens: entry.lens,
          takenAt: job.takenAt,
          vaultPath: path,
          captureJobJson: jsonEncode({
            ...publicSnapshot,
            'captureId': entry.id,
          }),
        );
        if (await _rolls.remainingFrames(roll.id) == 0) {
          await _rolls.closeRoll(roll.id, now: clock());
        }
        return added;
      });
    } on Object catch (error) {
      if (path != null) {
        try {
          await vault.delete(path);
        } on Object {
          /* Keep the original. */
        }
      }
      // A refusal is final (closed, full or missing roll): the frame is never
      // developed, so its plaintext original goes now. Any other failure keeps
      // it for the startup recovery.
      if (error is RollRefusedException) {
        await _recovery.removeBestEffort(entry);
      }
      rethrow;
    }
    // Encrypted bytes and settings are durable before plaintext is removed.
    await _recovery.removeBestEffort(entry);
    final updated = (await _rolls.rollById(roll.id))!;
    if (updated.state == RollState.developing) {
      await _closed(updated, requestPermission: !recovering);
    }
    return shot;
  }

  /// Stages the original. The job that goes with it is the one to develop: for
  /// a disposable roll it is the fixed frame of the disposable camera.
  Future<(RecoveryCapture, CaptureJob)> _protectOriginal(
    CaptureJob job,
    int? rollId,
    ShotLens lens,
  ) async {
    final boundRollId = rollId ?? (await _rolls.activeRoll())?.id;
    final roll = boundRollId == null
        ? null
        : await _rolls.rollById(boundRollId);
    final staged = roll?.mode == RollMode.disposable
        ? disposableFrame(job, await developer.loadBook())
        : job;
    return (await _recovery.stage(staged, boundRollId, lens), staged);
  }

  Future<RollRow> closeRoll([int? rollId]) => operations.run(() async {
    final roll = rollId == null
        ? await _rolls.activeRoll()
        : await _rolls.rollById(rollId);
    if (roll == null) throw const NoActiveRollException();
    if (roll.state != RollState.open) return roll;
    final closed = await _rolls.closeRoll(roll.id, now: clock());
    await _closed(closed);
    return closed;
  });

  Future<void> _closed(RollRow roll, {bool requestPermission = true}) async {
    if (roll.developDelay == DevelopDelay.instant) {
      // Do not await another operation while holding the shared queue.
      unawaited(
        developer.develop(roll.id).catchError((Object error) {
          if (!_notificationErrors.isClosed) _notificationErrors.add(error);
        }),
      );
    } else {
      if (requestPermission) await _notify(notifications.requestPermission);
      await _schedule(roll);
    }
  }

  Future<void> developNow(int rollId) async {
    await operations.run(() async {
      await _rolls.requestDevelopNow(rollId, now: clock());
      await _notify(() => notifications.cancel(rollId));
    });
    await developer.develop(rollId);
  }

  Future<void> discardRoll(int rollId) => operations.run(() async {
    // Persist intent before deleting anything, so startup never recovers a
    // half-discarded roll and subsequent discard attempts remain idempotent.
    await _rolls.discardRoll(rollId, now: clock());
    await _notify(() => notifications.cancel(rollId));
    await _finishDiscard(rollId);
  });

  /// Names the roll [rollId] [name], cleaned by [normalizeRollName]: an empty
  /// name clears it. The name is not photo content, so a roll can be named in
  /// any state. Returns the name that was stored.
  Future<String?> renameRoll(int rollId, String? name) =>
      operations.run(() async {
        final clean = normalizeRollName(name);
        await _rolls.renameRoll(rollId, clean);
        return clean;
      });

  Future<void> _finishDiscard(int rollId) async {
    for (final shot in await _rolls.shotsOf(rollId)) {
      if (shot.vaultPath != null) await vault.delete(shot.vaultPath!);
    }
    await _recovery.removeRoll(rollId);
  }

  Future<void> reconcileNotifications() async {
    for (final roll in await _rolls.allRolls()) {
      if (roll.state == RollState.developing &&
          roll.developAt! > clock().millisecondsSinceEpoch) {
        await _schedule(roll);
      } else if (roll.state != RollState.open) {
        await _notify(() => notifications.cancel(roll.id));
      }
    }
  }

  /// Schedules the readiness notification with the photos actually taken:
  /// a roll closed early holds fewer than its length.
  Future<void> _schedule(RollRow roll) async {
    final photos = await _rolls.shotsTaken(roll.id);
    await _notify(() => notifications.schedule(roll, photos: photos));
  }

  Future<void> _notify(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (error) {
      if (!_notificationErrors.isClosed) _notificationErrors.add(error);
    }
  }
}
