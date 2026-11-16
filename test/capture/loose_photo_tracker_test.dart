import 'package:diapo/capture/capture_providers.dart';
import 'package:diapo/capture/capture_queue.dart';
import 'package:diapo/capture/loose_photo_tracker.dart';
import 'package:diapo/core/settings/first_minute.dart';
import 'package:diapo/core/settings/settings_provider.dart';
import 'package:film_recipes/film_recipes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fakes.dart';

CaptureJob _job(String? captureId, {bool retried = false}) {
  final recipe = RecipeBook.parse(
    '{"schemaVersion":1,"recipesVersion":"2026.11.1","recipes":[{"id":"aa",'
    '"name":{"es":"a","ca":"a","en":"a"},'
    '"description":{"es":"a","ca":"a","en":"a"}}]}',
  ).recipes.first;
  return CaptureJob(
    filePath: 'a',
    filmId: 'aa',
    look: resolve(recipe),
    format: FrameFormat.r3x2,
    seed: 1,
    takenAt: DateTime(2026, 11, 9),
    captureId: captureId,
    retried: retried,
  );
}

/// An app that has just started, on the same preferences as the one before.
ProviderContainer _start(
  SharedPreferences preferences,
  FakeCaptureQueue queue,
) {
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(preferences),
      captureQueueProvider.overrideWithValue(queue),
    ],
  );
  addTearDown(container.dispose);
  container.read(loosePhotoTrackerProvider);
  return container;
}

Future<void> _save(FakeCaptureQueue queue, CaptureJob job) async {
  queue.saved(job);
  await pumpEventQueue();
}

Future<void> _fail(FakeCaptureQueue queue, CaptureJob job) async {
  queue.failed(job);
  await pumpEventQueue();
}

void main() {
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  test('counts a photo when it is saved, not when it fails', () async {
    final queue = FakeCaptureQueue();
    final container = _start(preferences, queue);

    await _fail(queue, _job('a'));
    expect(container.read(firstMinuteProvider).loosePhotos, 0);

    await _save(queue, _job('b'));
    expect(container.read(firstMinuteProvider).loosePhotos, 1);
  });

  test('a photo that failed, then was recovered after a restart, counts '
      'once', () async {
    // First run: the photo fails to save and is never counted.
    final first = FakeCaptureQueue();
    final before = _start(preferences, first);
    await _fail(first, _job('shot-1'));
    expect(before.read(firstMinuteProvider).loosePhotos, 0);
    before.dispose();

    // The app restarts and the failed shot is retried: it is saved now.
    final second = FakeCaptureQueue();
    final after = _start(preferences, second);
    await _save(second, _job('shot-1', retried: true));
    expect(after.read(firstMinuteProvider).loosePhotos, 1);

    // The same capture reported again is not counted twice, not even after
    // another restart.
    await _save(second, _job('shot-1', retried: true));
    expect(after.read(firstMinuteProvider).loosePhotos, 1);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    after.dispose();
    final third = FakeCaptureQueue();
    final again = _start(preferences, third);
    await _save(third, _job('shot-1', retried: true));
    expect(again.read(firstMinuteProvider).loosePhotos, 1);
  });

  test('a recovered photo and a new one are two', () async {
    final queue = FakeCaptureQueue();
    final container = _start(preferences, queue);
    await _save(queue, _job('old', retried: true));
    await _save(queue, _job('new'));
    expect(container.read(firstMinuteProvider).loosePhotos, 2);
  });

  test('a photo with no identity always counts', () async {
    final queue = FakeCaptureQueue();
    final container = _start(preferences, queue);
    queue.saved(_job(null), 'content://photo/1');
    await pumpEventQueue();
    queue.saved(_job(null), 'content://photo/2');
    await pumpEventQueue();
    expect(container.read(firstMinuteProvider).loosePhotos, 2);
  });

  test('an event with no capture id but a saved uri, emitted twice (recovery, '
      'then a later run), counts once', () async {
    final queue = FakeCaptureQueue();
    final container = _start(preferences, queue);
    queue.saved(_job(null), 'content://photo/1');
    await pumpEventQueue();
    queue.saved(_job(null), 'content://photo/1');
    await pumpEventQueue();
    expect(container.read(firstMinuteProvider).loosePhotos, 1);
  });

  test('a photo with no capture id and no saved uri counts each time '
      '(today\'s behaviour: it counts)', () async {
    final queue = FakeCaptureQueue();
    final container = _start(preferences, queue);
    queue.saved(_job(null), null);
    await pumpEventQueue();
    queue.saved(_job(null), null);
    await pumpEventQueue();
    expect(container.read(firstMinuteProvider).loosePhotos, 2);
  });

  test(
    'counts without a camera screen: nothing here needs the widget',
    () async {
      // The tracker is the app's, so a photo saved while the camera is not on
      // screen counts the same.
      final queue = FakeCaptureQueue();
      final container = _start(preferences, queue);
      for (var i = 0; i < 3; i++) {
        await _save(queue, _job('p$i'));
      }
      expect(container.read(firstMinuteProvider).loosePhotos, 3);
    },
  );

  test('stops counting once the offer was shown', () async {
    final queue = FakeCaptureQueue();
    final container = _start(preferences, queue);
    await _save(queue, _job('a'));
    container.read(firstMinuteProvider.notifier).markRollOfferSeen();
    await _save(queue, _job('b'));
    expect(container.read(firstMinuteProvider).loosePhotos, 1);
  });

  test('remembers only the last captures, so the list stays short', () async {
    final queue = FakeCaptureQueue();
    final container = _start(preferences, queue);
    for (var i = 0; i < kCountedCapturesKept + 8; i++) {
      await _save(queue, _job('p$i'));
    }
    expect(
      container.read(firstMinuteProvider).countedCaptures,
      hasLength(kCountedCapturesKept),
    );
  });
}
