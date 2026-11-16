import 'dart:async';
import 'dart:io';

import 'package:carrete/capture/capture_queue.dart';
import 'package:carrete/capture/film_capture_processor.dart';
import 'package:carrete/capture/loose_shot_recorder.dart';
import 'package:carrete/core/database/app_database.dart';
import 'package:carrete/core/database/converters.dart';
import 'package:carrete/core/database/shots_dao.dart';
import 'package:carrete/core/database/tables.dart';
import 'package:carrete/core/settings/app_settings.dart';
import 'package:carrete/core/settings/film_tuning.dart';
import 'package:carrete/import/import_developer.dart';
import 'package:carrete/import/import_intake.dart';
import 'package:carrete/import/import_job.dart';
import 'package:carrete/platform/exif_dates.dart';
import 'package:carrete/platform/photo_actions.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/import_fakes.dart';
import '../support/roll_fakes.dart';
import '../support/test_database.dart';

/// The real recorder, which fails when it is told to.
class _FlakyRecorder implements LooseShotRecorder {
  _FlakyRecorder(this.inner);

  final LooseShotRecorder inner;
  bool fails = false;

  @override
  Future<ShotRow> record(CaptureJob job, SavedStill still) async {
    if (fails) throw StateError('database is closed');
    return inner.record(job, still);
  }
}

void main() {
  final book = testBook();
  late Directory cache;
  late AppDatabase db;
  late ShotsDao shots;
  late FakePhotoLibrary library;
  late List<String> saved;
  late Set<String> unreadable;
  late Completer<void>? gate;
  late _FlakyRecorder recorder;
  late FakePhotoActions actions;
  late ImportDeveloper developer;

  CaptureJob jobAt(int i) {
    final file = File('${cache.path}/photo_$i.jpg')
      ..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xD9]);
    return importJobFor(
      photo: ImportPhoto(
        path: file.path,
        date: PhotoDate(
          wall: DateTime(2001, 2, 3 + i),
          instant: DateTime(2001, 2, 3 + i, 12),
        ),
      ),
      recipe: book.byId('beta')!,
      tuning: FilmTuning.defaults,
      stampStyle: DateStampStyle.yearFirst,
      includeLocation: false,
      developedAt: DateTime(2026, 11, 13, 20, 0, 0, i),
      captureId: 'imp000000$i',
    );
  }

  setUp(() async {
    cache = await Directory.systemTemp.createTemp('carrete_developer_');
    addTearDown(() => cache.delete(recursive: true));
    db = openMemoryDatabase();
    addTearDown(db.close);
    shots = ShotsDao(db);
    library = FakePhotoLibrary();
    saved = [];
    unreadable = {};
    gate = null;
    recorder = _FlakyRecorder(LooseShotRecorder(shots));
    actions = FakePhotoActions();
    developer = ImportDeveloper(
      processorFactory: (onSaved) => FilmCaptureProcessor(
        loadProgram: () async => throw StateError('no shader in this test'),
        onSaved: onSaved,
        // The render and the save are replaced; the rest is the real thing.
        save: (job) async {
          final pending = gate;
          if (pending != null) await pending.future;
          if (unreadable.contains(job.captureId)) {
            throw StateError('cannot decode');
          }
          final uri = 'content://media/${saved.length + 1}';
          saved.add(FilmCaptureProcessor.exportNameOf(job));
          return SavedStill(uri, width: 4000, height: 3000);
        },
      ),
      recorder: recorder,
      library: library,
      actions: actions,
    );
  });

  test('develops every photo and records each as a loose shot', () async {
    final jobs = [jobAt(0), jobAt(1), jobAt(2)];

    final outcome = await developer.start(jobs).outcome;

    expect(outcome.complete, isTrue);
    expect((outcome.total, outcome.developed, outcome.failed), (3, 3, 0));
    final rows = await shots.allShots();
    expect(rows, hasLength(3));
    for (final row in rows) {
      expect(row.rollId, isNull);
      expect(row.filmId, 'beta');
      expect(row.format, ShotFormat.ratio4x3);
      expect(row.lens, ShotLens.back);
      expect(row.width, 4000);
      expect(row.height, 3000);
    }
    expect(rows.map((r) => r.galleryUri).toSet(), {
      'content://media/1',
      'content://media/2',
      'content://media/3',
    });
    // The row is placed on the day the photo was taken, not the day it was
    // developed.
    expect(rows.map((r) => r.takenAt).toSet(), {
      DateTime(2001, 2, 3, 12).millisecondsSinceEpoch,
      DateTime(2001, 2, 4, 12).millisecondsSinceEpoch,
      DateTime(2001, 2, 5, 12).millisecondsSinceEpoch,
    });
    expect(saved, hasLength(3));
    expect(saved.toSet(), hasLength(3));
  });

  test('deletes the temporary copies as it goes', () async {
    final jobs = [jobAt(0), jobAt(1)];

    await developer.start(jobs).outcome;

    for (final job in jobs) {
      expect(File(job.filePath).existsSync(), isFalse);
    }
  });

  test('counts progress one photo at a time', () async {
    gate = Completer<void>();
    final run = developer.start([jobAt(0), jobAt(1)]);
    final seen = <ImportProgress>[run.progress.value];
    run.progress.addListener(() => seen.add(run.progress.value));

    gate!.complete();
    await run.outcome;

    expect(seen.first, const ImportProgress(done: 0, total: 2));
    expect(seen.last, const ImportProgress(done: 2, total: 2));
    expect(seen.first.current, 1);
    expect(seen.last.current, 2);
  });

  test('a photo that cannot be read fails alone, the rest go on', () async {
    unreadable.add('imp0000001');

    final outcome = await developer.start([
      jobAt(0),
      jobAt(1),
      jobAt(2),
    ]).outcome;

    expect(outcome.complete, isFalse);
    expect((outcome.developed, outcome.failed), (2, 1));
    expect(await shots.allShots(), hasLength(2));
  });

  test(
    'a photo saved but not recorded is removed, not left orphaned',
    () async {
      recorder.fails = true;

      final outcome = await developer.start([jobAt(0)]).outcome;

      expect((outcome.developed, outcome.failed, outcome.leftover), (0, 1, 0));
      expect(await shots.allShots(), isEmpty);
      // Nothing in the own gallery would ever point to it, so it goes.
      expect(actions.deleted, ['content://media/1']);
    },
  );

  test('an orphan that cannot be removed is reported, never silent', () async {
    recorder.fails = true;
    actions.deletion = PhotoDeletion.failed;

    final outcome = await developer.start([jobAt(0)]).outcome;

    expect(outcome.leftover, 1);
    expect(outcome.complete, isFalse);
    // It tried twice.
    expect(actions.deleted, hasLength(2));
  });

  test(
    'undoing a cancelled export that fails leaves the photos told',
    () async {
      gate = Completer<void>();
      library.deletion = PhotoDeletion.failed;
      final run = developer.start([jobAt(0), jobAt(1)]);
      await Future<void>.delayed(Duration.zero);
      run.cancel();
      gate!.complete();

      final outcome = await run.outcome;

      expect(outcome.cancelled, isTrue);
      expect(outcome.leftover, 1);
      expect(library.deleted, hasLength(2)); // tried twice
    },
  );

  test('a user who refuses the system dialog also leaves it told', () async {
    gate = Completer<void>();
    library.deletion = PhotoDeletion.cancelled;
    final run = developer.start([jobAt(0)]);
    await Future<void>.delayed(Duration.zero);
    run.cancel();
    gate!.complete();

    expect((await run.outcome).leftover, 1);
  });

  test('cancelling stops after the current photo and keeps nothing', () async {
    gate = Completer<void>();
    final jobs = [jobAt(0), jobAt(1), jobAt(2)];
    final run = developer.start(jobs);
    // Let the first photo start, then cancel while it is being developed.
    await Future<void>.delayed(Duration.zero);
    run.cancel();
    expect(run.progress.value.cancelling, isTrue);
    gate!.complete();

    final outcome = await run.outcome;

    expect(outcome.cancelled, isTrue);
    expect(outcome.developed, 0);
    // Only the first photo was ever saved, and it was deleted again.
    expect(saved, hasLength(1));
    expect(library.deleted, hasLength(1));
    expect(library.deleted.single.$2, 'content://media/1');
    for (final job in jobs) {
      expect(File(job.filePath).existsSync(), isFalse);
    }
  });

  test('cancelling twice, or after the end, does nothing', () async {
    final run = developer.start([jobAt(0)]);
    run.cancel();
    run.cancel();
    final outcome = await run.outcome;
    run.cancel();
    expect(outcome.cancelled, isTrue);
  });
}
