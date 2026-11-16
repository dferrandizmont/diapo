import 'dart:convert';
import 'dart:io';

import 'package:diapo/capture/capture_queue.dart';
import 'package:diapo/capture/failed_shots.dart';
import 'package:diapo/capture/film_capture_processor.dart';
import 'package:film_recipes/film_recipes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

/// The durable part of the loose capture: what survives when the save or the
/// recording stops half way. The shader is never needed: the render and save
/// are replaced by a fake.
void main() {
  final book = testBook();
  late Directory cache;
  late FailedShots failed;
  late File original;
  late List<String> saves;
  late List<String> recorded;
  late String? alreadySaved;
  late Object? saveFails;
  late Object? recordFails;
  late FilmCaptureProcessor processor;

  CaptureJob job({String? captureId = 'cap0000001', bool retried = false}) {
    final recipe = book.byId('beta')!;
    return CaptureJob(
      filePath: original.path,
      filmId: recipe.id,
      look: resolve(recipe),
      format: FrameFormat.r3x2,
      seed: 1,
      takenAt: DateTime(2026, 11, 13, 18, 30, 15, 250),
      captureId: captureId,
      retried: retried,
    );
  }

  Future<List<String>> keptFiles() async => [
    if (await failed.directory.exists())
      await for (final entry in failed.directory.list()) entry.path,
  ];

  setUp(() async {
    cache = await Directory.systemTemp.createTemp('carrete_processor_');
    addTearDown(() => cache.delete(recursive: true));
    failed = FailedShots(Directory('${cache.path}/failed'));
    original = File('${cache.path}/photo_1.jpg')
      ..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xD9]);
    saves = [];
    recorded = [];
    alreadySaved = null;
    saveFails = null;
    recordFails = null;
    processor = FilmCaptureProcessor(
      loadProgram: () async => throw StateError('no shader in this test'),
      failedShots: failed,
      findSaved: (name) async => alreadySaved,
      save: (job) async {
        if (saveFails != null) throw saveFails!;
        saves.add(FilmCaptureProcessor.exportNameOf(job));
        return const SavedStill('content://media/7', width: 30, height: 20);
      },
      onSaved: (job, still) async {
        if (recordFails != null) throw recordFails!;
        recorded.add('${job.captureId} ${still.uri}');
      },
    );
  });

  test('a shot that is saved and recorded leaves nothing behind', () async {
    final uri = await processor.process(job());

    expect(uri, 'content://media/7');
    expect(recorded, ['cap0000001 content://media/7']);
    expect(await keptFiles(), isEmpty);
    expect(original.existsSync(), isFalse);
  });

  test('the file is named by the time and the id of the shot', () async {
    await processor.process(job());
    await processor.process(job(captureId: null));

    expect(saves, [
      'CARRETE_20261113_183015_250_cap0000001',
      'CARRETE_20261113_183015_250',
    ]);
  });

  test('the shot is made durable before anything is saved', () async {
    saveFails = StateError('the save died');

    await expectLater(processor.process(job()), throwsStateError);

    // Original and sidecar are in failed/, the camera copy has moved there.
    final kept = await keptFiles();
    expect(kept, hasLength(2));
    expect(original.existsSync(), isFalse);
    expect(recorded, isEmpty);
  });

  test(
    'if recording fails the photo stays saved and the shot is kept',
    () async {
      recordFails = StateError('the database is locked');

      final uri = await processor.process(job());

      expect(uri, 'content://media/7');
      expect(saves, hasLength(1));
      expect(await keptFiles(), hasLength(2));
    },
  );

  test('the retry records the photo without saving it again', () async {
    recordFails = StateError('the process died here');
    await processor.process(job());
    recordFails = null;
    alreadySaved = 'content://media/7';
    saves.clear();

    final pending = await failed.pending(book);
    expect(pending, hasLength(1));
    expect(pending.single.captureId, 'cap0000001');
    final uri = await processor.process(pending.single);

    expect(uri, 'content://media/7');
    expect(saves, isEmpty); // not saved twice
    expect(recorded, ['cap0000001 content://media/7']);
    expect(await keptFiles(), isEmpty);
  });

  test('a retry whose save had not happened saves it now', () async {
    saveFails = StateError('the save died');
    await expectLater(processor.process(job()), throwsStateError);
    saveFails = null;

    final pending = await failed.pending(book);
    await processor.process(pending.single);

    expect(saves, hasLength(1));
    expect(recorded, hasLength(1));
    expect(await keptFiles(), isEmpty);
  });

  test('a processor with nowhere to keep shots works as before', () async {
    final plain = FilmCaptureProcessor(
      loadProgram: () async => throw StateError('no shader in this test'),
      save: (job) async => const SavedStill('content://media/9'),
    );

    expect(await plain.process(job()), 'content://media/9');
    expect(original.existsSync(), isFalse);
  });

  test('ids are different every time and fit a file name', () {
    final ids = {for (var i = 0; i < 200; i++) newCaptureId()};

    expect(ids, hasLength(200));
    expect(ids.every((id) => RegExp(r'^[0-9a-f]{10}$').hasMatch(id)), isTrue);
  });

  group('the limit of attempts', () {
    test('a retry that only records never counts against it', () async {
      recordFails = StateError('locked');
      await processor.process(job()); // saves (attempt 1), recording fails
      alreadySaved = 'content://media/7';
      for (var i = 0; i < 2; i++) {
        final pending = await failed.pending(book);
        await processor.process(pending.single); // reconciles, fails again
      }

      // Saved once; two reconciliations did not count as attempts.
      expect(saves, hasLength(1));
      final sidecar = jsonDecode(
        File('${failed.directory.path}/photo_1.jpg.json').readAsStringSync(),
      ) as Map;
      expect(sidecar['attempts'], 1);
      expect(sidecar['recordFailures'], 3);
    });

    test('the third attempt may save and still be recorded later', () async {
      // Two attempts die before saving...
      saveFails = StateError('the save died');
      for (var i = 0; i < 2; i++) {
        final next = i == 0 ? job() : (await failed.pending(book)).single;
        await expectLater(processor.process(next), throwsStateError);
      }
      // ...the third saves but cannot be recorded.
      saveFails = null;
      recordFails = StateError('locked');
      await processor.process((await failed.pending(book)).single);
      recordFails = null;
      alreadySaved = 'content://media/7';

      // Out of attempts, but the photo is in the gallery: it is listed.
      expect(await failed.pending(book), isEmpty);
      final pending = await failed.pending(book, published: (_) async => true);
      expect(pending, hasLength(1));
      saves.clear();
      await processor.process(pending.single);

      expect(saves, isEmpty); // not saved again
      expect(recorded, ['cap0000001 content://media/7']);
      expect(await keptFiles(), isEmpty);
    });

    test('a shot that cannot be recorded stops being retried', () async {
      recordFails = StateError('locked');
      await processor.process(job());
      alreadySaved = 'content://media/7';
      for (var i = 0; i < FailedShots.maxAttempts; i++) {
        final pending = await failed.pending(
          book,
          published: (_) async => true,
        );
        if (pending.isEmpty) break;
        await processor.process(pending.single);
      }

      expect(await failed.pending(book, published: (_) async => true), isEmpty);
      expect(await keptFiles(), hasLength(2)); // the files stay
    });
  });
}
