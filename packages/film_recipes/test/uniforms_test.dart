import 'dart:typed_data';

import 'package:film_recipes/film_recipes.dart';
import 'package:test/test.dart';

/// A look where every value is different, so the order of the uniforms can be
/// checked one by one.
ResolvedLook _look() {
  return ResolvedLook(
    exposure: 1.1,
    saturation: 1.2,
    matrix: const <double>[1, 2, 3, 4, 5, 6, 7, 8, 9],
    shadowTint: const <double>[10, 11, 12],
    highlightTint: const <double>[13, 14, 15],
    grainAmount: 16,
    grainSize: 17,
    vignetteAmount: 18,
    vignetteSoftness: 19,
    halationAmount: 20,
    halationThreshold: 21,
    halationRadius: 22,
    halationColor: const <double>[23, 24, 25],
    leakAmount: 26,
    leakPosition: const <double>[27, 28],
    leakRadius: 29,
    leakColor: const <double>[30, 31, 32],
    wbDrift: 33,
    curveR: Float64List(256),
    curveG: Float64List(256),
    curveB: Float64List(256),
    format: FrameFormat.r3x2,
    dateStamp: false,
    whiteFrame: false,
  );
}

void main() {
  group('shaderUniforms', () {
    test('holds the 45 floats of the slots 2 to 46 of the shader', () {
      final uniforms = shaderUniforms(_look(), seed: 42);

      expect(uniforms.length, 45);
      expect(uniforms.length, kShaderUniformCount);
    });

    test('writes every field in the order of the shader', () {
      final uniforms = shaderUniforms(_look(), seed: 42);

      // 2: the mode, which the app sets.
      expect(uniforms[0], 0);
      // 3: the seed.
      expect(uniforms[1], 42);
      // 4-5: the exposure and the saturation.
      expect(uniforms[2], 1.1);
      expect(uniforms[3], 1.2);
      // 6-14: the rows of the colour matrix.
      expect(uniforms.sublist(4, 13), <double>[1, 2, 3, 4, 5, 6, 7, 8, 9]);
      // 15-20: the tints.
      expect(uniforms.sublist(13, 16), <double>[10, 11, 12]);
      expect(uniforms.sublist(16, 19), <double>[13, 14, 15]);
      // 21-22: the grain.
      expect(uniforms[19], 16);
      expect(uniforms[20], 17);
      // 23-24: the vignette.
      expect(uniforms[21], 18);
      expect(uniforms[22], 19);
      // 25-30: the halation.
      expect(uniforms[23], 20);
      expect(uniforms[24], 21);
      expect(uniforms[25], 22);
      expect(uniforms.sublist(26, 29), <double>[23, 24, 25]);
      // 31-34: the light leak.
      expect(uniforms.sublist(29, 31), <double>[27, 28]);
      expect(uniforms[31], 29);
      expect(uniforms[32], 26);
      // 35-37: the colour of the light leak.
      expect(uniforms.sublist(33, 36), <double>[30, 31, 32]);
      // 38: the final mix.
      expect(uniforms[36], 1);
      expect(uniforms.sublist(37), [0, 0, 0, 0, 0, 0, 1, 1]);
    });

    test('writes tile coordinates after the unchanged look slots', () {
      final uniforms = shaderUniforms(
        _look(),
        seed: 42,
        frameWidth: 8160,
        frameHeight: 6120,
        tileX: 1024,
        tileY: 2048,
        inputLeft: 0.1,
        inputTop: 0.2,
        inputWidth: 0.8,
        inputHeight: 0.6,
      );
      expect(uniforms.sublist(37), [
        8160,
        6120,
        1024,
        2048,
        0.1,
        0.2,
        0.8,
        0.6,
      ]);
    });

    test('writes the seed and the intensity it is given', () {
      final uniforms = shaderUniforms(_look(), seed: 7.5, intensity: 0.25);

      expect(uniforms[1], 7.5);
      expect(uniforms[36], 0.25);
    });
  });
}
