/// Tone curves: monotone cubic interpolation and the lookup tables the shader
/// samples.
///
/// The interpolation is the Fritsch-Carlson monotone cubic Hermite spline: it
/// passes through every control point and never overshoots between them, so a
/// monotone set of points always gives a monotone curve.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'recipe.dart';

/// The number of entries of a tone curve lookup table.
const int kCurveLutSize = 256;

/// Builds the lookup table of the tone curve [points].
///
/// Entry `i` holds the value of the curve at `i / 255`.
Float64List buildLut(List<CurvePoint> points) {
  final curve = _MonotoneCurve(points);
  final lut = Float64List(kCurveLutSize);
  for (var i = 0; i < kCurveLutSize; i++) {
    lut[i] = curve.evaluate(i / (kCurveLutSize - 1));
  }
  return lut;
}

/// The value of the tone curve [points] at [x].
///
/// The curve passes exactly through its control points.
double curveValueAt(List<CurvePoint> points, double x) =>
    _MonotoneCurve(points).evaluate(x);

/// Combines a master lookup table with a channel lookup table.
///
/// The result is the channel curve applied to the values of the master curve:
/// `out[i] = channel(master(i / 255))`.
Float64List combineLuts(Float64List master, Float64List channel) {
  final out = Float64List(kCurveLutSize);
  for (var i = 0; i < kCurveLutSize; i++) {
    out[i] = sampleLut(channel, master[i]);
  }
  return out;
}

/// Samples a lookup table the way a linear sampler does.
///
/// The value is mapped to the texel centres of the table and interpolated
/// between the two nearest entries.
double sampleLut(Float64List lut, double value) {
  final t = value.clamp(0.0, 1.0) * (lut.length - 1);
  var i0 = t.floor();
  if (i0 < 0) {
    i0 = 0;
  }
  if (i0 > lut.length - 1) {
    i0 = lut.length - 1;
  }
  final i1 = i0 + 1 < lut.length ? i0 + 1 : i0;
  final alpha = t - i0;
  return lut[i0] + (lut[i1] - lut[i0]) * alpha;
}

/// The 256x1 RGBA bytes of three lookup tables.
///
/// The app uploads this as the `uCurve` texture of the shader.
Uint8List curveRgbaFromLuts(
  Float64List red,
  Float64List green,
  Float64List blue,
) {
  final out = Uint8List(kCurveLutSize * 4);
  for (var i = 0; i < kCurveLutSize; i++) {
    out[i * 4] = _toByte(red[i]);
    out[i * 4 + 1] = _toByte(green[i]);
    out[i * 4 + 2] = _toByte(blue[i]);
    out[i * 4 + 3] = 255;
  }
  return out;
}

int _toByte(double value) => (value.clamp(0.0, 1.0) * 255).round();

/// A monotone cubic Hermite spline through a set of control points.
class _MonotoneCurve {
  _MonotoneCurve(this.points)
    : xs = Float64List(points.length),
      ys = Float64List(points.length),
      tangents = Float64List(points.length) {
    for (var i = 0; i < points.length; i++) {
      xs[i] = points[i].x;
      ys[i] = points[i].y;
    }
    _computeTangents();
  }

  /// The control points of the curve.
  final List<CurvePoint> points;

  final Float64List xs;
  final Float64List ys;
  final Float64List tangents;

  void _computeTangents() {
    final n = xs.length;
    if (n < 2) {
      return;
    }

    final slopes = Float64List(n - 1);
    for (var i = 0; i < n - 1; i++) {
      slopes[i] = (ys[i + 1] - ys[i]) / (xs[i + 1] - xs[i]);
    }

    // Initial tangents: the slope of the segment at the ends and the mean
    // of the two neighbouring slopes inside.
    tangents[0] = slopes[0];
    tangents[n - 1] = slopes[n - 2];
    for (var i = 1; i < n - 1; i++) {
      tangents[i] = (slopes[i - 1] + slopes[i]) / 2;
    }

    // Fritsch-Carlson: limit the tangents so that the curve never overshoots
    // the data and stays monotone.
    for (var i = 0; i < n - 1; i++) {
      if (slopes[i] == 0) {
        tangents[i] = 0;
        tangents[i + 1] = 0;
        continue;
      }
      final alpha = tangents[i] / slopes[i];
      final beta = tangents[i + 1] / slopes[i];
      final magnitude = alpha * alpha + beta * beta;
      if (magnitude > 9) {
        final tau = 3 / math.sqrt(magnitude);
        tangents[i] = tau * alpha * slopes[i];
        tangents[i + 1] = tau * beta * slopes[i];
      }
    }
  }

  /// The value of the curve at [x].
  double evaluate(double x) {
    final n = xs.length;
    if (n == 0) {
      return x;
    }
    if (n == 1) {
      return ys[0];
    }
    if (x <= xs[0]) {
      return ys[0];
    }
    if (x >= xs[n - 1]) {
      return ys[n - 1];
    }

    var i = 0;
    while (i < n - 2 && x > xs[i + 1]) {
      i++;
    }

    final h = xs[i + 1] - xs[i];
    final t = (x - xs[i]) / h;
    final t2 = t * t;
    final t3 = t2 * t;
    final h00 = 2 * t3 - 3 * t2 + 1;
    final h10 = t3 - 2 * t2 + t;
    final h01 = -2 * t3 + 3 * t2;
    final h11 = t3 - t2;
    return h00 * ys[i] +
        h10 * h * tangents[i] +
        h01 * ys[i + 1] +
        h11 * h * tangents[i + 1];
  }
}
