import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:film_recipes/film_recipes.dart';

import '../capture/capture_queue.dart';
import '../capture/failed_shots.dart';
import '../capture/film_capture_processor.dart';
import '../core/database/app_database.dart';
import '../core/database/rolls_dao.dart';
import '../core/database/shots_dao.dart';
import '../core/database/shot_vault.dart';
import '../core/database/tables.dart';
import '../core/vault/vault_exceptions.dart';
import '../platform/media_store.dart';
import 'roll_notifications.dart';
import 'roll_operations.dart';
import 'roll_recovery.dart';
import 'roll_vault_payload.dart';

class DevelopProgress {
  const DevelopProgress(this.rollId, this.done, this.total, {this.failed = 0});
  final int rollId;

  /// Completed frames, including permanently failed frames.
  final int done;
  final int total;
  final int failed;
}

/// Foreground only: the processor needs dart:ui and the GPU.
class RollDeveloper {
  RollDeveloper({
    required this.database,
    required this.vault,
    required this.processor,
    required this.notifications,
    required this.cache,
    required this.loadBook,
    required this.operations,
    required this.clock,
    this.isForeground = _alwaysForeground,
    this.findSaved = MediaStore.findSaved,
  });

  static bool _alwaysForeground() => true;
  final bool Function() isForeground;
  final Future<String?> Function(String) findSaved;

  static String displayNameOf(ShotRow shot) =>
      '${FilmCaptureProcessor.displayNameOf(DateTime.fromMillisecondsSinceEpoch(shot.takenAt, isUtc: true))}_shot_${shot.id}';

  final AppDatabase database;
  final ShotVault vault;
  final CaptureProcessor processor;
  final RollNotifications notifications;
  final Directory cache;
  final Future<RecipeBook> Function() loadBook;
  final RollOperations operations;
  final DateTime Function() clock;
  final _progress = StreamController<DevelopProgress>.broadcast();
  final Map<int, DevelopProgress> _latest = {};

  Stream<DevelopProgress> get progress => _progress.stream;
  DevelopProgress? latestProgress(int rollId) => _latest[rollId];
  void dispose() => unawaited(_progress.close());

  Future<void> developDue(DateTime now) async {
    final rolls = await RollsDao(database).rollsDueForDeveloping(now);
    Object? firstError;
    StackTrace? firstStack;
    for (final roll in rolls) {
      try {
        await develop(roll.id);
      } on Object catch (error, stack) {
        // A transient failure in one roll must not starve the next one.
        firstError ??= error;
        firstStack ??= stack;
      }
    }
    if (firstError != null) Error.throwWithStackTrace(firstError, firstStack!);
  }

  Future<void> develop(int rollId) => operations.run(() => _develop(rollId));

  Future<void> _develop(int rollId) async {
    if (!isForeground()) return;
    final rolls = RollsDao(database);
    final shots = ShotsDao(database);
    final roll = await rolls.rollById(rollId);
    if (roll == null) throw ArgumentError.value(rollId, 'rollId');
    if (roll.state == RollState.discarded || roll.state == RollState.lost) {
      return;
    }
    if (roll.state == RollState.open) throw StateError('Close the roll first');
    try {
      await notifications.cancel(rollId);
    } on Object {
      // OS notification availability must never prevent developing.
    }
    var frames = await rolls.shotsOf(rollId);
    // Publication can outlive the URI transaction. Reconcile using only the
    // persisted shot identity before reading or rendering its encrypted data.
    for (final shot in frames) {
      if (!isForeground()) return;
      if (shot.galleryUri != null || shot.developFailure != null) continue;
      final uri = await findSaved(displayNameOf(shot));
      if (uri != null) await shots.markSavedInGallery(shot.id, uri);
    }
    frames = await rolls.shotsOf(rollId);
    var done = frames
        .where((s) => s.galleryUri != null || s.developFailure != null)
        .length;
    var failed = frames.where((s) => s.developFailure != null).length;
    void emit() {
      final event = DevelopProgress(
        rollId,
        done,
        frames.length,
        failed: failed,
      );
      _latest[rollId] = event;
      _progress.add(event);
    }

    emit();
    final book = await loadBook();
    final directory = Directory('${cache.path}/roll-develop');
    await directory.create(recursive: true);
    try {
      // Preflight every key before publishing anything. A roll with mixed key
      // ids (for example after a keystore reset) must not partly develop.
      for (final shot in frames) {
        if (!isForeground()) return;
        if (shot.galleryUri != null ||
            shot.developFailure != null ||
            shot.vaultPath == null) {
          continue;
        }
        try {
          await vault.read(shot.vaultPath!);
        } on VaultCorruptedException {
          // Persisted below so progress is emitted exactly once per frame.
        } on VaultMissingException {
          // Likewise: a frame whose encrypted file is gone fails on its own.
        }
      }
      for (final shot in frames) {
        if (!isForeground()) return;
        if (shot.galleryUri != null || shot.developFailure != null) {
          await _cleanVault(shot);
          continue;
        }
        final temp = File(
          '${directory.path}/roll_${rollId}_shot_${shot.id}.jpg',
        );
        try {
          if (shot.captureJobJson == null) {
            // v1 did not retain the settings needed for a faithful render.
            await _fail(shot.id, 'missingCaptureJob');
            failed++;
          } else {
            final payload = RollVaultPayload.decode(
              await vault.read(shot.vaultPath!),
            );
            await temp.writeAsBytes(payload.jpeg, flush: true);
            final json =
                payload.job ??
                Map<String, Object?>.from(
                  jsonDecode(shot.captureJobJson!) as Map,
                );
            final job = FailedShots.decode(json, book, temp.path);
            if (job == null) throw const FormatException('Invalid capture job');
            // The app may have paused while the vault or filesystem awaited.
            if (!isForeground()) return;
            final uri = await processor.process(
              job.withFile(temp.path, displayName: displayNameOf(shot)),
            );
            if (uri == null) throw StateError('Gallery save returned no URI');
            // Commit before removing the encrypted source. A restart skips
            // every committed save, and retries unfinished vault cleanup.
            await shots.markSavedInGallery(shot.id, uri);
          }
        } on VaultCorruptedException {
          await _fail(shot.id, 'corrupted');
          failed++;
        } on VaultMissingException {
          // Its file is gone (cleared storage, a transfer without the vault):
          // fail this frame instead of the whole roll on every resume.
          await _fail(shot.id, 'missing');
          failed++;
        } finally {
          if (await temp.exists()) await temp.delete();
        }
        // Legacy shots have no capture snapshot. Retain their source for
        // recovery rather than deleting an otherwise healthy encrypted JPEG.
        if (shot.captureJobJson != null) await _cleanVault(shot);
        done++;
        emit();
      }
      if (roll.state != RollState.developed) {
        await rolls.markDeveloped(rollId, now: clock());
      }
      await RollRecovery(cache, vault: vault).removeRoll(rollId);
    } on VaultKeyLostException {
      await rolls.markLost(rollId, clock());
    }
  }

  Future<void> _fail(int id, String reason) async {
    await (database.update(database.shots)..where((s) => s.id.equals(id)))
        .write(ShotsCompanion(developFailure: Value(reason)));
  }

  Future<void> _cleanVault(ShotRow shot) async {
    if (shot.developFailure == 'missingCaptureJob') return;
    if (shot.vaultPath == null) return;
    await vault.delete(shot.vaultPath!);
    await (database.update(database.shots)..where((s) => s.id.equals(shot.id)))
        .write(const ShotsCompanion(vaultPath: Value(null)));
  }
}
