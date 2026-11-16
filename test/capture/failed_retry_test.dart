import 'dart:async';
import 'dart:io';

import 'package:diapo/capture/capture_providers.dart';
import 'package:diapo/capture/capture_queue.dart';
import 'package:diapo/capture/failed_shots.dart';
import 'package:diapo/render/film_resources.dart';
import 'package:film_recipes/film_recipes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

/// The failed shots, remembering what every pass asked for.
class _SpyFailedShots extends FailedShots {
  _SpyFailedShots(super.directory);

  /// Whether each pass asked for the shots that used up their attempts.
  final List<bool> passes = <bool>[];

  /// When it is set, the next pass waits for it.
  Completer<void>? gate;

  @override
  Future<List<CaptureJob>> pending(
    RecipeBook book, {
    Future<bool> Function(CaptureJob job)? published,
    bool includeExhausted = false,
  }) async {
    passes.add(includeExhausted);
    final waiting = gate;
    if (waiting != null) {
      gate = null;
      await waiting.future;
    }
    return super.pending(
      book,
      published: published,
      includeExhausted: includeExhausted,
    );
  }
}

void main() {
  late Directory cache;
  late _SpyFailedShots failed;
  late FakeCaptureQueue queue;

  setUp(() async {
    cache = await Directory.systemTemp.createTemp('carrete_retry_');
    failed = _SpyFailedShots(Directory('${cache.path}/failed'));
    queue = FakeCaptureQueue();
  });

  tearDown(() async {
    await cache.delete(recursive: true);
  });

  /// A shot that used up its attempts: only the user can ask for it again.
  Future<CaptureJob> exhausted() async {
    final recipe = testBook().byId('alpha')!;
    final file = await File('${cache.path}/CAP1.jpg')
        .writeAsBytes([0xFF, 0xD8, 0xFF, 0xD9]);
    final kept = await failed.keep(
      CaptureJob(
        filePath: file.path,
        filmId: 'alpha',
        look: resolve(recipe),
        format: FrameFormat.r3x2,
        seed: 1,
        takenAt: DateTime(2026, 11, 9, 18),
      ),
    );
    expect(kept, isNotNull);
    for (var i = 0; i < FailedShots.maxAttempts; i++) {
      await failed.countAttempt(kept!);
    }
    return kept!;
  }

  ProviderContainer start() {
    final container = ProviderContainer(
      overrides: [
        cacheDirectoryProvider.overrideWithValue(cache),
        failedShotsProvider.overrideWithValue(failed),
        captureQueueProvider.overrideWithValue(queue),
        recipeBookProvider.overrideWith((ref) async => testBook()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('the retry of the failed shots', () {
    test('a manual one during the start-up one runs one more pass', () async {
      await exhausted();
      final container = start();
      final retry = container.read(failedRetryProvider);

      // The start-up pass is running: it waits for the folder of the shots.
      failed.gate = Completer<void>();
      final startUp = retry.run();
      // The user asks for the shots that used up their attempts, twice.
      final manual = retry.run(includeExhausted: true);
      final second = retry.run(includeExhausted: true);
      failed.gate!.complete();

      // The start-up pass leaves the exhausted shot alone.
      expect(await startUp, 0);
      // The two requests are one pass, which honours the request.
      expect(await manual, 1);
      expect(await second, 1);
      expect(failed.passes, [
        false,
        true,
      ], reason: 'one more pass, and only one');
      expect(queue.jobs, hasLength(1));
    });

    test('a start-up one alone never asks for the exhausted shots', () async {
      await exhausted();
      final container = start();
      final retry = container.read(failedRetryProvider);

      expect(await retry.run(), 0);
      expect(failed.passes, [false]);
      expect(queue.jobs, isEmpty);
    });
  });
}
