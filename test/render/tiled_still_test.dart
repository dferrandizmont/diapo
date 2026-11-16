import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:diapo/camera/frame_geometry.dart';
import 'package:diapo/capture/date_stamp.dart';
import 'package:diapo/capture/cinema_bands.dart';
import 'package:diapo/capture/film_still_renderer.dart';
import 'package:diapo/capture/white_frame.dart';
import 'package:diapo/render/look_adjust.dart';
import 'package:diapo/ui/theme/carrete_tokens.dart';
import 'package:film_recipes/film_recipes.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ui.Image> raster(ui.Size size, void Function(ui.Canvas) draw) async {
  final recorder = ui.PictureRecorder();
  draw(ui.Canvas(recorder));
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(size.width.round(), size.height.round());
  } finally {
    picture.dispose();
  }
}

/// The pre-tiles production path: materialize a centred crop, shade one full
/// target with the default whole-image uniforms, then compose the print.
/// Small fixtures need no decode scaling. Normalize the reference to straight
/// RGBA, the representation required by the new tiled Android setPixels sink.
Future<FilmStill> previousSinglePass({
  required ui.FragmentProgram program,
  required Uint8List input,
  required ResolvedLook look,
  required ui.Image curve,
  required FrameFormat format,
  double seed = 97.125,
  String? stampText,
  bool whiteFrame = false,
}) async {
  final codec = await ui.instantiateImageCodec(input);
  ui.Image photo;
  try {
    photo = (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
  final shader = program.fragmentShader();
  ui.Image? film;
  try {
    final source = ui.Size(photo.width.toDouble(), photo.height.toDouble());
    final crop = frameCrop(format, source);
    if (crop.size != source) {
      final cropped = await raster(crop.size, (canvas) {
        canvas.drawImageRect(
          photo,
          crop,
          ui.Offset.zero & crop.size,
          ui.Paint()..filterQuality = ui.FilterQuality.none,
        );
      });
      photo.dispose();
      photo = cropped;
    }
    final size = ui.Size(photo.width.toDouble(), photo.height.toDouble());
    applyResolvedLook(shader, look, filterMode: false, seed: seed, size: size);
    shader.setImageSampler(0, photo);
    shader.setImageSampler(1, curve);
    final framed = whiteFrame && format == FrameFormat.r1x1;
    film = await raster(size, (canvas) {
      canvas.drawRect(ui.Offset.zero & size, ui.Paint()..shader = shader);
      if (stampText != null && !framed) {
        DateStamp.paint(canvas, size, stampText);
      }
    });
    if (framed) {
      final inner = WhiteFrame.photoRect(size);
      final outer = WhiteFrame.outerSize(size);
      final printed = await raster(outer, (canvas) {
        canvas.drawRect(
          ui.Offset.zero & outer,
          ui.Paint()..color = CarreteColors.whiteFrame,
        );
        canvas.drawImage(film!, inner.topLeft, ui.Paint());
        if (stampText != null) {
          canvas.translate(inner.left, inner.top);
          DateStamp.paint(canvas, size, stampText);
        }
      });
      film.dispose();
      film = printed;
    }
    final bytes = await film.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    return FilmStill(
      rgba: Uint8List.sublistView(bytes!),
      width: film.width,
      height: film.height,
      timings: const {},
    );
  } finally {
    film?.dispose();
    shader.dispose();
    photo.dispose();
  }
}

void expectSame(FilmStill tiled, FilmStill single) {
  expect((tiled.width, tiled.height), (single.width, single.height));
  expect(tiled.rgba.length, single.rgba.length);
  var worst = 0;
  var worstIndex = 0;
  for (var i = 0; i < tiled.rgba.length; i++) {
    final delta = (tiled.rgba[i] - single.rgba[i]).abs();
    if (delta > worst) {
      worst = delta;
      worstIndex = i;
    }
  }
  expect(
    worst,
    lessThanOrEqualTo(2),
    reason:
        'pixel (${worstIndex ~/ 4 % single.width}, '
        '${worstIndex ~/ 4 ~/ single.width}), channel ${worstIndex % 4}',
  );
}

/// Read the fast path's premultiplied buffer back as straight RGBA, just as
/// Android's legacy copyPixelsFromBuffer stores it in a premultiplied Bitmap.
Future<FilmStill> fastSinglePass({
  required FilmStillRenderer renderer,
  required Uint8List input,
  required ResolvedLook look,
  required ui.Image curve,
  required FrameFormat format,
  String? stampText,
  bool whiteFrame = false,
  bool cinemaBands = false,
}) async {
  late FilmStill still;
  await renderer.renderTiles(
    jpeg: input,
    look: look,
    curve: curve,
    format: format,
    seed: 97.125,
    stampText: stampText,
    whiteFrame: whiteFrame,
    cinemaBands: cinemaBands,
    onBegin: (_, _) async => fail('Small still must use a single pass'),
    onTile: (_) async => fail('Small still must not emit tiles'),
    onSinglePass: (rgba, width, height) async {
      final image = await decodeRgba(rgba, width, height);
      try {
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        );
        still = FilmStill(
          rgba: Uint8List.sublistView(bytes!),
          width: width,
          height: height,
          timings: const {},
        );
      } finally {
        image.dispose();
      }
    },
  );
  return still;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final book = RecipeBook.parse(
    File('packages/film_recipes/assets/recipes.json').readAsStringSync(),
  );

  // Odd dimensions exercise partial tiles and asymmetric centred crops.
  Future<Uint8List> chart() async {
    final image = await decodeRgba(
      buildTestChart(width: 241, height: 163),
      241,
      163,
    );
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      return bytes!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  for (final portrait in [false, true]) {
    testWidgets(
      'cinema bands, date and production paths match (portrait=$portrait)',
      (tester) async {
        await tester.runAsync(() async {
          final renderer = FilmStillRenderer(
            await ui.FragmentProgram.fromAsset('shaders/film.frag'),
          );
          final look = resolve(book.byId('cine')!);
          final curve = await curveImageOf(look);
          final image = await decodeRgba(
            buildTestChart(
              width: portrait ? 163 : 241,
              height: portrait ? 241 : 163,
            ),
            portrait ? 163 : 241,
            portrait ? 241 : 163,
          );
          late Uint8List input;
          try {
            input = Uint8List.sublistView(
              (await image.toByteData(format: ui.ImageByteFormat.png))!,
            );
          } finally {
            image.dispose();
          }
          try {
            Future<FilmStill> render({
              int tileSize = 47,
              bool bands = true,
              String? date,
              FrameFormat format = FrameFormat.r16x9,
            }) => renderer.render(
              jpeg: input,
              look: look,
              curve: curve,
              format: format,
              seed: 97.125,
              cinemaBands: bands,
              stampText: date,
              tileSize: tileSize,
            );
            final bands = await render();
            final whole = await render(tileSize: 4096);
            expectSame(bands, whole);
            final plain = await render(bands: false);
            expect((bands.width, bands.height), (plain.width, plain.height));
            final size = ui.Size(
              bands.width.toDouble(),
              bands.height.toDouble(),
            );
            final picture = CinemaBands.pictureRect(size);
            var picturePixels = 0;
            for (var y = 0; y < bands.height; y++) {
              for (var x = 0; x < bands.width; x++) {
                final i = (y * bands.width + x) * 4;
                // Keep away from the subpixel boundary when checking flat bars.
                if (!picture.inflate(1).contains(ui.Offset(x + 0.5, y + 0.5))) {
                  expect(bands.rgba.sublist(i, i + 4), [10, 10, 10, 255]);
                } else if (picture
                    .deflate(1)
                    .contains(ui.Offset(x + 0.5, y + 0.5))) {
                  expect(
                    bands.rgba.sublist(i, i + 4),
                    plain.rgba.sublist(i, i + 4),
                  );
                  picturePixels++;
                }
              }
            }
            expect(picturePixels, greaterThan(0));
            final dated = await render(date: "'26 11 14");
            var datePixels = 0;
            for (var i = 0; i < dated.rgba.length; i += 4) {
              if (dated.rgba[i] != bands.rgba[i] ||
                  dated.rgba[i + 1] != bands.rgba[i + 1]) {
                final pixel = i ~/ 4;
                expect(
                  picture
                      .inflate(1)
                      .contains(
                        ui.Offset(
                          (pixel % bands.width) + 0.5,
                          (pixel ~/ bands.width) + 0.5,
                        ),
                      ),
                  isTrue,
                );
                datePixels++;
              }
            }
            expect(datePixels, greaterThan(0));
            final fast = await fastSinglePass(
              renderer: renderer,
              input: input,
              look: look,
              curve: curve,
              format: FrameFormat.r16x9,
              cinemaBands: true,
              stampText: "'26 11 14",
            );
            expectSame(dated, fast);
            expectSame(dated, await render(tileSize: 4096, date: "'26 11 14"));
            expectSame(
              await render(format: FrameFormat.r3x2),
              await render(format: FrameFormat.r3x2, bands: false),
            );
          } finally {
            curve.dispose();
          }
        });
      },
    );
  }

  for (final recipe in book.recipes) {
    testWidgets(
      '${recipe.id}: tiles match the previous single pass, date and print included',
      (tester) async {
        await tester.runAsync(() async {
          final renderer = FilmStillRenderer(
            await ui.FragmentProgram.fromAsset('shaders/film.frag'),
          );
          final input = await chart();
          for (final intensity in [0.5, 1.0]) {
            final look = resolve(recipe, intensity: intensity);
            final curve = await curveImageOf(look);
            try {
              for (final print in [false, true]) {
                Future<FilmStill> render(int side) => renderer.render(
                  jpeg: input,
                  look: look,
                  curve: curve,
                  format: print ? FrameFormat.r1x1 : FrameFormat.r3x2,
                  seed: 97.125,
                  stampText: "'26 11 14",
                  whiteFrame: print,
                  tileSize: side,
                );
                final single = await render(4096);
                final tiled = await render(47);
                expectSame(tiled, single);
                final previous = await previousSinglePass(
                  program: renderer.program,
                  input: input,
                  look: look,
                  curve: curve,
                  format: print ? FrameFormat.r1x1 : FrameFormat.r3x2,
                  stampText: "'26 11 14",
                  whiteFrame: print,
                );
                expectSame(tiled, previous);
                final fast = await fastSinglePass(
                  renderer: renderer,
                  input: input,
                  look: look,
                  curve: curve,
                  format: print ? FrameFormat.r1x1 : FrameFormat.r3x2,
                  stampText: "'26 11 14",
                  whiteFrame: print,
                );
                expectSame(tiled, fast);
              }
            } finally {
              curve.dispose();
            }
          }
        });
      },
    );
  }

  for (final source in ['16:9', 'EXIF rotation 6', 'transparent PNG']) {
    testWidgets('$source matches the previous single pass', (tester) async {
      await tester.runAsync(() async {
        final renderer = FilmStillRenderer(
          await ui.FragmentProgram.fromAsset('shaders/film.frag'),
        );
        final Uint8List input;
        if (source == 'EXIF rotation 6') {
          // Stored 241x163, EXIF rotates clockwise to upright 163x241.
          input = File('test/render/fixtures/chart_exif_6.jpg')
              .readAsBytesSync();
          final decoded = await FilmStillRenderer.decodeBounded(input);
          expect((decoded.width, decoded.height), (163, 241));
          decoded.dispose();
        } else if (source == 'transparent PNG') {
          final image = await raster(const ui.Size(241, 163), (canvas) {
            for (var x = 0; x < 241; x++) {
              canvas.drawRect(
                ui.Rect.fromLTWH(x.toDouble(), 0, 1, 163),
                ui.Paint()
                  ..color = ui.Color.fromARGB(
                    x < 80 ? 0 : (x < 160 ? 128 : 255),
                    200,
                    100,
                    50,
                  ),
              );
            }
          });
          try {
            final png = await image.toByteData(format: ui.ImageByteFormat.png);
            input = Uint8List.sublistView(png!);
          } finally {
            image.dispose();
          }
        } else {
          input = await chart();
        }
        final format = source == '16:9' ? FrameFormat.r16x9 : FrameFormat.r3x2;
        for (final recipe in book.recipes) {
          final look = resolve(recipe);
          final curve = await curveImageOf(look);
          try {
            final previous = await previousSinglePass(
              program: renderer.program,
              input: input,
              look: look,
              curve: curve,
              format: format,
            );
            final fast = await fastSinglePass(
              renderer: renderer,
              input: input,
              look: look,
              curve: curve,
              format: format,
            );
            expectSame(fast, previous);
            for (final side in [47, 4096]) {
              final tiled = await renderer.render(
                jpeg: input,
                look: look,
                curve: curve,
                format: format,
                seed: 97.125,
                tileSize: side,
              );
              expectSame(tiled, previous);
              if (source == 'transparent PNG') {
                final middle =
                    (tiled.height ~/ 2 * tiled.width + tiled.width ~/ 2) * 4;
                expect(tiled.rgba[middle + 3], 128);
              }
            }
          } finally {
            curve.dispose();
          }
        }
      });
    });
  }

  testWidgets(
    'tile consumer failure stops rendering and a fresh run succeeds',
    (tester) async {
      await tester.runAsync(() async {
        final renderer = FilmStillRenderer(
          await ui.FragmentProgram.fromAsset('shaders/film.frag'),
        );
        final look = resolve(book.recipes.first);
        final curve = await curveImageOf(look);
        try {
          final input = await chart();
          var calls = 0;
          await expectLater(
            renderer.renderTiles(
              jpeg: input,
              look: look,
              curve: curve,
              format: FrameFormat.r3x2,
              seed: 1,
              onBegin: (_, _) async {},
              onTile: (_) async {
                calls++;
                throw StateError('encoder failed');
              },
              tileSize: 47,
            ),
            throwsStateError,
          );
          expect(calls, 1);
          final output = await renderer.render(
            jpeg: input,
            look: look,
            curve: curve,
            format: FrameFormat.r3x2,
            seed: 1,
            tileSize: 47,
          );
          expect(output.rgba.length, output.width * output.height * 4);
        } finally {
          curve.dispose();
        }
      });
    },
  );
}
