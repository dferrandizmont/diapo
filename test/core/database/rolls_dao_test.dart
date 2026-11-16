import 'dart:async';

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

  setUp(() {
    db = openMemoryDatabase();
    rolls = RollsDao(db);
  });

  tearDown(() => db.close());

  test(
    'watchRoll follows only its id, including a missing or deleted roll',
    () async {
      final stream = StreamIterator(rolls.watchRoll(1));
      addTearDown(stream.cancel);
      expect(await stream.moveNext(), isTrue);
      expect(stream.current, isNull);

      final target = await rolls.openRoll(filmId: 'verano-98', length: 12);
      expect(target.id, 1);
      expect(await stream.moveNext(), isTrue);
      expect(stream.current, target);

      final closed = await rolls.closeRoll(target.id);
      expect(await stream.moveNext(), isTrue);
      expect(stream.current, closed);

      await rolls.openRoll(filmId: 'verano-98', length: 24);
      await (db.delete(db.rolls)..where((r) => r.id.equals(target.id))).go();
      while (stream.current != null) {
        expect(await stream.moveNext(), isTrue);
        expect(stream.current?.id, anyOf(isNull, target.id));
      }
    },
  );

  test('a roll that is opened is open, with its film and its frames', () async {
    final roll = await rolls.openRoll(
      filmId: 'verano-98',
      length: 24,
      now: DateTime(2026, 10, 24, 12),
    );

    expect(roll.filmId, 'verano-98');
    expect(roll.length, 24);
    expect(roll.mode, RollMode.roll);
    expect(roll.developDelay, DevelopDelay.oneHour);
    expect(roll.state, RollState.open);
    expect(roll.closedAt, isNull);
    expect(roll.developAt, isNull);
    expect(roll.developedAt, isNull);
    expect(roll.createdAt, DateTime(2026, 10, 24, 12).millisecondsSinceEpoch);
    expect(await rolls.remainingFrames(roll.id), 24);
  });

  test('the frames of a roll go down as it is shot', () async {
    final roll = await rolls.openRoll(filmId: 'verano-98', length: 12);
    final shots = ShotsDao(db);

    expect(await rolls.remainingFrames(roll.id), 12);
    await shots.addShot(
      rollId: roll.id,
      filmId: 'verano-98',
      format: ShotFormat.ratio3x2,
      lens: ShotLens.back,
      takenAt: DateTime(2026, 10, 24, 12),
    );
    expect(await rolls.remainingFrames(roll.id), 11);
  });

  test('a closed roll schedules its development and is developing', () async {
    final roll = await rolls.openRoll(
      filmId: 'verano-98',
      length: 24,
      developDelay: DevelopDelay.oneHour,
    );
    final closedAt = DateTime(2026, 10, 24, 21, 30);

    final closed = await rolls.closeRoll(roll.id, now: closedAt);

    expect(closed.state, RollState.developing);
    expect(closed.closedAt, closedAt.millisecondsSinceEpoch);
    expect(
      closed.developAt,
      DateTime(2026, 10, 24, 22, 30).millisecondsSinceEpoch,
    );
  });

  test('a roll that develops the next morning waits for the 08:00 of the '
      'next day', () async {
    final roll = await rolls.openRoll(
      filmId: 'verano-98',
      length: 24,
      developDelay: DevelopDelay.nextMorning,
    );

    final closed = await rolls.closeRoll(
      roll.id,
      now: DateTime(2026, 10, 24, 21, 30),
    );

    expect(closed.developAt, DateTime(2026, 10, 25, 8).millisecondsSinceEpoch);
  });

  test('a roll that is not open cannot be closed', () async {
    final roll = await rolls.openRoll(filmId: 'verano-98', length: 24);
    await rolls.closeRoll(roll.id, now: DateTime(2026, 10, 24, 12));

    expect(
      () => rolls.closeRoll(roll.id, now: DateTime(2026, 10, 24, 13)),
      throwsA(isA<StateError>()),
    );
  });

  test('a roll that does not exist cannot be closed', () async {
    expect(
      () => rolls.closeRoll(42, now: DateTime(2026, 10, 24, 12)),
      throwsA(isA<ArgumentError>()),
    );
  });

  test(
    'the rolls due for developing are the ones whose time has come',
    () async {
      final due = await rolls.openRoll(
        filmId: 'verano-98',
        length: 24,
        developDelay: DevelopDelay.oneHour,
      );
      await rolls.closeRoll(due.id, now: DateTime(2026, 10, 24, 12));

      final late = await rolls.openRoll(
        filmId: 'verano-98',
        length: 24,
        developDelay: DevelopDelay.oneHour,
      );
      await rolls.closeRoll(late.id, now: DateTime(2026, 10, 24, 18));

      final open = await rolls.openRoll(filmId: 'verano-98', length: 24);

      expect(
        (await rolls.rollsDueForDeveloping(DateTime(2026, 10, 24, 12, 59)))
            .map((roll) => roll.id),
        isEmpty,
      );
      expect(
        (await rolls.rollsDueForDeveloping(DateTime(2026, 10, 24, 13)))
            .map((roll) => roll.id),
        [due.id],
      );
      expect(
        (await rolls.rollsDueForDeveloping(DateTime(2026, 10, 24, 19)))
            .map((roll) => roll.id),
        [due.id, late.id],
      );
      // A roll that is open never develops.
      expect(
        (await rolls.rollsDueForDeveloping(DateTime(2027, 1, 1)))
            .map((roll) => roll.id),
        isNot(contains(open.id)),
      );
    },
  );

  test('a developed roll keeps the time it was developed at', () async {
    final roll = await rolls.openRoll(
      filmId: 'verano-98',
      length: 24,
      developDelay: DevelopDelay.instant,
    );
    await rolls.closeRoll(roll.id, now: DateTime(2026, 10, 24, 12));

    final developed = await rolls.markDeveloped(
      roll.id,
      now: DateTime(2026, 10, 24, 12),
    );

    expect(developed.state, RollState.developed);
    expect(
      developed.developedAt,
      DateTime(2026, 10, 24, 12).millisecondsSinceEpoch,
    );
    // A developed roll is not due anymore.
    expect(await rolls.rollsDueForDeveloping(DateTime(2027, 1, 1)), isEmpty);
  });

  test('a roll that is not developing cannot be marked as developed', () async {
    final roll = await rolls.openRoll(filmId: 'verano-98', length: 24);

    expect(
      () => rolls.markDeveloped(roll.id, now: DateTime(2026, 10, 24, 12)),
      throwsA(isA<StateError>()),
    );
  });

  test('a discarded roll is discarded', () async {
    final roll = await rolls.openRoll(filmId: 'verano-98', length: 24);

    final discarded = await rolls.discardRoll(
      roll.id,
      now: DateTime(2026, 10, 24, 12),
    );

    expect(discarded.state, RollState.discarded);
    expect(
      discarded.closedAt,
      DateTime(2026, 10, 24, 12).millisecondsSinceEpoch,
    );
  });

  test('every roll comes with the newest first', () async {
    final first = await rolls.openRoll(
      filmId: 'verano-98',
      length: 24,
      now: DateTime(2026, 10, 24, 12),
    );
    final second = await rolls.openRoll(
      filmId: 'verano-98',
      length: 24,
      now: DateTime(2026, 10, 25, 12),
    );

    expect((await rolls.allRolls()).map((roll) => roll.id), [
      second.id,
      first.id,
    ]);
  });
}
