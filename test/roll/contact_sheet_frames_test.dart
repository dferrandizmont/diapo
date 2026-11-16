import 'package:carrete/core/database/app_database.dart';
import 'package:carrete/core/database/converters.dart';
import 'package:carrete/core/database/rolls_dao.dart';
import 'package:carrete/core/database/shots_dao.dart';
import 'package:carrete/core/database/tables.dart';
import 'package:carrete/roll/contact_sheet_image.dart';
import 'package:carrete/roll/contact_sheet_share.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/roll_fakes.dart';
import '../support/test_database.dart';

/// The frames of the shareable sheet after photos were really deleted from the
/// database: a deleted frame is an empty cell that keeps its place.
void main() {
  late AppDatabase db;
  late RollsDao rolls;
  late ShotsDao shots;
  late FakeGalleryImages gallery;

  setUp(() {
    db = openMemoryDatabase();
    rolls = RollsDao(db);
    shots = ShotsDao(db);
    gallery = FakeGalleryImages();
  });

  tearDown(() => db.close());

  /// A roll of [length] frames with a developed photo in each.
  Future<(RollRow, List<ShotRow>)> shotRoll(int length) async {
    final roll = await rolls.openRoll(filmId: 'alpha', length: length);
    final taken = <ShotRow>[];
    for (var i = 1; i <= length; i++) {
      final shot = await shots.addShot(
        rollId: roll.id,
        filmId: 'alpha',
        format: ShotFormat.ratio3x2,
        lens: ShotLens.back,
        takenAt: DateTime(2026, 11, 14, 12, i),
      );
      await shots.markSavedInGallery(shot.id, 'content://media/$i');
      gallery.photos['content://media/$i'] = tinyPng;
      taken.add((await shots.shotById(shot.id))!);
    }
    return (roll, taken);
  }

  Future<List<ContactSheetFrame>> framesAfterDeleting(
    int length,
    Set<int> frames,
  ) async {
    final (roll, taken) = await shotRoll(length);
    for (final shot in taken) {
      if (frames.contains(shot.frameNumber)) await shots.deleteShot(shot.id);
    }
    final left = await rolls.shotsOf(roll.id);
    expect(left, hasLength(length - frames.length));
    return contactSheetFrames(left, gallery, rollLength: roll.length);
  }

  List<int> numbers(List<ContactSheetFrame> frames) => [
    for (final f in frames) f.number,
  ];

  List<bool> photos(List<ContactSheetFrame> frames) => [
    for (final f in frames) f.load != null,
  ];

  test('a roll with every photo has every frame', () async {
    final frames = await framesAfterDeleting(6, {});
    expect(numbers(frames), [1, 2, 3, 4, 5, 6]);
    expect(photos(frames), everyElement(isTrue));
  });

  test('a frame deleted in the middle stays as an empty cell', () async {
    final frames = await framesAfterDeleting(6, {3});
    expect(numbers(frames), [1, 2, 3, 4, 5, 6]);
    expect(photos(frames), [true, true, false, true, true, true]);
  });

  test('the first frames deleted leave empty cells at the start', () async {
    final frames = await framesAfterDeleting(6, {1, 2});
    expect(numbers(frames), [1, 2, 3, 4, 5, 6]);
    expect(photos(frames), [false, false, true, true, true, true]);
  });

  test('several gaps keep every original number', () async {
    final frames = await framesAfterDeleting(8, {1, 4, 5});
    expect(numbers(frames), [1, 2, 3, 4, 5, 6, 7, 8]);
    expect(photos(frames), [false, true, true, false, false, true, true, true]);
  });

  test('the last frames cannot be told from a roll closed early', () async {
    // The database holds the frames a roll can take, not how many were taken:
    // a trailing deletion is not drawn rather than invented for every roll
    // that was closed before it was full.
    final frames = await framesAfterDeleting(6, {6});
    expect(numbers(frames), [1, 2, 3, 4, 5]);
  });

  test('a gap never grows the sheet beyond the frames of the roll', () async {
    final roll = await rolls.openRoll(filmId: 'alpha', length: 4);
    final far = ShotRow(
      id: 900,
      rollId: roll.id,
      frameNumber: 5000,
      filmId: 'alpha',
      format: ShotFormat.ratio3x2,
      lens: ShotLens.back,
      takenAt: 1,
      galleryUri: 'content://media/9',
      intensity: 1,
    );
    final frames = contactSheetFrames([far], gallery, rollLength: roll.length);
    expect(numbers(frames), [1, 2, 3, 4, 5000]);
  });

  test('a photo without a frame number takes its place in the list', () async {
    final legacy = ShotRow(
      id: 1,
      rollId: 7,
      frameNumber: null,
      filmId: 'alpha',
      format: ShotFormat.ratio3x2,
      lens: ShotLens.back,
      takenAt: 1,
      galleryUri: 'content://media/1',
      intensity: 1,
    );
    final frames = contactSheetFrames(
      [legacy, legacy],
      gallery,
      rollLength: 24,
    );
    expect(numbers(frames), [1, 2]);
  });
}
