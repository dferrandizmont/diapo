import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// How far the phone is from level, in degrees: positive when it is turned
/// clockwise as seen from the front, as the camera shows it.
@immutable
class LevelTilt {
  const LevelTilt(this.degrees);

  /// The tilt of the horizon of the camera, in degrees, from -90 to 90. The
  /// screen is locked upright, so a phone on its side (landscape) reads about
  /// +-90, which is level too (see [isLandscape] and [offset]); a phone upside
  /// down reads as if upright, since the horizon is still a horizontal line.
  final double degrees;

  /// Within about 1 degree: the line turns to the accent colour.
  static const double levelWithin = 1;

  /// Once level, it takes this much to count as tilted again, so a hand that
  /// trembles around 1 degree does not make the colour flicker.
  static const double tiltedBeyond = 1.5;

  /// Past this the phone counts as held on its side (landscape).
  static const double landscapeBeyond = 50;

  /// Once in landscape, it takes less than this to count as upright again, so
  /// the ticks do not flip back and forth around 45 degrees.
  static const double portraitBelow = 40;

  /// Whether the phone is held on its side, given whether the last reading
  /// was: the nearest quarter turn, with a gap between 40 and 50 degrees.
  bool isLandscape({bool wasLandscape = false}) =>
      degrees.abs() > (wasLandscape ? portraitBelow : landscapeBeyond);

  /// How far the phone is from level, in degrees: from 0 when upright and
  /// from +-90 when on its side (+90 and -90 are the same horizon). [landscape]
  /// is what [isLandscape] said.
  double offset({bool landscape = false}) =>
      landscape ? degrees - 90 * degrees.sign : degrees;

  /// Whether the tilt counts as level, given whether the last one did and
  /// whether the phone was in landscape.
  bool isLevel({bool wasLevel = false, bool wasLandscape = false}) =>
      offset(landscape: isLandscape(wasLandscape: wasLandscape)).abs() <=
      (wasLevel ? tiltedBeyond : levelWithin);

  @override
  bool operator ==(Object other) =>
      other is LevelTilt && other.degrees == degrees;

  @override
  int get hashCode => degrees.hashCode;

  @override
  String toString() => 'LevelTilt($degrees)';
}

/// Turns the readings of the accelerometer into [LevelTilt]s.
///
/// The readings are smoothed with an exponential filter on the axes of the
/// screen (not on the angle, which jumps at +-180), the result is rounded to a
/// tenth of a degree so a still phone reports nothing new, and a phone lying
/// flat gives null: with the camera pointing up or down there is no horizon.
class TiltFilter {
  TiltFilter({this.smoothing = 0.25});

  /// How much of each new reading enters the average: 1 is no smoothing.
  final double smoothing;

  /// Below this much of gravity on the screen plane the phone is flat.
  static const double _flatBelow = 0.35 * 9.80665;

  double? _x;
  double? _y;

  /// Forgets the average (after a pause the old readings are stale).
  void reset() {
    _x = null;
    _y = null;
  }

  /// The tilt after the reading [x], [y] (m/s2 along the axes of the screen,
  /// as the accelerometer reports them), or null when the phone is flat.
  LevelTilt? add(double x, double y) {
    final px = _x;
    final py = _y;
    final fx = px == null ? x : px + smoothing * (x - px);
    final fy = py == null ? y : py + smoothing * (y - py);
    _x = fx;
    _y = fy;
    if (math.sqrt(fx * fx + fy * fy) < _flatBelow) return null;
    // Upright, gravity reads +y; turning the phone clockwise moves it to -x.
    var degrees = math.atan2(-fx, fy) * 180 / math.pi;
    // The horizon has no top or bottom: a half turn is the same line.
    degrees -= 180 * (degrees / 180).round();
    final tenth = (degrees * 10).round() / 10;
    return LevelTilt(tenth == 0 ? 0 : tenth);
  }
}

/// Where the tilt of the phone comes from.
abstract interface class LevelSource {
  /// The tilts, a few times per second, while someone listens. A null is a
  /// phone that has no horizon to show (lying flat).
  Stream<LevelTilt?> get tilts;
}

/// The accelerometer of the phone, through `sensors_plus`.
///
/// The stream asks for the UI rate (about 15 readings per second), which is
/// plenty for a line on the screen and costs the viewfinder nothing.
class AccelerometerLevelSource implements LevelSource {
  const AccelerometerLevelSource();

  @override
  Stream<LevelTilt?> get tilts {
    final filter = TiltFilter();
    return accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval)
        .map((event) => filter.add(event.x, event.y));
  }
}

/// The source of the level. The tests override it.
final levelSourceProvider = Provider<LevelSource>(
  (ref) => const AccelerometerLevelSource(),
);
