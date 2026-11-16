import 'package:carrete/core/database/app_database.dart';
import 'package:carrete/core/database/converters.dart';
import 'package:carrete/core/database/rolls_dao.dart';
import 'package:carrete/core/database/shots_dao.dart';
import 'package:carrete/core/database/tables.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/test_database.dart';

void main() {
  late AppDatabase db;
  late RollsDao rolls;
  late ShotsDao shots;

  setUp(() {
    db = openMemoryDatabase();
    rolls = RollsDao(db);
    shots = ShotsDao(db);
  });

  tearDown(() => db.close());

  Future<ShotRow> shoot(int? rollId, {DateTime? takenAt}) => shots.addShot(
    rollId: rollId,
    filmId: 'verano-98',
    format: ShotFormat.ratio3x2,
    lens: ShotLens.back,
    takenAt: takenAt ?? DateTime(2026, 10, 24, 12),
  );

  test('the frames of a roll are numbered from one', () async {
    final roll = await rolls.openRoll(filmId: 'verano-98', length: 12);

    final first = await shoot(roll.id);
    final second = await shoot(roll.id);
    final third = await shoot(roll.id);

    expect(first.frameNumber, 1);
    expect(second.frameNumber, 2);
    expect(third.frameNumber, 3);
    expect(first.rollId, roll.id);
  });

  test('removing an earlier photo does not duplicate a frame number', () async {
    final roll = await rolls.openRoll(filmId: 'verano-98', length: 12);
    final first = await shoot(roll.id);
    await shoot(roll.id);
    await (db.delete(db.shots)..where((s) => s.id.equals(first.id))).go();

    final next = await shoot(roll.id);

    expect(next.frameNumber, 3);
  });

  test('two photos of a roll cannot share a frame number', () async {
    final roll = await rolls.openRoll(filmId: 'verano-98', length: 12);
    final first = await shoot(roll.id);

    await expectLater(
      db.customStatement(
        'INSERT INTO shots (roll_id, frame_number, film_id, format, lens, taken_at) '
        "SELECT roll_id, frame_number, film_id, format, lens, taken_at FROM shots WHERE id = ${first.id}",
      ),
      throwsA(anything),
    );
  });

  test('a photo keeps the film, the format, the lens and the time', () async {
    final roll = await rolls.openRoll(filmId: 'invierno-84', length: 12);

    final shot = await shots.addShot(
      rollId: roll.id,
      filmId: 'invierno-84',
      format: ShotFormat.ratio16x9,
      lens: ShotLens.front,
      takenAt: DateTime(2026, 10, 24, 12, 34, 56),
      vaultPath: 'vault/1.jpg',
      width: 4032,
      height: 3024,
      intensity: 0.5,
      overridesJson: '{"grain":0.2}',
    );

    expect(shot.filmId, 'invierno-84');
    expect(shot.format, ShotFormat.ratio16x9);
    expect(shot.lens, ShotLens.front);
    expect(
      shot.takenAt,
      DateTime(2026, 10, 24, 12, 34, 56).millisecondsSinceEpoch,
    );
    expect(shot.vaultPath, 'vault/1.jpg');
    expect(shot.width, 4032);
    expect(shot.height, 3024);
    expect(shot.intensity, 0.5);
    expect(shot.overridesJson, '{"grain":0.2}');
    expect(shot.galleryUri, isNull);
  });

  test('the strength of the film look is one by default', () async {
    final shot = await shoot(null);
    expect(shot.intensity, 1);
  });

  test('a photo without a roll is a loose one, without a frame', () async {
    final shot = await shoot(null);

    expect(shot.rollId, isNull);
    expect(shot.frameNumber, isNull);
  });

  test('a roll that is full refuses the photos', () async {
    final roll = await rolls.openRoll(filmId: 'verano-98', length: 2);

    await shoot(roll.id);
    await shoot(roll.id);

    expect(
      () => shoot(roll.id),
      throwsA(
        isA<RollRefusedException>().having(
          (error) => error.reason,
          'reason',
          RollRefusal.full,
        ),
      ),
    );
  });

  test('a roll that is closed refuses the photos', () async {
    final roll = await rolls.openRoll(filmId: 'verano-98', length: 12);
    await rolls.closeRoll(roll.id, now: DateTime(2026, 10, 24, 12));

    expect(
      () => shoot(roll.id),
      throwsA(
        isA<RollRefusedException>().having(
          (error) => error.reason,
          'reason',
          RollRefusal.notOpen,
        ),
      ),
    );
  });

  test('a roll that does not exist refuses the photos', () async {
    expect(
      () => shoot(42),
      throwsA(
        isA<RollRefusedException>().having(
          (error) => error.reason,
          'reason',
          RollRefusal.missing,
        ),
      ),
    );
  });

  test('the photos of a roll come in the order of their frame', () async {
    final roll = await rolls.openRoll(filmId: 'verano-98', length: 12);
    await shoot(roll.id);
    await shoot(roll.id);

    expect((await shots.shotsOfRoll(roll.id)).map((shot) => shot.frameNumber), [
      1,
      2,
    ]);
  });

  test('a photo that is saved in the gallery keeps its place', () async {
    final shot = await shoot(null);

    await shots.markSavedInGallery(shot.id, 'content://media/1');

    expect((await shots.shotById(shot.id))!.galleryUri, 'content://media/1');
  });

  group('loose photos', () {
    Future<ShotRow> record(
      DateTime takenAt, {
      String film = 'verano-98',
      String uri = 'content://media/1',
      int? width,
      int? height,
      ShotLens lens = ShotLens.back,
      String? id,
    }) => shots.recordLooseShot(
      filmId: film,
      format: ShotFormat.ratio4x3,
      lens: lens,
      takenAt: takenAt,
      galleryUri: uri,
      captureId: id,
      width: width,
      height: height,
    );

    test(
      'a loose photo is recorded with its film, lens, size and place',
      () async {
        final taken = DateTime(2026, 11, 13, 9, 30);

        final shot = await record(
          taken,
          width: 3000,
          height: 4000,
          lens: ShotLens.front,
        );

        expect(shot.rollId, isNull);
        expect(shot.frameNumber, isNull);
        expect(shot.filmId, 'verano-98');
        expect(shot.format, ShotFormat.ratio4x3);
        expect(shot.lens, ShotLens.front);
        expect(shot.takenAt, taken.millisecondsSinceEpoch);
        expect(shot.galleryUri, 'content://media/1');
        expect((shot.width, shot.height), (3000, 4000));
        expect(shot.vaultPath, isNull);
      },
    );

    test(
      'recording the same shot again updates it and adds no second row',
      () async {
        final taken = DateTime(2026, 11, 13, 9, 30);

        final first = await record(taken, uri: 'content://media/1', id: 'abc');
        final again = await record(
          taken,
          uri: 'content://media/2',
          width: 10,
          id: 'abc',
        );

        expect(again.id, first.id);
        expect(again.galleryUri, 'content://media/2');
        expect(again.width, 10);
        expect(await shots.allShots(), hasLength(1));
      },
    );

    test('a record without a size keeps the size it had', () async {
      final taken = DateTime(2026, 11, 13, 9, 30);
      await record(taken, id: 'abc', width: 3000, height: 4000);

      // A retry that found the photo already saved knows no size.
      final again = await record(taken, id: 'abc', uri: 'content://media/2');

      expect((again.width, again.height), (3000, 4000));
    });

    test(
      'two different shots of the same millisecond and film stay two photos',
      () async {
        final taken = DateTime(2026, 11, 13, 9, 30);

        final one = await record(taken, id: 'one', uri: 'content://media/1');
        final two = await record(taken, id: 'two', uri: 'content://media/2');

        expect(two.id, isNot(one.id));
        expect(await shots.allShots(), hasLength(2));
        expect((await shots.shotById(one.id))!.galleryUri, 'content://media/1');
      },
    );

    test('shots with no identity at different places are two photos', () async {
      final taken = DateTime(2026, 11, 13, 9, 30);

      await record(taken, uri: 'content://media/1');
      await record(taken, uri: 'content://media/2');

      expect(await shots.allShots(), hasLength(2));
    });

    test('a shot with no identity is found by the place of its photo', () async {
      final taken = DateTime(2026, 11, 13, 9, 30);

      final first = await record(taken, uri: 'content://media/1');
      // A restart after recording but before the cleanup: the same photo again.
      final again = await record(taken, uri: 'content://media/1');
      final other = await record(taken, uri: 'content://media/2');

      expect(again.id, first.id);
      expect(other.id, isNot(first.id));
      expect(await shots.allShots(), hasLength(2));
    });

    test(
      'a row goes only while it still holds the place that was checked',
      () async {
        final shot = await record(DateTime(2026, 11, 13, 9, 30), id: 'abc');

        expect(
          await shots.deleteShotIfGalleryUri(shot.id, 'content://media/9'),
          isFalse,
        );
        expect(await shots.shotById(shot.id), isNotNull);
        expect(
          await shots.deleteShotIfGalleryUri(shot.id, 'content://media/1'),
          isTrue,
        );
        expect(await shots.shotById(shot.id), isNull);
      },
    );

    test('a shot is told apart from the frames of a roll', () async {
      final roll = await rolls.openRoll(filmId: 'verano-98', length: 12);
      // A roll frame whose job holds the same id must not be taken for it.
      await shots.addShot(
        rollId: roll.id,
        filmId: 'verano-98',
        format: ShotFormat.ratio3x2,
        lens: ShotLens.back,
        takenAt: DateTime(2026, 11, 13, 9, 30),
        captureJobJson: ShotsDao.looseCaptureKey('abc'),
      );

      final loose = await record(DateTime(2026, 11, 13, 9, 30), id: 'abc');

      expect(loose.rollId, isNull);
      expect(await shots.allShots(), hasLength(2));
    });

    test('a loose photo never takes the place of a frame of a roll', () async {
      final roll = await rolls.openRoll(filmId: 'verano-98', length: 12);
      final taken = DateTime(2026, 11, 13, 9, 30);
      final frame = await shoot(roll.id, takenAt: taken);

      final loose = await record(taken);

      expect(loose.id, isNot(frame.id));
      expect((await shots.shotById(frame.id))!.galleryUri, isNull);
    });

    test(
      'the gallery watches only the photos that are in the gallery',
      () async {
        await shoot(null); // not saved yet
        await record(DateTime(2026, 11, 13, 9, 30), uri: 'content://media/1');
        await record(DateTime(2026, 11, 13, 10, 30), uri: 'content://media/2');

        final watched = await shots.watchGalleryShots().first;

        expect(watched.map((s) => s.galleryUri), [
          'content://media/2',
          'content://media/1',
        ]);
      },
    );

    test('a deleted photo leaves the database and the rest stay', () async {
      final keep = await record(DateTime(2026, 11, 13, 9, 30));
      final drop = await record(
        DateTime(2026, 11, 13, 10, 30),
        uri: 'content://media/2',
      );

      await shots.deleteShot(drop.id);

      expect(await shots.shotById(drop.id), isNull);
      expect(await shots.shotById(keep.id), isNotNull);
    });

    test('deleting a photo that is not there is harmless', () async {
      await shots.deleteShot(999);
    });
  });
}
