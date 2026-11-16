import 'dart:io';

import 'package:film_recipes/film_recipes.dart';
import 'package:test/test.dart';

/// The names no film may use, because they belong to other makers.
const List<String> _forbiddenNames = <String>[
  'kodak',
  'fuji',
  'fujifilm',
  'polaroid',
  'ilford',
  'lomo',
  'leica',
  'canon',
  'nikon',
  'pentax',
  'olympus',
];

void main() {
  final book = RecipeBook.parse(File('assets/recipes.json').readAsStringSync());

  group('the recipes the app ships with', () {
    test(
      'are the ten films of the first version, in the order of the spec',
      () {
        expect(book.recipes.map((Recipe recipe) => recipe.id), [
          'verano-98',
          'diapositiva-fria',
          'caducada',
          'noche-de-flash',
          'bn-clasico',
          'bn-prensa',
          'instantanea',
          'desechable',
          'cine',
          'camara-de-juguete',
        ]);
      },
    );

    test('have distinct names in every language', () {
      for (final names in <String Function(Recipe)>[
        (Recipe r) => r.name.es,
        (Recipe r) => r.name.ca,
        (Recipe r) => r.name.en,
      ]) {
        final all = book.recipes.map(names).toList();
        expect(all.toSet(), hasLength(all.length));
      }
    });

    test('write their name and their description in the three languages', () {
      for (final recipe in book.recipes) {
        expect(recipe.name.es, isNotEmpty);
        expect(recipe.name.ca, isNotEmpty);
        expect(recipe.name.en, isNotEmpty);
        expect(recipe.description.es, isNotEmpty);
        expect(recipe.description.ca, isNotEmpty);
        expect(recipe.description.en, isNotEmpty);
      }
    });

    test('do not use the name of another maker', () {
      for (final recipe in book.recipes) {
        final text = <String>[
          recipe.name.es,
          recipe.name.ca,
          recipe.name.en,
          recipe.description.es,
          recipe.description.ca,
          recipe.description.en,
        ].join(' ').toLowerCase();

        for (final forbidden in _forbiddenNames) {
          expect(
            text.contains(forbidden),
            isFalse,
            reason: '${recipe.id} uses the name of another maker',
          );
        }
      }
    });

    test('have no emoji in their name or their description', () {
      final emoji = RegExp(
        '[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]',
        unicode: true,
      );

      for (final recipe in book.recipes) {
        for (final text in <String>[
          recipe.name.es,
          recipe.name.ca,
          recipe.name.en,
          recipe.description.es,
          recipe.description.ca,
          recipe.description.en,
        ]) {
          expect(emoji.hasMatch(text), isFalse, reason: recipe.id);
        }
      }
    });

    test('give the neutral look at zero intensity', () {
      for (final recipe in book.recipes) {
        final look = resolve(recipe, intensity: 0);

        expect(look.exposure, 0, reason: recipe.id);
        expect(look.matrix, <double>[
          1,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          1,
        ], reason: recipe.id);
        expect(look.shadowTint, <double>[0, 0, 0], reason: recipe.id);
        expect(look.highlightTint, <double>[0, 0, 0], reason: recipe.id);
        expect(look.grainAmount, 0, reason: recipe.id);
        expect(look.halationAmount, 0, reason: recipe.id);
        expect(look.leakAmount, 0, reason: recipe.id);
        expect(look.vignetteAmount, 0, reason: recipe.id);
        expect(look.wbDrift, 0, reason: recipe.id);
        for (var i = 0; i < 256; i++) {
          expect(look.curveR[i], closeTo(i / 255, 1e-12), reason: recipe.id);
          expect(look.curveG[i], closeTo(i / 255, 1e-12), reason: recipe.id);
          expect(look.curveB[i], closeTo(i / 255, 1e-12), reason: recipe.id);
        }
      }
    });

    test('give themselves at full intensity', () {
      for (final recipe in book.recipes) {
        final look = resolve(recipe);

        expect(look.exposure, recipe.exposure, reason: recipe.id);
        expect(look.grainAmount, recipe.grain.amount, reason: recipe.id);
        expect(look.halationAmount, recipe.halation.amount, reason: recipe.id);
        expect(look.leakAmount, recipe.leak.amount, reason: recipe.id);
        expect(look.vignetteAmount, recipe.vignette.amount, reason: recipe.id);
        expect(look.matrix, recipe.matrix, reason: recipe.id);
        expect(look.format, recipe.defaults.format, reason: recipe.id);
        expect(look.dateStamp, recipe.defaults.dateStamp, reason: recipe.id);
        expect(look.whiteFrame, recipe.defaults.whiteFrame, reason: recipe.id);
      }
    });

    test('keep the black and white films without colour', () {
      for (final id in <String>['bn-clasico', 'bn-prensa']) {
        final recipe = book.byId(id)!;

        expect(recipe.kind, FilmKind.bw, reason: id);
        expect(resolve(recipe).saturation, 0, reason: id);
      }
    });

    test(
      'give the press film more grain and contrast than the classic one',
      () {
        final classic = book.byId('bn-clasico')!;
        final press = book.byId('bn-prensa')!;

        expect(press.grain.amount, greaterThan(classic.grain.amount));
        expect(press.grain.size, greaterThan(classic.grain.size));
        final classicLut = resolve(classic).curveG;
        final pressLut = resolve(press).curveG;
        // Deeper shadows and brighter highlights: a steeper curve.
        expect(pressLut[64], lessThan(classicLut[64]));
        expect(pressLut[200], greaterThan(classicLut[200]));
      },
    );

    test('give the instant film its square frame with a white border', () {
      final look = resolve(book.byId('instantanea')!);

      expect(look.format, FrameFormat.r1x1);
      expect(look.whiteFrame, isTrue);
      expect(look.dateStamp, isFalse);
    });

    test('give the cinema film its wide frame', () {
      final look = resolve(book.byId('cine')!);

      expect(look.format, FrameFormat.r16x9);
      expect(look.whiteFrame, isFalse);
    });

    test('name a band colour for every film, in a different hue family', () {
      final bands = <String, List<double>>{};
      for (final recipe in book.recipes) {
        final hex = recipe.bandColor;
        expect(hex, isNotNull, reason: recipe.id);
        expect(RegExp(kBandColorPattern).hasMatch(hex!), isTrue);
        final v = <double>[
          for (var i = 1; i < 7; i += 2)
            int.parse(hex.substring(i, i + 2), radix: 16) / 255,
        ];
        final high = v.reduce((a, b) => a > b ? a : b);
        final low = v.reduce((a, b) => a < b ? a : b);
        final chroma = high - low;
        var hue = -1.0;
        if (chroma > 0.25) {
          final r = v[0], g = v[1], b = v[2];
          if (high == r) {
            hue = 60 * (((g - b) / chroma) % 6);
          } else if (high == g) {
            hue = 60 * ((b - r) / chroma + 2);
          } else {
            hue = 60 * ((r - g) / chroma + 4);
          }
        }
        // Neutral bands are told apart by lightness, as a negative hue.
        bands[recipe.id] = <double>[hue, high];
      }
      final ids = bands.keys.toList();
      for (var i = 0; i < ids.length; i++) {
        for (var j = i + 1; j < ids.length; j++) {
          final a = bands[ids[i]]!, b = bands[ids[j]]!;
          if (a[0] < 0 && b[0] < 0) {
            expect(
              (a[1] - b[1]).abs(),
              greaterThan(0.2),
              reason: '${ids[i]}/${ids[j]}',
            );
          } else if (a[0] >= 0 && b[0] >= 0) {
            var d = (a[0] - b[0]).abs();
            if (d > 180) d = 360 - d;
            expect(d, greaterThanOrEqualTo(25), reason: '${ids[i]}/${ids[j]}');
          }
        }
      }
    });

    test('read the band colour of a recipe and write it back', () {
      final recipe = book.byId('cine')!;

      expect(recipe.bandColor, '#1FA88C');
      expect(recipe.toJson()['bandColor'], '#1FA88C');
      expect(
        RecipeBook.parse(
          '{"schemaVersion":1,"recipesVersion":"1.0.0","recipes":[{"id":"sin",'
          '"name":{"es":"a","ca":"b","en":"c"},'
          '"description":{"es":"a","ca":"b","en":"c"}}]}',
        ).recipes.single.bandColor,
        isNull,
      );
    });

    test('give the toy camera the strongest vignette and light leak', () {
      final toy = book.byId('camara-de-juguete')!;

      for (final other in book.recipes.where((r) => r.id != toy.id)) {
        expect(toy.vignette.amount, greaterThan(other.vignette.amount));
        expect(toy.leak.amount, greaterThan(other.leak.amount));
      }
    });

    test('give the expired film a strong vignette and coarse grain', () {
      final expired = book.byId('caducada')!;

      expect(expired.vignette.amount, greaterThanOrEqualTo(0.5));
      expect(expired.grain.size, greaterThanOrEqualTo(2));
    });

    test('give the disposable film the frame of the disposable camera', () {
      final look = resolve(book.byId('desechable')!);

      // 3:2 without a border, like the disposable camera, so it does not
      // overlap with the square white frame of the instant film.
      expect(look.format, FrameFormat.r3x2);
      expect(look.dateStamp, isTrue);
      expect(look.whiteFrame, isFalse);
    });

    test('give the slide film no light leak', () {
      final look = resolve(book.byId('diapositiva-fria')!);

      expect(look.leakAmount, 0);
    });
  });
}
