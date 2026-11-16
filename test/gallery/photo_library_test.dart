import 'dart:async';

import 'package:carrete/core/database/app_database.dart';
import 'package:carrete/core/database/converters.dart';
import 'package:carrete/core/database/shots_dao.dart';
import 'package:carrete/core/database/tables.dart';
import 'package:carrete/gallery/photo_library.dart';
import 'package:carrete/platform/photo_actions.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_database.dart';

class _Actions implements PhotoActions {
  PhotoDeletion deletion = PhotoDeletion.deleted;
  bool shares = true;
  final List<String> shared = <String>[];
  final List<String> deleted = <String>[];
  Set<String> gone = <String>{};
  final List<List<String>> looked = <List<String>>[];

  /// While set, a lookup waits for it: the answer arrives late.
  Completer<void>? hold;

  @override
  Future<Set<String>> missing(Iterable<String> locations) async {
    looked.add(locations.toList());
    await hold?.future;
    return gone.intersection(locations.toSet());
  }

  @override
  Future<bool> share(String location) async {
    shared.add(location);
    return shares;
  }

  @override
  Future<bool> shareFile(String path) async => shares;

  @override
  Future<PhotoDeletion> delete(String location) async {
    deleted.add(location);
    return deletion;
  }
}

void main() {
  late AppDatabase db;
  late ShotsDao shots;
  late _Actions actions;
  late SystemPhotoLibrary library;
  late ShotRow photo;

  setUp(() async {
    db = openMemoryDatabase();
    shots = ShotsDao(db);
    actions = _Actions();
    library = SystemPhotoLibrary(actions: actions, shots: shots);
    photo = await shots.recordLooseShot(
      filmId: 'alpha',
      format: ShotFormat.ratio3x2,
      lens: ShotLens.back,
      takenAt: DateTime(2026, 11, 13, 9),
      galleryUri: 'content://media/1',
    );
  });

  tearDown(() => db.close());

  test('sharing hands the photo of the gallery to the system', () async {
    expect(await library.share('content://media/1'), isTrue);
    expect(actions.shared, ['content://media/1']);
  });

  test('sharing says when the system could not do it', () async {
    actions.shares = false;

    expect(await library.share('content://media/1'), isFalse);
  });

  test('deleting removes the photo of the gallery and the row', () async {
    final outcome = await library.delete(photo.id, 'content://media/1');

    expect(outcome, PhotoDeletion.deleted);
    expect(actions.deleted, ['content://media/1']);
    expect(await shots.shotById(photo.id), isNull);
  });

  test(
    'a photo the user already deleted outside the app loses its row',
    () async {
      actions.deletion = PhotoDeletion.gone;

      final outcome = await library.delete(photo.id, 'content://media/1');

      expect(outcome, PhotoDeletion.gone);
      expect(await shots.shotById(photo.id), isNull);
    },
  );

  test('a photo whose original stayed behind still loses its row', () async {
    actions.deletion = PhotoDeletion.deletedKeptOriginal;

    final outcome = await library.delete(photo.id, 'content://media/1');

    expect(outcome, PhotoDeletion.deletedKeptOriginal);
    expect(await shots.shotById(photo.id), isNull);
  });

  test(
    'refusing the dialog of the system keeps the photo and its row',
    () async {
      actions.deletion = PhotoDeletion.cancelled;

      final outcome = await library.delete(photo.id, 'content://media/1');

      expect(outcome, PhotoDeletion.cancelled);
      expect(await shots.shotById(photo.id), isNotNull);
    },
  );

  test(
    'a delete that fails keeps the row, so the photo can be tried again',
    () async {
      actions.deletion = PhotoDeletion.failed;

      final outcome = await library.delete(photo.id, 'content://media/1');

      expect(outcome, PhotoDeletion.failed);
      expect(await shots.shotById(photo.id), isNotNull);
    },
  );

  group('looking for photos that are gone', () {
    Future<ShotRow> record(int minute, String uri) => shots.recordLooseShot(
      filmId: 'alpha',
      format: ShotFormat.ratio3x2,
      lens: ShotLens.back,
      takenAt: DateTime(2026, 11, 13, 10, minute),
      galleryUri: uri,
    );

    test('drops the rows of the photos the system no longer has', () async {
      final b = await record(1, 'content://media/2');
      final c = await record(2, 'content://media/3');
      actions.gone = {'content://media/1', 'content://media/3'};

      final dropped = await library.dropMissing([photo, b, c]);

      expect(dropped, 2);
      expect(await shots.shotById(photo.id), isNull);
      expect(await shots.shotById(b.id), isNotNull);
      expect(await shots.shotById(c.id), isNull);
      expect(actions.looked.single, [
        'content://media/1',
        'content://media/2',
        'content://media/3',
      ]);
    });

    test('a photo the system cannot check keeps its row', () async {
      final dropped = await library.dropMissing([photo]);

      expect(dropped, 0);
      expect(await shots.shotById(photo.id), isNotNull);
    });

    test('a row a retry just moved is not dropped by a stale lookup', () async {
      final taken = DateTime(2026, 11, 13, 10);
      final row = await shots.recordLooseShot(
        filmId: 'alpha',
        format: ShotFormat.ratio3x2,
        lens: ShotLens.back,
        takenAt: taken,
        galleryUri: 'content://media/10',
        captureId: 'abc',
      );
      actions
        ..gone = {'content://media/10'}
        ..hold = Completer<void>();

      final sweep = library.dropMissing([row]); // checks place 10...
      await Future<void>.delayed(Duration.zero);
      // ...meanwhile a retry records the same shot at place 11.
      await shots.recordLooseShot(
        filmId: 'alpha',
        format: ShotFormat.ratio3x2,
        lens: ShotLens.back,
        takenAt: taken,
        galleryUri: 'content://media/11',
        captureId: 'abc',
      );
      actions.hold!.complete();

      expect(await sweep, 0);
      expect((await shots.shotById(row.id))!.galleryUri, 'content://media/11');
    });

    test('asks nothing when there are no photos', () async {
      expect(await library.dropMissing([]), 0);
      expect(actions.looked, isEmpty);
    });
  });
}
