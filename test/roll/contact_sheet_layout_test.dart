import 'dart:ui';

import 'package:diapo/roll/contact_sheet_layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether [inner] lies wholly inside [outer].
bool _contains(Rect outer, Rect inner) =>
    inner.left >= outer.left &&
    inner.top >= outer.top &&
    inner.right <= outer.right &&
    inner.bottom <= outer.bottom;

void main() {
  group('sizes by roll length', () {
    // 1200 px wide: strips of 1152, 20 px of film at each side and 12 px
    // between frames leave 269 px per cell, 3:2.
    const cases = <(int frames, int rows, int height)>[
      (12, 3, 955),
      (24, 6, 1774),
      (27, 7, 2047),
      (36, 9, 2593),
    ];
    for (final (frames, rows, height) in cases) {
      test('$frames frames: $rows rows of 4, ${height}px tall', () {
        final layout = ContactSheetLayout(frames);
        expect(layout.width, 1200);
        expect(layout.columns, 4);
        expect(layout.rows, rows);
        expect(layout.height, height);
        expect(layout.cellSize, const Size(269, 179));
      });
    }

    test('36 frames fit a tall phone screen: about 2.2 times as tall', () {
      final layout = ContactSheetLayout(36);
      expect(layout.height / layout.width, lessThan(2.4));
      expect(layout.height / layout.width, greaterThan(2.0));
    });

    test('the width scales every measure', () {
      final big = ContactSheetLayout(36, width: 1440);
      expect(big.width, 1440);
      expect(big.cellSize.width, greaterThan(320));
      expect(big.height / big.width, closeTo(2593 / 1200, 0.05));
      final small = ContactSheetLayout(36, width: 600);
      expect(small.height / small.width, closeTo(2593 / 1200, 0.05));
    });

    test('rejects an empty roll and nonsense sizes', () {
      expect(() => ContactSheetLayout(0), throwsArgumentError);
      expect(() => ContactSheetLayout(12, columns: 0), throwsArgumentError);
      expect(() => ContactSheetLayout(12, width: 100), throwsArgumentError);
    });
  });

  group('cells', () {
    for (final frames in [12, 24, 27, 36]) {
      test('$frames frames: equal cells inside their strip, none overlap', () {
        final layout = ContactSheetLayout(frames);
        final image = Rect.fromLTWH(
          0,
          0,
          layout.width.toDouble(),
          layout.height.toDouble(),
        );
        final cells = [for (var i = 0; i < frames; i++) layout.cellRect(i)];
        for (var i = 0; i < frames; i++) {
          final cell = cells[i];
          expect(cell.size, layout.cellSize);
          expect(_contains(layout.stripRect(layout.rowOf(i)), cell), isTrue);
          expect(_contains(image, layout.numberRect(i)), isTrue);
          expect(
            _contains(layout.stripRect(layout.rowOf(i)), layout.numberRect(i)),
            isTrue,
          );
          for (var j = i + 1; j < frames; j++) {
            expect(cell.overlaps(cells[j]), isFalse, reason: '$i and $j');
            expect(
              cell.overlaps(layout.numberRect(j)),
              isFalse,
              reason: 'cell $i and number $j',
            );
          }
        }
      });
    }

    test('the last row may be partial (27 frames: 3 in the seventh strip)', () {
      final layout = ContactSheetLayout(27);
      expect(layout.rowOf(26), 6);
      expect(layout.columnOf(26), 2);
      expect(layout.columnOf(24), 0);
      // The strip is still whole: the empty room is film, not missing sheet.
      expect(layout.stripRect(6).width, layout.stripRect(0).width);
      expect(layout.stripRect(6).bottom, lessThan(layout.height));
    });

    test('the frames are centred in the strip and the rows are in order', () {
      final layout = ContactSheetLayout(36);
      final first = layout.cellRect(0);
      final last = layout.cellRect(3);
      final strip = layout.stripRect(0);
      expect(first.left - strip.left, closeTo(strip.right - last.right, 1));
      expect(layout.cellRect(4).top, greaterThan(layout.cellRect(0).bottom));
      expect(layout.leaderRect.bottom, lessThan(strip.top));
    });

    test('indexes outside the roll are refused', () {
      final layout = ContactSheetLayout(12);
      expect(() => layout.cellRect(12), throwsRangeError);
      expect(() => layout.cellRect(-1), throwsRangeError);
      expect(() => layout.stripRect(3), throwsRangeError);
    });
  });

  group('fitting photos of every shape', () {
    final layout = ContactSheetLayout(24);
    final cell = layout.cellRect(5);
    const shapes = <String, (int, int)>{
      '3:2': (6000, 4000),
      '2:3': (4000, 6000),
      '4:3': (4000, 3000),
      '3:4': (3000, 4000),
      '1:1': (3000, 3000),
      '16:9': (3840, 2160),
      '9:16': (2160, 3840),
      'panorama 3:1': (6000, 2000),
      'thumbnail 320x213': (320, 213),
    };
    shapes.forEach((name, size) {
      test('$name sits whole and centred in the cell, never cropped', () {
        final (w, h) = size;
        final rect = layout.photoRect(5, w, h);
        expect(_contains(cell, rect), isTrue);
        // It touches the cell on one axis, at least.
        final touchesWidth = (rect.width - cell.width).abs() < 1;
        final touchesHeight = (rect.height - cell.height).abs() < 1;
        expect(touchesWidth || touchesHeight, isTrue);
        // Its shape is the photo's (within the rounding of whole pixels).
        expect(rect.width / rect.height, closeTo(w / h, 0.05 * w / h + 0.03));
        // Centred on both axes (to a pixel).
        expect(rect.center.dx, closeTo(cell.center.dx, 1));
        expect(rect.center.dy, closeTo(cell.center.dy, 1));
      });
    });

    test('a 3:2 photo fills its cell', () {
      final rect = layout.photoRect(5, 6000, 4000);
      expect((rect.width - cell.width).abs(), lessThanOrEqualTo(1));
      expect((rect.height - cell.height).abs(), lessThanOrEqualTo(1));
    });

    test('a portrait photo is letterboxed at the sides', () {
      final rect = layout.photoRect(5, 2160, 3840);
      expect(rect.height, cell.height);
      expect(rect.width, lessThan(cell.width * 0.6));
      expect(rect.left, greaterThan(cell.left + 40));
    });

    test('an unreadable size gives the whole cell', () {
      expect(layout.photoRect(5, 0, 0), cell);
    });
  });

  group('missing frames', () {
    test('keep their cell and number line like any other frame', () {
      final layout = ContactSheetLayout(36);
      // Frame 7 of the roll was deleted: its place is still there.
      expect(layout.cellRect(6).size, layout.cellSize);
      expect(layout.numberRect(6).top, layout.cellRect(6).bottom);
    });
  });
}
