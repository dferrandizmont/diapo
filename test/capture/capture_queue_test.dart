import 'dart:async';

import 'package:diapo/capture/capture_queue.dart';
import 'package:film_recipes/film_recipes.dart';
import 'package:flutter_test/flutter_test.dart';

CaptureJob _job(String path) {
  final recipe = RecipeBook.parse(
    '{"schemaVersion":1,"recipesVersion":"2026.11.1","recipes":[{"id":"aa",'
    '"name":{"es":"a","ca":"a","en":"a"},'
    '"description":{"es":"a","ca":"a","en":"a"}}]}',
  ).recipes.first;
  return CaptureJob(
    filePath: path,
    filmId: 'aa',
    look: resolve(recipe),
    format: FrameFormat.r3x2,
    seed: 1,
    takenAt: DateTime(2026, 11, 9),
  );
}

class _ManualProcessor implements CaptureProcessor {
  final List<String> started = <String>[];
  final Map<String, Completer<String?>> _gates = <String, Completer<String?>>{};

  Completer<String?> gate(String path) =>
      _gates.putIfAbsent(path, Completer<String?>.new);

  @override
  Future<String?> process(CaptureJob job) {
    started.add(job.filePath);
    return gate(job.filePath).future;
  }
}

void main() {
  test('enqueue returns at once and the job runs afterwards', () async {
    final processor = _ManualProcessor();
    final queue = SequentialCaptureQueue(processor);
    addTearDown(queue.dispose);

    queue.enqueue(_job('a'));
    expect(queue.pending.value, 1);
    await pumpEventQueue();
    expect(processor.started, ['a']);
    expect(queue.pending.value, 1, reason: 'still processing');

    processor.gate('a').complete('content://a');
    await pumpEventQueue();
    expect(queue.pending.value, 0);
  });

  test('runs one job at a time, in order, while more are queued', () async {
    final processor = _ManualProcessor();
    final queue = SequentialCaptureQueue(processor);
    addTearDown(queue.dispose);
    final events = <CaptureEvent>[];
    queue.events.listen(events.add);

    queue
      ..enqueue(_job('a'))
      ..enqueue(_job('b'))
      ..enqueue(_job('c'));
    await pumpEventQueue();
    expect(processor.started, ['a'], reason: 'b and c wait for a');
    expect(queue.pending.value, 3);

    processor.gate('a').complete('uri-a');
    await pumpEventQueue();
    expect(processor.started, ['a', 'b']);

    processor.gate('b').complete('uri-b');
    processor.gate('c').complete('uri-c');
    await pumpEventQueue();
    expect(processor.started, ['a', 'b', 'c']);
    expect(queue.pending.value, 0);
    expect(events.map((e) => e.uri), ['uri-a', 'uri-b', 'uri-c']);
    expect(events.every((e) => e.ok), isTrue);
  });

  test('a capture can be queued while another one is processing', () async {
    final processor = _ManualProcessor();
    final queue = SequentialCaptureQueue(processor);
    addTearDown(queue.dispose);

    queue.enqueue(_job('a'));
    await pumpEventQueue();
    queue.enqueue(_job('b'));
    expect(queue.pending.value, 2);
    processor.gate('a').complete('uri-a');
    await pumpEventQueue();
    expect(processor.started, ['a', 'b']);
  });

  test('a failed job is reported and the next one still runs', () async {
    final processor = _ManualProcessor();
    final queue = SequentialCaptureQueue(processor);
    addTearDown(queue.dispose);
    final events = <CaptureEvent>[];
    queue.events.listen(events.add);

    queue
      ..enqueue(_job('a'))
      ..enqueue(_job('b'));
    await pumpEventQueue();
    processor.gate('a').completeError(StateError('boom'));
    await pumpEventQueue();
    processor.gate('b').complete('uri-b');
    await pumpEventQueue();

    expect(events.map((e) => e.ok), [false, true]);
    expect(events.first.error, isA<StateError>());
    expect(events.last.uri, 'uri-b');
    expect(queue.pending.value, 0);
  });

  test('holds a job by the name of its file, wherever the file is', () async {
    final processor = _ManualProcessor();
    final queue = SequentialCaptureQueue(processor);
    addTearDown(queue.dispose);

    queue
      ..enqueue(_job('/cache/CAP1.jpg'))
      ..enqueue(_job('/cache/CAP2.jpg'));
    await pumpEventQueue();
    // The processor moves a shot into failed/ as soon as it starts on it.
    expect(queue.holds('/cache/failed/CAP1.jpg'), isTrue, reason: 'running');
    expect(queue.holds('/cache/failed/CAP2.jpg'), isTrue, reason: 'waiting');
    expect(queue.holds(r'C:\cache\failed\CAP2.jpg'), isTrue);
    expect(queue.holds('/cache/failed/CAP3.jpg'), isFalse);

    processor.gate('/cache/CAP1.jpg').complete('uri-1');
    await pumpEventQueue();
    expect(queue.holds('/cache/failed/CAP1.jpg'), isFalse, reason: 'done');
    expect(queue.holds('/cache/failed/CAP2.jpg'), isTrue);

    processor.gate('/cache/CAP2.jpg').completeError(StateError('boom'));
    await pumpEventQueue();
    expect(queue.holds('/cache/failed/CAP2.jpg'), isFalse, reason: 'failed');
  });
}
