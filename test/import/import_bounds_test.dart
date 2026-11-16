import 'dart:async';
import 'dart:io';

import 'package:carrete/capture/film_still_renderer.dart';
import 'package:carrete/import/import_providers.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/png.dart';

/// The size a provider decodes its picture to.
Future<Size> _decodedSize(ImageProvider provider) {
  final done = Completer<Size>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      done.complete(
        Size(info.image.width.toDouble(), info.image.height.toDouble()),
      );
      info.dispose();
      stream.removeListener(listener);
    },
    onError: (error, stack) {
      done.completeError(error, stack);
      stream.removeListener(listener);
    },
  );
  stream.addListener(listener);
  return done.future.timeout(const Duration(seconds: 20));
}

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('carrete_bounds_');
    addTearDown(() => dir.delete(recursive: true));
  });

  testWidgets('preview and thumbnail fit their box on both axes', (
    tester,
  ) async {
    final wide = File('${dir.path}/wide.png')
      ..writeAsBytesSync(makePng(3200, 400));
    final tall = File('${dir.path}/tall.png')
      ..writeAsBytesSync(makePng(400, 3200));
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.runAsync(() async {
      // The long side is brought to the box, whichever side it is, and the
      // proportion is kept (8:1).
      final previewWide = await _decodedSize(
        container.read(importPreviewProvider(wide.path)),
      );
      final previewTall = await _decodedSize(
        container.read(importPreviewProvider(tall.path)),
      );
      expect(previewWide.width, kImportPreviewSide);
      expect(previewWide.height, closeTo(kImportPreviewSide / 8, 1));
      expect(previewTall.height, kImportPreviewSide);
      expect(previewTall.width, closeTo(kImportPreviewSide / 8, 1));

      final thumbWide = await _decodedSize(
        container.read(importThumbnailProvider(wide.path)),
      );
      final thumbTall = await _decodedSize(
        container.read(importThumbnailProvider(tall.path)),
      );
      expect(thumbWide.width, kImportThumbnailSide);
      expect(thumbWide.height, closeTo(kImportThumbnailSide / 8, 1));
      expect(thumbTall.height, kImportThumbnailSide);
      expect(thumbTall.width, closeTo(kImportThumbnailSide / 8, 1));
    });
  });

  testWidgets('a small photo is never enlarged', (tester) async {
    final small = File('${dir.path}/small.png')
      ..writeAsBytesSync(makePng(100, 60));
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.runAsync(() async {
      final size = await _decodedSize(
        container.read(importPreviewProvider(small.path)),
      );
      expect(size, const Size(100, 60));
    });
  });

  group('the renderer refuses a big header before it decodes', () {
    testWidgets('a PNG that declares more than 100 MP', (tester) async {
      // 11000 x 11000 = 121 MP: under the 200 MP of a JPEG, over the 100 MP
      // of any other format. The file has no pixels: a decode would fail with
      // another error.
      await tester.runAsync(() async {
        await expectLater(
          FilmStillRenderer.decodeBounded(pngDeclaring(11000, 11000)),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('too many pixels'),
            ),
          ),
        );
      });
    });

    testWidgets('a huge header of any kind', (tester) async {
      await tester.runAsync(() async {
        await expectLater(
          FilmStillRenderer.decodeBounded(pngDeclaring(30000, 30000)),
          throwsA(isA<StateError>()),
        );
      });
    });

    testWidgets('a small real photo is still decoded', (tester) async {
      await tester.runAsync(() async {
        final image = await FilmStillRenderer.decodeBounded(makePng(64, 48));
        expect((image.width, image.height), (64, 48));
        image.dispose();
      });
    });
  });

  test('the FileProvider of the picker serves only an empty subfolder', () {
    final xml = File(
      'android/app/src/main/res/xml/flutter_image_picker_file_paths.xml',
    ).readAsStringSync();
    // Comments aside, the only path is the unused subfolder of the cache.
    final body = xml.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
    final entries = RegExp(r'<[a-z-]+-path\b[^>]*>').allMatches(body).toList();

    expect(entries, hasLength(1));
    expect(entries.single.group(0), contains('<cache-path'));
    expect(entries.single.group(0), contains('path="image_picker_unused/"'));
    expect(body, isNot(contains('path="."')));
    expect(body, isNot(contains('<root-path')));
    expect(body, isNot(contains('<files-path')));
  });
}
