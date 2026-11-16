import 'dart:convert';
import 'dart:io';

import 'package:carrete/camera/camera_flash.dart';
import 'package:carrete/capture/capture_queue.dart';
import 'package:carrete/capture/failed_shots.dart';
import 'package:carrete/core/database/tables.dart';
import 'package:carrete/core/settings/film_tuning.dart';
import 'package:film_recipes/film_recipes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

Future<Directory> _cache() async {
  final dir = await Directory.systemTemp.createTemp('carrete_cache_');
  addTearDown(() => dir.delete(recursive: true));
  return dir;
}

Future<File> _original(Directory cache, String name) async {
  final file = File('${cache.path}/$name');
  await file.writeAsBytes([0xFF, 0xD8, 0xFF, 0xD9]);
  return file;
}

CaptureJob _job(RecipeBook book, String path, {bool location = false}) {
  const tuning = FilmTuning(grain: 1.5, halation: 0.5, dateStamp: true);
  final recipe = book.byId('gamma')!;
  return CaptureJob(
    filePath: path,
    filmId: 'gamma',
    look: lookWithFlash(
      resolve(recipe, overrides: tuning.overrides),
      CarreteFlash.party,
    ),
    format: FrameFormat.r1x1,
    seed: 12.5,
    takenAt: DateTime(2026, 11, 9, 18, 30, 15, 250),
    tuning: tuning,
    flash: CarreteFlash.party,
    fieldAspect: 0.5625,
    stampText: "'26 11 9",
    whiteFrame: true,
    includeLocation: location,
  );
}

void main() {
  final book = testBook();

  test('cinema bands survive a job snapshot and old jobs decode as false', () {
    final base = _job(book, '/camera.jpg');
    const tuning = FilmTuning(cinemaBands: true, format: FrameFormat.r16x9);
    final job = base.withFrame(
      look: lookWithFlash(
        resolve(book.recipes.first, overrides: tuning.overrides),
        CarreteFlash.party,
      ),
      format: FrameFormat.r16x9,
      tuning: tuning,
      whiteFrame: false,
    );
    final json = FailedShots.encode(job.withFile('/copy.jpg'), attempts: 0);
    final restored = FailedShots.decode(json, book, '/temp.jpg')!;
    expect(restored.cinemaBands, isTrue);
    expect(restored.look.cinemaBands, isTrue);
    expect(restored.tuning.cinemaBands, isTrue);
    json.remove('cinemaBands');
    (json['look'] as Map).remove('cinemaBands');
    (json['tuning'] as Map).remove('cinemaBands');
    final old = FailedShots.decode(json, book, '/temp.jpg')!;
    expect(old.cinemaBands, isFalse);
    expect(old.look.cinemaBands, isFalse);
  });

  test('legacy Cine jobs do not acquire the new recipe default', () {
    final shipped = RecipeBook.parse(
      File('packages/film_recipes/assets/recipes.json').readAsStringSync(),
    );
    final json = FailedShots.encode(_job(book, '/camera.jpg'), attempts: 0)
      ..['version'] = 1
      ..['filmId'] = 'cine'
      ..remove('look')
      ..remove('cinemaBands');
    final old = FailedShots.decode(json, shipped, '/temp.jpg')!;
    expect(old.cinemaBands, isFalse);
    expect(old.look.cinemaBands, isFalse);
  });

  group('FailedShots', () {
    test(
      'v2 preserves the resolved look after a recipe is replaced or removed',
      () {
        final original = _job(book, '/camera.jpg');
        final json = FailedShots.encode(original, attempts: 0);
        json['filmId'] = 'removed-film';
        final decoded = FailedShots.decode(json, book, '/temp.jpg')!;
        expect(decoded.filmId, 'removed-film');
        expect(decoded.look.matrix, original.look.matrix);
        expect(decoded.look.curveR, original.look.curveR);
        expect(decoded.look.grainAmount, original.look.grainAmount);
        expect(decoded.look.halationRadius, original.look.halationRadius);
        expect(decoded.look.leakColor, original.look.leakColor);
        expect(decoded.look.exposure, original.look.exposure);
        expect(decoded.format, original.format);
      },
    );

    test('v1 still rebuilds a look, and unsupported versions are refused', () {
      final json = FailedShots.encode(_job(book, '/camera.jpg'), attempts: 0);
      json['version'] = 1;
      json.remove('look');
      expect(FailedShots.decode(json, book, '/temp.jpg'), isNotNull);
      json['version'] = 99;
      expect(FailedShots.decode(json, book, '/temp.jpg'), isNull);
    });

    test(
      'invalid v2 look snapshots are refused without touching the original',
      () {
        final json = FailedShots.encode(_job(book, '/camera.jpg'), attempts: 0);
        json['look'] = {'matrix': []};
        expect(FailedShots.decode(json, book, '/temp.jpg'), isNull);
      },
    );

    test('keeps the original in failed/ with a sidecar of the job', () async {
      final cache = await _cache();
      final shots = FailedShots(Directory('${cache.path}/failed'));
      final original = await _original(cache, 'CAP123.jpg');

      final kept = await shots.keep(_job(book, original.path, location: true));

      expect(kept, isNotNull);
      expect(await original.exists(), isFalse, reason: 'moved, not copied');
      expect(kept!.filePath, '${cache.path}/failed/CAP123.jpg');
      expect(await File(kept.filePath).exists(), isTrue);
      final sidecar = jsonDecode(
        await File(FailedShots.sidecarOf(kept.filePath)).readAsString(),
      );
      expect(sidecar['attempts'], 1);
      expect(sidecar['filmId'], 'gamma');
      expect(sidecar['tuning'], {
        'grain': 1.5,
        'halation': 0.5,
        'leak': 1.0,
        'vignette': 1.0,
        'dateStamp': true,
      });
      expect(sidecar['flash'], 'party');
      expect(sidecar['format'], '1:1');
      expect(sidecar['stampText'], "'26 11 9");
      expect(sidecar['takenAt'], '2026-11-09T18:30:15.250');
      expect(sidecar['takenAtMs'], kept.shutterInstant!.millisecondsSinceEpoch);
      expect(sidecar['includeLocation'], isTrue);
      expect(sidecar['whiteFrame'], isTrue);
    });

    test('a shot already kept gets one more attempt, not a copy', () async {
      final cache = await _cache();
      final shots = FailedShots(Directory('${cache.path}/failed'));
      final original = await _original(cache, 'CAP1.jpg');
      final first = (await shots.keep(_job(book, original.path)))!;
      final second = (await shots.keep(first))!;

      expect(second.filePath, first.filePath);
      expect(await shots.directory.list().length, 2);
      final sidecar = jsonDecode(
        await File(FailedShots.sidecarOf(second.filePath)).readAsString(),
      );
      expect(sidecar['attempts'], 2);
    });

    test('keep answers null when the original is gone', () async {
      final cache = await _cache();
      final shots = FailedShots(Directory('${cache.path}/failed'));
      expect(await shots.keep(_job(book, '${cache.path}/missing.jpg')), isNull);
      expect(await shots.directory.exists(), isFalse);
    });

    test('pending rebuilds the jobs, oldest first', () async {
      final cache = await _cache();
      final shots = FailedShots(Directory('${cache.path}/failed'));
      final late = await _original(cache, 'CAP2.jpg');
      final early = await _original(cache, 'CAP1.jpg');
      await shots.keep(_job(book, late.path, location: true));
      final earlyJob = CaptureJob(
        filePath: early.path,
        filmId: 'alpha',
        look: resolve(book.byId('alpha')!),
        format: FrameFormat.r3x2,
        seed: 3,
        takenAt: DateTime(2026, 11, 8),
      );
      await shots.keep(earlyJob);

      final jobs = await shots.pending(book);

      expect(jobs, hasLength(2));
      expect(jobs.first.filmId, 'alpha');
      expect(jobs.first.takenAt, DateTime(2026, 11, 8));
      expect(jobs.first.retried, isTrue);
      expect(jobs.first.includeLocation, isFalse);
      expect(
        jobs.first.filePath.replaceAll('\\', '/'),
        '${cache.path}/failed/CAP1.jpg'.replaceAll('\\', '/'),
      );

      final job = jobs.last;
      expect(job.filmId, 'gamma');
      expect(
        job.tuning,
        const FilmTuning(grain: 1.5, halation: 0.5, dateStamp: true),
      );
      expect(job.flash, CarreteFlash.party);
      expect(job.format, FrameFormat.r1x1);
      expect(job.seed, 12.5);
      expect(job.takenAt, DateTime(2026, 11, 9, 18, 30, 15, 250));
      expect(job.fieldAspect, 0.5625);
      expect(job.stampText, "'26 11 9");
      expect(job.whiteFrame, isTrue);
      expect(job.includeLocation, isTrue);
      // The look is the same one the viewfinder built.
      final expected = _job(book, job.filePath).look;
      expect(job.look.grainAmount, expected.grainAmount);
      expect(job.look.halationAmount, expected.halationAmount);
      expect(job.look.exposure, expected.exposure);
    });

    test(
      'pending skips shots that reached the limit, keeps their files',
      () async {
        final cache = await _cache();
        final shots = FailedShots(Directory('${cache.path}/failed'));
        final original = await _original(cache, 'CAP1.jpg');
        var job = _job(book, original.path);
        for (var i = 0; i < FailedShots.maxAttempts; i++) {
          job = (await shots.keep(job))!;
        }

        expect(await shots.pending(book), isEmpty);
        expect(await File(job.filePath).exists(), isTrue);
      },
    );

    test(
      'pending ignores a sidecar without its original or unreadable',
      () async {
        final cache = await _cache();
        final failed = Directory('${cache.path}/failed')..createSync();
        File('${failed.path}/orphan.jpg.json')
            .writeAsStringSync('{"filmId":"x"}');
        File('${failed.path}/bad.jpg').writeAsBytesSync([1]);
        File('${failed.path}/bad.jpg.json').writeAsStringSync('not json');
        File('${failed.path}/old.jpg').writeAsBytesSync([1]);
        File('${failed.path}/old.jpg.json').writeAsStringSync('{"attempts":1}');

        expect(await FailedShots(failed).pending(book), isEmpty);
        expect(await failed.list().length, 5, reason: 'nothing deleted');
      },
    );

    test('a film that left the book falls back to the first one', () {
      final job = FailedShots.decode(
        {'filmId': 'gone', 'takenAt': '2026-11-09T10:00:00.000'},
        book,
        '/failed/x.jpg',
      );
      expect(job, isNotNull);
      expect(job!.filmId, book.recipes.first.id);
      expect(job.format, resolve(book.recipes.first).format);
    });

    test('discard removes the kept copy and its sidecar only', () async {
      final cache = await _cache();
      final shots = FailedShots(Directory('${cache.path}/failed'));
      final original = await _original(cache, 'CAP1.jpg');
      final other = await _original(cache, 'CAP2.jpg');
      final kept = (await shots.keep(_job(book, original.path)))!;

      await shots.discard(kept);
      await shots.discard(_job(book, other.path));

      expect(await shots.directory.list().length, 0);
      expect(await other.exists(), isTrue, reason: 'not ours to delete');
    });
  });

  group('cleanCaptureLeftovers', () {
    test(
      'preserves unconfirmed camera originals and deletes only encoder temps',
      () async {
        final cache = await _cache();
        await _original(cache, 'CAP4521.jpg');
        await _original(cache, 'cap_lower.JPG');
        await _original(cache, 'CARRETE_20261109_183015_250.jpg');
        await _original(cache, 'other.jpg');
        await _original(cache, 'notes.txt');
        final failed = Directory('${cache.path}/failed')..createSync();
        await _original(failed, 'CAP1.jpg');
        File('${failed.path}/CAP1.jpg.json').writeAsStringSync('{}');

        final deleted = await cleanCaptureLeftovers(cache);

        expect(deleted, 1);
        final left = (await cache.list(recursive: true).toList())
            .map((e) => e.path.substring(cache.path.length + 1))
            .map((p) => p.replaceAll('\\', '/'))
            .toSet();
        expect(left, {
          'CAP4521.jpg',
          'cap_lower.JPG',
          'other.jpg',
          'notes.txt',
          'failed',
          'failed/CAP1.jpg',
          'failed/CAP1.jpg.json',
        });
      },
    );

    test('empties the staging folder of the originals, only that', () async {
      final cache = await _cache();
      final staging = Directory('${cache.path}/original-tmp')..createSync();
      await _original(staging, 'CARRETE_20261109_183015_250_original.jpg');
      await _original(staging, 'half_written.tmp');
      await _original(cache, 'CAP4521.jpg');

      final deleted = await cleanCaptureLeftovers(cache);

      expect(deleted, 2);
      expect(staging.existsSync(), isTrue);
      expect(staging.listSync(), isEmpty);
      expect(File('${cache.path}/CAP4521.jpg').existsSync(), isTrue);
    });

    test('a missing cache is not an error', () async {
      expect(await cleanCaptureLeftovers(Directory('/nowhere/at/all')), 0);
    });
  });

  group('the lens of a failed shot', () {
    test('survives the sidecar, so the retry records the right lens', () {
      final front = _job(book, '/camera.jpg').withFile('/camera.jpg');
      final json = FailedShots.encode(
        CaptureJob(
          filePath: front.filePath,
          filmId: front.filmId,
          look: front.look,
          format: front.format,
          seed: front.seed,
          takenAt: front.takenAt,
          lens: ShotLens.front,
        ),
        attempts: 1,
      );

      expect(json['lens'], 'front');
      expect(FailedShots.decode(json, book, '/x.jpg')!.lens, ShotLens.front);
    });

    test('the identity of the shot survives the sidecar', () {
      final job = CaptureJob(
        filePath: '/a.jpg',
        filmId: 'gamma',
        look: _job(book, '/a.jpg').look,
        format: FrameFormat.r3x2,
        seed: 1,
        takenAt: DateTime(2026, 11, 13),
        captureId: 'abc1234567',
      );

      final json = FailedShots.encode(job, attempts: 1);

      expect(json['captureId'], 'abc1234567');
      expect(FailedShots.decode(json, book, '/x.jpg')!.captureId, 'abc1234567');
      expect(job.withFile('/b.jpg').captureId, 'abc1234567');
      json.remove('captureId');
      expect(FailedShots.decode(json, book, '/x.jpg')!.captureId, isNull);
    });

    test('a sidecar from before the gallery has no lens: the back one', () {
      final json = FailedShots.encode(_job(book, '/camera.jpg'), attempts: 0)
        ..remove('lens');

      expect(FailedShots.decode(json, book, '/x.jpg')!.lens, ShotLens.back);
    });

    test('moving the file keeps the lens', () {
      final job = CaptureJob(
        filePath: '/a.jpg',
        filmId: 'gamma',
        look: _job(book, '/a.jpg').look,
        format: FrameFormat.r3x2,
        seed: 1,
        takenAt: DateTime(2026, 11, 13),
        lens: ShotLens.front,
      );

      expect(job.withFile('/b.jpg').lens, ShotLens.front);
    });
  });

  group('keeping a shot safely', () {
    test(
      'a sidecar that cannot be written leaves the original in place',
      () async {
        final cache = await _cache();
        final shots = FailedShots(Directory('${cache.path}/failed'));
        final original = await _original(cache, 'CAP1.jpg');
        // Something that is not a file sits where the sidecar goes.
        await Directory('${cache.path}/failed/CAP1.jpg.json')
            .create(recursive: true);

        final kept = await shots.keep(_job(book, original.path));

        expect(kept, isNull);
        expect(await original.exists(), isTrue); // not moved
        expect(await File('${cache.path}/failed/CAP1.jpg').exists(), isFalse);
        expect(await shots.pending(book), isEmpty);
      },
    );

    test('an original that cannot move leaves no record behind', () async {
      final cache = await _cache();
      final shots = FailedShots(Directory('${cache.path}/failed'));
      final original = await _original(cache, 'CAP1.jpg');
      // Something that is not a file sits where the original goes.
      await Directory('${cache.path}/failed/CAP1.jpg').create(recursive: true);

      final kept = await shots.keep(_job(book, original.path));

      expect(kept, isNull);
      expect(await original.exists(), isTrue);
      expect(
        await File('${cache.path}/failed/CAP1.jpg.json').exists(),
        isFalse,
      );
    });

    test('a kept original always has its sidecar, written whole', () async {
      final cache = await _cache();
      final shots = FailedShots(Directory('${cache.path}/failed'));
      final original = await _original(cache, 'CAP1.jpg');

      final kept = (await shots.keep(_job(book, original.path)))!;

      final names = [
        for (final e in Directory('${cache.path}/failed').listSync())
          e.path.split(RegExp(r'[/\\]')).last,
      ]..sort();
      expect(names, ['CAP1.jpg', 'CAP1.jpg.json']);
      expect(await shots.pending(book), hasLength(1));
      expect(kept.filePath, endsWith('CAP1.jpg'));
    });

    test('keeping without counting does not use up an attempt', () async {
      final cache = await _cache();
      final shots = FailedShots(Directory('${cache.path}/failed'));
      final original = await _original(cache, 'CAP1.jpg');
      var job = (await shots.keep(
        _job(book, original.path),
        countAttempt: false,
      ))!;
      for (var i = 0; i < FailedShots.maxAttempts + 2; i++) {
        job = (await shots.keep(job, countAttempt: false))!;
      }

      expect(await shots.pending(book), hasLength(1));
    });
  });

  group('shots that used up their attempts', () {
    Future<(FailedShots, CaptureJob)> exhausted() async {
      final cache = await _cache();
      final shots = FailedShots(Directory('${cache.path}/failed'));
      final original = await _original(cache, 'CAP1.jpg');
      final job = (await shots.keep(
        _job(book, original.path),
        countAttempt: false,
      ))!;
      for (var i = 0; i < FailedShots.maxAttempts; i++) {
        await shots.countAttempt(job);
      }
      return (shots, job);
    }

    test('stay out unless their photo is already in the gallery', () async {
      final (shots, _) = await exhausted();

      expect(await shots.pending(book), isEmpty);
      expect(await shots.pending(book, published: (_) async => false), isEmpty);
      expect(
        await shots.pending(book, published: (_) async => true),
        hasLength(1),
      );
    });

    test('a lookup that fails counts as not published', () async {
      final (shots, _) = await exhausted();

      expect(
        await shots.pending(
          book,
          published: (_) async => throw StateError('no media store'),
        ),
        isEmpty,
      );
    });

    test(
      'the published lookup is not asked for shots with attempts left',
      () async {
        final cache = await _cache();
        final shots = FailedShots(Directory('${cache.path}/failed'));
        final original = await _original(cache, 'CAP1.jpg');
        await shots.keep(_job(book, original.path));
        var asked = 0;

        final jobs = await shots.pending(
          book,
          published: (_) async {
            asked++;
            return false;
          },
        );

        expect(jobs, hasLength(1));
        expect(asked, 0);
      },
    );

    test(
      'a shot that failed to be recorded three times is left alone',
      () async {
        final (shots, job) = await exhausted();
        for (var i = 0; i < FailedShots.maxAttempts; i++) {
          await shots.countRecordFailure(job);
        }

        expect(
          await shots.pending(book, published: (_) async => true),
          isEmpty,
        );
        // The files stay: nothing is ever deleted for giving up.
        expect(await File(job.filePath).exists(), isTrue);
      },
    );

    test('two recording failures still leave it for the next start', () async {
      final (shots, job) = await exhausted();
      await shots.countRecordFailure(job);
      await shots.countRecordFailure(job);

      expect(
        await shots.pending(book, published: (_) async => true),
        hasLength(1),
      );
    });

    test('counting on a shot that is not kept does nothing', () async {
      final cache = await _cache();
      final shots = FailedShots(Directory('${cache.path}/failed'));

      await shots.countAttempt(_job(book, '${cache.path}/elsewhere.jpg'));
      await shots.countRecordFailure(_job(book, '${cache.path}/elsewhere.jpg'));

      expect(Directory('${cache.path}/failed').existsSync(), isFalse);
    });
  });
}
