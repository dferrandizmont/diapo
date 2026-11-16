import 'dart:convert';
import 'dart:io';

import 'package:diapo/capture/capture_queue.dart';
import 'package:diapo/capture/failed_shots.dart';
import 'package:diapo/core/database/app_database.dart';
import 'package:diapo/core/database/rolls_dao.dart';
import 'package:diapo/core/database/tables.dart';
import 'package:diapo/core/vault/encrypted_shot_vault.dart';
import 'package:diapo/core/vault/vault_key_store.dart';
import 'package:diapo/location/photo_location.dart';
import 'package:diapo/roll/roll_developer.dart';
import 'package:diapo/roll/roll_operations.dart';
import 'package:diapo/roll/roll_recovery.dart';
import 'package:diapo/roll/roll_service.dart';
import 'package:diapo/roll/roll_vault_payload.dart';
import 'package:film_recipes/film_recipes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/local_shutter_time.dart';
import '../support/test_database.dart';
import 'roll_test.dart' show FakeNotifications, FakeProcessor;

void main() {
  late Directory root;
  late EncryptedShotVault vault;
  late AppDatabase db;
  final book = testBook();
  final when = DateTime.utc(2026, 11, 14, 12);

  Future<CaptureJob> capture(int number) async {
    final file = File('${root.path}/CAP$number.jpg');
    await file.writeAsBytes([1, 2, 3]);
    final calendar = DateTime(2026, 11, 14, 12, 0, number);
    final time = LocalShutterTime(
      calendar,
      calendar.timeZoneOffset + const Duration(hours: 1),
    );
    return CaptureJob(
      filePath: file.path,
      filmId: book.recipes.first.id,
      look: resolve(book.recipes.first),
      format: FrameFormat.r3x2,
      seed: 1,
      takenAt: time,
      includeLocation: true,
      location: PhotoLocation(
        latitude: 48.654321 + number,
        longitude: -3.125,
        altitude: number == 0 ? null : -12.5,
        accuracy: 12,
        time: time,
      ),
    );
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('carrete_location_');
    vault = EncryptedShotVault(
      directory: () => Directory('${root.path}/vault'),
      keys: InMemoryVaultKeyStore(),
    );
    db = openMemoryDatabase();
  });
  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  test(
    'each roll or disposable frame develops with its own encrypted shutter fix',
    () async {
      for (final disposable in [false, true]) {
        final operations = RollOperations();
        final processor = FakeProcessor();
        final notifications = FakeNotifications();
        var now = when;
        final developer = RollDeveloper(
          database: db,
          vault: vault,
          processor: processor,
          notifications: notifications,
          cache: root,
          loadBook: () async => book,
          operations: operations,
          clock: () => now,
          findSaved: (_) async => null,
        );
        final service = RollService(
          database: db,
          vault: vault,
          notifications: notifications,
          developer: developer,
          operations: operations,
          cache: root,
          clock: () => now,
          defaultFilm: () => book.recipes.first.id,
        );
        addTearDown(service.dispose);
        addTearDown(developer.dispose);
        final roll = disposable
            ? await service.openDisposable(DevelopDelay.oneHour)
            : await service.openRoll(12, DevelopDelay.oneHour);
        final captures = [await capture(0), await capture(1)];
        for (final job in captures) {
          final shot = await service.captureIntoRoll(job, rollId: roll.id);
          expect(shot.captureJobJson, isNot(contains('latitude')));
          expect(shot.captureJobJson, isNot(contains('48.654321')));
          final payload = RollVaultPayload.decode(
            await vault.read(shot.vaultPath!),
          );
          expect(payload.job!['location'], job.location!.toJson());
          expect(payload.job!['takenAtMs'], job.takenAt.millisecondsSinceEpoch);
        }
        // No unencrypted sidecar or database snapshot holds coordinates.
        await for (final entry in root.list(recursive: true)) {
          if (entry is File) {
            final bytes = await entry.readAsBytes();
            expect(
              utf8.decode(bytes, allowMalformed: true),
              isNot(contains('latitude')),
            );
            expect(
              utf8.decode(bytes, allowMalformed: true),
              isNot(contains('48.654321')),
            );
          }
        }
        await service.closeRoll(roll.id);
        now = when.add(const Duration(hours: 1));
        await developer.develop(roll.id);
        expect(
          processor.saved.map((j) => j.location!.toJson()),
          captures.map((j) => j.location!.toJson()),
        );
        for (var i = 0; i < captures.length; i++) {
          final saved = processor.saved[i];
          expect(
            saved.shutterInstant!.millisecondsSinceEpoch,
            captures[i].takenAt.millisecondsSinceEpoch,
          );
          expect(saved.location!.isUsableAt(saved.shutterInstant!), isTrue);
          expect(
            saved.location!.isUsableAt(saved.takenAt),
            isFalse,
            reason: 'local fields are parsed under a shifted offset',
          );
        }
        expect(
          (await RollsDao(db).rollById(roll.id))!.state,
          RollState.developed,
        );
        expect(await vault.list(), isEmpty);
      }
    },
  );

  for (final legacy in [false, true]) {
    test(
      'recovery and development retain encrypted location metadata, legacy=$legacy',
      () async {
        final original = await capture(0);
        final operations = RollOperations();
        final processor = FakeProcessor();
        final notifications = FakeNotifications();
        var now = when;
        final developer = RollDeveloper(
          database: db,
          vault: vault,
          processor: processor,
          notifications: notifications,
          cache: root,
          loadBook: () async => book,
          operations: operations,
          clock: () => now,
          findSaved: (_) async => null,
        );
        final service = RollService(
          database: db,
          vault: vault,
          notifications: notifications,
          developer: developer,
          operations: operations,
          cache: root,
          clock: () => now,
          defaultFilm: () => book.recipes.first.id,
        );
        addTearDown(service.dispose);
        addTearDown(developer.dispose);
        final roll = await service.openRoll(12, DevelopDelay.oneHour);
        final initialSnapshot = FailedShots.encode(original, attempts: 0)
          ..['location'] = original.location!.toJson();
        if (legacy) initialSnapshot.remove('takenAtMs');
        final staged = FailedShots.decode(
          initialSnapshot,
          book,
          original.filePath,
        )!;
        final recovery = RollRecovery(root, vault: vault);
        await recovery.stage(staged, roll.id, ShotLens.back);
        final restarted = RollRecovery(root, vault: vault);
        final entry = (await restarted.pending()).single;
        final text = await entry.journal.readAsString();
        expect(text, isNot(contains('latitude')));
        expect(text, isNot(contains('48.654321')));
        expect(entry.snapshot, contains('encryptedJobPath'));
        final snapshot = await restarted.snapshotOf(entry);
        final job = FailedShots.decode(
          snapshot,
          book,
          (await entry.source())!.path,
        )!;
        expect(job.location!.toJson(), original.location!.toJson());
        if (legacy) {
          expect(job.shutterInstant, isNull);
        } else {
          expect(
            job.shutterInstant!.millisecondsSinceEpoch,
            original.takenAt.millisecondsSinceEpoch,
          );
        }
        await service.recoverCaptures();
        expect(await restarted.pending(), isEmpty);
        final shot = (await RollsDao(db).shotsOf(roll.id)).single;
        final stored = RollVaultPayload.decode(
          await vault.read(shot.vaultPath!),
        );
        expect(stored.job!.containsKey('takenAtMs'), !legacy);
        expect(stored.job!['takenAt'], initialSnapshot['takenAt']);
        await service.closeRoll(roll.id);
        now = when.add(const Duration(hours: 1));
        await developer.develop(roll.id);
        final saved = processor.saved.single;
        expect(saved.location!.toJson(), original.location!.toJson());
        if (legacy) {
          expect(saved.shutterInstant, isNull);
        } else {
          expect(
            saved.shutterInstant!.millisecondsSinceEpoch,
            original.takenAt.millisecondsSinceEpoch,
          );
          expect(saved.location!.isUsableAt(saved.shutterInstant!), isTrue);
        }
        expect(await vault.list(), isEmpty);
      },
    );
  }

  test('failed journal write deletes the newly encrypted metadata', () async {
    final job = await capture(0);
    await Directory('${job.filePath}.roll.json').create();
    await expectLater(
      RollRecovery(root, vault: vault).stage(job, 7, ShotLens.back),
      throwsA(isA<FileSystemException>()),
    );
    expect(await vault.list(), isEmpty);
    expect(await File(job.filePath).exists(), isTrue);
  });
}
