import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:film_recipes/film_recipes.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import '../camera/frame_geometry.dart';
import '../render/look_adjust.dart';
import '../ui/theme/carrete_tokens.dart';
import '../ui/widgets/seven_segment.dart';
import 'cinema_bands.dart';
import 'date_stamp.dart';
import 'still_bounds.dart';
import 'white_frame.dart';

/// The pixels of a finished photo and how long each step took.
class FilmStill {
  const FilmStill({
    required this.rgba,
    required this.width,
    required this.height,
    required this.timings,
  });

  /// Straight RGBA pixels, upright.
  final Uint8List rgba;

  /// Width in pixels.
  final int width;

  /// Height in pixels.
  final int height;

  /// Milliseconds spent in decode, tile shading and tile readback.
  final Map<String, int> timings;
}

/// A readback tile in the final print, including any white border.
class StillTile {
  const StillTile(this.x, this.y, this.width, this.height, this.rgba);
  final int x;
  final int y;
  final int width;
  final int height;

  /// Straight (unpremultiplied) RGBA, as expected by Android Bitmap.setPixels.
  final Uint8List rgba;
}

/// The output geometry and timings, without a full-frame Dart pixel buffer.
class StillRenderInfo {
  const StillRenderInfo(this.width, this.height, this.timings);
  final int width;
  final int height;
  final Map<String, int> timings;
}

/// Renders a full target or bounded tiles from one decoded input texture. The shader
/// samples the entire input, including neighbours across output tile edges:
/// halation needs no overlap or crop margin, even at its maximum radius.
class FilmStillRenderer {
  FilmStillRenderer(this.program);
  final ui.FragmentProgram program;

  /// Each tiled readback is at most 4 MiB.
  static const tileSide = 1024;

  /// Convenience for references, assembling tiles into a full Dart buffer.
  /// Production uses [renderTiles] with a direct single-pass encoder instead.
  Future<FilmStill> render({
    required Uint8List jpeg,
    required ResolvedLook look,
    required ui.Image curve,
    required FrameFormat format,
    required double seed,
    double? fieldAspect,
    String? stampText,
    bool whiteFrame = false,
    bool cinemaBands = false,
    int tileSize = tileSide,
  }) async {
    late Uint8List rgba;
    late int width;
    final info = await renderTiles(
      jpeg: jpeg,
      look: look,
      curve: curve,
      format: format,
      seed: seed,
      fieldAspect: fieldAspect,
      stampText: stampText,
      whiteFrame: whiteFrame,
      cinemaBands: cinemaBands,
      tileSize: tileSize,
      onBegin: (w, h) async {
        width = w;
        rgba = Uint8List(w * h * 4);
      },
      onTile: (tile) async {
        for (var row = 0; row < tile.height; row++) {
          final start = ((tile.y + row) * width + tile.x) * 4;
          rgba.setRange(
            start,
            start + tile.width * 4,
            tile.rgba,
            row * tile.width * 4,
          );
        }
      },
    );
    return FilmStill(
      rgba: rgba,
      width: info.width,
      height: info.height,
      timings: info.timings,
    );
  }

  /// Calls [onBegin] once, then awaits each [onTile] before rendering the next.
  /// Consumers must release each tile after copying it into the encoder.
  ///
  /// When [onSinglePass] is supplied and the decoded source and final print
  /// fit [StillBounds.fitsSinglePass], delivers one complete premultiplied RGBA
  /// buffer instead, for the legacy Bitmap.copyPixelsFromBuffer encoder.
  /// Neither tile callback runs in that case. All GPU images are released
  /// before that callback; tiled Bitmap.setPixels needs straight RGBA instead.
  Future<StillRenderInfo> renderTiles({
    required Uint8List jpeg,
    required ResolvedLook look,
    required ui.Image curve,
    required FrameFormat format,
    required double seed,
    required Future<void> Function(int width, int height) onBegin,
    required Future<void> Function(StillTile tile) onTile,
    Future<void> Function(Uint8List rgba, int width, int height)? onSinglePass,
    double? fieldAspect,
    String? stampText,
    bool whiteFrame = false,
    bool cinemaBands = false,
    int tileSize = tileSide,
  }) async {
    if (tileSize <= 0) throw ArgumentError.value(tileSize, 'tileSize');
    final timings = <String, int>{};
    final sw = Stopwatch()..start();
    final photo = await decodeBounded(jpeg);
    timings['decode'] = sw.elapsedMilliseconds;
    final shader = program.fragmentShader();
    ui.Image? stamp;
    var released = false;
    void releaseImages() {
      if (released) return;
      released = true;
      stamp?.dispose();
      photo.dispose();
      shader.dispose();
    }

    try {
      final source = ui.Size(photo.width.toDouble(), photo.height.toDouble());
      final crop = frameCrop(format, source, fieldAspect: fieldAspect);
      final size = ui.Size(
        crop.width.roundToDouble(),
        crop.height.roundToDouble(),
      );
      final frameIt = whiteFrame && format == FrameFormat.r1x1;
      final bandIt = cinemaBands && format.supportsCinemaBands;
      final picture = bandIt
          ? CinemaBands.pictureRect(size)
          : ui.Offset.zero & size;
      final outer = frameIt ? WhiteFrame.outerSize(size) : size;
      final inner = frameIt
          ? WhiteFrame.photoRect(size)
          : ui.Offset.zero & size;
      final inputRect = ui.Rect.fromLTWH(
        crop.left / source.width,
        crop.top / source.height,
        crop.width / source.width,
        crop.height / source.height,
      );
      // Rasterize the small date patch once. Skia's blurred stroke clipping
      // can vary when the path is redrawn against each tile's clip rectangle.
      // Integer patch bounds keep its sampling and glow identical in all tiles.
      var stampOrigin = ui.Offset.zero;
      if (stampText != null) {
        final height = DateStamp.digitHeight(picture.size);
        final origin =
            picture.topLeft + DateStamp.origin(picture.size, stampText);
        final extent = SevenSegment.measure(stampText, height);
        final pad =
            (height *
                    (3 * CarreteSegment.glowBlur +
                        CarreteSegment.stroke * CarreteSegment.glowStroke / 2))
                .ceil() +
            2;
        final bounds = ui.Rect.fromLTRB(
          (origin.dx - pad).floorToDouble(),
          (origin.dy - pad).floorToDouble(),
          (origin.dx + extent.width + pad).ceilToDouble(),
          (origin.dy + height + pad).ceilToDouble(),
        ).intersect(picture);
        stampOrigin = bounds.topLeft;
        stamp = await _toImage(bounds.size, (canvas) {
          canvas.translate(-bounds.left, -bounds.top);
          canvas.translate(picture.left, picture.top);
          DateStamp.paint(canvas, picture.size, stampText);
        });
      }
      Future<ui.Image> renderTile(int x, int y, int w, int h) async {
        final tile = ui.Size(w.toDouble(), h.toDouble());
        final origin = ui.Offset(x.toDouble(), y.toDouble());
        applyResolvedLook(
          shader,
          look,
          filterMode: false,
          seed: seed,
          size: tile,
          frameSize: size,
          tileOrigin: origin - inner.topLeft,
          inputRect: inputRect,
        );
        shader.setImageSampler(0, photo);
        shader.setImageSampler(1, curve);
        return _toImage(tile, (canvas) {
          if (frameIt) {
            canvas.drawRect(
              ui.Offset.zero & tile,
              ui.Paint()..color = CarreteColors.whiteFrame,
            );
          }
          // Leave shader coordinates tile-local; the origin uniform maps
          // them into the whole photo (excluding the print's white border).
          canvas.drawRect(inner.shift(-origin), ui.Paint()..shader = shader);
          if (stamp != null) {
            canvas.drawImage(
              stamp,
              inner.topLeft + stampOrigin - origin,
              ui.Paint(),
            );
          }
          if (bandIt) {
            canvas.save();
            canvas.translate(inner.left - origin.dx, inner.top - origin.dy);
            CinemaBands.paint(canvas, size);
            canvas.restore();
          }
        });
      }

      if (onSinglePass != null &&
          StillBounds.fitsSinglePass(
            photo.width,
            photo.height,
            outer.width.toInt(),
            outer.height.toInt(),
          )) {
        sw.reset();
        final image = await renderTile(
          0,
          0,
          outer.width.toInt(),
          outer.height.toInt(),
        );
        timings['shade'] = sw.elapsedMilliseconds;
        releaseImages();
        final ByteData? bytes;
        try {
          sw.reset();
          bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
          timings['readback'] = sw.elapsedMilliseconds;
        } finally {
          image.dispose();
        }
        final rgba = bytes!.buffer.asUint8List(
          bytes.offsetInBytes,
          bytes.lengthInBytes,
        );
        await onSinglePass(rgba, outer.width.toInt(), outer.height.toInt());
        return StillRenderInfo(
          outer.width.toInt(),
          outer.height.toInt(),
          timings,
        );
      }

      await onBegin(outer.width.toInt(), outer.height.toInt());
      var shade = 0;
      var readback = 0;
      for (var y = 0; y < outer.height; y += tileSize) {
        for (var x = 0; x < outer.width; x += tileSize) {
          final w = math.min(tileSize, outer.width.toInt() - x);
          final h = math.min(tileSize, outer.height.toInt() - y);
          sw.reset();
          final image = await renderTile(x, y, w, h);
          shade += sw.elapsedMilliseconds;
          try {
            sw.reset();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.rawStraightRgba,
            );
            readback += sw.elapsedMilliseconds;
            await onTile(
              StillTile(
                x,
                y,
                w,
                h,
                bytes!.buffer.asUint8List(
                  bytes.offsetInBytes,
                  bytes.lengthInBytes,
                ),
              ),
            );
          } finally {
            image.dispose();
          }
        }
      }
      timings['shade'] = shade;
      timings['readback'] = readback;
      return StillRenderInfo(
        outer.width.toInt(),
        outer.height.toInt(),
        timings,
      );
    } finally {
      releaseImages();
    }
  }

  /// Decodes [jpeg], asking the codec for a smaller image when the original
  /// is over [StillBounds]. A 50 MP source fits; larger sources are scaled.
  @visibleForTesting
  static Future<ui.Image> decodeBounded(Uint8List jpeg) async {
    // The codec decodes lazily on the engine's IO thread from the
    // descriptor's data, so the buffer and the descriptor must outlive
    // getNextFrame(). Disposing them earlier crashed the engine with a null
    // dereference on io.worker (OnePlus 8T, 2026-11-13).
    if (jpeg.lengthInBytes > StillBounds.maxFileBytes) {
      throw StateError('The original is too large to be developed');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(jpeg);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      // Refused from the header, before any pixel is decoded.
      final limit = StillBounds.sourcePixelLimit(
        jpeg: StillBounds.isJpeg(jpeg),
      );
      if (descriptor.width * descriptor.height > limit) {
        throw StateError('The photo has too many pixels to be developed');
      }
      final (w, h) = StillBounds.bounded(descriptor.width, descriptor.height);
      codec = w == descriptor.width && h == descriptor.height
          ? await descriptor.instantiateCodec()
          : await descriptor.instantiateCodec(targetWidth: w, targetHeight: h);
      final frame = await codec.getNextFrame();
      if (!StillBounds.fits(frame.image.width, frame.image.height)) {
        frame.image.dispose();
        throw StateError('The decoder exceeded the still bounds');
      }
      return frame.image;
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }

  Future<ui.Image> _toImage(
    ui.Size size,
    void Function(ui.Canvas canvas) draw,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    draw(canvas);
    final picture = recorder.endRecording();
    try {
      return await picture.toImage(size.width.round(), size.height.round());
    } finally {
      picture.dispose();
    }
  }
}
