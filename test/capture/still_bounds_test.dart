import 'package:carrete/capture/still_bounds.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StillBounds', () {
    test(
      'single pass keeps the old budget for both source and final print',
      () {
        expect(StillBounds.fitsSinglePass(4000, 3000, 3008, 3008), isTrue);
        expect(StillBounds.fitsSinglePass(6000, 4000, 6000, 4000), isTrue);
        expect(StillBounds.fitsSinglePass(8192, 1000, 8192, 1000), isTrue);
        expect(StillBounds.fitsSinglePass(6001, 4000, 4000, 4000), isFalse);
        expect(StillBounds.fitsSinglePass(4000, 4000, 5000, 5000), isFalse);
        expect(StillBounds.fitsSinglePass(8193, 1000, 8192, 1000), isFalse);
        expect(StillBounds.fitsSinglePass(8192, 1000, 8193, 1000), isFalse);
        expect(StillBounds.fitsSinglePass(8160, 6120, 6120, 6120), isFalse);
      },
    );

    test('a 12 MP still is untouched', () {
      expect(StillBounds.scaleFor(4000, 3000), 1);
      expect(StillBounds.bounded(4000, 3000), (4000, 3000));
      expect(StillBounds.fits(4000, 3000), isTrue);
    });

    test('exactly 50 MP and 8192 px fit', () {
      expect(StillBounds.bounded(8000, 6250), (8000, 6250));
      expect(StillBounds.bounded(8192, 2000), (8192, 2000));
    });

    test('a Pixel 50 MP still keeps every pixel', () {
      expect(StillBounds.bounded(8160, 6120), (8160, 6120));
      expect(StillBounds.fits(8160, 6120), isTrue);
    });

    test('the area guard applies even below the texture side limit', () {
      final (w, h) = StillBounds.bounded(8192, 8192);
      expect(w * h, lessThanOrEqualTo(50000000));
      expect(w * h, greaterThan(49980000));
    });

    test('a 200 MP still comes down to the same bound', () {
      final (w, h) = StillBounds.bounded(16320, 12240);
      expect(w * h, lessThanOrEqualTo(StillBounds.maxPixels));
      expect(w, lessThanOrEqualTo(StillBounds.maxSide));
      expect(h, lessThanOrEqualTo(StillBounds.maxSide));
    });

    test('a long panorama is bounded by the side, not the area', () {
      // 12000 x 1500 is 18 MP, under the area bound, but too wide.
      final (w, h) = StillBounds.bounded(12000, 1500);
      expect(w, StillBounds.maxSide);
      expect(h, 1024);
      expect(StillBounds.fits(12000, 1500), isFalse);
    });

    test('portrait and landscape are bounded alike', () {
      final (lw, lh) = StillBounds.bounded(9000, 6000);
      final (pw, ph) = StillBounds.bounded(6000, 9000);
      expect((pw, ph), (lh, lw));
    });

    test('import file and header guards stay independent of output bounds', () {
      expect(StillBounds.maxFileBytes, 100 * 1024 * 1024);
      expect(StillBounds.sourcePixelLimit(jpeg: true), 200000000);
      expect(StillBounds.sourcePixelLimit(jpeg: false), 100000000);
    });

    test('custom bounds', () {
      expect(StillBounds.bounded(400, 300, maxPixels: 30000), (200, 150));
      expect(StillBounds.bounded(400, 300, maxSide: 100), (100, 75));
      expect(
        StillBounds.scaleFor(400, 300, maxPixels: 30000),
        closeTo(0.5, 1e-9),
      );
    });

    test('degenerate sizes never go to zero', () {
      expect(StillBounds.bounded(0, 0), (0, 0));
      expect(StillBounds.bounded(1, 100000), (1, 8192));
      expect(StillBounds.scaleFor(-1, 5), 1);
    });
  });
}
