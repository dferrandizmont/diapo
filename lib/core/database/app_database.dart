import 'package:drift/drift.dart';

import 'app_database.steps.dart';
import 'converters.dart';
import 'tables.dart';

part 'app_database.g.dart';

/// The database of the app: the rolls of film and their photos.
///
/// It never leaves the device: there is no server, no account and no copy of
/// the photos anywhere else.
@DriftDatabase(tables: [Rolls, Shots])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// The schema version this code expects. Bump it together with a new
  /// migration step (see `app_database.steps.dart`).
  static const int latestSchemaVersion = 3;

  @override
  int get schemaVersion => latestSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    // `stepByStep` comes from app_database.steps.dart, regenerated with
    // `dart run drift_dev make-migrations`; every new version adds its
    // `fromXToY:` argument here.
    onUpgrade: stepByStep(
      from1To2: (m, schema) async {
        await m.addColumn(schema.rolls, schema.rolls.lostAt);
        await m.addColumn(schema.shots, schema.shots.captureJobJson);
        await m.addColumn(schema.shots, schema.shots.developFailure);
      },
      from2To3: (m, schema) async {
        // The optional name of a roll: the rolls that exist keep none.
        await m.addColumn(schema.rolls, schema.rolls.name);
      },
    ),
    beforeOpen: (details) async {
      // The photos of a roll go away with the roll.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
