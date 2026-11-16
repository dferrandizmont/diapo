import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:carrete/capture/cinema_bands.dart';
import 'package:carrete/capture/date_stamp.dart';
import 'package:carrete/camera/frame_geometry.dart';
import 'package:carrete/capture/film_still_renderer.dart';
import 'package:carrete/render/look_adjust.dart';
import 'package:carrete/ui/widgets/seven_segment.dart';
import 'package:film_recipes/film_recipes.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Uint8List> _pixels(ui.Image image) async {
  try {
    return Uint8List.sublistView(
      (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!,
    );
  } finally {
    image.dispose();
  }
}

/// Find complete #0A0A0A rows/columns, including alpha, rather than trusting
/// the geometry helper to tell the raster test where the bars ought to be.
List<Rect> _bandRects(Uint8List rgba, Size size) {
  final w = size.width.toInt();
  final h = size.height.toInt();
  final landscape = w > h;
  final lines = <int>[];
  for (var line = 0; line < (landscape ? h : w); line++) {
    var black = true;
    for (var p = 0; p < (landscape ? w : h); p++) {
      final i = (landscape ? line * w + p : p * w + line) * 4;
      if (rgba[i] != 10 ||
          rgba[i + 1] != 10 ||
          rgba[i + 2] != 10 ||
          rgba[i + 3] != 255) {
        black = false;
        break;
      }
    }
    if (black) lines.add(line);
  }
  final rects = <Rect>[];
  for (var i = 0; i < lines.length;) {
    final start = lines[i];
    var end = start + 1;
    while (++i < lines.length && lines[i] == end) {
      end++;
    }
    rects.add(
      landscape
          ? Rect.fromLTRB(0, start.toDouble(), size.width, end.toDouble())
          : Rect.fromLTRB(start.toDouble(), 0, end.toDouble(), size.height),
    );
  }
  return rects;
}

Rect _dateBounds(Uint8List dated, Uint8List plain, Size size) {
  Rect? bounds;
  for (var i = 0; i < dated.length; i += 4) {
    // Exclude the faintest glow tails, whose quantization depends on the
    // still's intermediate date patch. Include all visible date strokes.
    if ((dated[i] - plain[i]).abs() <= 8 &&
        (dated[i + 1] - plain[i + 1]).abs() <= 8 &&
        (dated[i + 2] - plain[i + 2]).abs() <= 8) {
      continue;
    }
    final pixel = i ~/ 4;
    final rect = Rect.fromLTWH(
      (pixel % size.width.toInt()).toDouble(),
      (pixel ~/ size.width.toInt()).toDouble(),
      1,
      1,
    );
    bounds = bounds?.expandToInclude(rect) ?? rect;
  }
  expect(bounds, isNotNull, reason: 'The date must actually paint pixels');
  return bounds!;
}

void _expectFractionalRect(Rect actual, Rect expected, Size size) {
  expect(
    actual.left / size.width,
    closeTo(expected.left / size.width, 1 / size.width),
  );
  expect(
    actual.right / size.width,
    closeTo(expected.right / size.width, 1 / size.width),
  );
  expect(
    actual.top / size.height,
    closeTo(expected.top / size.height, 1 / size.height),
  );
  expect(
    actual.bottom / size.height,
    closeTo(expected.bottom / size.height, 1 / size.height),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final size in const [
    Size(1600, 900),
    Size(3200, 1800),
    Size(900, 1600),
    Size(1800, 3200),
  ]) {
    test('cinema geometry and date placement at $size', () {
      final picture = CinemaBands.pictureRect(size);
      expect(
        picture.size.longestSide / picture.size.shortestSide,
        closeTo(2.39, 1e-12),
      );
      if (size.width > size.height) {
        expect(picture.top / size.height, closeTo(0.12808, 0.00001));
        expect(size.height - picture.bottom, closeTo(picture.top, 1e-10));
        expect(picture.width, size.width);
      } else {
        expect(picture.left / size.width, closeTo(0.12808, 0.00001));
        expect(size.width - picture.right, closeTo(picture.left, 1e-10));
        expect(picture.height, size.height);
      }
      final date =
          picture.topLeft + DateStamp.origin(picture.size, "'26 11 14");
      final digits = SevenSegment.measure(
        "'26 11 14",
        DateStamp.digitHeight(picture.size),
      );
      final bounds = date & digits;
      expect(
        (picture.right - bounds.right) / picture.size.shortestSide,
        closeTo(0.05, 1e-12),
      );
      expect(
        (picture.bottom - bounds.bottom) / picture.size.shortestSide,
        closeTo(0.05, 1e-12),
      );
      expect(bounds.height / picture.size.shortestSide, closeTo(0.05, 1e-12));
      expect(picture.contains(date), isTrue);
      expect(
        date.dy + DateStamp.digitHeight(picture.size),
        lessThan(picture.bottom),
      );
    });
  }

  test('only 16:9 supports bands', () {
    expect(FrameFormat.values.where((f) => f.supportsCinemaBands), [
      FrameFormat.r16x9,
    ]);
  });

  for (final size in const [Size(640, 360), Size(360, 640)]) {
    testWidgets('painted preview matches still bands and date at $size', (
      tester,
    ) async {
      // Both viewfinder and import use these exact two overlay widgets.
      // Paint them over the undated developed image so that date differences
      // measure placement, independently of the film shader's colour changes.
      const text = "'26 11 14";
      final book = RecipeBook.parse(
        File('packages/film_recipes/assets/recipes.json').readAsStringSync(),
      );
      final look = resolve(book.byId('cine')!);
      late FilmStill plain;
      late FilmStill dated;
      late ui.Image background;
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        ui.Canvas(recorder)
            .drawColor(const Color(0xffb06030), ui.BlendMode.src);
        final picture = recorder.endRecording();
        final image = await picture.toImage(
          size.width.toInt(),
          size.height.toInt(),
        );
        picture.dispose();
        late Uint8List input;
        try {
          input = Uint8List.sublistView(
            (await image.toByteData(format: ui.ImageByteFormat.png))!,
          );
        } finally {
          image.dispose();
        }
        final renderer = FilmStillRenderer(
          await ui.FragmentProgram.fromAsset('shaders/film.frag'),
        );
        final curve = await curveImageOf(look);
        try {
          Future<FilmStill> render({bool bands = true, String? stamp}) =>
              renderer.render(
                jpeg: input,
                look: look,
                curve: curve,
                format: FrameFormat.r16x9,
                seed: 42,
                cinemaBands: bands,
                stampText: stamp,
                // Cross both bands and the date with tile boundaries.
                tileSize: 83,
              );
          final base = await render(bands: false);
          background = await decodeRgba(base.rgba, base.width, base.height);
          plain = await render();
          dated = await render(stamp: text);
          expect(
            (dated.width, dated.height),
            (size.width.toInt(), size.height.toInt()),
          );
        } finally {
          curve.dispose();
        }
      });
      addTearDown(background.dispose);
      final key = GlobalKey();
      Future<void> preview({required bool date}) => tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox.fromSize(
                size: size,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RawImage(image: background),
                    if (date)
                      const DateStampOverlay(text: text, cinemaBands: true),
                    const CinemaBandsOverlay(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      // The portrait fixture is taller than the default test surface.
      await tester.binding.setSurfaceSize(const Size(800, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await preview(date: false);
      late Uint8List previewPlain;
      late Uint8List previewDated;
      Future<Uint8List> capture() async => _pixels(
        await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary)
            .toImage(pixelRatio: 1),
      );
      await tester.runAsync(() async {
        previewPlain = await capture();
      });
      await preview(date: true);
      await tester.runAsync(() async {
        previewDated = await capture();
      });

      final previewBands = _bandRects(previewDated, size);
      final stillBands = _bandRects(dated.rgba, size);
      expect(previewBands, hasLength(2));
      expect(stillBands, hasLength(2));
      final inset = (size.shortestSide - size.longestSide / 2.39) / 2;
      final expected = size.width > size.height
          ? [
              Rect.fromLTRB(0, 0, size.width, inset),
              Rect.fromLTRB(0, size.height - inset, size.width, size.height),
            ]
          : [
              Rect.fromLTRB(0, 0, inset, size.height),
              Rect.fromLTRB(size.width - inset, 0, size.width, size.height),
            ];
      for (var i = 0; i < 2; i++) {
        _expectFractionalRect(previewBands[i], stillBands[i], size);
        _expectFractionalRect(previewBands[i], expected[i], size);
      }
      final previewDate = _dateBounds(previewDated, previewPlain, size);
      final stillDate = _dateBounds(dated.rgba, plain.rgba, size);
      _expectFractionalRect(previewDate, stillDate, size);
      final picture = CinemaBands.pictureRect(size);
      expect(picture.contains(previewDate.topLeft), isTrue);
      expect(picture.contains(previewDate.bottomRight), isTrue);
      // Date remains in the lower right of the visible picture in both axes.
      expect(previewDate.left, greaterThan(picture.center.dx));
      expect(previewDate.top, greaterThan(picture.center.dy));
    });
  }
}
