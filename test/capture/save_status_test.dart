import 'dart:convert';
import 'dart:io';

import 'package:diapo/capture/capture_providers.dart';
import 'package:diapo/capture/capture_queue.dart';
import 'package:diapo/capture/failed_shots.dart';
import 'package:diapo/capture/save_status.dart';
import 'package:diapo/render/film_resources.dart';
import 'package:diapo/roll/roll_service.dart';
import 'package:film_recipes/film_recipes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

CaptureJob _job(String path, {int minute = 0}) {
  final recipe = testBook().byId('alpha')!;
  return CaptureJob(
    filePath: path,
    filmId: 'alpha',
    look: resolve(recipe),
    format: FrameFormat.r3x2,
    seed: 1,
    takenAt: DateTime(2026, 11, 9, 18, minute),
  );
}

/// The roll service of a camera that has nothing to recover: it only counts
/// how many times it was asked.
class _RollSpy implements RollService {
  int recovered = 0;

  @override
  Future<void> recoverCaptures() async => recovered++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Rig {
  _Rig(this.cache, this.queue, this.rolls);

  final Directory cache;
  final FakeCaptureQueue queue;
  final _RollSpy rolls;

  FailedShots get failed => FailedShots(Directory('${cache.path}/failed'));

  /// A camera original that failed to save: it is kept in `failed/`.
  Future<CaptureJob> fail(String name, {int minute = 0}) async {
    final file = File('${cache.path}/$name');
    await file.writeAsBytes([0xFF, 0xD8, 0xFF, 0xD9]);
    final kept = await failed.keep(_job(file.path, minute: minute));
    return kept!;
  }

  /// The app starting: a new container over the same cache.
  ProviderContainer start() {
    final container = ProviderContainer(
      overrides: [
        cacheDirectoryProvider.overrideWithValue(cache),
        captureQueueProvider.overrideWithValue(queue),
        rollServiceProvider.overrideWithValue(rolls),
        recipeBookProvider.overrideWith((ref) async => testBook()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }
}

Future<_Rig> _rig() async {
  final cache = await Directory.systemTemp.createTemp('carrete_status_');
  addTearDown(() async {
    try {
      await cache.delete(recursive: true);
    } on FileSystemException {
      // Windows keeps a folder busy for a moment after it was listed.
    }
  });
  return _Rig(cache, FakeCaptureQueue(), _RollSpy());
}

Future<SaveStatus> _settled(ProviderContainer container) async {
  container.listen(saveStatusProvider, (_, _) {});
  // The folders are read with real file access: wait for that read.
  await container.read(saveStatusProvider.notifier).refresh();
  return container.read(saveStatusProvider);
}

void main() {
  group('the failed count', () {
    test('is what the folder holds, and the same after a restart', () async {
      final rig = await _rig();
      await rig.fail('CAP1.jpg');
      await rig.fail('CAP2.jpg', minute: 1);

      final first = rig.start();
      expect((await _settled(first)).failed, 2);

      // The process dies and the app starts again over the same cache.
      first.dispose();
      final second = rig.start();
      final restarted = await _settled(second);
      expect(restarted.failed, 2);
      expect(restarted.hasFailures, isTrue);
      expect(restarted.problem, SaveProblem.unknown);
    });

    test('is zero when nothing waits', () async {
      final rig = await _rig();
      final status = await _settled(rig.start());
      expect(status.failed, 0);
      expect(status.hasFailures, isFalse);
      expect(status.isSaving, isFalse);
    });

    test(
      'ignores a sidecar without its original and an unreadable one',
      () async {
        final rig = await _rig();
        await rig.fail('CAP1.jpg');
        final folder = Directory('${rig.cache.path}/failed');
        await File('${folder.path}/CAP2.jpg.json').writeAsString('{}');
        await File('${folder.path}/CAP3.jpg').writeAsBytes([1]);
        await File('${folder.path}/CAP3.jpg.json').writeAsString('not json');
        expect((await _settled(rig.start())).failed, 1);
      },
    );

    test('counts the roll frames that were kept for recovery, not the ones '
        'being saved', () async {
      final rig = await _rig();
      Future<void> journal(String name) async {
        final original = '${rig.cache.path}/$name.jpg';
        await File(original).writeAsBytes([1]);
        await File('$original.roll.json').writeAsString(
          jsonEncode({
            'captureId': name,
            'rollId': 1,
            'lens': 'back',
            'originalPath': original,
            'folder': '${rig.cache.path}/roll-recovery/shot_$name',
            'failedFolder': '${rig.cache.path}/failed/roll_$name',
            'job': {'takenAt': DateTime(2026, 11, 9).toIso8601String()},
          }),
        );
      }

      await journal('CAPA');
      await journal('CAPB');
      final container = rig.start();
      final idle = await _settled(container);
      expect(idle.failed, 2);

      // CAPB is being put into the vault now: the camera says it is saving
      // and does not offer a retry of what is in use.
      container.read(saveActivityProvider).begin('${rig.cache.path}/CAPB.jpg');
      final busy = container.read(saveStatusProvider);
      expect(busy.saving, 1, reason: 'the frame of the roll counts');
      expect(busy.isSaving, isTrue);
      expect(busy.hasFailures, isFalse);
    });
  });

  group('the saving count', () {
    test('adds the queue and the frames of a roll', () async {
      final rig = await _rig();
      final container = rig.start();
      await _settled(container);

      rig.queue.pendingCount = 2;
      expect(container.read(saveStatusProvider).saving, 2);
      container.read(saveActivityProvider).begin('/cache/CAP9.jpg');
      expect(container.read(saveStatusProvider).saving, 3);
      expect(container.read(saveStatusProvider).savingCount, 3);

      container.read(saveActivityProvider).end('/cache/CAP9.jpg');
      rig.queue.pendingCount = 0;
      expect(container.read(saveStatusProvider).saving, 0);
      expect(container.read(saveStatusProvider).isSaving, isFalse);
    });

    test('does not count the shot that is being developed as a failure, and '
        'finds the failure once the line is empty', () async {
      final rig = await _rig();
      final container = rig.start();
      expect((await _settled(container)).failed, 0);

      // A shot is processed: the processor moves it into failed/ at once.
      rig.queue.pendingCount = 1;
      final job = await rig.fail('CAP1.jpg');
      await container.read(saveStatusProvider.notifier).refresh();
      expect(
        container.read(saveStatusProvider).failed,
        0,
        reason: 'it is in the line, not failed',
      );

      // It fails with a full storage: the line empties.
      rig.queue
        ..failed(job, FileSystemException('write', '/x', const OSError('', 28)))
        ..pendingCount = 0;
      await container.read(saveStatusProvider.notifier).refresh();
      final status = container.read(saveStatusProvider);
      expect(status.failed, 1);
      expect(status.problem, SaveProblem.storageFull);
      expect(status.hasFailures, isTrue);
    });
  });

  group('what went wrong', () {
    test('storage full', () {
      expect(
        saveProblemOf(FileSystemException('w', '/x', const OSError('', 28))),
        SaveProblem.storageFull,
      );
      expect(
        saveProblemOf(StateError('No space left on device')),
        SaveProblem.storageFull,
      );
    });

    test('permission', () {
      expect(
        saveProblemOf(Exception('SecurityException: permission denied')),
        SaveProblem.permission,
      );
      expect(
        saveProblemOf(FileSystemException('w', '/x', const OSError('', 13))),
        SaveProblem.permission,
      );
    });

    test('anything else is not guessed', () {
      expect(saveProblemOf(StateError('boom')), SaveProblem.unknown);
      expect(saveProblemOf(null), SaveProblem.unknown);
    });
  });

  group('the retry', () {
    test('gives every failed shot back to the queue, once, and says it is '
        'saving meanwhile', () async {
      final rig = await _rig();
      await rig.fail('CAP1.jpg');
      await rig.fail('CAP2.jpg', minute: 1);
      final container = rig.start();
      await _settled(container);

      final done = container.read(saveStatusProvider.notifier).retry();
      expect(container.read(saveStatusProvider).retrying, isTrue);
      expect(container.read(saveStatusProvider).isSaving, isTrue);
      expect(container.read(saveStatusProvider).savingCount, 2);
      await done;

      expect(rig.queue.jobs.map((j) => fileNameOf(j.filePath)), [
        'CAP1.jpg',
        'CAP2.jpg',
      ]);
      expect(container.read(saveStatusProvider).retrying, isFalse);
    });

    test(
      'never runs twice at once: a second tap waits for the first',
      () async {
        final rig = await _rig();
        await rig.fail('CAP1.jpg');
        final container = rig.start();
        await _settled(container);
        final controller = container.read(saveStatusProvider.notifier);

        final first = controller.retry();
        final second = controller.retry();
        final third = container.read(failedRetryProvider).run();
        await Future.wait([first, second, third]);

        expect(rig.queue.jobs, hasLength(1), reason: 'queued once');
        // After it finished, a new retry is possible again.
        await controller.retry();
        expect(rig.queue.jobs, hasLength(1), reason: 'already in the line');
      },
    );

    test('does not queue a shot that is already in the line', () async {
      final rig = await _rig();
      final job = await rig.fail('CAP1.jpg');
      rig.queue.enqueue(job);
      final container = rig.start();
      expect(await container.read(failedRetryProvider).run(), 0);
      expect(rig.queue.jobs, hasLength(1));
    });

    test('a shot that used up its attempts is retried only when the user '
        'asks', () async {
      final rig = await _rig();
      final job = await rig.fail('CAP1.jpg');
      for (var i = 0; i < FailedShots.maxAttempts; i++) {
        await rig.failed.countAttempt(job);
      }
      final container = rig.start();
      // The retry of every start leaves it alone...
      expect(await container.read(failedRetryProvider).run(), 0);
      expect(rig.queue.jobs, isEmpty);
      // ...but it still counts as a photo that is not saved...
      expect((await _settled(container)).failed, 1);
      // ...and the retry of the user gives it another try.
      await container.read(saveStatusProvider.notifier).retry();
      expect(rig.queue.jobs, hasLength(1));
    });

    test('asks the roll service to recover the frames it kept', () async {
      final rig = await _rig();
      final original = '${rig.cache.path}/CAPR.jpg';
      await File(original).writeAsBytes([1]);
      await File('$original.roll.json').writeAsString(
        jsonEncode({
          'captureId': 'r',
          'rollId': 1,
          'lens': 'back',
          'originalPath': original,
          'folder': '${rig.cache.path}/roll-recovery/shot_r',
          'failedFolder': '${rig.cache.path}/failed/roll_r',
          'job': {'takenAt': DateTime(2026, 11, 9).toIso8601String()},
        }),
      );
      final container = rig.start();
      expect((await _settled(container)).failed, 1);
      await container.read(saveStatusProvider.notifier).retry();
      expect(rig.rolls.recovered, 1);
    });

    test('with nothing to recover it does not wake the roll service', () async {
      final rig = await _rig();
      final container = rig.start();
      await _settled(container);
      await container.read(saveStatusProvider.notifier).retry();
      expect(rig.rolls.recovered, 0);
    });
  });
}
