import 'dart:ui';

import 'package:diapo/capture/date_stamp.dart';
import 'package:diapo/core/settings/app_settings.dart';
import 'package:diapo/ui/widgets/seven_segment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DateStamp.format', () {
    test('year first, 20th century', () {
      expect(
        DateStamp.format(DateTime(1998, 7, 14), DateStampStyle.yearFirst),
        "'98 7 14",
      );
    });

    test('day first, 20th century', () {
      expect(
        DateStamp.format(DateTime(1998, 7, 14), DateStampStyle.dayFirst),
        "14 7 '98",
      );
    });

    test('year first, 21st century keeps the leading zero of the year', () {
      expect(
        DateStamp.format(DateTime(2007, 1, 5), DateStampStyle.yearFirst),
        "'07 1 5",
      );
      expect(
        DateStamp.format(DateTime(2026, 11, 9), DateStampStyle.yearFirst),
        "'26 11 9",
      );
    });

    test('day first, 21st century', () {
      expect(
        DateStamp.format(DateTime(2007, 1, 5), DateStampStyle.dayFirst),
        "5 1 '07",
      );
      expect(
        DateStamp.format(DateTime(2000, 12, 31), DateStampStyle.dayFirst),
        "31 12 '00",
      );
    });
  });

  group('DateStamp layout', () {
    const text = "'98 7 14";

    test('the size and the position are relative to the short side', () {
      const small = Size(412, 618);
      const big = Size(2688, 4032);
      final smallScale = small.shortestSide;
      final bigScale = big.shortestSide;

      expect(
        DateStamp.digitHeight(small) / smallScale,
        closeTo(DateStamp.digitHeight(big) / bigScale, 1e-9),
      );

      final a = DateStamp.origin(small, text);
      final b = DateStamp.origin(big, text);
      // Same distance to the right and bottom edges, in short sides.
      expect(
        (small.width - a.dx) / smallScale,
        closeTo((big.width - b.dx) / bigScale, 1e-9),
      );
      expect(
        (small.height - a.dy) / smallScale,
        closeTo((big.height - b.dy) / bigScale, 1e-9),
      );
    });

    test('the text ends inside the frame, at the bottom right', () {
      const frame = Size(1000, 1500);
      final origin = DateStamp.origin(frame, text);
      final size = SevenSegment.measure(text, DateStamp.digitHeight(frame));
      expect(origin.dx + size.width, lessThan(frame.width));
      expect(origin.dy + size.height, lessThan(frame.height));
      expect(origin.dx, greaterThan(frame.width / 2));
      expect(origin.dy, greaterThan(frame.height / 2));
    });
  });

  group('SevenSegment.measure', () {
    test('grows with the number of digits and with the height', () {
      final one = SevenSegment.measure('1', 20);
      final two = SevenSegment.measure('12', 20);
      final tall = SevenSegment.measure('12', 40);
      expect(two.width, greaterThan(one.width));
      expect(tall.width, closeTo(two.width * 2, 1e-9));
      expect(tall.height, 40);
    });
  });
}
