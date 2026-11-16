/// Turning a recipe into the exact values the shader expects.
///
/// A recipe is resolved at an intensity between 0 (the untouched photo) and 1
/// (the film at full strength), with the optional changes the user made.
library;

import 'dart:typed_data';

import 'curve.dart';
import 'recipe.dart';

/// The changes the user makes on top of a recipe.
final class LookOverrides {
  /// Creates the overrides. Every field is optional.
  const LookOverrides({
    this.grain,
    this.halation,
    this.leak,
    this.vignette,
    this.dateStamp,
    this.format,
    this.whiteFrame,
    this.cinemaBands,
  });

  /// No override at all.
  static const LookOverrides none = LookOverrides();

  /// Multiplies the grain amount of the recipe, from 0 to 2.
  final double? grain;

  /// Multiplies the halation amount of the recipe, from 0 to 2.
  final double? halation;

  /// Multiplies the light leak amount of the recipe, from 0 to 2.
  final double? leak;

  /// Multiplies the vignette amount of the recipe, from 0 to 2.
  final double? vignette;

  /// Replaces the date imprint of the recipe.
  final bool? dateStamp;

  /// Replaces the frame format of the recipe.
  final FrameFormat? format;

  /// Replaces the white border of the recipe.
  final bool? whiteFrame;

  /// Replaces the cinema bands of the recipe.
  final bool? cinemaBands;
}

/// A recipe resolved at one intensity: the values the shader is fed with.
final class ResolvedLook {
  /// Creates a resolved look.
  const ResolvedLook({
    required this.exposure,
    required this.saturation,
    required this.matrix,
    required this.shadowTint,
    required this.highlightTint,
    required this.grainAmount,
    required this.grainSize,
    required this.vignetteAmount,
    required this.vignetteSoftness,
    required this.halationAmount,
    required this.halationThreshold,
    required this.halationRadius,
    required this.halationColor,
    required this.leakAmount,
    required this.leakPosition,
    required this.leakRadius,
    required this.leakColor,
    required this.wbDrift,
    required this.curveR,
    required this.curveG,
    required this.curveB,
    required this.format,
    required this.dateStamp,
    required this.whiteFrame,
    this.cinemaBands = false,
  });

  /// The exposure, in stops.
  final double exposure;

  /// The saturation, where 1 leaves the colours untouched.
  final double saturation;

  /// The colour matrix, row major.
  final List<double> matrix;

  /// The tint added to the shadows.
  final List<double> shadowTint;

  /// The tint added to the highlights.
  final List<double> highlightTint;

  /// How strong the grain is.
  final double grainAmount;

  /// How big the grain cells are.
  final double grainSize;

  /// How strong the vignette is.
  final double vignetteAmount;

  /// How soft the edge of the vignette is.
  final double vignetteSoftness;

  /// How strong the halation is.
  final double halationAmount;

  /// The luma above which a pixel starts to glow.
  final double halationThreshold;

  /// The radius of the halation, as a fraction of the short side.
  final double halationRadius;

  /// The colour of the halation.
  final List<double> halationColor;

  /// How strong the light leak is.
  final double leakAmount;

  /// Where the light leak sits, as a point of the frame.
  final List<double> leakPosition;

  /// The radius of the light leak, with the short side as 1.
  final double leakRadius;

  /// The colour of the light leak.
  final List<double> leakColor;

  /// The amplitude of the white balance drift that was folded into [matrix].
  final double wbDrift;

  /// The tone curve of the red channel, with 256 entries.
  final Float64List curveR;

  /// The tone curve of the green channel, with 256 entries.
  final Float64List curveG;

  /// The tone curve of the blue channel, with 256 entries.
  final Float64List curveB;

  /// The frame format of the shot.
  final FrameFormat format;

  /// Whether the date imprint is on.
  final bool dateStamp;

  /// Whether the white border is on.
  final bool whiteFrame;

  /// Whether cinema bands are enabled (applied only to 16:9 frames).
  final bool cinemaBands;
}

/// Resolves [recipe] at [intensity] with the [overrides] of the user.
///
/// The intensity is clamped to 0..1. At 0 the look is the neutral one (no
/// exposure, no saturation change, identity matrix, no tints, identity curves
/// and no grain, halation, leak or vignette); at 1 it is the recipe itself.
/// Every value in between is a straight line between the two.
///
/// The curves are interpolated entry by entry once both have been sampled into
/// their 256 entry lookup tables.
///
/// When [shotSeed] is not zero the white balance drifts: the seed is mixed
/// with a 32 bit integer hash and each channel gets its own multiplier of
/// `1 +/- wbDrift`, which is folded into the diagonal of the colour matrix.
/// The same seed always drifts the same way, and a seed of zero drifts not at
/// all.
ResolvedLook resolve(
  Recipe recipe, {
  double intensity = 1,
  LookOverrides overrides = LookOverrides.none,
  int shotSeed = 0,
}) {
  final t = intensity.clamp(0.0, 1.0);
  // The ends are exact: at zero the look is the neutral one and at one it is
  // the recipe, with no rounding of its own.
  double lerp(double from, double to) {
    if (t == 1) {
      return to;
    }
    if (t == 0) {
      return from;
    }
    return from + (to - from) * t;
  }

  // The neutral look, used as the origin of the interpolation.
  const neutralMatrix = <double>[1, 0, 0, 0, 1, 0, 0, 0, 1];
  const neutralShadowTint = <double>[0, 0, 0];
  const neutralHighlightTint = <double>[0, 0, 0];
  const neutralHalationColor = <double>[1, 0.35, 0.15];
  const neutralLeakColor = <double>[1, 0.45, 0.1];
  const neutralLeakPosition = <double>[0.9, 0.1];

  // Black and white films always end at zero saturation, but they still start
  // at one, so that the intensity slides from the colour photo to the
  // black and white one.
  final saturation = lerp(
    1,
    recipe.kind == FilmKind.bw ? 0 : recipe.saturation,
  );

  final matrix = List<double>.generate(
    recipe.matrix.length,
    (int i) => lerp(_neutralAt(neutralMatrix, i), recipe.matrix[i]),
  );

  final drift = lerp(0, recipe.wbDrift);
  if (shotSeed != 0 && drift > 0 && matrix.length >= 9) {
    final multipliers = _wbMultipliers(shotSeed, drift);
    // Diagonal scaling: the gain of the input channel changes, which is what
    // a white balance does.
    matrix[0] *= multipliers[0];
    matrix[4] *= multipliers[1];
    matrix[8] *= multipliers[2];
  }

  final masterLut = buildLut(recipe.curve.master.points);
  final curveR = _lerpLut(
    combineLuts(masterLut, buildLut(recipe.curve.r.points)),
    t,
  );
  final curveG = _lerpLut(
    combineLuts(masterLut, buildLut(recipe.curve.g.points)),
    t,
  );
  final curveB = _lerpLut(
    combineLuts(masterLut, buildLut(recipe.curve.b.points)),
    t,
  );

  return ResolvedLook(
    exposure: lerp(0, recipe.exposure),
    saturation: saturation,
    matrix: matrix,
    shadowTint: List<double>.generate(
      recipe.shadowTint.length,
      (int i) => lerp(_neutralAt(neutralShadowTint, i), recipe.shadowTint[i]),
    ),
    highlightTint: List<double>.generate(
      recipe.highlightTint.length,
      (int i) =>
          lerp(_neutralAt(neutralHighlightTint, i), recipe.highlightTint[i]),
    ),
    grainAmount: (lerp(0, recipe.grain.amount) * (overrides.grain ?? 1)).clamp(
      0.0,
      1.0,
    ),
    grainSize: lerp(1, recipe.grain.size),
    vignetteAmount:
        (lerp(0, recipe.vignette.amount) * (overrides.vignette ?? 1)).clamp(
          0.0,
          1.0,
        ),
    vignetteSoftness: lerp(0.5, recipe.vignette.softness),
    halationAmount:
        (lerp(0, recipe.halation.amount) * (overrides.halation ?? 1)).clamp(
          0.0,
          1.0,
        ),
    halationThreshold: lerp(0.75, recipe.halation.threshold),
    halationRadius: lerp(0.01, recipe.halation.radius),
    halationColor: List<double>.generate(
      recipe.halation.color.length,
      (int i) =>
          lerp(_neutralAt(neutralHalationColor, i), recipe.halation.color[i]),
    ),
    leakAmount: (lerp(0, recipe.leak.amount) * (overrides.leak ?? 1)).clamp(
      0.0,
      1.0,
    ),
    leakPosition: List<double>.generate(
      recipe.leak.position.length,
      (int i) =>
          lerp(_neutralAt(neutralLeakPosition, i), recipe.leak.position[i]),
    ),
    leakRadius: lerp(0.4, recipe.leak.radius),
    leakColor: List<double>.generate(
      recipe.leak.color.length,
      (int i) => lerp(_neutralAt(neutralLeakColor, i), recipe.leak.color[i]),
    ),
    wbDrift: drift,
    curveR: curveR,
    curveG: curveG,
    curveB: curveB,
    format: overrides.format ?? recipe.defaults.format,
    dateStamp: overrides.dateStamp ?? recipe.defaults.dateStamp,
    whiteFrame: overrides.whiteFrame ?? recipe.defaults.whiteFrame,
    cinemaBands: overrides.cinemaBands ?? recipe.defaults.cinemaBands,
  );
}

/// The neutral value at [index], or zero when the neutral list is shorter.
double _neutralAt(List<double> neutral, int index) =>
    index < neutral.length ? neutral[index] : 0;

/// Interpolates a lookup table between the identity curve and [target].
Float64List _lerpLut(Float64List target, double t) {
  if (t == 1) {
    return Float64List.fromList(target);
  }
  final out = Float64List(kCurveLutSize);
  for (var i = 0; i < kCurveLutSize; i++) {
    final identity = i / (kCurveLutSize - 1);
    out[i] = identity + (target[i] - identity) * t;
  }
  return out;
}

/// The white balance multipliers of [seed], one per channel.
List<double> _wbMultipliers(int seed, double amount) => <double>[
  _wbChannel(seed, 0, amount),
  _wbChannel(seed, 1, amount),
  _wbChannel(seed, 2, amount),
];

double _wbChannel(int seed, int channel, double amount) {
  final hash = _mix32(seed * 0x9E3779B1 + channel * 0x85EBCA6B);
  final unit = (hash & 0xFFFFFF) / 0xFFFFFF;
  return 1 + (unit * 2 - 1) * amount;
}

/// The "lowbias32" finaliser, a small integer hash.
int _mix32(int value) {
  var h = value & 0xFFFFFFFF;
  h ^= h >> 16;
  h = _mul32(h, 0x7feb352d);
  h ^= h >> 15;
  h = _mul32(h, 0x846ca68b);
  h ^= h >> 16;
  return h & 0xFFFFFFFF;
}

/// Multiplies two 32 bit numbers keeping the low 32 bits.
int _mul32(int a, int b) {
  final aLow = a & 0xFFFF;
  final aHigh = (a >> 16) & 0xFFFF;
  final bLow = b & 0xFFFF;
  final bHigh = (b >> 16) & 0xFFFF;
  return (aLow * bLow + (((aLow * bHigh + aHigh * bLow) & 0xFFFF) << 16)) &
      0xFFFFFFFF;
}
