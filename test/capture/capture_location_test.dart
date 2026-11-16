import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:carrete/capture/film_capture_processor.dart';
import 'package:carrete/capture/loose_shot_recorder.dart';
import 'package:carrete/core/database/app_database.dart';
import 'package:carrete/core/database/shots_dao.dart';
import 'package:drift/native.dart';

import 'package:carrete/capture/capture_queue.dart';
import 'package:carrete/capture/failed_shots.dart';
import 'package:carrete/location/photo_location.dart';
import 'package:carrete/roll/roll_vault_payload.dart';
import 'package:film_recipes/film_recipes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';

import '../support/fakes.dart';
import '../support/local_shutter_time.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final book = testBook();
  final time = DateTime.utc(2026, 11, 14, 12);
  final location = PhotoLocation(
    latitude: 40,
    longitude: -3,
    altitude: 650,
    accuracy: 10,
    time: time,
  );
  CaptureJob job({bool includeLocation = true}) => CaptureJob(
    filePath: 'camera.jpg',
    filmId: book.recipes.first.id,
    look: resolve(book.recipes.first),
    format: FrameFormat.r3x2,
    seed: 1,
    takenAt: time,
    includeLocation: includeLocation,
    location: location,
  );

  for (final legacy in [false, true]) {
    test(
      'the default original saver forwards only an unambiguous shutter, legacy=$legacy',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'carrete_location_original_',
        );
        addTearDown(() => root.delete(recursive: true));
        final original = await File('${root.path}/camera.jpg')
            .writeAsBytes([0xff, 0xd8, 0xff, 0xd9]);
        final calls = <MethodCall>[];
        const channel = MethodChannel('carrete/media');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'saveOriginal' ? 'content://original/1' : null;
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        final calendar = DateTime(2026, 11, 14, 12);
        final shutter = LocalShutterTime(
          calendar,
          calendar.timeZoneOffset + const Duration(hours: 1),
        );
        final captured = CaptureJob(
          filePath: original.path,
          filmId: book.recipes.first.id,
          look: resolve(book.recipes.first),
          format: FrameFormat.r3x2,
          seed: 1,
          takenAt: shutter,
          includeLocation: true,
          location: PhotoLocation(
            latitude: 40,
            longitude: -3,
            accuracy: 10,
            time: DateTime.fromMillisecondsSinceEpoch(
              shutter.millisecondsSinceEpoch,
              isUtc: true,
            ),
          ),
          saveOriginal: true,
        );
        final snapshot = FailedShots.encode(captured, attempts: 1)
          ..['location'] = captured.location!.toJson();
        expect(snapshot['takenAt'], calendar.toIso8601String());
        expect(snapshot['takenAtMs'], shutter.millisecondsSinceEpoch);
        if (legacy) snapshot.remove('takenAtMs');
        final restored = FailedShots.decode(snapshot, book, original.path)!;
        expect(restored.takenAt, calendar);
        expect(
          restored.location!.isUsableAt(restored.takenAt),
          isFalse,
          reason:
              'the decoding zone differs from the shutter offset by one hour',
        );
        if (!legacy) {
          expect(
            restored.location!.isUsableAt(restored.shutterInstant!),
            isTrue,
          );
        }
        expect(
          FailedShots.encode(
            restored.withFile(original.path),
            attempts: 2,
          ).containsKey('takenAtMs'),
          !legacy,
        );
        final processor = FilmCaptureProcessor(
          loadProgram: () async => throw StateError('unused'),
          save: (_) async => const SavedStill('content://saved/1'),
        );
        await processor.process(restored);
        final arguments =
            calls.singleWhere((call) => call.method == 'saveOriginal').arguments
                as Map;
        if (legacy) {
          expect(arguments.containsKey('takenAt'), isFalse);
        } else {
          expect(arguments['takenAt'], shutter.millisecondsSinceEpoch);
        }
        expect(arguments['location'], captured.location!.toJson());
      },
    );
  }

  test('invalid unambiguous shutter fields are rejected', () {
    for (final invalid in ['123', 1.5, true, 8640000000000001]) {
      final snapshot = FailedShots.encode(job(), attempts: 0)
        ..['takenAtMs'] = invalid;
      expect(FailedShots.decode(snapshot, book, 'restored.jpg'), isNull);
    }
  });

  test('job copies retain the fix but plaintext retry snapshots omit it', () {
    final original = job();
    final file = original.withFile('retry.jpg', retried: true);
    final framed = file.withFrame(
      look: original.look,
      format: original.format,
      tuning: original.tuning,
      whiteFrame: true,
    );
    expect(framed.location, same(location));
    final restored = FailedShots.decode(
      FailedShots.encode(framed, attempts: 1),
      book,
      'restored.jpg',
    )!;
    expect(restored.location, isNull);
    expect(restored.includeLocation, isTrue);
  });

  test(
    'off omits coordinates from serialized jobs, including accidental fixes',
    () {
      final snapshot = FailedShots.encode(
        job(includeLocation: false),
        attempts: 0,
      );
      expect(snapshot, isNot(contains('location')));
      snapshot['location'] = location.toJson();
      expect(
        FailedShots.decode(snapshot, book, 'restored.jpg')!.location,
        isNull,
      );
    },
  );

  test(
    'vault envelope retains the job and JPEG; legacy JPEGs stay unchanged',
    () {
      final jpeg = Uint8List.fromList([0xff, 0xd8, 1, 2, 0xff, 0xd9]);
      final snapshot = FailedShots.encode(job(), attempts: 0)
        ..['includeLocation'] = true
        ..['location'] = location.toJson();
      final payload = RollVaultPayload.decode(
        RollVaultPayload.encode(jpeg, snapshot),
      );
      expect(payload.jpeg, jpeg);
      final restored = FailedShots.decode(payload.job!, book, 'develop.jpg')!;
      expect(restored.location!.toJson(), location.toJson());
      expect(RollVaultPayload.decode(jpeg).jpeg, same(jpeg));
      expect(RollVaultPayload.decode(jpeg).job, isNull);
      expect(
        () => RollVaultPayload.decode(Uint8List.fromList([67, 82, 74, 70])),
        throwsFormatException,
      );
    },
  );

  test('vault and retry decoding preserve approximate and legacy fixes', () {
    final jpeg = Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]);
    for (final approximate in [null, false, true]) {
      final json = location.toJson()..remove('approximate');
      if (approximate != null) json['approximate'] = approximate;
      json['accuracy'] = 2000.0;
      final snapshot = FailedShots.encode(job(), attempts: 0)
        ..['location'] = json;
      final payload = RollVaultPayload.decode(
        RollVaultPayload.encode(jpeg, snapshot),
      );
      for (final saved in [snapshot, payload.job!]) {
        final restored = FailedShots.decode(saved, book, 'restored.jpg')!;
        expect(restored.location!.approximate, approximate == true);
        expect(restored.location!.accuracy, 2000);
        expect(restored.location!.isUsableAt(time), approximate == true);
      }
    }
  });

  for (final fail in [false, true]) {
    test(
      'loose save plaintext scan during save, failure=$fail and restart',
      () async {
        final root = await Directory.systemTemp.createTemp('carrete_gps_scan_');
        addTearDown(() => root.delete(recursive: true));
        final cache = await Directory('${root.path}/cache').create();
        final support = await Directory('${root.path}/support').create();
        final databaseFile = File('${support.path}/carrete.sqlite');
        var database = AppDatabase(NativeDatabase(databaseFile));
        addTearDown(() => database.close());
        await database.customSelect('SELECT 1').get();
        expect(await databaseFile.exists(), isTrue);
        final original = await File('${cache.path}/camera.jpg')
            .writeAsBytes([0xff, 0xd8, 0xff, 0xd9]);
        final fix = PhotoLocation(
          latitude: 48.654321,
          longitude: -3.123456,
          altitude: -12.5678,
          accuracy: 10,
          time: time,
        );
        final captured = CaptureJob(
          filePath: original.path,
          filmId: book.recipes.first.id,
          look: resolve(book.recipes.first),
          format: FrameFormat.r3x2,
          seed: 1,
          takenAt: time,
          includeLocation: true,
          location: fix,
          captureId: 'plaintext-scan',
        );
        Future<void> scan() async {
          await for (final entry in root.list(
            recursive: true,
            followLinks: false,
          )) {
            if (entry is! File) continue;
            final text = utf8.decode(
              await entry.readAsBytes(),
              allowMalformed: true,
            );
            for (final marker in [
              'latitude',
              'longitude',
              '48.654321',
              '-3.123456',
              '-12.5678',
            ]) {
              expect(text, isNot(contains(marker)), reason: entry.path);
            }
          }
        }

        final rendering = Completer<void>();
        final release = Completer<void>();
        final failed = FailedShots(Directory('${cache.path}/failed'));
        final processor = FilmCaptureProcessor(
          loadProgram: () async => throw StateError('unused'),
          failedShots: failed,
          save: (job) async {
            expect(job.location, same(fix));
            rendering.complete();
            await release.future;
            if (fail) throw StateError('save failed');
            return const SavedStill('content://saved/1');
          },
          onSaved: (job, still) async {
            await LooseShotRecorder(ShotsDao(database)).record(job, still);
            await scan();
          },
        );
        final saving = processor.process(captured);
        final checked = fail
            ? expectLater(saving, throwsStateError)
            : expectLater(saving, completion('content://saved/1'));
        await rendering.future;
        await scan();
        release.complete();
        await checked;
        await scan();
        await database.close();
        database = AppDatabase(NativeDatabase(databaseFile));
        expect(
          await database.select(database.shots).get(),
          hasLength(fail ? 0 : 1),
        );
        final restarted = FailedShots(failed.directory);
        final retries = await restarted.pending(book);
        if (fail) {
          final retry = retries.single;
          expect(retry.location, isNull);
          expect(retry.includeLocation, isTrue);
          final retryProcessor = FilmCaptureProcessor(
            loadProgram: () async => throw StateError('unused'),
            failedShots: restarted,
            save: (job) async {
              expect(job.location, isNull);
              expect(job.includeLocation, isTrue);
              await scan();
              throw StateError('still failing');
            },
          );
          for (var attempt = 1; attempt < FailedShots.maxAttempts; attempt++) {
            await expectLater(retryProcessor.process(retry), throwsStateError);
            await scan();
          }
          expect(await FailedShots(failed.directory).pending(book), isEmpty);
          expect(await failed.directory.list().toList(), isNotEmpty);
        } else {
          expect(retries, isEmpty);
          expect(await failed.directory.list().toList(), isEmpty);
        }
        await scan();
      },
    );
  }
}
