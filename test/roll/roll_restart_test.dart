import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:diapo/capture/capture_queue.dart';
import 'package:diapo/capture/failed_shots.dart';
import 'package:diapo/capture/film_capture_processor.dart';
import 'package:diapo/core/database/app_database.dart';
import 'package:diapo/core/database/rolls_dao.dart';
import 'package:diapo/core/database/shots_dao.dart';
import 'package:diapo/core/database/tables.dart';
import 'package:diapo/core/vault/vault_exceptions.dart';
import 'package:diapo/roll/roll_developer.dart';
import 'package:diapo/roll/roll_operations.dart';
import 'package:diapo/roll/roll_recovery.dart';
import 'package:diapo/roll/roll_service.dart';
import 'package:diapo/roll/roll_temp_files.dart';
import 'package:drift/native.dart';
import 'package:film_recipes/film_recipes.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import 'roll_test.dart' show FakeNotifications, FakeVault;

/// Fail the real filesystem operations at the crash boundaries, leaving the
/// other operations and the on-disk database intact.
final class FaultIo extends IOOverrides {
  bool mkdir = false;
  bool moveAndCopy = false;
  bool cleanup = false;
  int mkdirFailures = 0;
  int renameFailures = 0;
  int copyFailures = 0;
  String normalized(String path) => path.replaceAll('\\', '/');

  @override
  Directory createDirectory(String path) {
    final real = super.createDirectory(path);
    return mkdir && normalized(path).contains('/roll-recovery')
        ? FailingDirectory(real, this)
        : real;
  }

  @override
  File createFile(String path) => FailingFile(super.createFile(path), this);
}

class FailingDirectory implements Directory {
  FailingDirectory(this.real, this.fault);
  final Directory real;
  final FaultIo fault;
  @override
  String get path => real.path;
  @override
  Future<Directory> create({bool recursive = false}) async {
    fault.mkdirFailures++;
    throw FileSystemException('injected mkdir failure', path);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FailingFile implements File {
  FailingFile(this.real, this.fault);
  final File real;
  final FaultIo fault;
  @override
  String get path => real.path;
  @override
  Directory get parent => real.parent;
  @override
  Uri get uri => real.uri;
  @override
  File get absolute => real.absolute;
  @override
  Future<bool> exists() => real.exists();
  @override
  Future<File> rename(String newPath) async {
    if (fault.moveAndCopy && newPath.contains('roll-recovery')) {
      fault.renameFailures++;
      throw FileSystemException('injected rename failure', path);
    }
    return real.rename(newPath);
  }

  @override
  Future<File> copy(String newPath) async {
    if (fault.moveAndCopy && newPath.contains('roll-recovery')) {
      fault.copyFailures++;
      await File(newPath).writeAsBytes([9], flush: true);
      throw FileSystemException('injected copy failure', path);
    }
    return real.copy(newPath);
  }

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async {
    if (fault.cleanup && path.endsWith('original.jpg')) {
      throw FileSystemException('injected plaintext cleanup failure', path);
    }
    return real.delete(recursive: recursive);
  }

  @override
  Future<Uint8List> readAsBytes() => real.readAsBytes();
  @override
  Future<File> writeAsBytes(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) => real.writeAsBytes(bytes, mode: mode, flush: flush);
  @override
  Future<String> readAsString({Encoding encoding = utf8}) =>
      real.readAsString(encoding: encoding);
  @override
  Future<File> writeAsString(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) => real.writeAsString(
    contents,
    mode: mode,
    encoding: encoding,
    flush: flush,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class GalleryProcessor implements CaptureProcessor {
  final items = <({String name, String uri})>[];
  final lookups = <String>[];
  void Function()? afterPublish;

  Future<String?> findSaved(String name) async {
    lookups.add(name);
    return items.where((i) => i.name == name).firstOrNull?.uri;
  }

  @override
  Future<String?> process(CaptureJob job) async {
    expect(await File(job.filePath).readAsBytes(), [1, 2, 3]);
    final name =
        job.displayName ?? FilmCaptureProcessor.displayNameOf(job.takenAt);
    final uri = 'content://gallery/${items.length + 1}';
    items.add((name: name, uri: uri));
    afterPublish?.call();
    return uri;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory cache;
  late File databaseFile;
  late AppDatabase db;
  late RollService service;
  late RollDeveloper developer;
  late RollOperations operations;
  late FakeVault vault;
  late FakeNotifications notifications;
  late GalleryProcessor gallery;
  late DateTime now;
  var foreground = true;
  var serial = 0;
  final book = testBook();

  void open() {
    db = AppDatabase(NativeDatabase(databaseFile));
    operations = RollOperations();
    developer = RollDeveloper(
      database: db,
      vault: vault,
      processor: gallery,
      notifications: notifications,
      cache: cache,
      loadBook: () async => book,
      operations: operations,
      clock: () => now,
      isForeground: () => foreground,
    );
    service = RollService(
      database: db,
      vault: vault,
      notifications: notifications,
      developer: developer,
      operations: operations,
      cache: cache,
      clock: () => now,
      defaultFilm: () => 'gamma',
    );
  }

  Future<void> startup() async {
    await cleanCaptureLeftovers(cache);
    await cleanRollDevelopmentTemps(cache);
    await service.recoverCaptures();
    await service.reconcileNotifications();
    await developer.developDue(now);
  }

  Future<void> restart() async {
    await operations.run(() async {});
    service.dispose();
    developer.dispose();
    await db.close();
    final previous = db;
    open();
    expect(identical(db, previous), isFalse);
    await startup();
  }

  Future<CaptureJob> job() async {
    final file = await File('${cache.path}/CAP${serial++}.jpg')
        .writeAsBytes([1, 2, 3]);
    return CaptureJob(
      filePath: file.path,
      filmId: 'gamma',
      look: resolve(book.byId('gamma')!),
      format: FrameFormat.r3x2,
      seed: 42,
      takenAt: now,
    );
  }

  Future<List<File>> plaintext() async => cache
      .list(recursive: true)
      .where(
        (e) =>
            e is File &&
            (e.path.endsWith('.jpg') ||
                e.path.endsWith('capture.json') ||
                e.path.endsWith('.roll.json')),
      )
      .cast<File>()
      .toList();

  Future<void> captureFailure(
    FaultIo fault,
    CaptureJob capture,
    int rollId,
  ) async {
    // Staging may recover immediately via its fallback or fail for startup to
    // retry. Either outcome must keep the shot and its complete snapshot.
    try {
      await IOOverrides.runWithIOOverrides(
        () => service.captureIntoRoll(capture, rollId: rollId),
        fault,
      );
    } on FileSystemException {
      // The next process owns recovery.
    } on StateError {
      // A simulated vault outage also leaves an uncommitted capture.
    }
  }

  setUp(() async {
    cache = await Directory.systemTemp.createTemp('carrete_restart_');
    databaseFile = File('${cache.path}/rolls.sqlite');
    vault = FakeVault();
    notifications = FakeNotifications();
    gallery = GalleryProcessor();
    now = DateTime(2026, 11, 13, 12);
    foreground = true;
    open();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('carrete/media'), (
          call,
        ) async {
          expect(call.method, 'findSaved');
          return gallery.findSaved(
            (call.arguments as Map)['displayName'] as String,
          );
        });
  });

  tearDown(() async {
    await operations.run(() async {});
    service.dispose();
    developer.dispose();
    await db.close();
    await cache.delete(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('carrete/media'), null);
  });

  for (final recoveryFirst in [true, false]) {
    test(
      'recovery ${recoveryFirst ? 'ahead of' : 'behind'} a queued capture counts both frames once',
      () async {
        final roll = await service.openRoll(12, DevelopDelay.threeDays);
        vault.storeError = StateError('interrupted capture');
        await expectLater(
          service.captureIntoRoll(await job(), rollId: roll.id),
          throwsStateError,
        );
        vault.storeError = null;

        final release = Completer<void>();
        final blocked = operations.run(() => release.future);
        final queuedJob = await job();
        Future<void>? recovery;
        if (recoveryFirst) recovery = service.recoverCaptures();
        final capture = service.captureIntoRoll(queuedJob, rollId: roll.id);
        recovery ??= service.recoverCaptures();
        try {
          // Wait for staging outside the operation queue, so recovery sees the
          // live journal alongside the interrupted capture's journal.
          var staged = false;
          for (var attempt = 0; attempt < 200; attempt++) {
            final pending = await RollRecovery(cache).pending();
            if (pending.length == 2 &&
                !await File(queuedJob.filePath).exists()) {
              staged = true;
              break;
            }
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
          expect(staged, isTrue);
        } finally {
          release.complete();
        }
        await blocked;
        final shot = await capture;
        await recovery;
        await service.recoverCaptures();
        final frames = await RollsDao(db).shotsOf(roll.id);
        expect(frames.map((s) => s.frameNumber).toSet(), {1, 2});
        expect(frames.map((s) => s.id), contains(shot.id));
        expect(frames, hasLength(2));
        expect(await RollsDao(db).remainingFrames(roll.id), 10);
        expect(vault.files, hasLength(2));
        expect(await plaintext(), isEmpty);
      },
    );
  }

  for (final folderFailure in [true, false]) {
    test(
      folderFailure
          ? 'folder creation failure preserves a recoverable shot across restart'
          : 'rename and copy failure preserves a recoverable shot across restart',
      () async {
        final roll = await service.openRoll(12, DevelopDelay.threeDays);
        final capture = await job();
        final fault = FaultIo()
          ..mkdir = folderFailure
          ..moveAndCopy = !folderFailure;
        vault.storeError = StateError('vault temporarily unavailable');
        await captureFailure(fault, capture, roll.id);
        if (folderFailure) {
          expect(fault.mkdirFailures, greaterThan(0));
        } else {
          expect(fault.renameFailures, greaterThan(0));
          expect(fault.copyFailures, greaterThan(0));
        }
        expect(await plaintext(), isNotEmpty);
        vault.storeError = null;
        await restart();
        expect(await RollsDao(db).shotsTaken(roll.id), 1);
        expect(vault.files.values.single, [1, 2, 3]);
        expect(await plaintext(), isEmpty);
        await restart();
        expect(await RollsDao(db).shotsTaken(roll.id), 1);
        expect(gallery.items, isEmpty);
      },
    );
  }

  test(
    'publication before URI commit produces one gallery item across restart',
    () async {
      final roll = await service.openRoll(12, DevelopDelay.oneHour);
      await service.captureIntoRoll(await job());
      await service.closeRoll();
      await db.customStatement(
        "CREATE TRIGGER fail_gallery BEFORE UPDATE OF gallery_uri ON shots BEGIN SELECT RAISE(FAIL, 'URI commit failed'); END",
      );
      now = now.add(const Duration(hours: 2));
      await expectLater(developer.developDue(now), throwsA(anything));
      expect(gallery.items, hasLength(1));
      expect((await RollsDao(db).shotsOf(roll.id)).single.galleryUri, isNull);
      await db.customStatement('DROP TRIGGER fail_gallery');
      await restart();
      expect(gallery.items, hasLength(1));
      expect(
        (await RollsDao(db).shotsOf(roll.id)).single.galleryUri,
        gallery.items.single.uri,
      );
      expect(vault.files, isEmpty);
    },
  );

  test(
    'lookup_failed preserves a frame until its saved export can be found',
    () async {
      final roll = await service.openRoll(12, DevelopDelay.oneHour);
      await service.captureIntoRoll(await job());
      await service.closeRoll();
      final shot = (await RollsDao(db).shotsOf(roll.id)).single;
      final path = shot.vaultPath!;
      vault.faults[path] = VaultMissingException(path);
      gallery.items.add((
        name: RollDeveloper.displayNameOf(shot),
        uri: 'content://gallery/recovered',
      ));
      var unavailable = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('carrete/media'), (
            call,
          ) async {
            if (unavailable) throw PlatformException(code: 'lookup_failed');
            return gallery.findSaved(
              (call.arguments as Map)['displayName'] as String,
            );
          });
      now = now.add(const Duration(hours: 2));
      await expectLater(
        developer.developDue(now),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'lookup_failed',
          ),
        ),
      );
      final pending = (await RollsDao(db).shotsOf(roll.id)).single;
      expect(pending.galleryUri, isNull);
      expect(pending.developFailure, isNull);
      expect(vault.deleted, isEmpty);
      expect(
        (await RollsDao(db).rollById(roll.id))!.state,
        RollState.developing,
      );

      unavailable = false;
      await developer.developDue(now);
      final recovered = (await RollsDao(db).shotsOf(roll.id)).single;
      expect(recovered.galleryUri, 'content://gallery/recovered');
      expect(recovered.developFailure, isNull);
      expect(gallery.items, hasLength(1));
    },
  );

  test(
    'roll display name is stable across restarts and developing dates',
    () async {
      final roll = await service.openRoll(12, DevelopDelay.oneHour);
      await service.captureIntoRoll(await job());
      await service.closeRoll();
      gallery.afterPublish = () => throw StateError('crash after publish');
      now = now.add(const Duration(hours: 2));
      await expectLater(developer.developDue(now), throwsStateError);
      final firstName = gallery.items.single.name;
      expect(gallery.lookups, [firstName]);
      gallery.afterPublish = null;
      now = now.add(const Duration(days: 10));
      await restart();
      expect(gallery.lookups, [firstName, firstName]);
      expect(
        (await RollsDao(db).shotsOf(roll.id)).single.galleryUri,
        gallery.items.single.uri,
      );
    },
  );

  test(
    'committed capture cleanup after restart counts the shot once',
    () async {
      final roll = await service.openRoll(12, DevelopDelay.threeDays);
      await captureFailure(FaultIo()..cleanup = true, await job(), roll.id);
      expect(await plaintext(), isNotEmpty);
      expect(await RollsDao(db).shotsTaken(roll.id), 1);
      await restart();
      expect(await plaintext(), isEmpty);
      expect(await RollsDao(db).shotsTaken(roll.id), 1);
      expect(vault.files, hasLength(1));
    },
  );

  test('uncommitted open-roll capture recovers once after restart', () async {
    final roll = await service.openRoll(12, DevelopDelay.threeDays);
    vault.storeError = StateError('process died before encryption');
    await expectLater(service.captureIntoRoll(await job()), throwsStateError);
    vault.storeError = null;
    await restart();
    expect(await RollsDao(db).shotsTaken(roll.id), 1);
    expect(await plaintext(), isEmpty);
    await restart();
    expect(await RollsDao(db).shotsTaken(roll.id), 1);
  });

  test(
    'a refused frame on a closed roll leaves no plaintext before developing',
    () async {
      final roll = await service.openRoll(12, DevelopDelay.oneHour);
      await captureFailure(FaultIo()..cleanup = true, await job(), roll.id);
      await service.closeRoll();
      await expectLater(
        service.captureIntoRoll(await job(), rollId: roll.id),
        throwsA(isA<RollRefusedException>()),
      );
      await service.recoverCaptures();
      // Neither the refused original nor the committed leftover waits in
      // plaintext for the develop delay.
      expect(await plaintext(), isEmpty);
      expect(gallery.items, isEmpty);
      await service.developNow(roll.id);
      expect(gallery.items, hasLength(1));
      expect(await plaintext(), isEmpty);
    },
  );

  test(
    'an uncommitted capture of a roll closed meanwhile is dropped at restart',
    () async {
      final roll = await service.openRoll(12, DevelopDelay.threeDays);
      vault.storeError = StateError('vault temporarily unavailable');
      await expectLater(
        service.captureIntoRoll(await job(), rollId: roll.id),
        throwsStateError,
      );
      vault.storeError = null;
      await service.closeRoll(roll.id);
      expect(await plaintext(), isNotEmpty);
      await restart();
      expect(await plaintext(), isEmpty);
      expect(await RollsDao(db).shotsTaken(roll.id), 0);
    },
  );

  test('a frame whose vault file is missing fails alone', () async {
    final roll = await service.openRoll(12, DevelopDelay.threeDays);
    await service.captureIntoRoll(await job(), rollId: roll.id);
    await service.captureIntoRoll(await job(), rollId: roll.id);
    final first = (await RollsDao(db).shotsOf(roll.id)).first;
    vault.faults[first.vaultPath!] = VaultMissingException(first.vaultPath!);
    await service.developNow(roll.id);
    final shots = await RollsDao(db).shotsOf(roll.id);
    expect(shots.firstWhere((s) => s.id == first.id).developFailure, 'missing');
    expect(gallery.items, hasLength(1));
    expect((await RollsDao(db).rollById(roll.id))!.state, RollState.developed);
  });

  test(
    'discard removes all leftover plaintext associated with its roll',
    () async {
      final roll = await service.openRoll(12, DevelopDelay.threeDays);
      await captureFailure(FaultIo()..cleanup = true, await job(), roll.id);
      await service.discardRoll(roll.id);
      expect(await plaintext(), isEmpty);
      expect(vault.files, isEmpty);
    },
  );

  test('interrupted discard survives restart and a second discard', () async {
    final roll = await service.openRoll(12, DevelopDelay.threeDays);
    await service.captureIntoRoll(await job());
    await captureFailure(FaultIo()..cleanup = true, await job(), roll.id);
    // Delete the first vault file, then fail halfway through the discard.
    vault.storeError = StateError('uncommitted capture');
    await expectLater(service.captureIntoRoll(await job()), throwsStateError);
    vault.storeError = null;
    vault.failDeleteAt = 1;
    await expectLater(service.discardRoll(roll.id), throwsStateError);
    expect(vault.files, hasLength(1));
    vault.failDeleteAt = null;
    await restart();
    await service.discardRoll(roll.id);
    expect((await RollsDao(db).rollById(roll.id))!.state, RollState.discarded);
    expect(vault.files, isEmpty);
    expect(await plaintext(), isEmpty);
    expect(gallery.items, isEmpty);
  });

  for (final early in [true, false]) {
    test(
      early
          ? 'paused early development resumes after restart without a reminder'
          : 'paused due development resumes after restart',
      () async {
        final roll = await service.openRoll(12, DevelopDelay.threeDays);
        await service.captureIntoRoll(await job());
        await service.captureIntoRoll(await job());
        await service.closeRoll();
        gallery.afterPublish = () => foreground = false;
        if (early) {
          await service.developNow(roll.id);
        } else {
          now = now.add(const Duration(days: 4));
          await developer.developDue(now);
        }
        expect(gallery.items, hasLength(1));
        expect(
          (await RollsDao(db).rollById(roll.id))!.state,
          RollState.developing,
        );
        gallery.afterPublish = null;
        foreground = true;
        final scheduledBeforeRestart = notifications.scheduledIds.length;
        await restart();
        expect(
          (await RollsDao(db).rollById(roll.id))!.state,
          RollState.developed,
        );
        expect(gallery.items, hasLength(2));
        expect(notifications.scheduled, isEmpty);
        expect(notifications.scheduledIds.length, scheduledBeforeRestart);
      },
    );
  }

  test('restart reschedules the reminder with the photos taken', () async {
    final roll = await service.openRoll(24, DevelopDelay.oneHour);
    for (var i = 0; i < 3; i++) {
      await service.captureIntoRoll(await job());
    }
    await service.closeRoll();
    notifications.scheduledPhotos.clear();
    await restart();
    expect(notifications.scheduledPhotos[roll.id], 3);
  });

  for (final delay in [DevelopDelay.oneHour, DevelopDelay.instant]) {
    test(
      'cleanup failure preserves capture success and ${delay.name} close effects',
      () async {
        final roll = await service.openRoll(12, delay);
        for (var i = 0; i < 11; i++) {
          await service.captureIntoRoll(await job());
        }
        final capture = await job();
        final shot = await IOOverrides.runWithIOOverrides(
          () => service.captureIntoRoll(capture),
          FaultIo()..cleanup = true,
        );
        expect(shot.frameNumber, 12);
        await operations.run(() async {});
        if (delay == DevelopDelay.instant) {
          expect(gallery.items, hasLength(12));
        } else {
          expect(notifications.scheduled, contains(roll.id));
        }
        await restart();
        expect(await plaintext(), isEmpty);
        expect(await RollsDao(db).shotsTaken(roll.id), 12);
      },
    );
  }
}
