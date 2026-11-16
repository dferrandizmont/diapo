import 'dart:convert';
import 'dart:io';

import 'package:film_recipes/film_recipes.dart';
import 'package:json_schema/json_schema.dart';
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

/// The schema of the format.
JsonSchema _schema() {
  final text = File('schema/recipes.schema.json').readAsStringSync();
  return JsonSchema.create(jsonDecode(text) as Map<String, dynamic>);
}

/// Whether the validator of the engine accepts [json].
bool _validatorAccepts(String json) => RecipeBook.tryParse(json).isValid;

/// Whether the schema accepts [json].
bool _schemaAccepts(JsonSchema schema, String json) =>
    schema.validate(jsonDecode(json)).isValid;

/// What the schema says about [json].
String _schemaSays(JsonSchema schema, String json) =>
    schema.validate(jsonDecode(json)).errors.toString();

void main() {
  final schema = _schema();

  group('the schema of the format', () {
    test('accepts the recipes the app ships with', () {
      final json = File('assets/recipes.json').readAsStringSync();

      expect(_validatorAccepts(json), isTrue);
      expect(
        _schemaAccepts(schema, json),
        isTrue,
        reason: 'the schema says: ${_schemaSays(schema, json)}',
      );
    });

    test('accepts the book the engine writes back', () {
      final book = RecipeBook.parse(
        File('assets/recipes.json').readAsStringSync(),
      );
      final json = jsonEncode(book.toJson());

      expect(
        _schemaAccepts(schema, json),
        isTrue,
        reason: 'the schema says: ${_schemaSays(schema, json)}',
      );
    });
  });

  group('the validator and the schema agree', () {
    // The rules that JSON Schema cannot write are checked by the validator
    // alone: the x of the curve points must increase strictly, the last
    // point of a curve must end at x = 1 and the ids of the book must be
    // unique.
    final List<String> valid = <String>[
      bookWith(recipe(_fields)),
      bookWith(recipe('$_fields,"kind":"bw"')),
      bookWith(recipe('$_fields,"exposure":-2')),
      bookWith(recipe('$_fields,"saturation":2')),
      bookWith(recipe('$_fields,"matrix":[2,2,2,2,2,2,2,2,2]')),
      bookWith(recipe('$_fields,"shadowTint":[-0.2,-0.2,-0.2]')),
      bookWith(recipe('$_fields,"highlightTint":[0.2,0.2,0.2]')),
      bookWith(
        recipe(
          '$_fields,"defaults":{"format":"16:9","dateStamp":true,'
          '"whiteFrame":true}',
        ),
      ),
      bookWith(recipe('$_fields,"grain":{"amount":1,"size":4}')),
      bookWith(
        recipe(
          '$_fields,"halation":{"amount":1,"threshold":1,"radius":0.05,'
          '"color":[1,1,1]}',
        ),
      ),
      bookWith(
        recipe(
          '$_fields,"leak":{"amount":1,"position":[1,1],"radius":1.5,'
          '"color":[0,0,0]}',
        ),
      ),
      bookWith(recipe('$_fields,"vignette":{"amount":1,"softness":1}')),
      bookWith(recipe('$_fields,"wbDrift":0.1')),
      bookWith(recipe('$_fields,"notes":"una nota"')),
      bookWith(recipe('$_fields,"bandColor":"#e0a030"')),
      bookWith(recipe('$_fields,"curve":{"master":[[0,0],[0.5,0.5],[1,1]]}')),
    ];

    final List<String> invalid = <String>[
      '{"recipesVersion":"1.0.0","recipes":[]}',
      '{"schemaVersion":"1","recipesVersion":"1.0.0","recipes":[]}',
      '{"schemaVersion":2,"recipesVersion":"1.0.0","recipes":[]}',
      '{"schemaVersion":1,"recipes":[]}',
      '{"schemaVersion":1,"recipesVersion":1,"recipes":[]}',
      '{"schemaVersion":1,"recipesVersion":"primera","recipes":[]}',
      '{"schemaVersion":1,"recipesVersion":"1.0.0"}',
      '{"schemaVersion":1,"recipesVersion":"1.0.0","recipes":{}}',
      '{"schemaVersion":1,"recipesVersion":"1.0.0","recipes":[]}',
      '{"schemaVersion":1,"recipesVersion":"1.0.0","recipes":[],"extra":1}',
      bookWith('"hola"'),
      bookWith(recipe('$_name,$_description')),
      bookWith(recipe('"id":7,$_name,$_description')),
      bookWith(recipe('"id":"Verano 98!",$_name,$_description')),
      bookWith(
        recipe('"id":"prueba","name":{"es":"a","en":"c"},$_description'),
      ),
      bookWith(
        recipe(
          '"id":"prueba","name":{"es":"","ca":"b","en":"c"},$_description',
        ),
      ),
      bookWith(recipe('"id":"prueba",$_description')),
      bookWith(recipe('$_fields,"brillo":1')),
      bookWith(recipe('$_fields,"kind":"sepia"')),
      bookWith(recipe('$_fields,"defaults":{"format":"5:4"}')),
      bookWith(recipe('$_fields,"defaults":{"dateStamp":"si"}')),
      bookWith(recipe('$_fields,"exposure":2.5')),
      bookWith(recipe('$_fields,"saturation":3')),
      bookWith(recipe('$_fields,"matrix":[1,0,0,0,1,0,0,0]')),
      bookWith(recipe('$_fields,"matrix":[1,0,0,0,1,0,0,0,3]')),
      bookWith(recipe('$_fields,"shadowTint":[0,0]')),
      bookWith(recipe('$_fields,"shadowTint":[0,0,0.5]')),
      bookWith(recipe('$_fields,"highlightTint":[-0.5,0,0]')),
      bookWith(recipe('$_fields,"notes":7')),
      bookWith(recipe('$_fields,"bandColor":"e0a030"')),
      bookWith(recipe('$_fields,"bandColor":"#e0a03"')),
      bookWith(recipe('$_fields,"bandColor":"#gggggg"')),
      bookWith(recipe('$_fields,"bandColor":16')),
      bookWith(recipe('$_fields,"bandColor":null')),
      bookWith(recipe('$_fields,"curve":{"y":[[0,0],[1,1]]}')),
      bookWith(recipe('$_fields,"curve":{"master":[[0,0]]}')),
      bookWith(recipe('$_fields,"curve":{"master":[[0],[1]]}')),
      bookWith(recipe('$_fields,"curve":{"master":[["0",0],[1,1]]}')),
      bookWith(recipe('$_fields,"curve":{"master":[[0.1,0],[1,1]]}')),
      bookWith(recipe('$_fields,"curve":{"master":[[0,0],[1,1.5]]}')),
      bookWith(recipe('$_fields,"grain":{"amount":1.4}')),
      bookWith(recipe('$_fields,"grain":{"size":0.1}')),
      bookWith(recipe('$_fields,"halation":{"radius":0.1}')),
      bookWith(recipe('$_fields,"halation":{"color":[1,0]}')),
      bookWith(recipe('$_fields,"leak":{"position":[1.5,0.5]}')),
      bookWith(recipe('$_fields,"leak":{"radius":0.01}')),
      bookWith(recipe('$_fields,"vignette":{"amount":1.4}')),
      bookWith(recipe('$_fields,"wbDrift":0.2')),
    ];

    test('on the valid fixtures', () {
      for (final json in valid) {
        expect(
          _validatorAccepts(json),
          isTrue,
          reason:
              'the validator says '
              '${RecipeBook.tryParse(json).errors}',
        );
        expect(
          _schemaAccepts(schema, json),
          isTrue,
          reason: 'the schema says ${_schemaSays(schema, json)}',
        );
      }
    });

    test('on the invalid fixtures', () {
      for (final json in invalid) {
        expect(
          _validatorAccepts(json),
          isFalse,
          reason: 'the validator accepted $json',
        );
        expect(
          _schemaAccepts(schema, json),
          isFalse,
          reason: 'the schema accepted $json',
        );
      }
    });

    test('on at least fifteen invalid fixtures', () {
      expect(invalid.length, greaterThanOrEqualTo(15));
    });
  });
}
