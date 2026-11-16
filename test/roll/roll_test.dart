import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:carrete/location/photo_location.dart';
import 'package:carrete/capture/capture_providers.dart';
import 'package:carrete/capture/capture_queue.dart';
import 'package:carrete/capture/failed_shots.dart';
import 'package:carrete/capture/film_capture_processor.dart';
import 'package:carrete/core/database/app_database.dart';
import 'package:carrete/core/database/database_provider.dart';
import 'package:carrete/core/database/develop_schedule.dart';
import 'package:carrete/core/database/rolls_dao.dart';
import 'package:carrete/core/database/shot_vault.dart';
import 'package:carrete/core/database/tables.dart';
import 'package:carrete/core/vault/vault_exceptions.dart';
import 'package:carrete/render/film_resources.dart';
import 'package:carrete/roll/roll_developer.dart';
import 'package:carrete/roll/roll_notifications.dart';
import 'package:carrete/roll/roll_service.dart';
import 'package:carrete/roll/roll_temp_files.dart';
import 'package:carrete/core/settings/settings_provider.dart';
import 'package:film_recipes/film_recipes.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import '../support/test_database.dart';

class FakeVault implements ShotVault {
  final files = <String, Uint8List>{};
  final faults = <String, Object>{};
  final deleted = <String>[];
  Object? storeError;
  bool failDelete = false;
  int? failDeleteAt;
  int next = 0;

  /// When it is set, every write waits for it.
  Completer<void>? storeGate;

  /// Completes when a write starts, so a test can wait for it.
  Completer<void>? storeStarted;

  @override
  Future<String> store(Uint8List bytes) async {
    final started = storeStarted;
    if (started != null && !started.isCompleted) started.complete();
    final gate = storeGate;
    if (gate != null) await gate.future;
    if (storeError != null) throw storeError!;
    final path = 'encrypted-${next++}';
    files[path] = bytes;
    return path;
  }

  @override
  Future<Uint8List> read(String path) async {
    if (faults[path] != null) throw faults[path]!;
    return files[path]!;
  }

  @override
  Future<void> delete(String path) async {
    if (failDelete || deleted.length == failDeleteAt) {
      throw StateError('delete failed');
    }
    deleted.add(path);
    files.remove(path);
  }

  @override
  Future<void> deleteAll() async => files.clear();
}

class FakeNotifications implements RollNotifications {
  int requested = 0;
  bool unavailable = false;
  final scheduled = <int, RollRow>{};
  final scheduledPhotos = <int, int>{};
  final scheduledIds = <int>[];
  final cancelled = <int>[];
  @override
  Future<void> requestPermission() async {
    requested++;
    if (unavailable) throw StateError('denied');
  }

  @override
  Future<void> schedule(RollRow roll, {required int photos}) async {
    if (unavailable) throw StateError('unavailable');
    scheduledIds.add(roll.id);
    scheduled[roll.id] = roll;
    scheduledPhotos[roll.id] = photos;
  }

  @override
  Future<void> cancel(int id) async {
    if (unavailable) throw StateError('unavailable');
    cancelled.add(id);
    scheduled.remove(id);
  }
}

class FakeProcessor implements CaptureProcessor {
  final saved = <CaptureJob>[];
  int? failAt;
  Completer<void>? blocked;

  /// When set, the job goes through it after being recorded here, to check
  /// what the real processor does with a roll frame.
  CaptureProcessor? inner;
  @override
  Future<String?> process(CaptureJob job) async {
    expect(await File(job.filePath).readAsBytes(), [1, 2, 3]);
    if (blocked != null) await blocked!.future;
    if (saved.length == failAt) throw StateError('simulated process death');
    saved.add(job);
    final real = inner;
    if (real != null) return real.process(job);
    return 'gallery://${saved.length}';
  }
}

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late Directory cache;
  late FakeVault vault;
  late FakeNotifications notifications;
  late FakeProcessor processor;
  late RollService service;
  late RollDeveloper developer;
  late RollsDao rolls;
  late DateTime now;
  final book = testBook();
  var photoNumber = 0;

  Future<CaptureJob> job({bool saveOriginal = false}) async {
    final file = File('${cache.path}/CAP${photoNumber++}.jpg');
    await file.writeAsBytes([1, 2, 3]);
    return CaptureJob(
      filePath: file.path,
      filmId: 'gamma',
      look: resolve(book.byId('gamma')!),
      format: FrameFormat.r3x2,
      seed: 42.5,
      takenAt: now,
      fieldAspect: 0.5625,
      stampText: "'26 11 13",
      includeLocation: true,
      saveOriginal: saveOriginal,
    );
  }

  Future<RollRow> filled({
    DevelopDelay delay = DevelopDelay.oneHour,
    int count = 2,
    bool saveOriginal = false,
  }) async {
    final roll = await service.openRoll(12, delay);
    for (var i = 0; i < count; i++) {
      await service.captureIntoRoll(await job(saveOriginal: saveOriginal));
    }
    await service.closeRoll();
    return (await rolls.rollById(roll.id))!;
  }

  setUp(() async {
    db = openMemoryDatabase();
    rolls = RollsDao(db);
    cache = await Directory.systemTemp.createTemp('carrete_roll_test_');
    vault = FakeVault();
    notifications = FakeNotifications();
    processor = FakeProcessor();
    now = DateTime(2026, 11, 13, 21, 30);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        cacheDirectoryProvider.overrideWithValue(cache),
        sharedPreferencesProvider.overrideWithValue(prefs),
        shotVaultProvider.overrideWithValue(vault),
        rollNotificationsProvider.overrideWithValue(notifications),
        rollCaptureProcessorProvider.overrideWithValue(processor),
        rollSavedLookupProvider.overrideWithValue((_) async => null),
        rollClockProvider.overrideWithValue(() => now),
        recipeBookProvider.overrideWith((ref) async => book),
      ],
    );
    service = container.read(rollServiceProvider);
    developer = container.read(rollDeveloperProvider);
  });
  tearDown(() async {
    await container.read(rollOperationsProvider).run(() async {});
    container.dispose();
    await db.close();
    await cache.delete(recursive: true);
  });

  for (final delay in DevelopDelay.values) {
    test('12 captures auto-close with ${delay.name} schedule', () async {
      final roll = await service.openRoll(12, delay);
      for (var i = 0; i < 12; i++) {
        final capture = await job();
        final shot = await service.captureIntoRoll(capture);
        expect(shot.frameNumber, i + 1);
        expect(shot.galleryUri, isNull);
        expect(
          jsonDecode(shot.captureJobJson!)['version'],
          FailedShots.jobVersion,
        );
        expect(await File(capture.filePath).exists(), isFalse);
        expect(await rolls.remainingFrames(roll.id), 11 - i);
      }
      final closed = (await rolls.rollById(roll.id))!;
      expect(closed.closedAt, now.millisecondsSinceEpoch);
      expect(closed.developAt, developAtFor(delay, now).millisecondsSinceEpoch);
      expect(await rolls.activeRoll(), isNull);
      if (delay != DevelopDelay.instant) {
        expect(notifications.scheduled[roll.id]?.developAt, closed.developAt);
        expect(notifications.scheduledPhotos[roll.id], 12);
        expect(processor.saved, isEmpty);
      } else {
        await container.read(rollOperationsProvider).run(() async {});
        expect(processor.saved.length, 12);
        expect(notifications.requested, 0);
      }
    });
  }

  test(
    'a roll closed early announces the photos taken, not its length',
    () async {
      final roll = await service.openRoll(24, DevelopDelay.oneHour);
      await service.captureIntoRoll(await job());
      await service.captureIntoRoll(await job());
      await service.closeRoll();
      expect(notifications.scheduledPhotos[roll.id], 2);
    },
  );

  test('only one open roll, including concurrent open requests', () async {
    final first = service.openRoll(24, DevelopDelay.oneHour);
    final second = service.openRoll(36, DevelopDelay.threeDays);
    await expectLater(second, throwsA(isA<OpenRollExistsException>()));
    expect((await first).length, 24);
    expect((await rolls.allRolls()).length, 1);
  });

  test('invalid lengths are refused without opening a roll', () async {
    await expectLater(
      service.openRoll(27, DevelopDelay.instant),
      throwsArgumentError,
    );
    expect(await rolls.allRolls(), isEmpty);
  });

  test(
    'a queued capture protects its original while development is busy',
    () async {
      final roll = await service.openRoll(12, DevelopDelay.oneHour);
      final busy = Completer<void>();
      final started = Completer<void>();
      final holding = container.read(rollOperationsProvider).run(() async {
        started.complete();
        await busy.future;
      });
      await started.future;
      final capture = await job();
      final saving = service.captureIntoRoll(capture, rollId: roll.id);
      try {
        await Future.doWhile(() => File(capture.filePath).exists())
            .timeout(const Duration(seconds: 3));
        await cleanCaptureLeftovers(cache);
        expect(vault.files, isEmpty, reason: 'still queued');
      } finally {
        busy.complete();
      }
      await holding;
      await saving;
      expect(vault.files, hasLength(1));
    },
  );

  test('startup removes abandoned decrypted temps and preserves recovery originals', () async {
    final temp = await Directory('${cache.path}/roll-develop').create();
    await File('${temp.path}/old.jpg').writeAsBytes([1, 2, 3]);
    final recovery = await Directory('${cache.path}/roll-recovery').create();
    final original = await File('${recovery.path}/original.jpg')
        .writeAsBytes([1, 2, 3]);
    await cleanRollDevelopmentTemps(cache);
    expect(await temp.list().isEmpty, isTrue);
    expect(await original.readAsBytes(), [1, 2, 3]);
  });

  test(
    'capture failure preserves original and settings across startup cleanup',
    () async {
      await service.openRoll(12, DevelopDelay.oneHour);
      final capture = await job();
      vault.storeError = StateError('disk full');
      await expectLater(service.captureIntoRoll(capture), throwsStateError);
      await cleanCaptureLeftovers(cache);
      final retained = await Directory('${cache.path}/roll-recovery')
          .list(recursive: true)
          .where((f) => f.path.endsWith('original.jpg'))
          .toList();
      expect(retained, hasLength(1));
      expect(await File(retained.single.path).readAsBytes(), [1, 2, 3]);
      final json = jsonDecode(
        await File('${retained.single.parent.path}/capture.json')
            .readAsString(),
      );
      expect(json['job']['filmId'], capture.filmId);
      expect(
        await FailedShots(Directory('${cache.path}/failed')).pending(book),
        isEmpty,
      );
      expect(processor.saved, isEmpty);
      expect(await rolls.shotsTaken((await rolls.activeRoll())!.id), 0);
    },
  );

  test(
    'refused capture leaves neither plaintext nor an orphan vault entry',
    () async {
      final roll = await service.openRoll(12, DevelopDelay.oneHour);
      await service.closeRoll();
      await expectLater(
        service.captureIntoRoll(await job(), rollId: roll.id),
        throwsA(isA<Exception>()),
      );
      expect(vault.files, isEmpty);
      expect(
        await Directory('${cache.path}/roll-recovery')
            .list(recursive: true)
            .where((f) => f is File && f.path.endsWith('.jpg'))
            .length,
        0,
      );
    },
  );

  test('a capture with no roll to take it leaves no plaintext', () async {
    await expectLater(
      service.captureIntoRoll(await job()),
      throwsA(isA<NoActiveRollException>()),
    );
    expect(vault.files, isEmpty);
    expect(
      await cache
          .list(recursive: true)
          .where(
            (f) =>
                f is File &&
                (f.path.endsWith('.jpg') || f.path.endsWith('.roll.json')),
          )
          .length,
      0,
    );
  });

  test(
    'the originals of a roll are saved when it develops, never before',
    () async {
      final names = <String>[];
      final sources = <String>[];
      final inGallery = <String>{};
      processor.inner = FilmCaptureProcessor(
        loadProgram: () async => throw StateError('no shader in this test'),
        findSavedOriginal: (name) async =>
            inGallery.contains(name) ? name : null,
        saveOriginal:
            ({
              required String sourcePath,
              required String name,
              required bool includeLocation,
              PhotoLocation? location,
              DateTime? takenAt,
            }) async {
              sources.add(sourcePath);
              names.add(name);
              inGallery.add(name);
              return name;
            },
        save: (job) async => SavedStill('gallery://${job.displayName}'),
      );

      // Taking and closing the roll saves nothing, not even an original: the
      // frames are encrypted in the vault and the gallery knows nothing.
      final roll = await filled(saveOriginal: true);
      expect(names, isEmpty);
      expect(processor.saved, isEmpty);
      expect(vault.files, hasLength(2));
      final stored = jsonDecode(
        (await rolls.shotsOf(roll.id)).first.captureJobJson!,
      );
      expect(stored['saveOriginal'], isTrue);

      await service.developNow(roll.id);

      final shots = await rolls.shotsOf(roll.id);
      expect(names, [
        for (final shot in shots)
          '${RollDeveloper.displayNameOf(shot)}_original',
      ]);
      expect(names.toSet(), hasLength(2));
      // The copy is read from the decrypted temporary file, which is gone now.
      expect(sources.every((path) => path.contains('roll-develop')), isTrue);
      expect(vault.files, isEmpty);

      // Developing again saves nothing twice.
      await developer.develop(roll.id);
      expect(names, hasLength(2));
    },
  );

  test('a roll taken without the setting saves no originals', () async {
    var saves = 0;
    processor.inner = FilmCaptureProcessor(
      loadProgram: () async => throw StateError('no shader in this test'),
      saveOriginal:
          ({
            required String sourcePath,
            required String name,
            required bool includeLocation,
            PhotoLocation? location,
            DateTime? takenAt,
          }) async {
            saves++;
            return name;
          },
      save: (job) async => SavedStill('gallery://${job.displayName}'),
    );
    final roll = await filled();
    await service.developNow(roll.id);

    expect(processor.saved, hasLength(2));
    expect(saves, 0);
  });

  test(
    'develop all with original settings, progress, URIs and no plaintext left',
    () async {
      final roll = await filled();
      final progress = <DevelopProgress>[];
      final sub = developer.progress.listen(progress.add);
      await service.developNow(roll.id);
      await Future<void>.delayed(Duration.zero);
      expect((await rolls.rollById(roll.id))!.state, RollState.developed);
      final shots = await rolls.shotsOf(roll.id);
      expect(shots.map((s) => s.galleryUri), ['gallery://1', 'gallery://2']);
      expect(shots.every((s) => s.vaultPath == null), isTrue);
      expect(processor.saved.first.seed, 42.5);
      expect(processor.saved.first.includeLocation, isTrue);
      expect(processor.saved.first.stampText, "'26 11 13");
      expect(progress.last.done, 2);
      expect(progress.last.total, 2);
      expect(vault.files, isEmpty);
      expect(notifications.cancelled, contains(roll.id));
      expect(
        await Directory('${cache.path}/roll-develop').list().isEmpty,
        isTrue,
      );
      await developer.develop(roll.id);
      expect(processor.saved, hasLength(2));
      await sub.cancel();
    },
  );

  test(
    'retries a processing interruption without saving committed photos twice',
    () async {
      final roll = await filled(count: 3);
      processor.failAt = 1;
      await expectLater(developer.develop(roll.id), throwsStateError);
      expect((await rolls.rollById(roll.id))!.state, RollState.developing);
      expect(processor.saved, hasLength(1));
      expect(
        await Directory('${cache.path}/roll-develop').list().isEmpty,
        isTrue,
      );
      processor.failAt = null;
      await developer.develop(roll.id);
      expect(processor.saved, hasLength(3));
      expect(
        (await rolls.shotsOf(roll.id)).map((s) => s.galleryUri).toSet(),
        hasLength(3),
      );
    },
  );

  test(
    'URI commit followed by vault cleanup failure retries without republishing',
    () async {
      final roll = await filled(count: 1);
      vault.failDelete = true;
      await expectLater(developer.develop(roll.id), throwsStateError);
      expect((await rolls.shotsOf(roll.id)).single.galleryUri, 'gallery://1');
      vault.failDelete = false;
      await developer.develop(roll.id);
      expect(processor.saved, hasLength(1));
      expect(vault.files, isEmpty);
      expect((await rolls.rollById(roll.id))!.state, RollState.developed);
    },
  );

  test(
    'lost key on any frame marks roll lost before publishing any frame',
    () async {
      final roll = await filled();
      vault.faults['encrypted-1'] = const VaultKeyLostException('encrypted-1');
      await developer.develop(roll.id);
      expect((await rolls.rollById(roll.id))!.state, RollState.lost);
      expect(
        (await rolls.rollById(roll.id))!.lostAt,
        now.millisecondsSinceEpoch,
      );
      expect(processor.saved, isEmpty);
      expect(vault.files, hasLength(2));
      expect(
        await Directory('${cache.path}/roll-develop').list().isEmpty,
        isTrue,
      );
      await developer.develop(roll.id);
      expect(processor.saved, isEmpty);
    },
  );

  test('corrupted frame is counted as failed and the rest develop', () async {
    final roll = await filled(count: 3);
    vault.faults['encrypted-1'] = const VaultCorruptedException(
      'encrypted-1',
      VaultCorruption.tampered,
    );
    await developer.develop(roll.id);
    expect(processor.saved, hasLength(2));
    final shots = await rolls.shotsOf(roll.id);
    expect(shots[1].developFailure, 'corrupted');
    expect(shots[1].galleryUri, isNull);
    expect(developer.latestProgress(roll.id)!.failed, 1);
    expect(developer.latestProgress(roll.id)!.done, 3);
    expect((await rolls.rollById(roll.id))!.state, RollState.developed);
    await developer.develop(roll.id);
    expect(processor.saved, hasLength(2));
  });

  test('discard deletes only its vault files, cancels notification and is idempotent', () async {
    final roll = await filled();
    await vault.store(Uint8List.fromList([99]));
    await service.discardRoll(roll.id);
    await service.discardRoll(roll.id);
    expect(vault.files.keys, ['encrypted-2']);
    expect((await rolls.rollById(roll.id))!.state, RollState.discarded);
    expect(notifications.scheduled, isEmpty);
    expect(notifications.cancelled, contains(roll.id));
    await developer.develop(roll.id);
    expect(processor.saved, isEmpty);
  });

  test(
    'notification permission is requested on delayed roll actions only',
    () async {
      expect(notifications.requested, 0);
      final roll = await filled();
      expect(notifications.requested, 2);
      expect(notifications.scheduled.keys, [roll.id]);
      await service.developNow(roll.id);
      expect(notifications.cancelled, contains(roll.id));
      expect(notifications.scheduled, isEmpty);
    },
  );

  test('notification denial never prevents capture, closing or foreground developing', () async {
    notifications.unavailable = true;
    final roll = await filled();
    now = now.add(const Duration(hours: 2));
    await developer.developDue(now);
    expect((await rolls.rollById(roll.id))!.state, RollState.developed);
    expect(processor.saved, hasLength(2));
  });

  test('developDue selects only due, closed, healthy rolls', () async {
    final due = await filled();
    final later = await filled(delay: DevelopDelay.threeDays);
    final discarded = await filled();
    await service.discardRoll(discarded.id);
    final open = await service.openRoll(24, DevelopDelay.oneHour);
    now = now.add(const Duration(hours: 1));
    await developer.developDue(now);
    expect((await rolls.rollById(due.id))!.state, RollState.developed);
    expect((await rolls.rollById(later.id))!.state, RollState.developing);
    expect((await rolls.rollById(open.id))!.state, RollState.open);
    expect((await rolls.rollById(discarded.id))!.state, RollState.discarded);
    expect(processor.saved, hasLength(2));
  });

  test('concurrent developing and discard are serialized', () async {
    final roll = await filled();
    processor.blocked = Completer<void>();
    final developing = developer.develop(roll.id);
    final discard = service.discardRoll(roll.id);
    processor.blocked!.complete();
    await Future.wait([developing, discard]);
    expect(processor.saved, hasLength(2));
    expect(vault.files, isEmpty);
  });

  test(
    'providers expose active roll, remaining frames, list, shots and progress',
    () async {
      final subscriptions = [
        container.listen(activeRollProvider, (_, _) {}),
        container.listen(remainingFramesProvider, (_, _) {}),
        container.listen(rollsListProvider, (_, _) {}),
      ];
      expect(await container.read(activeRollProvider.future), isNull);
      final roll = await service.openRoll(36, DevelopDelay.oneHour);
      expect((await service.activeRoll.first)!.id, roll.id);
      expect(await service.remainingFrames.first, 36);
      await service.captureIntoRoll(await job());
      expect(await service.remainingFrames.first, 35);
      final shotsSubscription = container.listen(
        rollShotsProvider(roll.id),
        (_, _) {},
      );
      final frames = await container.read(rollShotsProvider(roll.id).future);
      expect(frames, hasLength(1));
      expect(frames.single.galleryUri, isNull);
      expect(
        (await container.read(rollsListProvider.future)).single.length,
        36,
      );
      await service.developNow(roll.id);
      final progressSubscription = container.listen(
        rollDevelopProgressProvider(roll.id),
        (_, _) {},
      );
      expect(
        (await container.read(rollDevelopProgressProvider(roll.id).future))
            .done,
        1,
      );
      expect(
        (await service.shotsOf(roll.id).first).single.galleryUri,
        'gallery://1',
      );
      for (final sub in subscriptions) {
        sub.close();
      }
      shotsSubscription.close();
      progressSubscription.close();
    },
  );

  test(
    'foreground triggers pause and coalesce, then develop on resume',
    () async {
      final roll = await filled();
      now = now.add(const Duration(hours: 2));
      final foreground = container.read(rollForegroundProvider);
      foreground.didChangeAppLifecycleState(AppLifecycleState.paused);
      await foreground.run();
      expect(processor.saved, isEmpty);
      foreground.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await foreground.run();
      expect((await rolls.rollById(roll.id))!.state, RollState.developed);
      expect(processor.saved, hasLength(2));
    },
  );

  group('the recovery of a frame', () {
    /// A capture that died before the vault write leaves its journal behind,
    /// ready for the recovery of the next start.
    Future<RollRow> interruptedCapture() async {
      final roll = await service.openRoll(12, DevelopDelay.threeDays);
      vault.storeError = StateError('the vault was closed');
      await expectLater(service.captureIntoRoll(await job()), throwsStateError);
      return roll;
    }

    test('counts the frame as saving while it is committed', () async {
      final roll = await interruptedCapture();
      vault.storeError = null;
      final activity = container.read(saveActivityProvider);
      expect(activity.saving.value, 0);

      // The write into the vault is held back: the frame is being saved.
      final gate = Completer<void>();
      final started = Completer<void>();
      vault.storeGate = gate;
      vault.storeStarted = started;

      final recovery = service.recoverCaptures();
      await started.future;
      expect(activity.saving.value, 1, reason: 'the frame is being saved');

      gate.complete();
      await recovery;
      expect(activity.saving.value, 0);
      expect(await rolls.shotsTaken(roll.id), 1);
    });

    test('stops counting the frame when the recovery fails', () async {
      final roll = await interruptedCapture();
      final activity = container.read(saveActivityProvider);
      final errors = <Object>[];
      final subscription = service.notificationErrors.listen(errors.add);
      addTearDown(subscription.cancel);

      final gate = Completer<void>();
      final started = Completer<void>();
      vault.storeGate = gate;
      vault.storeStarted = started;

      final recovery = service.recoverCaptures();
      await started.future;
      expect(activity.saving.value, 1, reason: 'the frame is being saved');

      // The write into the vault fails: the frame is not saved.
      gate.complete();
      await recovery;
      expect(activity.saving.value, 0);
      expect(errors, hasLength(1));
      expect(await rolls.shotsTaken(roll.id), 0);
    });
  });

  group('naming a roll', () {
    test('a new roll has no name and rolls that exist keep none', () async {
      final roll = await service.openRoll(12, DevelopDelay.oneHour);
      expect(roll.name, isNull);
    });

    test('stores the name cleaned up and says what it stored', () async {
      final roll = await service.openRoll(12, DevelopDelay.oneHour);
      expect(
        await service.renameRoll(roll.id, '  Verano \n  en   la playa  '),
        'Verano en la playa',
      );
      expect((await rolls.rollById(roll.id))!.name, 'Verano en la playa');
    });

    test('an empty or blank name clears it', () async {
      final roll = await service.openRoll(12, DevelopDelay.oneHour);
      await service.renameRoll(roll.id, 'Verano');
      expect(await service.renameRoll(roll.id, '   '), isNull);
      expect((await rolls.rollById(roll.id))!.name, isNull);
      await service.renameRoll(roll.id, 'Otoño');
      await service.renameRoll(roll.id, null);
      expect((await rolls.rollById(roll.id))!.name, isNull);
    });

    test('cuts a long name at 40 characters, emoji and all', () async {
      final roll = await service.openRoll(12, DevelopDelay.oneHour);
      final stored = await service.renameRoll(roll.id, '👨‍👩‍👧' * 60);
      expect(stored, '👨‍👩‍👧' * 40);
      expect((await rolls.rollById(roll.id))!.name, stored);
    });

    test(
      'names a roll in any state, and the name outlives developing',
      () async {
        final roll = await filled();
        await service.renameRoll(roll.id, 'Boda de Laia');
        now = now.add(const Duration(hours: 2));
        await developer.develop(roll.id);
        final developed = (await rolls.rollById(roll.id))!;
        expect(developed.state, RollState.developed);
        expect(developed.name, 'Boda de Laia');
      },
    );

    test('naming a roll that does not exist fails', () async {
      await expectLater(
        service.renameRoll(99, 'Nada'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('goes through the queue of the other roll operations', () async {
      final roll = await service.openRoll(12, DevelopDelay.oneHour);
      final gate = Completer<void>();
      final operations = container.read(rollOperationsProvider);
      unawaited(operations.run(() => gate.future));
      var done = false;
      final rename = service.renameRoll(roll.id, 'Despues').then((_) {
        done = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(done, isFalse, reason: 'it waits for the operation before it');
      gate.complete();
      await rename;
      expect((await rolls.rollById(roll.id))!.name, 'Despues');
    });
  });
}
