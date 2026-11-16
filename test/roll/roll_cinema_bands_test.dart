import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:diapo/capture/capture_queue.dart';
import 'package:diapo/capture/failed_shots.dart';
import 'package:diapo/capture/film_capture_processor.dart';
import 'package:diapo/core/database/app_database.dart';
import 'package:diapo/core/database/rolls_dao.dart';
import 'package:diapo/core/database/tables.dart';
import 'package:diapo/core/settings/film_tuning.dart';
import 'package:diapo/core/vault/encrypted_shot_vault.dart';
import 'package:diapo/core/vault/vault_key_store.dart';
import 'package:diapo/location/photo_location.dart';
import 'package:diapo/roll/roll_developer.dart';
import 'package:diapo/roll/roll_operations.dart';
import 'package:diapo/roll/roll_recovery.dart';
import 'package:diapo/roll/roll_service.dart';
import 'package:diapo/roll/roll_vault_payload.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:film_recipes/film_recipes.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'roll_test.dart' show FakeNotifications;

enum _Snapshot { enabled, disabled, legacyV1, legacyV2 }

/// Model records written before cinema bands existed, at all three levels.
Map<String, Object?> _oldSnapshot(
  Map<String, Object?> snapshot,
  _Snapshot kind,
) {
  if (kind == _Snapshot.enabled || kind == _Snapshot.disabled) return snapshot;
  snapshot.remove('cinemaBands');
  (snapshot['tuning'] as Map).remove('cinemaBands');
  (snapshot['look'] as Map?)?.remove('cinemaBands');
  if (kind == _Snapshot.legacyV1) {
    snapshot['version'] = 1;
    snapshot.remove('look');
  }
  return snapshot;
}

void _expectSnapshot(
  Map<String, Object?> snapshot,
  RecipeBook book,
  bool bands,
) {
  final decoded = FailedShots.decode(snapshot, book, 'restored.jpg')!;
  expect(decoded.filmId, 'cine');
  expect(decoded.format, FrameFormat.r16x9);
  expect(decoded.cinemaBands, bands);
  expect(decoded.look.cinemaBands, bands);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final book = RecipeBook.parse(
    File('packages/film_recipes/assets/recipes.json').readAsStringSync(),
  );
  final when = DateTime.utc(2026, 11, 14, 12);
  const pixels = BasicMessageChannel<ByteData?>(
    'carrete/media/pixels',
    BinaryCodec(),
  );
  const media = MethodChannel('carrete/media');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  for (final recovery in [false, true]) {
    for (final location in [false, true]) {
      for (final kind in _Snapshot.values) {
        testWidgets('${recovery ? 'journal recovery' : 'committed frame'}: '
            '${kind.name}, ${location ? 'encrypted job envelope' : 'database job'} '
            'survives restart and renders its stored bands', (tester) async {
          await tester.runAsync(() async {
            expect(resolve(book.byId('cine')!).cinemaBands, isTrue);
            final root = await Directory.systemTemp.createTemp('roll_bands_');
            addTearDown(() => root.delete(recursive: true));
            final keys = InMemoryVaultKeyStore();
            late AppDatabase db;
            late EncryptedShotVault vault;
            late RollService service;
            late RollDeveloper developer;
            late RollOperations operations;
            var now = when;
            var saves = 0;
            final bands = kind == _Snapshot.enabled;

            messenger.setMockMethodCallHandler(media, (call) async {
              expect(call.method, 'beginSave');
              final args = call.arguments as Map;
              expect((args['width'], args['height']), (320, 180));
              return 1;
            });
            messenger.setMockDecodedMessageHandler<ByteData?>(pixels, (
              message,
            ) async {
              final rgba = Uint8List.sublistView(message!);
              expect(rgba.length, 320 * 180 * 4);
              final blackRows = <int>[];
              for (var y = 0; y < 180; y++) {
                var black = true;
                for (var x = 0; x < 320; x++) {
                  final i = (y * 320 + x) * 4;
                  if (rgba[i] != 10 ||
                      rgba[i + 1] != 10 ||
                      rgba[i + 2] != 10 ||
                      rgba[i + 3] != 255) {
                    black = false;
                    break;
                  }
                }
                if (black) blackRows.add(y);
              }
              // Independent 2.39:1 reference, rounded to raster rows.
              final inset = ((180 - 320 / 2.39) / 2).round();
              expect(
                blackRows,
                bands
                    ? [
                        for (var y = 0; y < inset; y++) y,
                        for (var y = 180 - inset; y < 180; y++) y,
                      ]
                    : isEmpty,
              );
              saves++;
              return ByteData.sublistView(
                utf8.encode('{"ok":true,"uri":"content://bands/1"}'),
              );
            });
            addTearDown(() {
              messenger.setMockMethodCallHandler(media, null);
              messenger.setMockDecodedMessageHandler<ByteData?>(pixels, null);
            });

            void open() {
              db = AppDatabase(
                NativeDatabase(File('${root.path}/roll.sqlite')),
              );
              vault = EncryptedShotVault(
                directory: () => Directory('${root.path}/vault'),
                keys: keys,
              );
              operations = RollOperations();
              developer = RollDeveloper(
                database: db,
                vault: vault,
                processor: FilmCaptureProcessor(
                  loadProgram: () =>
                      ui.FragmentProgram.fromAsset('shaders/film.frag'),
                ),
                notifications: FakeNotifications(),
                cache: root,
                loadBook: () async => book,
                operations: operations,
                clock: () => now,
                findSaved: (_) async => null,
              );
              service = RollService(
                database: db,
                vault: vault,
                notifications: FakeNotifications(),
                developer: developer,
                operations: operations,
                cache: root,
                clock: () => now,
                defaultFilm: () => 'cine',
              );
            }

            Future<void> close() async {
              await operations.run(() async {});
              service.dispose();
              developer.dispose();
              await db.close();
            }

            open();
            addTearDown(() => close());
            final recorder = ui.PictureRecorder();
            ui.Canvas(recorder)
                .drawColor(const ui.Color(0xffb06030), ui.BlendMode.src);
            final picture = recorder.endRecording();
            final image = await picture.toImage(320, 180);
            picture.dispose();
            late Uint8List original;
            try {
              original = Uint8List.sublistView(
                (await image.toByteData(format: ui.ImageByteFormat.png))!,
              );
            } finally {
              image.dispose();
            }
            final file = await File('${root.path}/CAP.png')
                .writeAsBytes(original);
            // Legacy fixtures start with the current true default, then lose
            // the key. This catches accidentally adopting that default.
            final tuning = FilmTuning(
              cinemaBands: kind != _Snapshot.disabled,
              format: FrameFormat.r16x9,
            );
            final job = CaptureJob(
              filePath: file.path,
              filmId: 'cine',
              look: resolve(book.byId('cine')!, overrides: tuning.overrides),
              tuning: tuning,
              format: FrameFormat.r16x9,
              cinemaBands: kind != _Snapshot.disabled,
              seed: 42,
              takenAt: when,
              includeLocation: location,
              location: location
                  ? PhotoLocation(
                      latitude: 48,
                      longitude: -3,
                      accuracy: 10,
                      time: when,
                    )
                  : null,
            );
            final roll = await service.openRoll(12, DevelopDelay.oneHour);

            if (recovery) {
              // A crash after staging but before committing the shot.
              final journal = RollRecovery(root, vault: vault);
              final entry = await journal.stage(job, roll.id, ShotLens.back);
              final snapshot = _oldSnapshot(
                await journal.snapshotOf(entry),
                kind,
              );
              final encryptedPath =
                  entry.snapshot['encryptedJobPath'] as String?;
              if (encryptedPath == null) {
                entry.data['job'] = snapshot;
              } else {
                final replacement = await vault.store(
                  Uint8List.fromList(utf8.encode(jsonEncode(snapshot))),
                );
                entry.data['job'] = {
                  ...entry.snapshot,
                  'encryptedJobPath': replacement,
                };
                await vault.delete(encryptedPath);
              }
              await entry.journal.writeAsString(
                jsonEncode(entry.data),
                flush: true,
              );
              await File('${entry.folder.path}/capture.json')
                  .writeAsString(jsonEncode(entry.data), flush: true);
              expect(await RollsDao(db).shotsOf(roll.id), isEmpty);
            } else {
              final shot = await service.captureIntoRoll(job, rollId: roll.id);
              final snapshot = _oldSnapshot(
                Map<String, Object?>.from(
                  jsonDecode(shot.captureJobJson!) as Map,
                ),
                kind,
              );
              var path = shot.vaultPath!;
              if (location) {
                final payload = RollVaultPayload.decode(await vault.read(path));
                path = await vault.store(
                  RollVaultPayload.encode(
                    payload.jpeg,
                    _oldSnapshot(payload.job!, kind),
                  ),
                );
                await vault.delete(shot.vaultPath!);
              }
              await (db.update(
                db.shots,
              )..where((s) => s.id.equals(shot.id))).write(
                ShotsCompanion(
                  captureJobJson: Value(jsonEncode(snapshot)),
                  vaultPath: Value(path),
                ),
              );
            }

            await close();
            open(); // New DB connection, vault instance and service objects.
            if (recovery) {
              final journal = RollRecovery(root, vault: vault);
              final entry = (await journal.pending()).single;
              _expectSnapshot(await journal.snapshotOf(entry), book, bands);
              await service.recoverCaptures();
              expect(await journal.pending(), isEmpty);
            }
            final shot = (await RollsDao(db).shotsOf(roll.id)).single;
            _expectSnapshot(
              Map<String, Object?>.from(
                jsonDecode(shot.captureJobJson!) as Map,
              ),
              book,
              bands,
            );
            final payload = RollVaultPayload.decode(
              await vault.read(shot.vaultPath!),
            );
            expect(payload.jpeg, original);
            if (location) {
              _expectSnapshot(payload.job!, book, bands);
            } else {
              expect(payload.job, isNull); // JPEG-only vaults use the DB job.
            }
            expect(saves, 0);
            await service.closeRoll(roll.id);
            now = when.add(const Duration(hours: 2));
            await developer.developDue(now);
            expect(saves, 1);
            final developed = (await RollsDao(db).shotsOf(roll.id)).single;
            expect(developed.galleryUri, 'content://bands/1');
            expect(developed.developFailure, isNull);
            expect(
              (await RollsDao(db).rollById(roll.id))!.state,
              RollState.developed,
            );
            expect(await vault.list(), isEmpty);
          });
        });
      }
    }
  }
}
