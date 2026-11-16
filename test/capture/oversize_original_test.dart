import 'dart:io';

import 'package:carrete/capture/capture_queue.dart';
import 'package:carrete/capture/film_capture_processor.dart';
import 'package:carrete/capture/still_bounds.dart';
import 'package:film_recipes/film_recipes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  test(
    'an original over the size limit is refused before it is read',
    () async {
      final dir = await Directory.systemTemp.createTemp('carrete_oversize_');
      addTearDown(() => dir.delete(recursive: true));
      // A sparse file one byte over the limit: it is never read.
      final file = File('${dir.path}/huge.jpg');
      final raf = file.openSync(mode: FileMode.write);
      raf.truncateSync(StillBounds.maxFileBytes + 1);
      raf.closeSync();
      final recipe = testBook().byId('beta')!;
      final processor = FilmCaptureProcessor(
        // Reaching the shader would fail with another message.
        loadProgram: () async => throw StateError('shader reached'),
      );

      await expectLater(
        processor.process(
          CaptureJob(
            filePath: file.path,
            filmId: recipe.id,
            look: resolve(recipe),
            format: FrameFormat.r3x2,
            seed: 1,
            takenAt: DateTime(2026, 11, 13),
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('too large'),
          ),
        ),
      );
    },
  );
}
