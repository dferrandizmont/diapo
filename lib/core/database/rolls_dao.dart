import 'package:drift/drift.dart';

import 'app_database.dart';
import 'develop_schedule.dart';
import 'tables.dart';

/// The rules of the rolls: how many frames they have, when they develop and
/// when they are ready.
///
/// The times of the arguments and of the results are local times; they are
/// stored in the database as milliseconds since the epoch (UTC).
class RollsDao {
  RollsDao(this._database);

  final AppDatabase _database;

  Future<RollRow?> activeRoll() =>
      (_database.select(_database.rolls)
            ..where((r) => r.state.equals(RollState.open.name))
            ..limit(1))
          .getSingleOrNull();

  Stream<RollRow?> watchActiveRoll() =>
      (_database.select(_database.rolls)
            ..where((r) => r.state.equals(RollState.open.name))
            ..limit(1))
          .watchSingleOrNull();

  Stream<List<RollRow>> watchRolls() => (_database.select(
    _database.rolls,
  )..orderBy([(r) => OrderingTerm.desc(r.createdAt)])).watch();

  Stream<RollRow?> watchRoll(int id) => (_database.select(
    _database.rolls,
  )..where((r) => r.id.equals(id))).watchSingleOrNull();

  Stream<List<ShotRow>> watchShots(int id) =>
      (_database.select(_database.shots)
            ..where((s) => s.rollId.equals(id))
            ..orderBy([(s) => OrderingTerm.asc(s.frameNumber)]))
          .watch();

  Stream<int> watchRemainingFrames() {
    final query = _database.customSelect(
      "SELECT r.length - COUNT(s.id) AS remaining FROM rolls r "
      "LEFT JOIN shots s ON s.roll_id = r.id WHERE r.state = 'open' "
      'GROUP BY r.id LIMIT 1',
      readsFrom: {_database.rolls, _database.shots},
    );
    return query.watch().map(
      (rows) => rows.isEmpty ? 0 : rows.single.read<int>('remaining'),
    );
  }

  Future<int> markLost(int id, DateTime now) =>
      (_database.update(_database.rolls)..where((r) => r.id.equals(id))).write(
        RollsCompanion(
          state: const Value(RollState.lost),
          lostAt: Value(now.millisecondsSinceEpoch),
        ),
      );

  /// Opens a roll of [filmId] with [length] frames.
  ///
  /// The roll develops [developDelay] after it is closed.
  Future<RollRow> openRoll({
    required String filmId,
    required int length,
    RollMode mode = RollMode.roll,
    DevelopDelay developDelay = DevelopDelay.oneHour,
    DateTime? now,
  }) async {
    final id = await _database
        .into(_database.rolls)
        .insert(
          RollsCompanion.insert(
            filmId: filmId,
            length: length,
            mode: mode,
            developDelay: developDelay,
            state: RollState.open,
            createdAt: _millis(now ?? DateTime.now()),
          ),
        );
    return (await rollById(id))!;
  }

  /// The roll [id], or null when there is no such roll.
  Future<RollRow?> rollById(int id) => (_database.select(
    _database.rolls,
  )..where((roll) => roll.id.equals(id))).getSingleOrNull();

  /// Every roll, the newest first.
  Future<List<RollRow>> allRolls() => (_database.select(
    _database.rolls,
  )..orderBy([(roll) => OrderingTerm.desc(roll.createdAt)])).get();

  /// The frames the roll [id] has left.
  Future<int> remainingFrames(int id) async {
    final roll = await rollById(id);
    if (roll == null) throw ArgumentError.value(id, 'id', 'No such roll');
    return roll.length - await shotsTaken(id);
  }

  /// The photos of the roll [id], in the order of their frame.
  Future<List<ShotRow>> shotsOf(int id) =>
      (_database.select(_database.shots)
            ..where((shot) => shot.rollId.equals(id))
            ..orderBy([(shot) => OrderingTerm.asc(shot.frameNumber)]))
          .get();

  /// Closes the roll [id] and schedules its development.
  ///
  /// The roll has to be open. The time of the development comes from the
  /// delay of the roll (see [developAtFor]).
  Future<RollRow> closeRoll(int id, {DateTime? now}) async {
    final closedAt = now ?? DateTime.now();
    return _database.transaction(() async {
      final roll = await rollById(id);
      if (roll == null) throw ArgumentError.value(id, 'id', 'No such roll');
      if (roll.state != RollState.open) {
        throw StateError('The roll $id is ${roll.state.name}, not open');
      }
      await (_database.update(
        _database.rolls,
      )..where((row) => row.id.equals(id))).write(
        RollsCompanion(
          state: const Value(RollState.developing),
          closedAt: Value(_millis(closedAt)),
          developAt: Value(_millis(developAtFor(roll.developDelay, closedAt))),
        ),
      );
      return (await rollById(id))!;
    });
  }

  /// Atomically closes a roll and persists eligibility for early developing.
  Future<void> requestDevelopNow(int id, {required DateTime now}) =>
      _database.transaction(() async {
        final roll = await rollById(id);
        if (roll == null) throw ArgumentError.value(id, 'id', 'No such roll');
        if (roll.state != RollState.open &&
            roll.state != RollState.developing) {
          return;
        }
        await (_database.update(
          _database.rolls,
        )..where((r) => r.id.equals(id))).write(
          RollsCompanion(
            state: const Value(RollState.developing),
            closedAt: Value(roll.closedAt ?? _millis(now)),
            developAt: Value(_millis(now)),
          ),
        );
      });

  /// The rolls whose time to develop has come at [at], the oldest first.
  Future<List<RollRow>> rollsDueForDeveloping(DateTime at) =>
      (_database.select(_database.rolls)
            ..where(
              (roll) =>
                  roll.state.equals(RollState.developing.name) &
                  roll.developAt.isSmallerOrEqualValue(_millis(at)),
            )
            ..orderBy([(roll) => OrderingTerm.asc(roll.developAt)]))
          .get();

  /// Marks the roll [id] as developed.
  ///
  /// The roll has to be developing (closed and waiting for its time).
  Future<RollRow> markDeveloped(int id, {DateTime? now}) async {
    final developedAt = now ?? DateTime.now();
    return _database.transaction(() async {
      final roll = await rollById(id);
      if (roll == null) throw ArgumentError.value(id, 'id', 'No such roll');
      if (roll.state != RollState.developing) {
        throw StateError('The roll $id is ${roll.state.name}, not developing');
      }
      await (_database.update(
        _database.rolls,
      )..where((row) => row.id.equals(id))).write(
        RollsCompanion(
          state: const Value(RollState.developed),
          developedAt: Value(_millis(developedAt)),
        ),
      );
      return (await rollById(id))!;
    });
  }

  /// Throws the roll [id] away.
  ///
  /// The photos of the roll are kept: the vault (and what happens to the
  /// files of a discarded roll) is decided later.
  Future<RollRow> discardRoll(int id, {DateTime? now}) async {
    final discardedAt = now ?? DateTime.now();
    return _database.transaction(() async {
      final roll = await rollById(id);
      if (roll == null) throw ArgumentError.value(id, 'id', 'No such roll');
      if (roll.state == RollState.discarded) return roll;
      await (_database.update(
        _database.rolls,
      )..where((row) => row.id.equals(id))).write(
        RollsCompanion(
          state: const Value(RollState.discarded),
          closedAt: Value(roll.closedAt ?? _millis(discardedAt)),
        ),
      );
      return (await rollById(id))!;
    });
  }

  /// Gives the roll [id] the [name] (already cleaned by the caller); null
  /// clears it. Throws when there is no such roll.
  Future<void> renameRoll(int id, String? name) async {
    final rows = await (_database.update(
      _database.rolls,
    )..where((r) => r.id.equals(id))).write(RollsCompanion(name: Value(name)));
    if (rows == 0) throw ArgumentError.value(id, 'id', 'No such roll');
  }

  /// The number of photos the roll [id] has.
  Future<int> shotsTaken(int id) async {
    final count = _database.shots.id.count();
    final query = _database.selectOnly(_database.shots)
      ..addColumns([count])
      ..where(_database.shots.rollId.equals(id));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }
}

/// The milliseconds since the epoch of [time].
int _millis(DateTime time) => time.millisecondsSinceEpoch;
