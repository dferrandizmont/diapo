import 'dart:convert';
import 'dart:io';

import 'package:carrete/location/photo_location.dart';
import 'package:carrete/capture/capture_queue.dart';
import 'package:carrete/capture/failed_shots.dart';
import 'package:carrete/capture/film_capture_processor.dart';
import 'package:carrete/core/settings/app_settings.dart';
import 'package:film_recipes/film_recipes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

/// "Also save the original": the untouched camera JPEG goes next to the
/// developed photo. The native copy is replaced by a fake that remembers the
/// names, so what is checked here is when it is asked for and under which
/// name, never the bytes.
void main() {
  final book = testBook();
  late Directory cache;
  late FailedShots failed;
  late List<String> developed;
  late List<String> recorded;
  // The originals "in the gallery": name -> where.
  late Map<String, String> originals;
  late List<bool> originalLocation;
  late List<bool> sourceExisted;
  late List<String> order;
  late String? developedAlready;
  late Object? originalFails;
  late int originalSaves;
  late FilmCaptureProcessor processor;
  var shot = 0;

  Future<CaptureJob> job({
    bool saveOriginal = true,
    bool includeLocation = false,
    String? captureId = 'cap0000001',
    DateTime? takenAt,
    String? displayName,
  }) async {
    final recipe = book.byId('beta')!;
    final file = File('${cache.path}/photo_${shot++}.jpg')
      ..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xD9]);
    return CaptureJob(
      filePath: file.path,
      filmId: recipe.id,
      look: resolve(recipe),
      format: FrameFormat.r3x2,
      seed: 1,
      takenAt: takenAt ?? DateTime(2026, 11, 13, 18, 30, 15, 250),
      captureId: captureId,
      saveOriginal: saveOriginal,
      includeLocation: includeLocation,
      displayName: displayName,
    );
  }

  setUp(() async {
    cache = await Directory.systemTemp.createTemp('carrete_original_');
    addTearDown(() => cache.delete(recursive: true));
    failed = FailedShots(Directory('${cache.path}/failed'));
    developed = [];
    recorded = [];
    originals = {};
    originalLocation = [];
    sourceExisted = [];
    order = [];
    developedAlready = null;
    originalFails = null;
    originalSaves = 0;
    processor = FilmCaptureProcessor(
      loadProgram: () async => throw StateError('no shader in this test'),
      failedShots: failed,
      findSaved: (name) async => developedAlready,
      findSavedOriginal: (name) async => originals[name],
      saveOriginal:
          ({
            required String sourcePath,
            required String name,
            required bool includeLocation,
            PhotoLocation? location,
            DateTime? takenAt,
          }) async {
            if (originalFails != null) throw originalFails!;
            originalSaves++;
            order.add('original');
            sourceExisted.add(File(sourcePath).existsSync());
            originalLocation.add(includeLocation);
            return originals[name] = 'content://media/orig/$name';
          },
      save: (job) async {
        order.add('developed');
        developed.add(FilmCaptureProcessor.exportNameOf(job));
        return const SavedStill('content://media/7', width: 30, height: 20);
      },
      onSaved: (job, still) async => recorded.add('${job.captureId}'),
    );
  });

  group('off by default', () {
    test('the setting and the job start without it', () async {
      expect(AppSettings.defaults.saveOriginal, isFalse);
      expect(
        CaptureJob(
          filePath: 'x',
          filmId: 'beta',
          look: resolve(book.byId('beta')!),
          format: FrameFormat.r3x2,
          seed: 1,
          takenAt: DateTime(2026),
        ).saveOriginal,
        isFalse,
      );
    });

    test('a shot taken without it saves no original', () async {
      await processor.process(await job(saveOriginal: false));

      expect(developed, hasLength(1));
      expect(originalSaves, 0);
      expect(originals, isEmpty);
    });
  });

  group('on', () {
    test(
      'two shots save two originals with names tied to their photos',
      () async {
        await processor.process(await job());
        await processor.process(
          await job(
            captureId: 'cap0000002',
            takenAt: DateTime(2026, 11, 13, 18, 31, 2, 5),
          ),
        );

        expect(developed, [
          'CARRETE_20261113_183015_250_cap0000001',
          'CARRETE_20261113_183102_005_cap0000002',
        ]);
        expect(originals.keys.toList(), [
          'CARRETE_20261113_183015_250_cap0000001_original',
          'CARRETE_20261113_183102_005_cap0000002_original',
        ]);
        // The camera file was still there when it was copied.
        expect(sourceExisted, [true, true]);
        // The original is written before the photo that marks the shot done.
        expect(order, ['original', 'developed', 'original', 'developed']);
      },
    );

    test('the location follows the setting of the shot', () async {
      await processor.process(await job(includeLocation: true));
      await processor.process(
        await job(captureId: 'cap0000002', includeLocation: false),
      );

      expect(originalLocation, [true, false]);
    });

    test('a roll frame is named after its export name', () async {
      await processor.process(
        await job(displayName: 'CARRETE_20261113_183015_250_shot_12'),
      );

      expect(originals.keys, ['CARRETE_20261113_183015_250_shot_12_original']);
    });

    test('the camera file goes only once the original is saved', () async {
      final camera = await job();
      await processor.process(camera);

      expect(File(camera.filePath).existsSync(), isFalse);
      expect(originals, hasLength(1));
    });
  });

  group('retry', () {
    test('records the photo without saving the original again', () async {
      final first = await job();
      // The process died after both saves, before recording.
      final broken = FilmCaptureProcessor(
        loadProgram: () async => throw StateError('no shader'),
        failedShots: failed,
        findSavedOriginal: (name) async => originals[name],
        saveOriginal: ({
          required String sourcePath,
          required String name,
          required bool includeLocation,
          PhotoLocation? location,
          DateTime? takenAt,
        }) async => originals[name] = 'content://media/orig/$name',
        save: (job) async =>
            const SavedStill('content://media/7', width: 30, height: 20),
        onSaved: (job, still) async => throw StateError('database locked'),
      );
      await broken.process(first);
      expect(originals, hasLength(1));

      developedAlready = 'content://media/7';
      final pending = await failed.pending(book);
      expect(pending, hasLength(1));
      // Both saves are done: a retry of the photo does not try it again.
      expect(pending.single.saveOriginal, isFalse);
      await processor.process(pending.single);

      expect(originalSaves, 0); // found by its name, not saved twice
      expect(originals, hasLength(1));
      expect(developed, isEmpty);
      expect(recorded, ['cap0000001']);
    });

    test(
      'an original that failed is dropped: nothing is kept or retried',
      () async {
        originalFails = StateError('no space left');
        final camera = await job();
        final uri = await processor.process(camera);

        // The photo is saved and recorded as if nothing had happened.
        expect(uri, 'content://media/7');
        expect(developed, hasLength(1));
        expect(recorded, ['cap0000001']);
        expect(originals, isEmpty);
        // Nothing waits for the next start, and the camera file is gone.
        expect(await failed.pending(book), isEmpty);
        expect(
          failed.directory.existsSync() ? failed.directory.listSync() : [],
          isEmpty,
        );
        expect(File(camera.filePath).existsSync(), isFalse);
        expect(originalSaves, 0);
      },
    );

    test(
      'a photo deleted after its original failed is not brought back',
      () async {
        originalFails = StateError('no space left');
        await processor.process(await job());
        expect(developed, hasLength(1));

        // The user deletes the developed photo; the app restarts.
        developedAlready = null;
        final queued = await failed.pending(book);
        for (final job in queued) {
          await processor.process(job);
        }

        expect(queued, isEmpty);
        expect(developed, hasLength(1), reason: 'nothing is rendered again');
        expect(recorded, hasLength(1), reason: 'nothing is recorded again');
      },
    );
  });

  group('attempted once', () {
    test('a retry of the photo never tries the original again', () async {
      originalFails = StateError('no space left');
      final recording = FilmCaptureProcessor(
        loadProgram: () async => throw StateError('no shader'),
        failedShots: failed,
        findSavedOriginal: (name) async => null,
        saveOriginal: ({
          required String sourcePath,
          required String name,
          required bool includeLocation,
          PhotoLocation? location,
          DateTime? takenAt,
        }) async => throw StateError('no space left'),
        save: (job) async =>
            const SavedStill('content://media/7', width: 30, height: 20),
        onSaved: (job, still) async => throw StateError('database locked'),
      );
      await recording.process(await job());

      final pending = await failed.pending(book);
      expect(pending, hasLength(1));
      expect(pending.single.saveOriginal, isFalse);

      // The retry has room now, but must not try the original at all.
      originalFails = null;
      developedAlready = 'content://media/7';
      await processor.process(pending.single);

      expect(originalSaves, 0);
      expect(originals, isEmpty);
      expect(recorded, ['cap0000001']);
    });
  });

  group('the sidecar', () {
    test('keeps the setting of the shot', () async {
      final original = await job(includeLocation: true);
      final copy = FailedShots.decode(
        jsonDecode(jsonEncode(FailedShots.encode(original, attempts: 1)))
            as Map<String, Object?>,
        book,
        original.filePath,
      );

      expect(copy!.saveOriginal, isTrue);
      expect(copy.includeLocation, isTrue);
      expect(copy.withFile('other.jpg').saveOriginal, isTrue);
    });

    test('an old sidecar has none', () async {
      final original = await job();
      final json = Map<String, Object?>.from(
        FailedShots.encode(original, attempts: 0),
      )..remove('saveOriginal');
      final copy = FailedShots.decode(json, book, original.filePath);

      expect(copy!.saveOriginal, isFalse);
    });
  });
}
