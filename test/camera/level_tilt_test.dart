import 'dart:math' as math;

import 'package:diapo/camera/level_tilt.dart';
import 'package:flutter_test/flutter_test.dart';

const double _g = 9.80665;

void main() {
  group('TiltFilter', () {
    test('an upright phone is level', () {
      final tilt = TiltFilter().add(0, _g);
      expect(tilt?.degrees, 0);
      expect(tilt?.isLevel(), isTrue);
    });

    test('turning the phone clockwise is a positive tilt', () {
      // Gravity moves to -x when the phone turns clockwise.
      final tilt = TiltFilter(smoothing: 1).add(-_g * 0.0872, _g * 0.9962);
      expect(tilt!.degrees, closeTo(5, 0.1));
    });

    test('turning it anticlockwise is a negative tilt', () {
      final tilt = TiltFilter(smoothing: 1).add(_g * 0.0872, _g * 0.9962);
      expect(tilt!.degrees, closeTo(-5, 0.1));
    });

    // The gravity reading of a phone turned [degrees] clockwise.
    LevelTilt? turned(double degrees) {
      final a = degrees * math.pi / 180;
      return TiltFilter(smoothing: 1).add(-_g * math.sin(a), _g * math.cos(a));
    }

    test('keeps the true tilt up to 45 degrees and past it', () {
      expect(turned(45)!.degrees, closeTo(45, 0.1));
      expect(turned(-45)!.degrees, closeTo(-45, 0.1));
      // 46 degrees must not jump to -44: the screen is locked upright.
      expect(turned(46)!.degrees, closeTo(46, 0.1));
      expect(turned(-46)!.degrees, closeTo(-46, 0.1));
      expect(turned(60)!.degrees, closeTo(60, 0.1));
    });

    test('a phone on its side is level at 90 and -90', () {
      for (final side in [90.0, -90.0, 89.1, -89.1]) {
        final tilt = turned(side)!;
        expect(tilt.degrees.abs(), greaterThan(89), reason: '$side');
        expect(tilt.isLandscape(), isTrue, reason: '$side');
        expect(tilt.isLevel(), isTrue, reason: '$side');
      }
      expect(const LevelTilt(88.9).isLevel(), isFalse);
      expect(const LevelTilt(87).isLevel(), isFalse);
      expect(const LevelTilt(-87).isLevel(), isFalse);
      expect(const LevelTilt(87).offset(landscape: true), -3);
      expect(const LevelTilt(-87).offset(landscape: true), 3);
    });

    test('switches between portrait and landscape with a gap', () {
      expect(const LevelTilt(48).isLandscape(), isFalse);
      expect(const LevelTilt(52).isLandscape(), isTrue);
      expect(const LevelTilt(42).isLandscape(wasLandscape: true), isTrue);
      expect(const LevelTilt(38).isLandscape(wasLandscape: true), isFalse);
      expect(const LevelTilt(-48).isLandscape(), isFalse);
      expect(const LevelTilt(-52).isLandscape(), isTrue);
    });

    test('landscape keeps the hold once level', () {
      expect(const LevelTilt(88.7).isLevel(wasLevel: true), isTrue);
      expect(const LevelTilt(88.3).isLevel(wasLevel: true), isFalse);
      expect(const LevelTilt(91.4).isLevel(wasLevel: true), isTrue);
    });

    test('an upside down phone sees the same horizon', () {
      expect(turned(180)!.degrees.abs(), lessThan(0.1));
      expect(turned(170)!.degrees, closeTo(-10, 0.1));
      expect(turned(-170)!.degrees, closeTo(10, 0.1));
      expect(turned(181)!.degrees, closeTo(1, 0.1));
    });

    test('a phone lying flat has no horizon', () {
      expect(TiltFilter().add(0.3, 0.4), isNull);
    });

    test('smooths the readings: one jolt moves the line a fraction', () {
      final filter = TiltFilter(smoothing: 0.25)..add(0, _g);
      final jolt = filter.add(-_g * 0.5, _g * 0.866)!; // a 30 degree jolt
      expect(jolt.degrees, greaterThan(0));
      expect(jolt.degrees, lessThan(10));
    });

    test('a still phone reports the same tilt every time', () {
      final filter = TiltFilter();
      final first = filter.add(-0.4, 9.7);
      for (var i = 0; i < 20; i++) {
        filter.add(-0.4, 9.7);
      }
      expect(filter.add(-0.4, 9.7), first);
    });

    test('reset forgets the old readings', () {
      final filter = TiltFilter()..add(-3, 9);
      filter.reset();
      expect(filter.add(0, _g)!.degrees, 0);
    });
  });

  group('LevelTilt', () {
    test('is level within 1 degree', () {
      expect(const LevelTilt(0.9).isLevel(), isTrue);
      expect(const LevelTilt(-1).isLevel(), isTrue);
      expect(const LevelTilt(1.2).isLevel(), isFalse);
    });

    test('keeps the colour up to 1.5 degrees once it was level', () {
      expect(const LevelTilt(1.4).isLevel(wasLevel: true), isTrue);
      expect(const LevelTilt(1.6).isLevel(wasLevel: true), isFalse);
    });
  });
}
