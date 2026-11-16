import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:carrete/capture/capture_providers.dart';
import 'package:carrete/capture/capture_queue.dart';
import 'package:carrete/core/database/app_database.dart';
import 'package:carrete/core/database/database_provider.dart';
import 'package:carrete/core/database/rolls_dao.dart';
import 'package:carrete/core/database/shots_dao.dart';
import 'package:carrete/core/database/tables.dart';
import 'package:carrete/core/database/converters.dart';
import 'package:carrete/core/settings/film_tuning.dart';
import 'package:carrete/core/settings/settings_provider.dart';
import 'package:carrete/render/film_resources.dart';
import 'package:carrete/roll/disposable.dart';
import 'package:carrete/roll/roll_recovery.dart';
import 'package:carrete/roll/roll_service.dart';
import 'package:film_recipes/film_recipes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';
import '../support/test_database.dart';
import 'roll_test.dart' show FakeNotifications, FakeProcessor, FakeVault;

RollRow _row({
  int id = 5,
  RollMode mode = RollMode.disposable,
  RollState state = RollState.open,
}) => RollRow(
  id: id,
  filmId: 'desechable',
  length: 27,
  mode: mode,
  developDelay: DevelopDelay.nextMorning,
  state: state,
  createdAt: 1,
);

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late Directory cache;
  late FakeNotifications notifications;
  late RollService service;
  late RollsDao rolls;
  late DateTime now;
  late SharedPreferences prefs;
  final book = testBook();
  var photo = 0;

  Future<CaptureJob> job() async {
    final file = File('${cache.path}/CAP${photo++}.jpg');
    await file.writeAsBytes([1, 2, 3]);
    return CaptureJob(
      filePath: file.path,
      filmId: 'gamma',
      look: resolve(book.byId('gamma')!),
      format: FrameFormat.r3x2,
      seed: 42.5,
      takenAt: now,
      fieldAspect: 0.5625,
    );
  }

  setUp(() async {
    db = openMemoryDatabase();
    rolls = RollsDao(db);
    cache = await Directory.systemTemp.createTemp('carrete_disposable_test_');
    notifications = FakeNotifications();
    now = DateTime(2026, 11, 13, 21, 30);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        cacheDirectoryProvider.overrideWithValue(cache),
        sharedPreferencesProvider.overrideWithValue(prefs),
        shotVaultProvider.overrideWithValue(FakeVault()),
        rollNotificationsProvider.overrideWithValue(notifications),
        rollCaptureProcessorProvider.overrideWithValue(FakeProcessor()),
        rollSavedLookupProvider.overrideWithValue((_) async => null),
        rollClockProvider.overrideWithValue(() => now),
        recipeBookProvider.overrideWith((ref) async => book),
      ],
    );
    service = container.read(rollServiceProvider);
  });
  tearDown(() async {
    await container.read(rollOperationsProvider).run(() async {});
    container.dispose();
    await db.close();
    await cache.delete(recursive: true);
  });

  test('the fixed disposable frame ignores cinema bands', () async {
    const tuning = FilmTuning(cinemaBands: true, format: FrameFormat.r16x9);
    final wide = (await job()).withFrame(
      look: resolve(book.recipes.first, overrides: tuning.overrides),
      format: FrameFormat.r16x9,
      tuning: tuning,
      whiteFrame: false,
    );
    expect(wide.cinemaBands, isTrue);
    final fixed = disposableFrame(wide, book);
    expect(fixed.format, FrameFormat.r3x2);
    expect(fixed.cinemaBands, isFalse);
  });

  group('the disposable roll', () {
    test('is a roll of 27 frames in disposable mode', () async {
      final roll = await service.openDisposable(
        kDisposableDefaultDelay,
        filmId: kDisposableFilmId,
      );
      expect(roll.length, kDisposableFrames);
      expect(roll.length, 27);
      expect(roll.mode, RollMode.disposable);
      expect(roll.state, RollState.open);
      expect(roll.filmId, 'desechable');
      expect(roll.developDelay, DevelopDelay.nextMorning);
      expect(await rolls.remainingFrames(roll.id), 27);
    });

    test('develops the next morning unless another time is picked', () {
      expect(kDisposableDefaultDelay, DevelopDelay.nextMorning);
    });

    test('does not open a normal roll of 27', () {
      expect(
        () => service.openRoll(27, DevelopDelay.oneHour),
        throwsArgumentError,
      );
    });

    // A job as the camera of design A would make it for a square instant film:
    // 1:1, a white border, and the format chosen in the tuning.
    Future<CaptureJob> squareJob() async {
      final plain = await job();
      return plain.withFrame(
        look: resolve(
          book.byId('gamma')!,
          overrides: const FilmTuning(format: FrameFormat.r1x1).overrides,
        ),
        format: FrameFormat.r1x1,
        tuning: const FilmTuning(format: FrameFormat.r1x1),
        whiteFrame: true,
      );
    }

    test('frames are 3:2 with no white border, from any path', () async {
      final roll = await service.openDisposable(DevelopDelay.nextMorning);
      final square = await squareJob();
      expect(square.format, FrameFormat.r1x1);
      expect(square.whiteFrame, isTrue);
      // Handed over with the roll id, as the locked screen does ...
      final one = await service.captureIntoRoll(square, rollId: roll.id);
      // ... and with none, as the camera of design A would.
      final two = await service.captureIntoRoll(await squareJob());
      for (final shot in [one, two]) {
        expect(shot.format, ShotFormat.ratio3x2);
        final saved = jsonDecode(shot.captureJobJson!) as Map;
        expect(saved['format'], '3:2');
        expect(saved['whiteFrame'], isFalse);
      }
    });

    test('a capture staged before, as the normal camera made it, is fixed '
        'when it is recovered', () async {
      final roll = await service.openDisposable(DevelopDelay.nextMorning);
      // An earlier run staged a square frame with a white border and its own
      // tuning, and was killed before committing it.
      await RollRecovery(cache)
          .stage(await squareJob(), roll.id, ShotLens.back);
      expect(await rolls.shotsTaken(roll.id), 0);

      await service.recoverCaptures();

      final shots = await rolls.shotsOf(roll.id);
      expect(shots, hasLength(1));
      expect(shots.single.format, ShotFormat.ratio3x2);
      final saved = jsonDecode(shots.single.captureJobJson!) as Map;
      expect(saved['format'], '3:2');
      expect(saved['whiteFrame'], isFalse);
      expect(
        FilmTuning.fromJson(Map<String, Object?>.from(saved['tuning'] as Map)),
        kDisposableTuning,
      );
    });

    test('a normal roll keeps the frame it was given', () async {
      await service.openRoll(12, DevelopDelay.oneHour);
      final shot = await service.captureIntoRoll(await squareJob());
      expect(shot.format, ShotFormat.ratio1x1);
      final saved = jsonDecode(shot.captureJobJson!) as Map;
      expect(saved['format'], '1:1');
      expect(saved['whiteFrame'], isTrue);
    });

    test('takes 27 photos, closes by itself and then refuses more', () async {
      final roll = await service.openDisposable(DevelopDelay.nextMorning);
      for (var i = 0; i < 26; i++) {
        final shot = await service.captureIntoRoll(await job());
        expect(shot.frameNumber, i + 1);
      }
      expect((await rolls.rollById(roll.id))!.state, RollState.open);
      expect(await rolls.remainingFrames(roll.id), 1);

      final last = await service.captureIntoRoll(await job());
      expect(last.frameNumber, 27);
      final closed = (await rolls.rollById(roll.id))!;
      expect(closed.state, RollState.developing);
      expect(closed.closedAt, now.millisecondsSinceEpoch);
      // The next morning, and the reminder is set for that time.
      expect(
        DateTime.fromMillisecondsSinceEpoch(closed.developAt!),
        DateTime(2026, 11, 14, nextMorningHour),
      );
      expect(notifications.scheduled.keys, [roll.id]);
      expect(notifications.scheduledPhotos[roll.id], 27);
      expect(await rolls.activeRoll(), isNull);

      // A 28th shutter press has no roll to go in.
      await expectLater(
        service.captureIntoRoll(await job(), rollId: roll.id),
        throwsA(
          isA<RollRefusedException>().having(
            (e) => e.reason,
            'reason',
            RollRefusal.notOpen,
          ),
        ),
      );
      expect(await rolls.shotsTaken(roll.id), 27);
    });

    test('is due at once when that is the time picked', () async {
      final roll = await service.openDisposable(DevelopDelay.instant);
      for (var i = 0; i < 27; i++) {
        await service.captureIntoRoll(await job());
      }
      final closed = (await rolls.rollById(roll.id))!;
      expect(closed.state, RollState.developing);
      expect(closed.developAt, closed.closedAt);
      expect(notifications.scheduled, isEmpty);
    });

    test('cannot start while another roll is open', () async {
      final first = await service.openRoll(12, DevelopDelay.oneHour);
      await expectLater(
        service.openDisposable(DevelopDelay.nextMorning),
        throwsA(
          isA<OpenRollExistsException>().having(
            (e) => e.rollId,
            'rollId',
            first.id,
          ),
        ),
      );
    });

    test('set aside keeps its photos and the frames left', () async {
      final roll = await service.openDisposable(DevelopDelay.nextMorning);
      for (var i = 0; i < 3; i++) {
        await service.captureIntoRoll(await job());
      }
      final lock = container.read(disposableLockProvider.notifier);
      await lock.lock(roll.id);
      await lock.release();
      final kept = (await rolls.rollById(roll.id))!;
      expect(kept.state, RollState.open);
      expect(await rolls.remainingFrames(roll.id), 24);
    });
  });

  group('the lock at start', () {
    DisposableLock lock() => container.read(disposableLockProvider.notifier);
    const shortWait = Duration(milliseconds: 10);

    Future<void> settle() async {
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
    }

    test('is checked against a prompt answer', () async {
      await lock().lock(5);
      await reconcileDisposableLock(lock(), Future.value(null));
      expect(container.read(disposableLockProvider), isNull);
    });

    test('is checked against a late null too', () async {
      await lock().lock(5);
      final answer = Completer<RollRow?>();
      await reconcileDisposableLock(lock(), answer.future, wait: shortWait);
      // The start did not wait for it and the lock stays for now.
      expect(container.read(disposableLockProvider), 5);
      answer.complete(null);
      await settle();
      expect(container.read(disposableLockProvider), isNull);
    });

    test('is checked against a late answer with another roll', () async {
      await lock().lock(5);
      final answer = Completer<RollRow?>();
      await reconcileDisposableLock(lock(), answer.future, wait: shortWait);
      answer.complete(_row(id: 9));
      await settle();
      expect(container.read(disposableLockProvider), isNull);
    });

    test('is kept by a late answer with its own open roll', () async {
      await lock().lock(5);
      final answer = Completer<RollRow?>();
      await reconcileDisposableLock(lock(), answer.future, wait: shortWait);
      answer.complete(_row());
      await settle();
      expect(container.read(disposableLockProvider), 5);
    });

    test('a late answer does not clear a newer lock', () async {
      await lock().lock(5);
      final answer = Completer<RollRow?>();
      await reconcileDisposableLock(lock(), answer.future, wait: shortWait);
      // The person left and started another disposable meanwhile.
      await lock().release();
      await lock().lock(9);
      answer.complete(null);
      await settle();
      expect(container.read(disposableLockProvider), 9);
      expect(prefs.getInt('carrete.disposable.rollId'), 9);
    });

    test(
      'a late answer with the old roll does not clear a newer lock',
      () async {
        await lock().lock(5);
        final answer = Completer<RollRow?>();
        await reconcileDisposableLock(lock(), answer.future, wait: shortWait);
        await lock().lock(9);
        answer.complete(_row(state: RollState.developing));
        await settle();
        expect(container.read(disposableLockProvider), 9);
      },
    );

    test('a failing answer leaves the lock and throws nothing', () async {
      await lock().lock(5);
      await reconcileDisposableLock(
        lock(),
        Future<RollRow?>.error(StateError('db')),
      );
      expect(container.read(disposableLockProvider), 5);
    });
  });

  group('the lock', () {
    DisposableLock lock() => container.read(disposableLockProvider.notifier);

    test('is kept on the device', () async {
      expect(container.read(disposableLockProvider), isNull);
      await lock().lock(5);
      expect(container.read(disposableLockProvider), 5);
      expect(prefs.getInt('carrete.disposable.rollId'), 5);
      await lock().release();
      expect(container.read(disposableLockProvider), isNull);
      expect(prefs.getInt('carrete.disposable.rollId'), isNull);
    });

    test('survives a restart', () async {
      await lock().lock(5);
      final again = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(again.dispose);
      expect(again.read(disposableLockProvider), 5);
    });

    test('stays for an open disposable roll', () async {
      await lock().lock(5);
      await lock().releaseIfStale(_row());
      expect(container.read(disposableLockProvider), 5);
    });

    final stale = <String, RollRow?>{
      'no roll': null,
      'another roll': _row(id: 6),
      'a closed roll': _row(state: RollState.developing),
      'a normal roll': _row(mode: RollMode.roll),
    };
    for (final entry in stale.entries) {
      test('is dropped when there is ${entry.key}', () async {
        await lock().lock(5);
        await lock().releaseIfStale(entry.value);
        expect(container.read(disposableLockProvider), isNull);
        expect(prefs.getInt('carrete.disposable.rollId'), isNull);
      });
    }
  });
}
