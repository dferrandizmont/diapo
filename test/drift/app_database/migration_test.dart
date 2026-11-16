import 'package:carrete/core/database/app_database.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final verifier = SchemaVerifier(GeneratedHelper());

  test('the app opens the latest snapshot', () {
    expect(AppDatabase.latestSchemaVersion, 3);
  });

  test('v1 to v2 schema matches the generated snapshot', () async {
    final schema = await verifier.schemaAt(1);
    final db = AppDatabase(schema.newConnection());
    try {
      await verifier.migrateAndValidate(db, 2);
    } finally {
      await db.close();
    }
  });

  test(
    'v1 to v2 preserves encrypted and saved photos and roll state',
    () async {
      await verifier.testWithDataIntegrity(
        oldVersion: 1,
        newVersion: 2,
        createOld: v1.DatabaseAtV1.new,
        createNew: v2.DatabaseAtV2.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch.insertAll(oldDb.rolls, const [
            v1.RollsData(
              id: 1,
              filmId: 'verano-98',
              length: 24,
              mode: 'roll',
              developDelay: 'nextMorning',
              state: 'open',
              createdAt: 1000,
            ),
            v1.RollsData(
              id: 2,
              filmId: 'gamma',
              length: 12,
              mode: 'roll',
              developDelay: 'instant',
              state: 'developed',
              createdAt: 1000,
              closedAt: 2000,
              developAt: 2000,
              developedAt: 3000,
            ),
          ]);
          batch.insertAll(oldDb.shots, const [
            v1.ShotsData(
              id: 1,
              rollId: 1,
              frameNumber: 1,
              filmId: 'verano-98',
              format: '3:2',
              lens: 'front',
              takenAt: 1100,
              vaultPath: 'encrypted',
              intensity: 0.7,
              overridesJson: '{"grain":1.5}',
            ),
            v1.ShotsData(
              id: 2,
              rollId: 2,
              frameNumber: 1,
              filmId: 'gamma',
              format: '1:1',
              lens: 'back',
              takenAt: 1100,
              galleryUri: 'content://saved',
              width: 4000,
              height: 4000,
              intensity: 1,
            ),
          ]);
        },
        validateItems: (newDb) async {
          final rolls = await newDb.select(newDb.rolls).get();
          expect(rolls, const [
            v2.RollsData(
              id: 1,
              filmId: 'verano-98',
              length: 24,
              mode: 'roll',
              developDelay: 'nextMorning',
              state: 'open',
              createdAt: 1000,
            ),
            v2.RollsData(
              id: 2,
              filmId: 'gamma',
              length: 12,
              mode: 'roll',
              developDelay: 'instant',
              state: 'developed',
              createdAt: 1000,
              closedAt: 2000,
              developAt: 2000,
              developedAt: 3000,
            ),
          ]);
          final shots = await newDb.select(newDb.shots).get();
          expect(shots, const [
            v2.ShotsData(
              id: 1,
              rollId: 1,
              frameNumber: 1,
              filmId: 'verano-98',
              format: '3:2',
              lens: 'front',
              takenAt: 1100,
              vaultPath: 'encrypted',
              intensity: 0.7,
              overridesJson: '{"grain":1.5}',
            ),
            v2.ShotsData(
              id: 2,
              rollId: 2,
              frameNumber: 1,
              filmId: 'gamma',
              format: '1:1',
              lens: 'back',
              takenAt: 1100,
              galleryUri: 'content://saved',
              width: 4000,
              height: 4000,
              intensity: 1,
            ),
          ]);
          expect(rolls.every((r) => r.lostAt == null), isTrue);
          expect(
            shots.every(
              (s) => s.captureJobJson == null && s.developFailure == null,
            ),
            isTrue,
          );
        },
      );
    },
  );

  test('v2 to v3 schema matches the generated snapshot', () async {
    final schema = await verifier.schemaAt(2);
    final db = AppDatabase(schema.newConnection());
    try {
      await verifier.migrateAndValidate(db, 3);
    } finally {
      await db.close();
    }
  });

  test('v1 straight to v3 schema matches the generated snapshot', () async {
    final schema = await verifier.schemaAt(1);
    final db = AppDatabase(schema.newConnection());
    try {
      await verifier.migrateAndValidate(db, 3);
    } finally {
      await db.close();
    }
  });

  test(
    'v2 to v3 keeps every roll and photo and gives the rolls no name',
    () async {
      await verifier.testWithDataIntegrity(
        oldVersion: 2,
        newVersion: 3,
        createOld: v2.DatabaseAtV2.new,
        createNew: v3.DatabaseAtV3.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch.insertAll(oldDb.rolls, const [
            v2.RollsData(
              id: 1,
              filmId: 'verano-98',
              length: 24,
              mode: 'roll',
              developDelay: 'nextMorning',
              state: 'developing',
              createdAt: 1000,
              closedAt: 2000,
              developAt: 5000,
            ),
            v2.RollsData(
              id: 2,
              filmId: 'gamma',
              length: 12,
              mode: 'roll',
              developDelay: 'instant',
              state: 'lost',
              createdAt: 1000,
              lostAt: 4000,
            ),
          ]);
          batch.insertAll(oldDb.shots, const [
            v2.ShotsData(
              id: 1,
              rollId: 1,
              frameNumber: 1,
              filmId: 'verano-98',
              format: '3:2',
              lens: 'back',
              takenAt: 1100,
              vaultPath: 'encrypted',
              intensity: 0.7,
            ),
          ]);
        },
        validateItems: (newDb) async {
          final rolls = await newDb.select(newDb.rolls).get();
          expect(rolls, hasLength(2));
          expect(rolls.map((r) => r.id), [1, 2]);
          expect(rolls.map((r) => r.state), ['developing', 'lost']);
          expect(rolls.first.developAt, 5000);
          expect(rolls.last.lostAt, 4000);
          // Rolls that exist keep no name.
          expect(rolls.every((r) => r.name == null), isTrue);
          final shots = await newDb.select(newDb.shots).get();
          expect(shots.single.vaultPath, 'encrypted');
        },
      );
    },
  );

  test('a name written after the migration is stored and cleared', () async {
    final schema = await verifier.schemaAt(2);
    final db = AppDatabase(schema.newConnection());
    try {
      await verifier.migrateAndValidate(db, 3);
      await db.customStatement(
        'INSERT INTO rolls (film_id, length, mode, develop_delay, state, created_at) '
        "VALUES ('gamma', 12, 'roll', 'instant', 'open', 1)",
      );
      await db.customStatement("UPDATE rolls SET name = 'Verano'");
      expect((await db.select(db.rolls).getSingle()).name, 'Verano');
      await db.customStatement('UPDATE rolls SET name = NULL');
      expect((await db.select(db.rolls).getSingle()).name, isNull);
    } finally {
      await db.close();
    }
  });
}
