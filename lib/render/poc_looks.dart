import 'dart:math' as math;

import 'film_uniforms.dart';

/// Hand-made look for the proof of concept ("Verano 98"-ish warm negative).
/// Replaced by JSON recipes once the recipe engine lands.
FilmLook pocWarmNegative() {
  double s(double x, double contrast, double lift) {
    // Filmic S-curve with lifted blacks and rolled-off whites.
    final y = 1 / (1 + math.exp(-contrast * (x - 0.5)));
    final y0 = 1 / (1 + math.exp(contrast * 0.5));
    final y1 = 1 / (1 + math.exp(-contrast * 0.5));
    final n = (y - y0) / (y1 - y0);
    return lift + n * (0.97 - lift);
  }

  return FilmLook(
    exposure: 0.1,
    saturation: 1.08,
    matrix: const [1.06, -0.02, -0.04, -0.03, 1.02, 0.01, -0.02, -0.05, 0.95],
    shadowTint: const [0.012, 0.0, -0.01],
    highlightTint: const [0.03, 0.012, -0.03],
    grainAmount: 0.35,
    grainSize: 1.1,
    vignette: 0.28,
    vignetteSoft: 0.6,
    halation: 0.35,
    halationThreshold: 0.78,
    halationRadius: 0.012,
    leak: const [0.95, 0.12, 0.45, 0.22],
    leakColor: const [1.0, 0.42, 0.12],
    curve: buildCurve(
      (x, c) => s(x, c == 2 ? 5.6 : 6.2, c == 2 ? 0.07 : 0.045),
    ),
  );
}
