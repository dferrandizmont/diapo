import 'dart:convert';

import 'package:drift/drift.dart';

import 'app_database.dart';
import 'converters.dart';
import 'tables.dart';

/// Why a roll refused a photo.
enum RollRefusal {
  /// There is no roll with that id.
  missing,

  /// The roll is not open (it is closed, developing, developed or discarded).
  notOpen,

  /// The roll has no frames left.
  full,
}

/// Thrown when a roll cannot take the photo it was asked for.
class RollRefusedException implements Exception {
  const RollRefusedException(this.reason, this.rollId);

  /// Why the roll refused the photo.
  final RollRefusal reason;

  /// The roll that refused it.
  final int rollId;

  @override
  String toString() =>
      'RollRefusedException: the roll $rollId refused the photo '
      '(${reason.name})';
}

/// The photos of the app: the frames of the rolls and the loose photos.
class ShotsDao {
  ShotsDao(this._database);

  final AppDatabase _database;

  /// Adds a photo.
  ///
  /// With [rollId] the photo is the next frame of that roll: the roll has to
  /// be open and to have frames left, or a [RollRefusedException] is thrown.
  /// Without [rollId] the photo is a loose one, outside of any roll, and it
  /// has no frame number.
  Future<ShotRow> addShot({
    int? rollId,
    required String filmId,
    required ShotFormat format,
    required ShotLens lens,
    required DateTime takenAt,
    String? vaultPath,
    int? width,
    int? height,
    double intensity = 1,
    String? overridesJson,
    String? captureJobJson,
  }) async {
    if (rollId == null) {
      final id = await _insert(
        filmId: filmId,
        format: format,
        lens: lens,
        takenAt: takenAt,
        vaultPath: vaultPath,
        width: width,
        height: height,
        intensity: intensity,
        overridesJson: overridesJson,
        captureJobJson: captureJobJson,
      );
      return (await shotById(id))!;
    }
    return _database.transaction(() async {
      final roll = await (_database.select(
        _database.rolls,
      )..where((row) => row.id.equals(rollId))).getSingleOrNull();
      if (roll == null) {
        throw RollRefusedException(RollRefusal.missing, rollId);
      }
      if (roll.state != RollState.open) {
        throw RollRefusedException(RollRefusal.notOpen, rollId);
      }
      final taken = await _shotsTaken(rollId);
      if (taken >= roll.length) {
        throw RollRefusedException(RollRefusal.full, rollId);
      }
      final id = await _insert(
        rollId: rollId,
        frameNumber: await _nextFrame(rollId),
        filmId: filmId,
        format: format,
        lens: lens,
        takenAt: takenAt,
        vaultPath: vaultPath,
        width: width,
        height: height,
        intensity: intensity,
        overridesJson: overridesJson,
        captureJobJson: captureJobJson,
      );
      return (await shotById(id))!;
    });
  }

  /// The photo [id], or null when there is no such photo.
  Future<ShotRow?> shotById(int id) => (_database.select(
    _database.shots,
  )..where((shot) => shot.id.equals(id))).getSingleOrNull();

  /// The photos of the roll [id], in the order of their frame.
  Future<List<ShotRow>> shotsOfRoll(int id) =>
      (_database.select(_database.shots)
            ..where((shot) => shot.rollId.equals(id))
            ..orderBy([(shot) => OrderingTerm.asc(shot.frameNumber)]))
          .get();

  /// Every photo, the newest first.
  Future<List<ShotRow>> allShots() => (_database.select(
    _database.shots,
  )..orderBy([(shot) => OrderingTerm.desc(shot.takenAt)])).get();

  /// How many loose photos (outside any roll) are recorded.
  Future<int> looseShotCount() async {
    final count = _database.shots.id.count();
    final query = _database.selectOnly(_database.shots)
      ..addColumns([count])
      ..where(_database.shots.rollId.isNull());
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  /// Every photo that is in the gallery of the system (a loose photo, or a
  /// frame of a developed roll), the newest first, as it changes.
  Stream<List<ShotRow>> watchGalleryShots() =>
      (_database.select(_database.shots)
            ..where((shot) => shot.galleryUri.isNotNull())
            ..orderBy([(shot) => OrderingTerm.desc(shot.takenAt)]))
          .watch();

  /// Records a loose photo (outside of any roll) that was saved in the gallery
  /// of the system at [galleryUri].
  ///
  /// [captureId] is the identity of the shot (see `CaptureJob.captureId`),
  /// the same through every retry: recording a shot again updates its row
  /// instead of adding another, while two different shots, even of the same
  /// millisecond and film, stay two photos. It is kept in `captureJobJson`
  /// (loose photos have no other use for it). Without it the photo is always
  /// added.
  Future<ShotRow> recordLooseShot({
    required String filmId,
    required ShotFormat format,
    required ShotLens lens,
    required DateTime takenAt,
    required String galleryUri,
    String? captureId,
    int? width,
    int? height,
  }) => _database.transaction(() async {
    final key = captureId == null ? null : looseCaptureKey(captureId);
    // A shot with an identity is found by it; one without (a sidecar from
    // before the identities) by the place its photo has in the gallery, which
    // is the same however often it is recorded.
    final existing =
        await (_database.select(_database.shots)
              ..where(
                (shot) =>
                    shot.rollId.isNull() &
                    (key != null
                        ? shot.captureJobJson.equals(key)
                        : shot.galleryUri.equals(galleryUri)),
              )
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) {
      await (_database.update(
        _database.shots,
      )..where((shot) => shot.id.equals(existing.id))).write(
        ShotsCompanion(
          galleryUri: Value(galleryUri),
          width: Value(width ?? existing.width),
          height: Value(height ?? existing.height),
        ),
      );
      return (await shotById(existing.id))!;
    }
    final id = await _insert(
      filmId: filmId,
      format: format,
      lens: lens,
      takenAt: takenAt,
      width: width,
      height: height,
      captureJobJson: key,
    );
    await markSavedInGallery(id, galleryUri);
    return (await shotById(id))!;
  });

  /// What `captureJobJson` holds for the loose photo of the shot [captureId].
  static String looseCaptureKey(String captureId) =>
      jsonEncode({'captureId': captureId});

  /// Removes the photo [id] only if its row still holds [galleryUri]: a row
  /// that was updated meanwhile (a retry recorded the photo at another place)
  /// is left alone. True when a row went.
  Future<bool> deleteShotIfGalleryUri(int id, String galleryUri) async {
    final removed =
        await (_database.delete(_database.shots)..where(
              (shot) => shot.id.equals(id) & shot.galleryUri.equals(galleryUri),
            ))
            .go();
    return removed > 0;
  }

  /// Removes the photo [id] from the database. The photo of the gallery of
  /// the system is not touched here.
  Future<void> deleteShot(int id) => (_database.delete(
    _database.shots,
  )..where((shot) => shot.id.equals(id))).go();

  /// Saves the photo [id] in the gallery of the system.
  Future<void> markSavedInGallery(int id, String galleryUri) async {
    await (_database.update(_database.shots)
          ..where((shot) => shot.id.equals(id)))
        .write(ShotsCompanion(galleryUri: Value(galleryUri)));
  }

  Future<int> _insert({
    int? rollId,
    int? frameNumber,
    required String filmId,
    required ShotFormat format,
    required ShotLens lens,
    required DateTime takenAt,
    String? vaultPath,
    int? width,
    int? height,
    double intensity = 1,
    String? overridesJson,
    String? captureJobJson,
  }) => _database
      .into(_database.shots)
      .insert(
        ShotsCompanion.insert(
          rollId: Value(rollId),
          frameNumber: Value(frameNumber),
          filmId: filmId,
          format: format,
          lens: lens,
          takenAt: takenAt.millisecondsSinceEpoch,
          vaultPath: Value(vaultPath),
          width: Value(width),
          height: Value(height),
          intensity: Value(intensity),
          overridesJson: Value(overridesJson),
          captureJobJson: Value(captureJobJson),
        ),
      );

  /// The next frame of the roll: one past the highest frame taken, so the
  /// numbering stays unique even if a photo is ever removed.
  Future<int> _nextFrame(int rollId) async {
    final highest = _database.shots.frameNumber.max();
    final query = _database.selectOnly(_database.shots)
      ..addColumns([highest])
      ..where(_database.shots.rollId.equals(rollId));
    final row = await query.getSingle();
    return (row.read(highest) ?? 0) + 1;
  }

  Future<int> _shotsTaken(int rollId) async {
    final count = _database.shots.id.count();
    final query = _database.selectOnly(_database.shots)
      ..addColumns([count])
      ..where(_database.shots.rollId.equals(rollId));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }
}
