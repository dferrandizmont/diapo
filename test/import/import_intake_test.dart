import 'dart:async';
import 'dart:io';

import 'package:carrete/capture/still_bounds.dart';
import 'package:carrete/import/import_intake.dart';
import 'package:carrete/platform/exif_dates.dart';
import 'package:flutter_test/flutter_test.dart';

/// A picker that "copies" photos into folders of the cache, like the plugin.
class _FakePicker implements ImportPicker {
  _FakePicker(this.cache);

  final Directory cache;
  int count = 0;
  int? lastLimit;
  int lostDiscarded = 0;
  int picks = 0;
  int round = 0;

  /// The first bytes of every photo (a JPEG by default).
  List<int> magic = [0xFF, 0xD8, 0xFF, 0xD9];

  /// Holds the cleanup of the start until it completes.
  Completer<void>? lostGate;

  @override
  Future<List<String>> pick({required int limit}) async {
    lastLimit = limit;
    picks++;
    round++;
    final paths = <String>[];
    for (var i = 0; i < count; i++) {
      final folder = await Directory(
        '${cache.path}/00000000-0000-4000-8000-0000000000$round$i',
      ).create();
      final file = File('${folder.path}/IMG_$i.jpg')..writeAsBytesSync(magic);
      paths.add(file.path);
    }
    return paths;
  }

  @override
  Future<void> discardLost() async {
    lostDiscarded++;
    await lostGate?.future;
  }
}

void main() {
  late Directory cache;
  late Directory staging;
  late _FakePicker picker;
  late Map<String, ExifDates> exif;
  late Map<String, (int, int)> sizes;
  late Object? datesFail;
  late ImportStaging stagingFolder;
  late ImportIntake intake;

  /// The folders and files left in the cache, relative to it.
  List<String> leftovers() => [
    for (final entry in cache.listSync(recursive: true))
      entry.path.substring(cache.path.length + 1).replaceAll('\\', '/'),
  ];

  setUp(() async {
    cache = await Directory.systemTemp.createTemp('carrete_import_');
    addTearDown(() => cache.delete(recursive: true));
    staging = Directory('${cache.path}/import');
    stagingFolder = ImportStaging(staging, cacheDirectory: cache);
    picker = _FakePicker(cache);
    exif = {};
    sizes = {};
    datesFail = null;
    intake = ImportIntake(
      picker: picker,
      staging: stagingFolder,
      readDates: (path) async {
        final failure = datesFail;
        if (failure != null && path.endsWith('photo_1.jpg')) throw failure;
        return exif[path.split(RegExp(r'[\\/]')).last] ?? const ExifDates();
      },
      readSize: (path) async => sizes[path.split(RegExp(r'[\\/]')).last],
      limit: 3,
    );
  });

  test('chooses nothing: nothing to develop, nothing left behind', () async {
    picker.count = 0;
    expect(await intake.pick(), isNull);
    expect(leftovers(), isEmpty);
  });

  test('moves each photo into the folder of its batch, in order', () async {
    picker.count = 2;

    final batch = (await intake.pick())!;

    expect(batch.truncated, isFalse);
    expect(batch.rejected, 0);
    expect(batch.photos.map((p) => p.path.split(RegExp(r'[\\/]')).last), [
      'photo_0.jpg',
      'photo_1.jpg',
    ]);
    for (final photo in batch.photos) {
      expect(File(photo.path).existsSync(), isTrue);
      expect(File(photo.path).parent.parent.path, staging.path);
    }
  });

  test('no copy of the picker stays in the cache', () async {
    picker.count = 2;

    await intake.pick();

    // Only the staging folder is left: the folders of the picker are gone.
    expect(
      leftovers().where((p) => !p.startsWith('import')),
      isEmpty,
      reason: leftovers().join(', '),
    );
  });

  test('two batches never share a path, so no picture is reused', () async {
    picker.count = 1;
    final first = (await intake.pick())!.photos.single.path;
    final second = (await intake.pick())!.photos.single.path;

    expect(second, isNot(first));
    // The first batch is gone when the second starts.
    expect(File(first).existsSync(), isFalse);
  });

  test('prints the own date of the photo, with its offset', () async {
    picker.count = 2;
    exif['photo_0.jpg'] = const ExifDates(
      original: '2019:07:14 18:30:05',
      originalOffset: '+02:00',
    );

    final batch = (await intake.pick())!;

    expect(batch.photos[0].date!.wall, DateTime(2019, 7, 14, 18, 30, 5));
    expect(
      batch.photos[0].date!.instant.toUtc(),
      DateTime.utc(2019, 7, 14, 16, 30, 5),
    );
  });

  test(
    'a photo with no EXIF date has no date, not the day of the copy',
    () async {
      picker.count = 1;

      final batch = (await intake.pick())!;

      expect(batch.photos.single.date, isNull);
    },
  );

  test('keeps the first photos when more than the limit are chosen', () async {
    picker.count = 5;

    final batch = (await intake.pick())!;

    // The picker is asked for one more than the limit to notice the excess.
    expect(picker.lastLimit, 4);
    expect(batch.photos, hasLength(3));
    expect(batch.truncated, isTrue);
    expect(
      leftovers().where((p) => p.endsWith('.jpg')),
      hasLength(3),
      reason: leftovers().join(', '),
    );
    expect(leftovers().where((p) => p.startsWith('0000')), isEmpty);
  });

  test('refuses a file over the size limit before it is opened', () async {
    // The second photo is a sparse 100 MB + 1 file.
    final oversize = _FakePickerWithBigSecond(cache);
    final tooBig = ImportIntake(
      picker: oversize,
      staging: stagingFolder,
      readDates: (path) async => const ExifDates(),
      readSize: (path) async => null,
    );

    final batch = (await tooBig.pick())!;

    expect(batch.photos, hasLength(1));
    expect(batch.rejected, 1);
    expect(
      leftovers().where((p) => p.endsWith('.jpg')),
      hasLength(1),
      reason: leftovers().join(', '),
    );
  });

  test('refuses an image over the pixel limit, read from its header', () async {
    picker.count = 3;
    sizes['photo_1.jpg'] = (20000, 20000); // 400 MP
    sizes['photo_2.jpg'] = (14142, 14142); // just under 200 MP

    final batch = (await intake.pick())!;

    expect(batch.photos.map((p) => p.path.split(RegExp(r'[\\/]')).last), [
      'photo_0.jpg',
      'photo_2.jpg',
    ]);
    expect(batch.rejected, 1);
    expect(14142 * 14142, lessThan(StillBounds.maxSourcePixels));
  });

  test('a PNG or WebP is limited to 100 MP, a JPEG to 200 MP', () async {
    picker.count = 1;
    sizes['photo_0.jpg'] = (11000, 11000); // 121 MP

    expect((await intake.pick())!.photos, hasLength(1));

    picker.magic = [0x89, 0x50, 0x4E, 0x47];
    final other = await intake.pick();
    // Same pixels, other format: refused.
    expect(other!.photos, isEmpty);
    expect(other.rejected, 1);
  });

  test('every photo too big: an empty batch that says so', () async {
    picker.count = 1;
    sizes['photo_0.jpg'] = (30000, 30000);

    final batch = (await intake.pick())!;

    expect(batch.photos, isEmpty);
    expect(batch.rejected, 1);
    expect(leftovers().where((p) => p.endsWith('.jpg')), isEmpty);
  });

  test('a failure half way deletes everything it had taken', () async {
    picker.count = 3;
    datesFail = StateError('cannot read the second one');

    await expectLater(intake.pick(), throwsStateError);

    expect(
      leftovers().where((p) => p.endsWith('.jpg')),
      isEmpty,
      reason: leftovers().join(', '),
    );
    expect(staging.existsSync(), isFalse);
  });

  test('removes what an earlier import left in the staging folder', () async {
    await staging.create();
    final stale = File('${staging.path}/photo_9.jpg')..writeAsBytesSync([1]);
    picker.count = 1;

    await intake.pick();

    expect(stale.existsSync(), isFalse);
  });

  test('clear removes every staged photo', () async {
    picker.count = 2;
    final batch = (await intake.pick())!;

    await stagingFolder.clear();

    for (final photo in batch.photos) {
      expect(File(photo.path).existsSync(), isFalse);
    }
    expect(staging.existsSync(), isFalse);
  });

  group('the leftovers of an earlier run', () {
    test('are swept at start: staging and the folders of the picker', () async {
      await Directory('${staging.path}/b1').create(recursive: true);
      File('${staging.path}/b1/photo_0.jpg').writeAsBytesSync([1]);
      final pick = Directory(
        '${cache.path}/3f2b8c1e-0a4d-4c7e-9b1a-5d6e7f809a1b',
      )..createSync();
      File('${pick.path}/IMG_1.jpg').writeAsBytesSync([1]);
      // Other things of the cache are not touched.
      final failed = Directory('${cache.path}/failed')..createSync();
      final other = File('${cache.path}/not-a-uuid.tmp')..writeAsBytesSync([1]);

      await intake.cleanLeftovers();

      expect(staging.existsSync(), isFalse);
      expect(pick.existsSync(), isFalse);
      expect(failed.existsSync(), isTrue);
      expect(other.existsSync(), isTrue);
      // What the plugin kept of a pick cut short is thrown away too.
      expect(picker.lostDiscarded, 1);
    });

    Directory uuidFolder(String name) =>
        Directory('${cache.path}/$name')..createSync();

    test('only a folder that is provably the picker\'s is deleted', () async {
      // The picker's own: a UUID v4 holding one photo.
      final ours = uuidFolder('3f2b8c1e-0a4d-4c7e-9b1a-5d6e7f809a1b');
      File('${ours.path}/IMG_1.JPG').writeAsBytesSync([1]);
      // Foreign folders with a UUID name but other content.
      final withData = uuidFolder('11111111-2222-4333-8444-555555555555');
      File('${withData.path}/IMG_1.jpg').writeAsBytesSync([1]);
      File('${withData.path}/state.db').writeAsBytesSync([1]);
      final withSub = uuidFolder('21111111-2222-4333-8444-555555555555');
      Directory('${withSub.path}/inner').createSync();
      final vaultLike = uuidFolder('31111111-2222-4333-8444-555555555555');
      File('${vaultLike.path}/blob.bin').writeAsBytesSync([1]);
      final crowded = uuidFolder('41111111-2222-4333-8444-555555555555');
      for (var i = 0; i < 6; i++) {
        File('${crowded.path}/IMG_$i.jpg').writeAsBytesSync([1]);
      }
      // Not a v4 UUID, and not a UUID at all.
      final notV4 = uuidFolder('51111111-2222-1333-8444-555555555555');
      File('${notV4.path}/IMG_1.jpg').writeAsBytesSync([1]);
      final named = uuidFolder('roll-recovery');
      File('${named.path}/IMG_1.jpg').writeAsBytesSync([1]);
      final failed = uuidFolder('failed');
      File('${failed.path}/job.json').writeAsBytesSync([1]);
      File('${failed.path}/IMG_9.jpg').writeAsBytesSync([1]);
      // Loose temp files of the cache, one named like a UUID.
      final loose = [
        File('${cache.path}/CARRETE_20261113.jpg'),
        File('${cache.path}/61111111-2222-4333-8444-555555555555'),
      ]..forEach((f) => f.writeAsBytesSync([1]));

      await intake.cleanLeftovers();

      expect(ours.existsSync(), isFalse);
      for (final kept in [
        withData,
        withSub,
        vaultLike,
        crowded,
        notV4,
        named,
        failed,
      ]) {
        expect(kept.existsSync(), isTrue, reason: kept.path);
      }
      expect(File('${withData.path}/state.db').existsSync(), isTrue);
      expect(File('${failed.path}/IMG_9.jpg').existsSync(), isTrue);
      expect(loose.every((f) => f.existsSync()), isTrue);
    });

    test('a pick never deletes a foreign folder, only its own file', () async {
      final foreign = uuidFolder('11111111-2222-4333-8444-555555555555');
      final photo = File('${foreign.path}/IMG_1.jpg')..writeAsBytesSync([1]);
      final other = File('${foreign.path}/keep.db')..writeAsBytesSync([1]);

      await stagingFolder.discardPicked([photo.path]);

      expect(photo.existsSync(), isFalse);
      expect(other.existsSync(), isTrue);
      expect(foreign.existsSync(), isTrue);
    });

    test(
      'a pick waits for the cleanup of the start and is not cut by it',
      () async {
        picker.count = 1;
        picker.lostGate = Completer<void>();

        final cleaning = intake.cleanLeftovers();
        final picking = intake.pick();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        // The picker has not been opened: the cleanup is still running.
        expect(picker.picks, 0);

        picker.lostGate!.complete();
        await cleaning;
        final batch = (await picking)!;

        expect(picker.picks, 1);
        expect(File(batch.photos.single.path).existsSync(), isTrue);
      },
    );

    test('never throw, even when the picker cannot say', () async {
      final broken = ImportIntake(
        picker: _ThrowingPicker(),
        staging: stagingFolder,
        readDates: (path) async => const ExifDates(),
      );

      await broken.cleanLeftovers();
    });
  });
}

/// A picker whose second photo is a file over the size limit.
class _FakePickerWithBigSecond extends _FakePicker {
  _FakePickerWithBigSecond(super.cache) {
    count = 2;
  }

  @override
  Future<List<String>> pick({required int limit}) async {
    final paths = await super.pick(limit: limit);
    final raf = File(paths[1]).openSync(mode: FileMode.write);
    raf.truncateSync(StillBounds.maxFileBytes + 1);
    raf.closeSync();
    return paths;
  }
}

class _ThrowingPicker implements ImportPicker {
  @override
  Future<List<String>> pick({required int limit}) async => const [];

  @override
  Future<void> discardLost() async => throw StateError('no lost data');
}
