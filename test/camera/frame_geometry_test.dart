import 'dart:ui';

import 'package:carrete/camera/frame_geometry.dart';
import 'package:film_recipes/film_recipes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('frameCrop on a portrait still (3024 x 4032)', () {
    const still = Size(3024, 4032);

    test('3:2 crops the sides', () {
      expect(
        frameCrop(FrameFormat.r3x2, still),
        const Rect.fromLTWH(168, 0, 2688, 4032),
      );
    });

    test('4:3 keeps the whole still', () {
      expect(
        frameCrop(FrameFormat.r4x3, still),
        const Rect.fromLTWH(0, 0, 3024, 4032),
      );
    });

    test('1:1 crops the top and the bottom', () {
      expect(
        frameCrop(FrameFormat.r1x1, still),
        const Rect.fromLTWH(0, 504, 3024, 3024),
      );
    });

    test('16:9 crops the sides', () {
      expect(
        frameCrop(FrameFormat.r16x9, still),
        const Rect.fromLTWH(378, 0, 2268, 4032),
      );
    });
  });

  group('frameCrop on a landscape still (4032 x 3024)', () {
    const still = Size(4032, 3024);

    test('3:2 crops the top and the bottom', () {
      expect(
        frameCrop(FrameFormat.r3x2, still),
        const Rect.fromLTWH(0, 168, 4032, 2688),
      );
    });

    test('4:3 keeps the whole still', () {
      expect(
        frameCrop(FrameFormat.r4x3, still),
        const Rect.fromLTWH(0, 0, 4032, 3024),
      );
    });

    test('1:1 crops the sides', () {
      expect(
        frameCrop(FrameFormat.r1x1, still),
        const Rect.fromLTWH(504, 0, 3024, 3024),
      );
    });

    test('16:9 crops the top and the bottom', () {
      expect(
        frameCrop(FrameFormat.r16x9, still),
        const Rect.fromLTWH(0, 378, 4032, 2268),
      );
    });
  });

  group('frameCrop with odd sizes', () {
    test('always lands on whole pixels inside the still', () {
      for (final format in FrameFormat.values) {
        for (final size in const [
          Size(3001, 4001),
          Size(4001, 3001),
          Size(1999, 3499),
          Size(4000, 3000),
        ]) {
          final crop = frameCrop(format, size);
          expect(crop.left, crop.left.roundToDouble());
          expect(crop.top, crop.top.roundToDouble());
          expect(crop.width, crop.width.roundToDouble());
          expect(crop.height, crop.height.roundToDouble());
          expect(crop.left, greaterThanOrEqualTo(0));
          expect(crop.top, greaterThanOrEqualTo(0));
          expect(crop.right, lessThanOrEqualTo(size.width));
          expect(crop.bottom, lessThanOrEqualTo(size.height));
          // The aspect ratio matches the format within a pixel.
          final landscape = size.width > size.height;
          final wanted = landscape && format != FrameFormat.r1x1
              ? 1 / format.portraitAspect
              : format.portraitAspect;
          expect(crop.width / crop.height, closeTo(wanted, 0.002));
        }
      }
    });
  });

  group('frameCrop with the field of view of the preview', () {
    test('a 9:16 preview narrows a 3:4 still before the format', () {
      // The preview only shows the middle 2268 x 4032 of the still; the 3:4
      // frame is the biggest one of that field, 2268 x 3024.
      expect(
        frameCrop(
          FrameFormat.r4x3,
          const Size(3024, 4032),
          fieldAspect: 9 / 16,
        ),
        const Rect.fromLTWH(378, 504, 2268, 3024),
      );
    });

    test('a preview with the same aspect ratio changes nothing', () {
      expect(
        frameCrop(FrameFormat.r3x2, const Size(3024, 4032), fieldAspect: 3 / 4),
        frameCrop(FrameFormat.r3x2, const Size(3024, 4032)),
      );
    });

    test('works for a landscape still too', () {
      final crop = frameCrop(
        FrameFormat.r16x9,
        const Size(4032, 3024),
        fieldAspect: 3 / 4,
      );
      expect(crop.width / crop.height, closeTo(16 / 9, 0.002));
    });
  });

  group('FrameFormatGeometry', () {
    test('portrait aspect ratios', () {
      expect(FrameFormat.r3x2.portraitAspect, closeTo(2 / 3, 1e-9));
      expect(FrameFormat.r4x3.portraitAspect, closeTo(3 / 4, 1e-9));
      expect(FrameFormat.r1x1.portraitAspect, 1);
      expect(FrameFormat.r16x9.portraitAspect, closeTo(9 / 16, 1e-9));
    });

    test('the format key cycles through the four formats and back', () {
      var format = FrameFormat.r3x2;
      final seen = <String>[];
      for (var i = 0; i < 5; i++) {
        seen.add(format.label);
        format = format.next;
      }
      expect(seen, ['3:2', '4:3', '1:1', '16:9', '3:2']);
    });
  });

  group('placeFrame', () {
    test('a frame that fits the band is as wide as the screen and centred', () {
      final frame = placeFrame(
        screen: const Size(400, 900),
        aspect: 2 / 3,
        topReserved: 100,
        bottomReserved: 200,
      );
      expect(frame.width, 400);
      expect(frame.height, closeTo(600, 1e-9));
      // The band is 100 to 700 and the frame fills it.
      expect(frame.top, closeTo(100, 1e-9));
    });

    test('a frame that is shorter than the band is centred in it', () {
      final frame = placeFrame(
        screen: const Size(400, 900),
        aspect: 1,
        topReserved: 100,
        bottomReserved: 200,
      );
      expect(frame.size, const Size(400, 400));
      expect(frame.center.dy, closeTo(400, 1e-9));
    });

    test('a frame taller than the band shrinks to the band, centred', () {
      final frame = placeFrame(
        screen: const Size(400, 900),
        aspect: 9 / 16,
        topReserved: 100,
        bottomReserved: 280,
      );
      // The band is 100 to 620, 520 tall.
      expect(frame.top, closeTo(100, 1e-9));
      expect(frame.bottom, closeTo(620, 1e-9));
      expect(frame.width, closeTo(520 * 9 / 16, 1e-9));
      expect(frame.center.dx, closeTo(200, 1e-9));
    });

    test('a band without height gives an empty frame', () {
      final frame = placeFrame(
        screen: const Size(400, 300),
        aspect: 2 / 3,
        topReserved: 150,
        bottomReserved: 200,
      );
      expect(frame.isEmpty, isTrue);
      expect(frame.width, 0);
    });

    // The OnePlus 10T is 1080 x 2412 px at 2.625: about 411 x 919 dp, with a
    // status bar of 32 dp. The reserved bands are those of the camera screen:
    // the status bar and 82 for the top bar; the carousel (90), 8, the
    // shutter row (88) and the gesture inset (12) for the bottom.
    for (final device in <(String, Size, double)>[
      ('OnePlus 10T (411 x 915 dp)', const Size(411, 915), 32),
      ('small phone (360 x 640 dp)', const Size(360, 640), 24),
      ('very short screen (320 x 480 dp)', const Size(320, 480), 24),
    ]) {
      final (name, screen, statusBar) = device;
      final top = statusBar + 82;
      const bottom = 90 + 8 + 88 + 12.0;
      for (final format in FrameFormat.values) {
        test('the whole ${format.label} frame is visible on $name', () {
          final frame = placeFrame(
            screen: screen,
            aspect: format.portraitAspect,
            topReserved: top,
            bottomReserved: bottom,
          );
          expect(frame.top, greaterThanOrEqualTo(top - 1e-9));
          expect(
            frame.bottom,
            lessThanOrEqualTo(screen.height - bottom + 1e-9),
          );
          expect(frame.left, greaterThanOrEqualTo(0));
          expect(frame.right, lessThanOrEqualTo(screen.width + 1e-9));
          expect(
            frame.width / frame.height,
            closeTo(format.portraitAspect, 1e-9),
          );
          expect(frame.center.dx, closeTo(screen.width / 2, 1e-9));
          // It is as big as the band and the width allow.
          final band = screen.height - top - bottom;
          final biggest =
              frame.width >= screen.width - 1e-9 || frame.height >= band - 1e-9;
          expect(biggest, isTrue);
        });
      }
    }
  });

  group('framePointToPreview', () {
    test('the centre of the frame is the centre of the preview', () {
      final p = framePointToPreview(
        const Offset(0.5, 0.5),
        const Size(400, 400),
        const Size(1080, 1920),
      );
      expect(p.dx, closeTo(0.5, 1e-9));
      expect(p.dy, closeTo(0.5, 1e-9));
    });

    test('a taller preview is cropped at the top and bottom', () {
      // Frame 1:1, preview 9:16: only 56 % of the height is visible.
      final top = framePointToPreview(
        Offset.zero,
        const Size(400, 400),
        const Size(1080, 1920),
      );
      expect(top.dx, 0);
      expect(top.dy, closeTo((1 - 0.5625) / 2, 1e-9));
    });

    test('a wider preview is cropped at the sides', () {
      final left = framePointToPreview(
        Offset.zero,
        const Size(300, 600),
        const Size(1080, 1080),
      );
      expect(left.dy, 0);
      expect(left.dx, closeTo((1 - 0.5) / 2, 1e-9));
    });
  });
}
