import 'package:film_recipes/film_recipes.dart';
import 'package:test/test.dart';

/// The name of a recipe with the least fields the format allows.
const String _name = '"name":{"es":"a","ca":"b","en":"c"}';

/// The description of a recipe with the least fields the format allows.
const String _description = '"description":{"es":"a","ca":"b","en":"c"}';

/// The fields of a recipe with the least fields the format allows.
const String _fields = '"id":"prueba",$_name,$_description';

/// A recipe with the given [fields].
String recipe(String fields) => '{$fields}';

/// A book with one recipe, where [recipe] replaces the default one.
String bookWith(String recipe) =>
    '{"schemaVersion":1,"recipesVersion":"1.0.0","recipes":[$recipe]}';

/// The errors of the book of [json], which must not be valid.
List<ValidationError> errorsOf(String json) {
  final result = RecipeBook.tryParse(json);
  expect(result.book, isNull, reason: 'the book should not have been parsed');
  return result.errors;
}

/// Expects that the book of [json] is not valid and that one of its errors is
/// about [path].
void expectInvalid(String json, String path) {
  final errors = errorsOf(json);
  expect(errors, isNotEmpty, reason: 'no error was reported for $path');
  expect(
    errors.map((ValidationError error) => error.path),
    contains(path),
    reason: 'the error about $path is missing in ${errors.join(', ')}',
  );
}

void main() {
  test('rejects cinema bands that are not a boolean', () {
    expectInvalid(
      bookWith(recipe('$_fields,"defaults":{"cinemaBands":"yes"}')),
      'recipes[0].defaults.cinemaBands',
    );
  });

  group('the book', () {
    test('rejects a document that is not an object', () {
      expectInvalid('[]', '.');
    });

    test('rejects a missing schemaVersion', () {
      expectInvalid('{"recipesVersion":"1.0.0","recipes":[]}', 'schemaVersion');
    });

    test('rejects a schemaVersion that is not a whole number', () {
      expectInvalid(
        '{"schemaVersion":"1","recipesVersion":"1.0.0","recipes":[]}',
        'schemaVersion',
      );
    });

    test('rejects a schemaVersion the engine does not know', () {
      expectInvalid(
        '{"schemaVersion":2,"recipesVersion":"1.0.0","recipes":[]}',
        'schemaVersion',
      );
    });

    test('rejects a missing recipesVersion', () {
      expectInvalid('{"schemaVersion":1,"recipes":[]}', 'recipesVersion');
    });

    test('rejects a recipesVersion that is not a string', () {
      expectInvalid(
        '{"schemaVersion":1,"recipesVersion":1,"recipes":[]}',
        'recipesVersion',
      );
    });

    test('rejects a recipesVersion that does not look like a version', () {
      expectInvalid(
        '{"schemaVersion":1,"recipesVersion":"primera","recipes":[]}',
        'recipesVersion',
      );
    });

    test('rejects a missing list of recipes', () {
      expectInvalid('{"schemaVersion":1,"recipesVersion":"1.0.0"}', 'recipes');
    });

    test('rejects a list of recipes that is not an array', () {
      expectInvalid(
        '{"schemaVersion":1,"recipesVersion":"1.0.0","recipes":{}}',
        'recipes',
      );
    });

    test('rejects a book without recipes', () {
      expectInvalid(
        '{"schemaVersion":1,"recipesVersion":"1.0.0","recipes":[]}',
        'recipes',
      );
    });

    test('rejects a recipe that is not an object', () {
      expectInvalid(bookWith('"hola"'), 'recipes[0]');
    });

    test('rejects an unknown key at the top level', () {
      expectInvalid(
        '{"schemaVersion":1,"recipesVersion":"1.0.0","recipes":[],"extra":1}',
        'extra',
      );
    });

    test('reports every error and not only the first', () {
      final errors = errorsOf(
        '{"schemaVersion":2,"recipesVersion":"x","recipes":[]}',
      );

      expect(errors.length, greaterThanOrEqualTo(3));
    });
  });

  group('a recipe', () {
    test('rejects a missing id', () {
      expectInvalid(bookWith(recipe('$_name,$_description')), 'recipes[0].id');
    });

    test('rejects an id that is not a string', () {
      expectInvalid(
        bookWith(recipe('"id":7,$_name,$_description')),
        'recipes[0].id',
      );
    });

    test('rejects an id that does not follow the pattern', () {
      expectInvalid(
        bookWith(recipe('"id":"Verano 98!",$_name,$_description')),
        'recipes[0].id',
      );
    });

    test('rejects an id that is too short', () {
      expectInvalid(
        bookWith(recipe('"id":"a",$_name,$_description')),
        'recipes[0].id',
      );
    });

    test('rejects an id that is used twice', () {
      expectInvalid(
        bookWith('${recipe(_fields)},${recipe(_fields)}'),
        'recipes[1].id',
      );
    });

    test('rejects a missing name', () {
      expectInvalid(
        bookWith(recipe('"id":"prueba",$_description')),
        'recipes[0].name',
      );
    });

    test('rejects a name that is not an object', () {
      expectInvalid(
        bookWith(recipe('"id":"prueba","name":"a",$_description')),
        'recipes[0].name',
      );
    });

    test('rejects a name without every language', () {
      expectInvalid(
        bookWith(
          recipe('"id":"prueba","name":{"es":"a","en":"c"},$_description'),
        ),
        'recipes[0].name.ca',
      );
    });

    test('rejects an empty name', () {
      expectInvalid(
        bookWith(
          recipe(
            '"id":"prueba","name":{"es":"","ca":"b","en":"c"},$_description',
          ),
        ),
        'recipes[0].name.es',
      );
    });

    test('rejects a name with an unknown language', () {
      expectInvalid(
        bookWith(
          recipe(
            '"id":"prueba","name":{"es":"a","ca":"b","en":"c","fr":"d"},'
            '$_description',
          ),
        ),
        'recipes[0].name.fr',
      );
    });

    test('rejects a missing description', () {
      expectInvalid(
        bookWith(recipe('"id":"prueba",$_name')),
        'recipes[0].description',
      );
    });

    test('rejects an unknown key in a recipe', () {
      expectInvalid(
        bookWith(recipe('$_fields,"brillo":1')),
        'recipes[0].brillo',
      );
    });

    test('rejects a kind that is not known', () {
      expectInvalid(
        bookWith(recipe('$_fields,"kind":"sepia"')),
        'recipes[0].kind',
      );
    });

    test('rejects a kind that is not a string', () {
      expectInvalid(bookWith(recipe('$_fields,"kind":1')), 'recipes[0].kind');
    });

    test('rejects defaults that are not an object', () {
      expectInvalid(
        bookWith(recipe('$_fields,"defaults":1')),
        'recipes[0].defaults',
      );
    });

    test('rejects an unknown key in the defaults', () {
      expectInvalid(
        bookWith(recipe('$_fields,"defaults":{"marco":true}')),
        'recipes[0].defaults.marco',
      );
    });

    test('rejects a format that is not known', () {
      expectInvalid(
        bookWith(recipe('$_fields,"defaults":{"format":"5:4"}')),
        'recipes[0].defaults.format',
      );
    });

    test('rejects a date stamp that is not a boolean', () {
      expectInvalid(
        bookWith(recipe('$_fields,"defaults":{"dateStamp":"si"}')),
        'recipes[0].defaults.dateStamp',
      );
    });

    test('rejects a white frame that is not a boolean', () {
      expectInvalid(
        bookWith(recipe('$_fields,"defaults":{"whiteFrame":"si"}')),
        'recipes[0].defaults.whiteFrame',
      );
    });

    test('rejects an exposure out of range', () {
      expectInvalid(
        bookWith(recipe('$_fields,"exposure":2.5')),
        'recipes[0].exposure',
      );
    });

    test('rejects an exposure that is not a number', () {
      expectInvalid(
        bookWith(recipe('$_fields,"exposure":"0"')),
        'recipes[0].exposure',
      );
    });

    test('rejects a saturation out of range', () {
      expectInvalid(
        bookWith(recipe('$_fields,"saturation":3')),
        'recipes[0].saturation',
      );
    });

    test('rejects a matrix that is not an array', () {
      expectInvalid(
        bookWith(recipe('$_fields,"matrix":1')),
        'recipes[0].matrix',
      );
    });

    test('rejects a matrix that does not hold nine numbers', () {
      expectInvalid(
        bookWith(recipe('$_fields,"matrix":[1,0,0,0,1,0,0,0]')),
        'recipes[0].matrix',
      );
    });

    test('rejects a matrix value out of range', () {
      expectInvalid(
        bookWith(recipe('$_fields,"matrix":[1,0,0,0,1,0,0,0,3]')),
        'recipes[0].matrix[8]',
      );
    });

    test('rejects a shadow tint that does not hold three numbers', () {
      expectInvalid(
        bookWith(recipe('$_fields,"shadowTint":[0,0]')),
        'recipes[0].shadowTint',
      );
    });

    test('rejects a shadow tint value out of range', () {
      expectInvalid(
        bookWith(recipe('$_fields,"shadowTint":[0,0,0.5]')),
        'recipes[0].shadowTint[2]',
      );
    });

    test('rejects a highlight tint value out of range', () {
      expectInvalid(
        bookWith(recipe('$_fields,"highlightTint":[-0.5,0,0]')),
        'recipes[0].highlightTint[0]',
      );
    });

    test('rejects notes that are not a string', () {
      expectInvalid(bookWith(recipe('$_fields,"notes":7')), 'recipes[0].notes');
    });
  });

  group('the curves', () {
    test('rejects a curve that is not an object', () {
      expectInvalid(bookWith(recipe('$_fields,"curve":1')), 'recipes[0].curve');
    });

    test('rejects an unknown channel', () {
      expectInvalid(
        bookWith(recipe('$_fields,"curve":{"y":[[0,0],[1,1]]}')),
        'recipes[0].curve.y',
      );
    });

    test('rejects a curve with a single point', () {
      expectInvalid(
        bookWith(recipe('$_fields,"curve":{"master":[[0,0]]}')),
        'recipes[0].curve.master',
      );
    });

    test('rejects a curve with too many points', () {
      final points = List<String>.generate(
        17,
        (int i) => '[${i / 16},0.5]',
      ).join(',');
      expectInvalid(
        bookWith(recipe('$_fields,"curve":{"master":[$points]}')),
        'recipes[0].curve.master',
      );
    });

    test('rejects a point that is not a pair', () {
      expectInvalid(
        bookWith(recipe('$_fields,"curve":{"master":[[0],[1]]}')),
        'recipes[0].curve.master[0]',
      );
    });

    test('rejects a point that is not made of numbers', () {
      expectInvalid(
        bookWith(recipe('$_fields,"curve":{"master":[["0",0],[1,1]]}')),
        'recipes[0].curve.master[0]',
      );
    });

    test('rejects a curve that does not start at zero', () {
      expectInvalid(
        bookWith(recipe('$_fields,"curve":{"master":[[0.1,0],[1,1]]}')),
        'recipes[0].curve.master[0][0]',
      );
    });

    test('rejects a curve that does not end at one', () {
      expectInvalid(
        bookWith(recipe('$_fields,"curve":{"master":[[0,0],[0.9,1]]}')),
        'recipes[0].curve.master[1][0]',
      );
    });

    test('rejects a curve whose x does not increase', () {
      expectInvalid(
        bookWith(
          recipe(
            '$_fields,"curve":{"master":[[0,0],[0.5,0.4],[0.4,0.8],[1,1]]}',
          ),
        ),
        'recipes[0].curve.master[2][0]',
      );
    });

    test('rejects a point outside the unit square', () {
      expectInvalid(
        bookWith(recipe('$_fields,"curve":{"master":[[0,0],[1,1.5]]}')),
        'recipes[0].curve.master[1][1]',
      );
    });
  });

  group('the grain, the halation, the leak and the vignette', () {
    test('rejects a grain amount out of range', () {
      expectInvalid(
        bookWith(recipe('$_fields,"grain":{"amount":1.4}')),
        'recipes[0].grain.amount',
      );
    });

    test('rejects a grain size out of range', () {
      expectInvalid(
        bookWith(recipe('$_fields,"grain":{"size":0.1}')),
        'recipes[0].grain.size',
      );
    });

    test('rejects an unknown key in the grain', () {
      expectInvalid(
        bookWith(recipe('$_fields,"grain":{"fino":true}')),
        'recipes[0].grain.fino',
      );
    });

    test('rejects a halation amount out of range', () {
      expectInvalid(
        bookWith(recipe('$_fields,"halation":{"amount":-0.1}')),
        'recipes[0].halation.amount',
      );
    });

    test('rejects a halation threshold out of range', () {
      expectInvalid(
        bookWith(recipe('$_fields,"halation":{"threshold":2}')),
        'recipes[0].halation.threshold',
      );
    });

    test('rejects a halation radius out of range', () {
      expectInvalid(
        bookWith(recipe('$_fields,"halation":{"radius":0.1}')),
        'recipes[0].halation.radius',
      );
    });

    test('rejects a halation colour that does not hold three numbers', () {
      expectInvalid(
        bookWith(recipe('$_fields,"halation":{"color":[1,0]}')),
        'recipes[0].halation.color',
      );
    });

    test('rejects a halation colour out of range', () {
      expectInvalid(
        bookWith(recipe('$_fields,"halation":{"color":[1,0,1.5]}')),
        'recipes[0].halation.color[2]',
      );
    });

    test('rejects a leak amount out of range', () {
      expectInvalid(
        bookWith(recipe('$_fields,"leak":{"amount":1.4}')),
        'recipes[0].leak.amount',
      );
    });

    test('rejects a leak position that does not hold two numbers', () {
      expectInvalid(
        bookWith(recipe('$_fields,"leak":{"position":[0.5]}')),
        'recipes[0].leak.position',
      );
    });

    test('rejects a leak position out of range', () {
      expectInvalid(
        bookWith(recipe('$_fields,"leak":{"position":[1.5,0.5]}')),
        'recipes[0].leak.position[0]',
      );
    });

    test('rejects a leak radius out of range', () {
      expectInvalid(
        bookWith(recipe('$_fields,"leak":{"radius":0.01}')),
        'recipes[0].leak.radius',
      );
    });

    test('rejects a vignette amount out of range', () {
      expectInvalid(
        bookWith(recipe('$_fields,"vignette":{"amount":1.4}')),
        'recipes[0].vignette.amount',
      );
    });

    test('rejects a vignette softness out of range', () {
      expectInvalid(
        bookWith(recipe('$_fields,"vignette":{"softness":-1}')),
        'recipes[0].vignette.softness',
      );
    });

    test('rejects a white balance drift out of range', () {
      expectInvalid(
        bookWith(recipe('$_fields,"wbDrift":0.2')),
        'recipes[0].wbDrift',
      );
    });
  });

  group('the message of an error', () {
    test('tells what is wrong and where', () {
      final errors = errorsOf(
        bookWith(recipe('$_fields,"grain":{"amount":1.4}')),
      );

      expect(
        errors.single.formatted,
        'recipes[0].grain.amount: 1.4 is above the maximum 1',
      );
    });
  });
}
