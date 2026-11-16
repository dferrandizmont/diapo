import 'package:carrete/capture/capture_queue.dart';
import 'package:carrete/capture/film_capture_processor.dart';
import 'package:carrete/capture/loose_shot_recorder.dart';
import 'package:carrete/core/database/app_database.dart';
import 'package:carrete/core/database/converters.dart';
import 'package:carrete/core/database/shots_dao.dart';
import 'package:carrete/core/database/tables.dart';
import 'package:film_recipes/film_recipes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/test_database.dart';

CaptureJob _job(
  RecipeBook book, {
  DateTime? takenAt,
  FrameFormat format = FrameFormat.r4x3,
  ShotLens lens = ShotLens.back,
  String? captureId = 'cap0000001',
  bool retried = false,
}) {
  final recipe = book.byId('beta')!;
  return CaptureJob(
    filePath: '/camera.jpg',
    filmId: recipe.id,
    look: resolve(recipe),
    format: format,
    seed: 1,
    takenAt: takenAt ?? DateTime(2026, 11, 13, 18, 30, 15, 250),
    lens: lens,
    captureId: captureId,
    retried: retried,
  );
}

void main() {
  final book = testBook();
  late AppDatabase db;
  late ShotsDao shots;
  late LooseShotRecorder recorder;

  setUp(() {
    db = openMemoryDatabase();
    shots = ShotsDao(db);
    recorder = LooseShotRecorder(shots);
  });

  tearDown(() => db.close());

  test('records the film, format, lens, time, place and size', () async {
    final job = _job(book, lens: ShotLens.front);

    await recorder.record(
      job,
      const SavedStill('content://media/7', width: 4000, height: 3000),
    );

    final row = (await shots.allShots()).single;
    expect(row.rollId, isNull);
    expect(row.filmId, 'beta');
    expect(row.format, ShotFormat.ratio4x3);
    expect(row.lens, ShotLens.front);
    expect(row.takenAt, job.takenAt.millisecondsSinceEpoch);
    expect(row.galleryUri, 'content://media/7');
    expect((row.width, row.height), (4000, 3000));
  });

  test(
    'a shot retried after the process died is recorded once, at its place',
    () async {
      final taken = DateTime(2026, 11, 13, 18, 30);
      await recorder.record(
        _job(book, takenAt: taken),
        const SavedStill('content://media/7', width: 4000, height: 3000),
      );
      // The retry found the photo already saved: it knows no size.
      await recorder.record(
        _job(book, takenAt: taken, retried: true),
        const SavedStill('content://media/7'),
      );

      final rows = await shots.allShots();
      expect(rows, hasLength(1));
      expect(rows.single.width, 4000);
    },
  );

  test('two shots of the same moment keep their own rows', () async {
    final taken = DateTime(2026, 11, 13, 18, 30);

    await recorder.record(
      _job(book, takenAt: taken, captureId: 'one'),
      const SavedStill('content://media/1'),
    );
    await recorder.record(
      _job(book, takenAt: taken, captureId: 'two'),
      const SavedStill('content://media/2'),
    );

    expect(await shots.allShots(), hasLength(2));
  });

  test('every format of the camera can be recorded', () async {
    var minute = 0;
    for (final format in FrameFormat.values) {
      await recorder.record(
        _job(
          book,
          format: format,
          takenAt: DateTime(2026, 11, 13, 9, minute++),
          captureId: 'f$minute',
        ),
        SavedStill('content://media/$minute'),
      );
    }

    expect(await shots.allShots(), hasLength(FrameFormat.values.length));
  });

  test('throws when the database cannot, so the shot is kept', () async {
    final broken = LooseShotRecorder(_BrokenShots(db));

    await expectLater(
      broken.record(_job(book), const SavedStill('content://media/7')),
      throwsStateError,
    );
  });
}

/// A table of photos that cannot write.
class _BrokenShots extends ShotsDao {
  _BrokenShots(super.database);

  @override
  Future<ShotRow> recordLooseShot({
    required String filmId,
    required ShotFormat format,
    required ShotLens lens,
    required DateTime takenAt,
    required String galleryUri,
    String? captureId,
    int? width,
    int? height,
  }) => throw StateError('the database is locked');
}
