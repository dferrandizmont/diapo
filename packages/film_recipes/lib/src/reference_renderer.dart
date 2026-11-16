/// A CPU port of `shaders/film.frag` in paint mode.
///
/// The port follows the shader block by block and every block keeps a comment
/// pointing at the code it mirrors, so the two can be compared at a glance.
/// It is used by the golden tests to notice any change in the look of a
/// recipe.
///
/// The shader runs on 32 bit floats and this port on doubles, so the grain
/// may differ in the last bits. The golden test allows a difference of one
/// level per channel for that reason.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'resolve.dart';
import 'uniforms.dart';

/// Renders [look] over the [width] x [height] RGBA image [rgba].
///
/// The image is sampled the way the GPU samples a texture: bilinear with the
/// edges clamped. The result is the rendered image as RGBA bytes.
Uint8List renderReference(
  Uint8List rgba,
  int width,
  int height,
  ResolvedLook look, {
  double seed = 0.37,
}) {
  final out = Uint8List(width * height * 4);
  final curve = curveRgba(look);
  final shortSide = math.min(width, height).toDouble();
  // The frame coordinates with the short side as 1, centred.
  final aspectX = width / shortSide;
  final aspectY = height / shortSide;

  final matrix = look.matrix;
  final shadowTint = look.shadowTint;
  final highlightTint = look.highlightTint;
  final halationColor = look.halationColor;
  final leakColor = look.leakColor;

  final sample = Float64List(4);
  final sampleHalf = Float64List(4);

  for (var y = 0; y < height; y++) {
    final v = (y + 0.5) / height;
    final frameY = (v - 0.5) * aspectY;
    for (var x = 0; x < width; x++) {
      final u = (x + 0.5) / width;
      final frameX = (u - 0.5) * aspectX;

      // vec4 src = texture(uInput, sampleUv);
      _sampleInput(rgba, width, height, u, v, sample);
      final originalR = sample[0];
      final originalG = sample[1];
      final originalB = sample[2];
      final originalAlpha = sample[3];

      // Exposure in approximately linear light.
      final gain = _exp2(look.exposure);
      final sourceR = _pow(math.max(originalR, 0), 2.2) * gain;
      final sourceG = _pow(math.max(originalG, 0), 2.2) * gain;
      final sourceB = _pow(math.max(originalB, 0), 2.2) * gain;

      // Colour matrix.
      var red = matrix[0] * sourceR + matrix[1] * sourceG + matrix[2] * sourceB;
      var green =
          matrix[3] * sourceR + matrix[4] * sourceG + matrix[5] * sourceB;
      var blue =
          matrix[6] * sourceR + matrix[7] * sourceG + matrix[8] * sourceB;

      red = _pow(math.max(red, 0), 1 / 2.2);
      green = _pow(math.max(green, 0), 1 / 2.2);
      blue = _pow(math.max(blue, 0), 1 / 2.2);

      // Saturation around the luma.
      final luma = _luma(red, green, blue);
      red = luma + (red - luma) * look.saturation;
      green = luma + (green - luma) * look.saturation;
      blue = luma + (blue - luma) * look.saturation;

      // Split toning.
      final shadowWeight = 1 - _smoothstep(0, 0.5, luma);
      final highlightWeight = _smoothstep(0.5, 1, luma);
      red += shadowTint[0] * shadowWeight + highlightTint[0] * highlightWeight;
      green +=
          shadowTint[1] * shadowWeight + highlightTint[1] * highlightWeight;
      blue += shadowTint[2] * shadowWeight + highlightTint[2] * highlightWeight;

      // Tone curve.
      red = _sampleCurve(curve, red);
      green = _sampleCurve(curve, green);
      blue = _sampleCurve(curve, blue);

      // Halation: the glow of the highlights bleeding into the red layer.
      if (look.halationAmount > 0.001) {
        final radius = look.halationRadius * shortSide;
        final texelX = radius / width;
        final texelY = radius / height;
        var glow = 0.0;
        for (var i = 0; i < 8; i++) {
          final angle = i * 0.785398;
          final dirX = math.cos(angle);
          final dirY = math.sin(angle);
          _sampleInput(
            rgba,
            width,
            height,
            u + dirX * texelX,
            v + dirY * texelY,
            sample,
          );
          _sampleInput(
            rgba,
            width,
            height,
            u + dirX * texelX * 0.5,
            v + dirY * texelY * 0.5,
            sampleHalf,
          );
          glow += math.max(
            _luma(sample[0], sample[1], sample[2]) - look.halationThreshold,
            0,
          );
          glow += math.max(
            _luma(sampleHalf[0], sampleHalf[1], sampleHalf[2]) -
                look.halationThreshold,
            0,
          );
        }
        glow /= 16 * math.max(1 - look.halationThreshold, 0.001);
        final strength = glow * look.halationAmount;
        red = 1 - (1 - red) * (1 - halationColor[0] * strength);
        green = 1 - (1 - green) * (1 - halationColor[1] * strength);
        blue = 1 - (1 - blue) * (1 - halationColor[2] * strength);
      }

      // Light leak: a soft additive blob.
      if (look.leakAmount > 0.001) {
        final leakX = (look.leakPosition[0] - 0.5) * aspectX;
        final leakY = (look.leakPosition[1] - 0.5) * aspectY;
        final dx = frameX - leakX;
        final dy = frameY - leakY;
        final distance =
            math.sqrt(dx * dx + dy * dy) / math.max(look.leakRadius, 0.001);
        final leak = math.exp(-distance * distance * 2) * look.leakAmount;
        red = 1 - (1 - red) * (1 - leakColor[0] * leak);
        green = 1 - (1 - green) * (1 - leakColor[1] * leak);
        blue = 1 - (1 - blue) * (1 - leakColor[2] * leak);
      }

      // Vignette.
      if (look.vignetteAmount > 0.001) {
        final distance =
            math.sqrt(frameX * frameX + frameY * frameY) /
            (0.5 * math.sqrt(aspectX * aspectX + aspectY * aspectY));
        final vignette = _smoothstep(
          1 - look.vignetteSoftness,
          1 + look.vignetteSoftness * 0.2,
          distance,
        );
        final keep = 1 - vignette * look.vignetteAmount;
        red *= keep;
        green *= keep;
        blue *= keep;
      }

      // Grain: two octaves of value noise, strongest in the midtones.
      if (look.grainAmount > 0.001) {
        final cells = 1000.0 / math.max(look.grainSize, 0.05);
        final grainX = u * aspectX * cells + seed * 17.0;
        final grainY = v * aspectY * cells + seed * 31.0;
        var grain =
            _valueNoise(grainX, grainY) +
            0.5 * _valueNoise(grainX * 2.1 + 7.3, grainY * 2.1 + 7.3);
        grain = grain / 1.5 - 0.5;
        final tone = _luma(red, green, blue);
        final middle = 1 - _pow((2 * tone - 1).abs(), 2);
        final strength =
            grain * look.grainAmount * (0.35 + 0.65 * middle) * 0.35;
        red += strength;
        green += strength;
        blue += strength;
      }

      red = red.clamp(0.0, 1.0);
      green = green.clamp(0.0, 1.0);
      blue = blue.clamp(0.0, 1.0);

      // The intensity is already part of the resolved look, so the final mix
      // with the untouched photo keeps the whole colour.
      final alpha = originalAlpha;
      final index = (y * width + x) * 4;
      out[index] = _toByte(red * alpha);
      out[index + 1] = _toByte(green * alpha);
      out[index + 2] = _toByte(blue * alpha);
      out[index + 3] = _toByte(alpha);
    }
  }

  return out;
}

/// Samples the input image the way a texture sampler with a linear filter and
/// clamped edges does.
void _sampleInput(
  Uint8List rgba,
  int width,
  int height,
  double u,
  double v,
  Float64List out,
) {
  final clampedU = u.clamp(0.0, 1.0);
  final clampedV = v.clamp(0.0, 1.0);
  final fx = clampedU * width - 0.5;
  final fy = clampedV * height - 0.5;
  final x0 = fx.floorToDouble();
  final y0 = fy.floorToDouble();
  final tx = fx - x0;
  final ty = fy - y0;
  final ix0 = _clampIndex(x0.toInt(), width);
  final ix1 = _clampIndex(x0.toInt() + 1, width);
  final iy0 = _clampIndex(y0.toInt(), height);
  final iy1 = _clampIndex(y0.toInt() + 1, height);

  final topLeft = (iy0 * width + ix0) * 4;
  final topRight = (iy0 * width + ix1) * 4;
  final bottomLeft = (iy1 * width + ix0) * 4;
  final bottomRight = (iy1 * width + ix1) * 4;

  for (var channel = 0; channel < 4; channel++) {
    final top =
        rgba[topLeft + channel] * (1 - tx) + rgba[topRight + channel] * tx;
    final bottom =
        rgba[bottomLeft + channel] * (1 - tx) +
        rgba[bottomRight + channel] * tx;
    out[channel] = (top * (1 - ty) + bottom * ty) / 255.0;
  }
}

/// Samples the tone curve the way the GPU samples the `uCurve` texture: the
/// value is mapped to the texel centres of the 256 wide table and
/// interpolated between the two nearest entries.
double _sampleCurve(Uint8List curve, double value) {
  final t = value.clamp(0.0, 1.0) * 255.0;
  final base = t.floorToDouble();
  final alpha = t - base;
  var i0 = base.toInt();
  var i1 = i0 + 1;
  if (i0 < 0) {
    i0 = 0;
  }
  if (i0 > 255) {
    i0 = 255;
  }
  if (i1 < 0) {
    i1 = 0;
  }
  if (i1 > 255) {
    i1 = 255;
  }
  final low = curve[i0 * 4] / 255.0;
  final high = curve[i1 * 4] / 255.0;
  return low + (high - low) * alpha;
}

/// The hash of the shader.
double _hash(double px, double py) {
  // vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  var p3x = _fract(px * 0.1031);
  var p3y = _fract(py * 0.1031);
  var p3z = _fract(px * 0.1031);
  // p3 += dot(p3, p3.yzx + 33.33);
  final sum = p3x * (p3y + 33.33) + p3y * (p3z + 33.33) + p3z * (p3x + 33.33);
  p3x += sum;
  p3y += sum;
  p3z += sum;
  // return fract((p3.x + p3.y) * p3.z);
  return _fract((p3x + p3y) * p3z);
}

/// The value noise of the shader.
double _valueNoise(double px, double py) {
  final ix = px.floorToDouble();
  final iy = py.floorToDouble();
  var fx = _fract(px);
  var fy = _fract(py);
  fx = fx * fx * (3.0 - 2.0 * fx);
  fy = fy * fy * (3.0 - 2.0 * fy);
  final a = _hash(ix, iy);
  final b = _hash(ix + 1, iy);
  final c = _hash(ix, iy + 1);
  final d = _hash(ix + 1, iy + 1);
  final top = a * (1 - fx) + b * fx;
  final bottom = c * (1 - fx) + d * fx;
  return top * (1 - fy) + bottom * fy;
}

/// The luma of the shader.
double _luma(double red, double green, double blue) =>
    0.2126 * red + 0.7152 * green + 0.0722 * blue;

/// The smoothstep of the shader.
double _smoothstep(double edge0, double edge1, double x) {
  final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

double _fract(double x) => x - x.floorToDouble();

double _pow(double base, double exponent) =>
    math.pow(base, exponent).toDouble();

double _exp2(double x) => math.pow(2, x).toDouble();

int _toByte(double value) => (value.clamp(0.0, 1.0) * 255).round();

int _clampIndex(int index, int length) =>
    index < 0 ? 0 : (index >= length ? length - 1 : index);
