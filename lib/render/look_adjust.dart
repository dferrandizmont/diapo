import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:film_recipes/film_recipes.dart';

/// Small adjustments of a [ResolvedLook] that do not come from a recipe.
extension ResolvedLookAdjust on ResolvedLook {
  /// The same look with [stops] added to the exposure and the halation
  /// multiplied by [halationScale] (never above 1, the maximum of the shader).
  ResolvedLook adjusted({double stops = 0, double halationScale = 1}) {
    if (stops == 0 && halationScale == 1) return this;
    return ResolvedLook(
      exposure: exposure + stops,
      saturation: saturation,
      matrix: matrix,
      shadowTint: shadowTint,
      highlightTint: highlightTint,
      grainAmount: grainAmount,
      grainSize: grainSize,
      vignetteAmount: vignetteAmount,
      vignetteSoftness: vignetteSoftness,
      halationAmount: (halationAmount * halationScale).clamp(0.0, 1.0),
      halationThreshold: halationThreshold,
      halationRadius: halationRadius,
      halationColor: halationColor,
      leakAmount: leakAmount,
      leakPosition: leakPosition,
      leakRadius: leakRadius,
      leakColor: leakColor,
      wbDrift: wbDrift,
      curveR: curveR,
      curveG: curveG,
      curveB: curveB,
      format: format,
      dateStamp: dateStamp,
      whiteFrame: whiteFrame,
      cinemaBands: cinemaBands,
    );
  }
}

/// The value of the `uMode` uniform: 1 only for an image filter over a camera
/// texture, the one case in which the shader flips the picture vertically;
/// 0 for the saved still and for a filter over anything else.
double shaderModeOf({required bool filterMode, bool cameraTexture = true}) =>
    filterMode && cameraTexture ? 1 : 0;

/// Writes [look] into [shader] following the uniform contract of
/// `shaders/film.frag`, using the values of the recipe engine.
///
/// In filter mode (the live viewfinder) the engine sets the size and the input
/// image; in paint mode (the saved still) pass the [size] of the frame.
///
/// [cameraTexture] says where the filtered picture comes from. The shader
/// turns the picture upside down in filter mode on Impeller's OpenGL ES
/// backend, which is what puts a camera texture upright. A picture that is
/// not a camera texture (a decoded photo in an `Image`) is already upright
/// there, so it passes false and is left alone. See [shaderModeOf].
void applyResolvedLook(
  ui.FragmentShader shader,
  ResolvedLook look, {
  required bool filterMode,
  required double seed,
  ui.Size? size,
  bool cameraTexture = true,
  ui.Size? frameSize,
  ui.Offset tileOrigin = ui.Offset.zero,
  ui.Rect inputRect = const ui.Rect.fromLTWH(0, 0, 1, 1),
}) {
  final values = shaderUniforms(
    look,
    seed: seed,
    frameWidth: frameSize?.width ?? 0,
    frameHeight: frameSize?.height ?? 0,
    tileX: tileOrigin.dx,
    tileY: tileOrigin.dy,
    inputLeft: inputRect.left,
    inputTop: inputRect.top,
    inputWidth: inputRect.width,
    inputHeight: inputRect.height,
  );
  assert(
    values.length == kShaderUniformCount,
    'uniform contract drifted: ${values.length} floats',
  );
  var slot = 0;
  if (size != null) {
    shader.setFloat(slot++, size.width);
    shader.setFloat(slot++, size.height);
  } else {
    slot = 2;
  }
  // values[0] is the mode, which the app sets.
  shader.setFloat(
    slot++,
    shaderModeOf(filterMode: filterMode, cameraTexture: cameraTexture),
  );
  for (var i = 1; i < values.length; i++) {
    shader.setFloat(slot++, values[i]);
  }
}

/// Uploads the tone curve of [look] as the 256 x 1 image of `uCurve`.
Future<ui.Image> curveImageOf(ResolvedLook look) {
  final Uint8List rgba = curveRgba(look);
  return decodeRgba(rgba, 256, 1);
}

/// Decodes straight RGBA pixels into an image.
Future<ui.Image> decodeRgba(Uint8List rgba, int width, int height) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    rgba,
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}
