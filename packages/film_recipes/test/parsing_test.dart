import 'dart:convert';
import 'dart:io';

import 'package:film_recipes/film_recipes.dart';
import 'package:test/test.dart';

/// The JSON of the recipes the app ships with.
String shippedJson() => File('assets/recipes.json').readAsStringSync();

void main() {
  test('only Cine defaults to cinema bands and they round trip', () {
    final book = RecipeBook.parse(shippedJson());
    expect(book.recipes.where((r) => r.defaults.cinemaBands).map((r) => r.id), [
      'cine',
    ]);
    final cine = book.byId('cine')!;
    expect(cine.defaults.format, FrameFormat.r16x9);
    expect(Recipe.fromJson(cine.toJson()).defaults.cinemaBands, isTrue);
    expect(resolve(cine).cinemaBands, isTrue);
    expect(
      resolve(
        cine,
        overrides: const LookOverrides(cinemaBands: false),
      ).cinemaBands,
      isFalse,
    );
  });

  group('RecipeBook.parse', () {
    test('reads the book the app ships with', () {
      final book = RecipeBook.parse(shippedJson());

      expect(book.schemaVersion, 1);
      expect(book.recipesVersion, isNotEmpty);
      expect(book.recipes, isNotEmpty);
      expect(book.recipes.first.id, 'verano-98');
      expect(book.recipes, hasLength(10));
    });

    test('reads the recipes by id', () {
      final book = RecipeBook.parse(shippedJson());

      expect(book.byId('verano-98'), isNotNull);
      expect(book.byId('verano-98')!.name.es, 'Verano 98');
      expect(book.byId('no-existe'), isNull);
    });

    test('applies the default of every field the JSON leaves out', () {
      final book = RecipeBook.parse(
        '{"schemaVersion":1,"recipesVersion":"1.0.0","recipes":['
        '{"id":"minima","name":{"es":"a","ca":"b","en":"c"},'
        '"description":{"es":"a","ca":"b","en":"c"}}]}',
      );
      final recipe = book.recipes.single;

      expect(recipe.kind, FilmKind.color);
      expect(recipe.defaults.format, FrameFormat.r3x2);
      expect(recipe.defaults.dateStamp, isFalse);
      expect(recipe.defaults.whiteFrame, isFalse);
      expect(recipe.defaults.cinemaBands, isFalse);
      expect(recipe.exposure, 0);
      expect(recipe.saturation, 1);
      expect(recipe.matrix, <double>[1, 0, 0, 0, 1, 0, 0, 0, 1]);
      expect(recipe.shadowTint, <double>[0, 0, 0]);
      expect(recipe.highlightTint, <double>[0, 0, 0]);
      expect(recipe.curve.master.points.length, 2);
      expect(recipe.curve.r.points.length, 2);
      expect(recipe.curve.g.points.length, 2);
      expect(recipe.curve.b.points.length, 2);
      expect(recipe.grain.amount, 0);
      expect(recipe.grain.size, 1);
      expect(recipe.halation.amount, 0);
      expect(recipe.halation.threshold, 0.75);
      expect(recipe.halation.radius, 0.01);
      expect(recipe.halation.color, <double>[1, 0.35, 0.15]);
      expect(recipe.leak.amount, 0);
      expect(recipe.leak.position, <double>[0.9, 0.1]);
      expect(recipe.leak.radius, 0.4);
      expect(recipe.leak.color, <double>[1, 0.45, 0.1]);
      expect(recipe.vignette.amount, 0);
      expect(recipe.vignette.softness, 0.5);
      expect(recipe.wbDrift, 0);
      expect(recipe.notes, isNull);
    });

    test('reads the values the JSON does write', () {
      // Compared with the raw JSON, so tuning a film never breaks this test.
      final book = RecipeBook.parse(shippedJson());
      final verano = book.byId('verano-98')!;
      final raw =
          ((jsonDecode(shippedJson()) as Map<String, Object?>)['recipes']
                  as List<Object?>)
              .cast<Map<String, Object?>>()
              .firstWhere((r) => r['id'] == 'verano-98');
      double toD(Object? v) => (v as num).toDouble();
      final grain = raw['grain'] as Map<String, Object?>;
      final leak = raw['leak'] as Map<String, Object?>;

      expect(verano.kind, FilmKind.color);
      expect(verano.exposure, toD(raw['exposure']));
      expect(verano.saturation, toD(raw['saturation']));
      expect(verano.matrix, (raw['matrix'] as List<Object?>).map(toD).toList());
      expect(verano.curve.master.points.first.x, 0);
      expect(verano.curve.master.points.last.x, 1);
      expect(verano.grain.amount, toD(grain['amount']));
      expect(verano.leak.amount, toD(leak['amount']));
      expect(verano.notes, isNotNull);
    });

    test('keeps the ids of the book unique', () {
      final book = RecipeBook.parse(shippedJson());
      final ids = book.recipes.map((Recipe recipe) => recipe.id).toList();

      expect(ids.toSet().length, ids.length);
    });

    test('writes the book back with the same values', () {
      final book = RecipeBook.parse(shippedJson());
      final again = RecipeBook.parse(jsonEncode(book.toJson()));

      expect(again.toJson(), book.toJson());
    });

    test('throws with every error when the book is not valid', () {
      expect(
        () => RecipeBook.parse('{"schemaVersion":2}'),
        throwsA(
          isA<RecipeFormatException>().having(
            (RecipeFormatException error) => error.errors.length,
            'errors',
            greaterThan(1),
          ),
        ),
      );
    });

    test('tryParse returns the errors instead of throwing', () {
      final result = RecipeBook.tryParse('{"schemaVersion":1}');

      expect(result.isValid, isFalse);
      expect(result.book, isNull);
      expect(result.errors, isNotEmpty);
    });

    test('tryParse returns the book when it is valid', () {
      final result = RecipeBook.tryParse(shippedJson());

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
      expect(result.book, isNotNull);
    });

    test('reports a broken JSON as one error', () {
      final result = RecipeBook.tryParse('{not json');

      expect(result.isValid, isFalse);
      expect(result.errors.length, 1);
      expect(result.errors.single.path, '.');
      expect(result.errors.single.message, contains('invalid JSON'));
    });
  });
}
