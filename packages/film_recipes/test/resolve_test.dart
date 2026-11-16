import 'package:film_recipes/film_recipes.dart';
import 'package:test/test.dart';

/// A recipe with every knob turned, so the resolution can be checked.
Recipe _recipe({
  FilmKind kind = FilmKind.color,
  double exposure = 0.5,
  double saturation = 1.5,
  List<double> matrix = const <double>[
    1.1, 0, 0, //
    0, 1.2, 0, //
    0, 0, 1.3, //
  ],
  List<double> shadowTint = const <double>[0.05, 0, 0],
  List<double> highlightTint = const <double>[0, 0, 0.05],
  double grain = 0.4,
  double grainSize = 2,
  double halation = 0.5,
  double halationThreshold = 0.6,
  double halationRadius = 0.02,
  double leak = 0.3,
  List<double> leakPosition = const <double>[0.2, 0.8],
  double leakRadius = 0.9,
  double vignette = 0.7,
  double vignetteSoftness = 0.8,
  double wbDrift = 0.05,
  CurveSet curve = const CurveSet(
    master: ToneCurve(<CurvePoint>[CurvePoint(0, 0.1), CurvePoint(1, 0.9)]),
    r: ToneCurve(<CurvePoint>[CurvePoint(0, 0.2), CurvePoint(1, 0.8)]),
  ),
}) {
  return Recipe(
    id: 'prueba',
    name: const LocalizedText(es: 'a', ca: 'b', en: 'c'),
    description: const LocalizedText(es: 'a', ca: 'b', en: 'c'),
    kind: kind,
    exposure: exposure,
    saturation: saturation,
    matrix: matrix,
    shadowTint: shadowTint,
    highlightTint: highlightTint,
    grain: GrainSettings(amount: grain, size: grainSize),
    halation: HalationSettings(
      amount: halation,
      threshold: halationThreshold,
      radius: halationRadius,
    ),
    leak: LeakSettings(
      amount: leak,
      position: leakPosition,
      radius: leakRadius,
    ),
    vignette: VignetteSettings(amount: vignette, softness: vignetteSoftness),
    wbDrift: wbDrift,
    curve: curve,
  );
}

void main() {
  group('resolve', () {
    test('at full strength gives the recipe back', () {
      final recipe = _recipe();
      final look = resolve(recipe);

      expect(look.exposure, recipe.exposure);
      expect(look.saturation, recipe.saturation);
      expect(look.matrix, recipe.matrix);
      expect(look.shadowTint, recipe.shadowTint);
      expect(look.highlightTint, recipe.highlightTint);
      expect(look.grainAmount, recipe.grain.amount);
      expect(look.grainSize, recipe.grain.size);
      expect(look.halationAmount, recipe.halation.amount);
      expect(look.halationThreshold, recipe.halation.threshold);
      expect(look.halationRadius, recipe.halation.radius);
      expect(look.leakAmount, recipe.leak.amount);
      expect(look.leakPosition, recipe.leak.position);
      expect(look.leakRadius, recipe.leak.radius);
      expect(look.vignetteAmount, recipe.vignette.amount);
      expect(look.vignetteSoftness, recipe.vignette.softness);
      expect(look.wbDrift, recipe.wbDrift);
    });

    test('at zero gives the neutral look', () {
      final look = resolve(_recipe(), intensity: 0);

      expect(look.exposure, 0);
      expect(look.saturation, 1);
      expect(look.matrix, <double>[1, 0, 0, 0, 1, 0, 0, 0, 1]);
      expect(look.shadowTint, <double>[0, 0, 0]);
      expect(look.highlightTint, <double>[0, 0, 0]);
      expect(look.grainAmount, 0);
      expect(look.halationAmount, 0);
      expect(look.leakAmount, 0);
      expect(look.vignetteAmount, 0);
      expect(look.wbDrift, 0);
    });

    test('at zero gives the identity curves', () {
      final look = resolve(_recipe(), intensity: 0);

      for (var i = 0; i < 256; i++) {
        expect(look.curveR[i], closeTo(i / 255, 1e-12));
        expect(look.curveG[i], closeTo(i / 255, 1e-12));
        expect(look.curveB[i], closeTo(i / 255, 1e-12));
      }
    });

    test('in between gives half of the way', () {
      final look = resolve(_recipe(), intensity: 0.5);

      expect(look.exposure, closeTo(0.25, 1e-12));
      expect(look.saturation, closeTo(1.25, 1e-12));
      expect(look.matrix[0], closeTo(1.05, 1e-12));
      expect(look.grainAmount, closeTo(0.2, 1e-12));
      expect(look.vignetteAmount, closeTo(0.35, 1e-12));
    });

    test('clamps the intensity', () {
      expect(resolve(_recipe(), intensity: 5).exposure, 0.5);
      expect(resolve(_recipe(), intensity: -5).exposure, 0);
    });

    test('keeps the choices of the recipe', () {
      final recipe = Recipe(
        id: 'prueba',
        name: const LocalizedText(es: 'a', ca: 'b', en: 'c'),
        description: const LocalizedText(es: 'a', ca: 'b', en: 'c'),
        defaults: const RecipeDefaults(
          format: FrameFormat.r1x1,
          dateStamp: true,
          whiteFrame: true,
          cinemaBands: true,
        ),
      );
      final look = resolve(recipe);

      expect(look.format, FrameFormat.r1x1);
      expect(look.dateStamp, isTrue);
      expect(look.whiteFrame, isTrue);
      expect(look.cinemaBands, isTrue);
    });
  });

  group('the overrides', () {
    test('multiply the amounts of the recipe', () {
      final look = resolve(
        _recipe(),
        overrides: const LookOverrides(
          grain: 0.5,
          halation: 2,
          leak: 0,
          vignette: 1.5,
        ),
      );

      expect(look.grainAmount, closeTo(0.2, 1e-12));
      expect(look.halationAmount, 1);
      expect(look.leakAmount, 0);
      expect(look.vignetteAmount, 1);
    });

    test('clamp the amounts to one', () {
      final look = resolve(
        _recipe(),
        overrides: const LookOverrides(grain: 4, halation: 4, leak: 4),
      );

      expect(look.grainAmount, 1);
      expect(look.halationAmount, 1);
      expect(look.leakAmount, 1);
    });

    test('replace the choices of the recipe', () {
      final look = resolve(
        _recipe(),
        overrides: const LookOverrides(
          format: FrameFormat.r16x9,
          dateStamp: true,
          whiteFrame: true,
          cinemaBands: true,
        ),
      );

      expect(look.format, FrameFormat.r16x9);
      expect(look.dateStamp, isTrue);
      expect(look.whiteFrame, isTrue);
      expect(look.cinemaBands, isTrue);
    });
  });

  group('the black and white films', () {
    test('always end at zero saturation', () {
      final look = resolve(_recipe(kind: FilmKind.bw, saturation: 1.5));

      expect(look.saturation, 0);
    });

    test('still start at one, so the intensity slides to the colour photo', () {
      expect(resolve(_recipe(kind: FilmKind.bw), intensity: 0).saturation, 1);
      expect(
        resolve(_recipe(kind: FilmKind.bw), intensity: 0.5).saturation,
        closeTo(0.5, 1e-12),
      );
    });
  });

  group('the white balance drift', () {
    test('does not drift without a seed', () {
      final look = resolve(_recipe());

      expect(look.matrix, _recipe().matrix);
    });

    test('drifts the same way with the same seed', () {
      final first = resolve(_recipe(), shotSeed: 7);
      final second = resolve(_recipe(), shotSeed: 7);

      expect(first.matrix, second.matrix);
    });

    test('drifts differently with another seed', () {
      final first = resolve(_recipe(), shotSeed: 7);
      final second = resolve(_recipe(), shotSeed: 8);

      expect(first.matrix, isNot(second.matrix));
    });

    test('only touches the diagonal of the matrix', () {
      final look = resolve(_recipe(), shotSeed: 7);
      final recipe = _recipe();

      expect(look.matrix[1], recipe.matrix[1]);
      expect(look.matrix[3], recipe.matrix[3]);
      expect(look.matrix[0], isNot(recipe.matrix[0]));
    });

    test('keeps the multiplier near one', () {
      final look = resolve(_recipe(), shotSeed: 12345);
      final recipe = _recipe();

      expect(look.matrix[0] / recipe.matrix[0], inInclusiveRange(0.95, 1.05));
    });

    test('does not drift at zero intensity', () {
      final look = resolve(_recipe(), intensity: 0, shotSeed: 7);

      expect(look.matrix, <double>[1, 0, 0, 0, 1, 0, 0, 0, 1]);
    });
  });
}
