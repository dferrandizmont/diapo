import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Parameters of one film look, in the units the shader expects.
///
/// This is the temporary proof-of-concept model; the recipe engine
/// (`packages/film_recipes`) will produce the same values from JSON.
class FilmLook {
  const FilmLook({
    this.exposure = 0,
    this.saturation = 1,
    this.matrix = const [1, 0, 0, 0, 1, 0, 0, 0, 1],
    this.shadowTint = const [0, 0, 0],
    this.highlightTint = const [0, 0, 0],
    this.grainAmount = 0,
    this.grainSize = 1,
    this.vignette = 0,
    this.vignetteSoft = 0.5,
    this.halation = 0,
    this.halationThreshold = 0.75,
    this.halationRadius = 0.01,
    this.halationColor = const [1, 0.35, 0.15],
    this.leak = const [0.9, 0.1, 0.4, 0],
    this.leakColor = const [1, 0.45, 0.1],
    this.curve,
  });

  final double exposure;
  final double saturation;

  /// Row-major 3x3 colour matrix.
  final List<double> matrix;
  final List<double> shadowTint;
  final List<double> highlightTint;
  final double grainAmount;
  final double grainSize;
  final double vignette;
  final double vignetteSoft;
  final double halation;
  final double halationThreshold;
  final double halationRadius;
  final List<double> halationColor;

  /// x, y (frame uv), radius (short side = 1), amount.
  final List<double> leak;
  final List<double> leakColor;

  /// 256 x 1 RGBA tone curve; identity when null.
  final Uint8List? curve;
}

/// Writes [look] into [shader] following the uniform contract in
/// `shaders/film.frag`. [size] is only written in paint mode: in filter mode
/// the engine sets it.
void applyFilmUniforms(
  ui.FragmentShader shader,
  FilmLook look, {
  required bool filterMode,
  required double seed,
  double intensity = 1,
  ui.Size? size,
}) {
  var i = 0;
  void f(double v) => shader.setFloat(i++, v);
  void all(List<double> v) => v.forEach(f);

  if (size != null) {
    f(size.width);
    f(size.height);
  } else {
    i = 2;
  }
  f(filterMode ? 1 : 0);
  f(seed);
  f(look.exposure);
  f(look.saturation);
  all(look.matrix);
  all(look.shadowTint);
  all(look.highlightTint);
  f(look.grainAmount);
  f(look.grainSize);
  f(look.vignette);
  f(look.vignetteSoft);
  f(look.halation);
  f(look.halationThreshold);
  f(look.halationRadius);
  all(look.halationColor);
  all(look.leak);
  all(look.leakColor);
  f(intensity);
  all([0, 0, 0, 0, 0, 0, 1, 1]); // Whole frame, full input texture.
  assert(i == 47, 'uniform contract drifted: wrote $i floats');
}

/// Builds a 256x1 RGBA curve from per-channel lookups.
Uint8List buildCurve(double Function(double x, int channel) curve) {
  final out = Uint8List(256 * 4);
  for (var x = 0; x < 256; x++) {
    for (var c = 0; c < 3; c++) {
      final v = curve(x / 255, c).clamp(0.0, 1.0);
      out[x * 4 + c] = (v * 255).round();
    }
    out[x * 4 + 3] = 255;
  }
  return out;
}

Future<ui.Image> curveImage(Uint8List rgba) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    rgba,
    256,
    1,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}
