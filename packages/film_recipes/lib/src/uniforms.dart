/// The contract with `shaders/film.frag`.
///
/// The shader reads its uniforms in declaration order, so the values are
/// written here in exactly the same order. Slots 0 and 1 hold the current
/// render target size and are set by the app, so this file starts at slot 2.
library;

import 'dart:typed_data';

import 'curve.dart';
import 'resolve.dart';

/// The number of float slots, from the mode through the tile/input coordinates.
const int kShaderUniformCount = 45;

/// The uniform values of [look], in the order of `shaders/film.frag`.
///
/// The list holds the slots 2 to 46 of the shader: the mode, the seed, the
/// exposure, the saturation, the three rows of the colour matrix, the two
/// tints, the grain, the vignette, the halation, the light leak and the final
/// intensity, then the frame size, tile origin and input crop. A zero frame
/// size selects the engine size. The mode is 0 here because the app sets it.
List<double> shaderUniforms(
  ResolvedLook look, {
  required double seed,
  double intensity = 1,
  double frameWidth = 0,
  double frameHeight = 0,
  double tileX = 0,
  double tileY = 0,
  double inputLeft = 0,
  double inputTop = 0,
  double inputWidth = 1,
  double inputHeight = 1,
}) {
  return <double>[
    // 2: the mode, always paint here, the app overrides it.
    0,
    // 3: the grain seed.
    seed,
    // 4-5: exposure and saturation.
    look.exposure,
    look.saturation,
    // 6-14: the rows of the colour matrix.
    ...look.matrix,
    // 15-20: the tints of the shadows and of the highlights.
    ...look.shadowTint,
    ...look.highlightTint,
    // 21-22: the grain.
    look.grainAmount,
    look.grainSize,
    // 23-24: the vignette.
    look.vignetteAmount,
    look.vignetteSoftness,
    // 25-30: the halation.
    look.halationAmount,
    look.halationThreshold,
    look.halationRadius,
    ...look.halationColor,
    // 31-34: the light leak: position, radius and amount.
    ...look.leakPosition,
    look.leakRadius,
    look.leakAmount,
    // 35-37: the colour of the light leak.
    ...look.leakColor,
    // 38: the final mix with the untouched photo.
    intensity,
    // 39-46: whole frame, tile origin and normalized source crop.
    frameWidth, frameHeight, tileX, tileY,
    inputLeft, inputTop, inputWidth, inputHeight,
  ];
}

/// The 256x1 RGBA tone curve of [look], ready to be uploaded as `uCurve`.
///
/// The red, green and blue entries come from the three channel curves and
/// the alpha is always opaque.
Uint8List curveRgba(ResolvedLook look) =>
    curveRgbaFromLuts(look.curveR, look.curveG, look.curveB);
