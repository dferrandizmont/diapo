/// Validation of the recipe format.
///
/// The rules implemented here are the single source of truth of the format;
/// `schema/recipes.schema.json` mirrors them for editors and for the test
/// that checks that both agree. The validator never stops at the first
/// problem: every error is reported with the JSON path where it was found.
library;

/// The version of the recipe format this package understands.
const int kSupportedSchemaVersion = 1;

/// The film kinds the format accepts.
const List<String> kFilmKinds = <String>['color', 'bw'];

/// The frame formats the format accepts.
const List<String> kFrameFormats = <String>['3:2', '4:3', '1:1', '16:9'];

/// The pattern a recipe id must follow.
const String kIdPattern = r'^[a-z0-9-]{2,40}$';

/// The pattern the band colour of a recipe must follow.
const String kBandColorPattern = r'^#[0-9a-fA-F]{6}$';

/// The pattern the version of the recipe book must follow.
const String kRecipesVersionPattern = r'^\d+\.\d+\.\d+$';

/// The languages every name and description is written in.
const List<String> kLanguages = <String>['es', 'ca', 'en'];

/// A problem found while validating a recipe book.
final class ValidationError {
  /// Creates an error for the value at [path].
  const ValidationError(this.path, this.message);

  /// The JSON path of the offending value, for example `recipes[2].grain.amount`.
  final String path;

  /// What is wrong with that value.
  final String message;

  /// The error on one line: `path: message`.
  String get formatted => '$path: $message';

  @override
  String toString() => formatted;

  @override
  bool operator ==(Object other) =>
      other is ValidationError &&
      other.path == path &&
      other.message == message;

  @override
  int get hashCode => Object.hash(path, message);
}

/// Thrown when a recipe book does not follow the format.
final class RecipeFormatException implements Exception {
  /// Creates an exception carrying every [errors] found.
  RecipeFormatException(this.errors)
    : message = errors.map((ValidationError e) => e.formatted).join('\n');

  /// Every problem found, in the order they were detected.
  final List<ValidationError> errors;

  /// The errors as one block of text.
  final String message;

  @override
  String toString() => 'RecipeFormatException:\n$message';
}

/// Checks decoded recipe JSON against the rules of the format.
abstract final class RecipeValidator {
  /// Validates the decoded [json] of a recipe book.
  ///
  /// Returns an empty list when the book is valid.
  static List<ValidationError> validate(Object? json) => _Checker().run(json);
}

class _Checker {
  final List<ValidationError> errors = <ValidationError>[];

  List<ValidationError> run(Object? json) {
    if (json is! Map<String, dynamic>) {
      errors.add(const ValidationError('.', 'expected a JSON object'));
      return errors;
    }

    _checkKeys(json, const <String>{
      'schemaVersion',
      'recipesVersion',
      'recipes',
    }, '');
    _checkSchemaVersion(json, '');
    _checkRecipesVersion(json, '');
    _checkRecipes(json, '');
    return errors;
  }

  // --- book -----------------------------------------------------------------

  void _checkSchemaVersion(Map<String, dynamic> json, String path) {
    final value = json['schemaVersion'];
    final field = _join(path, 'schemaVersion');
    if (value == null) {
      errors.add(ValidationError(field, 'is required'));
    } else if (value is! num || !_isInteger(value)) {
      errors.add(ValidationError(field, 'must be an integer'));
    } else if (value.toInt() != kSupportedSchemaVersion) {
      errors.add(ValidationError(field, 'must be $kSupportedSchemaVersion'));
    }
  }

  void _checkRecipesVersion(Map<String, dynamic> json, String path) {
    final value = json['recipesVersion'];
    final field = _join(path, 'recipesVersion');
    if (value == null) {
      errors.add(ValidationError(field, 'is required'));
    } else if (value is! String) {
      errors.add(ValidationError(field, 'must be a string'));
    } else if (!RegExp(kRecipesVersionPattern).hasMatch(value)) {
      errors.add(ValidationError(field, 'must look like 2026.11.1'));
    }
  }

  void _checkRecipes(Map<String, dynamic> json, String path) {
    final value = json['recipes'];
    if (value == null) {
      errors.add(ValidationError(_join(path, 'recipes'), 'is required'));
      return;
    }
    if (value is! List) {
      errors.add(ValidationError(_join(path, 'recipes'), 'must be an array'));
      return;
    }
    if (value.isEmpty) {
      errors.add(
        ValidationError(
          _join(path, 'recipes'),
          'must hold at least one recipe',
        ),
      );
      return;
    }

    final recipesPath = _join(path, 'recipes');
    final ids = <String, int>{};
    for (var i = 0; i < value.length; i++) {
      final itemPath = '$recipesPath[$i]';
      final item = value[i];
      if (item is! Map<String, dynamic>) {
        errors.add(ValidationError(itemPath, 'must be an object'));
        continue;
      }
      _checkRecipe(item, itemPath, i, ids);
    }
  }

  // --- recipe ---------------------------------------------------------------

  void _checkRecipe(
    Map<String, dynamic> json,
    String path,
    int index,
    Map<String, int> ids,
  ) {
    _checkKeys(json, const <String>{
      'id',
      'name',
      'description',
      'kind',
      'defaults',
      'exposure',
      'saturation',
      'matrix',
      'shadowTint',
      'highlightTint',
      'curve',
      'grain',
      'halation',
      'leak',
      'vignette',
      'wbDrift',
      'bandColor',
      'notes',
    }, path);
    _checkId(json, path, index, ids);
    _checkLocalized(json, 'name', path);
    _checkLocalized(json, 'description', path);
    _checkKind(json, path);
    _checkDefaults(json, path);
    _checkNumber(json, 'exposure', path, -2, 2);
    _checkNumber(json, 'saturation', path, 0, 2);
    _checkNumberArray(json, 'matrix', path, 9, -2, 2);
    _checkNumberArray(json, 'shadowTint', path, 3, -0.2, 0.2);
    _checkNumberArray(json, 'highlightTint', path, 3, -0.2, 0.2);
    _checkCurve(json, path);
    _checkGrain(json, path);
    _checkHalation(json, path);
    _checkLeak(json, path);
    _checkVignette(json, path);
    _checkNumber(json, 'wbDrift', path, 0, 0.1);
    _checkBandColor(json, path);
    _checkNotes(json, path);
  }

  void _checkId(
    Map<String, dynamic> json,
    String path,
    int index,
    Map<String, int> ids,
  ) {
    final value = json['id'];
    final field = _join(path, 'id');
    if (value == null) {
      errors.add(ValidationError(field, 'is required'));
      return;
    }
    if (value is! String) {
      errors.add(ValidationError(field, 'must be a string'));
      return;
    }
    if (!RegExp(kIdPattern).hasMatch(value)) {
      errors.add(ValidationError(field, 'must match $kIdPattern'));
      return;
    }
    final previous = ids[value];
    if (previous != null) {
      errors.add(
        ValidationError(field, 'is already used by recipes[$previous]'),
      );
    } else {
      ids[value] = index;
    }
  }

  void _checkLocalized(Map<String, dynamic> json, String key, String path) {
    final value = json[key];
    final field = _join(path, key);
    if (value == null) {
      errors.add(ValidationError(field, 'is required'));
      return;
    }
    if (value is! Map<String, dynamic>) {
      errors.add(ValidationError(field, 'must be an object'));
      return;
    }
    _checkKeys(value, kLanguages.toSet(), field);
    for (final language in kLanguages) {
      final text = value[language];
      final languagePath = _join(field, language);
      if (text == null) {
        errors.add(ValidationError(languagePath, 'is required'));
      } else if (text is! String) {
        errors.add(ValidationError(languagePath, 'must be a string'));
      } else if (text.isEmpty) {
        errors.add(ValidationError(languagePath, 'must not be empty'));
      }
    }
  }

  void _checkKind(Map<String, dynamic> json, String path) {
    final value = json['kind'];
    if (value == null) {
      return;
    }
    final field = _join(path, 'kind');
    if (value is! String) {
      errors.add(ValidationError(field, 'must be a string'));
    } else if (!kFilmKinds.contains(value)) {
      errors.add(
        ValidationError(field, 'must be one of ${kFilmKinds.join(', ')}'),
      );
    }
  }

  void _checkDefaults(Map<String, dynamic> json, String path) {
    final value = json['defaults'];
    if (value == null) {
      return;
    }
    final field = _join(path, 'defaults');
    if (value is! Map<String, dynamic>) {
      errors.add(ValidationError(field, 'must be an object'));
      return;
    }
    _checkKeys(value, const <String>{
      'format',
      'dateStamp',
      'whiteFrame',
      'cinemaBands',
    }, field);

    final format = value['format'];
    if (format != null) {
      final formatPath = _join(field, 'format');
      if (format is! String) {
        errors.add(ValidationError(formatPath, 'must be a string'));
      } else if (!kFrameFormats.contains(format)) {
        errors.add(
          ValidationError(
            formatPath,
            'must be one of ${kFrameFormats.join(', ')}',
          ),
        );
      }
    }
    for (final flag in const <String>[
      'dateStamp',
      'whiteFrame',
      'cinemaBands',
    ]) {
      final enabled = value[flag];
      if (enabled != null && enabled is! bool) {
        errors.add(ValidationError(_join(field, flag), 'must be a boolean'));
      }
    }
  }

  void _checkNumber(
    Map<String, dynamic> json,
    String key,
    String path,
    double min,
    double max,
  ) {
    final value = json[key];
    if (value == null) {
      return;
    }
    final field = _join(path, key);
    if (value is! num) {
      errors.add(ValidationError(field, 'must be a number'));
      return;
    }
    final number = value.toDouble();
    if (number < min) {
      errors.add(
        ValidationError(
          field,
          '${_formatNumber(number)} is below the minimum '
          '${_formatNumber(min)}',
        ),
      );
    } else if (number > max) {
      errors.add(
        ValidationError(
          field,
          '${_formatNumber(number)} is above the maximum '
          '${_formatNumber(max)}',
        ),
      );
    }
  }

  void _checkNumberArray(
    Map<String, dynamic> json,
    String key,
    String path,
    int length,
    double min,
    double max,
  ) {
    final value = json[key];
    if (value == null) {
      return;
    }
    final field = _join(path, key);
    if (value is! List) {
      errors.add(ValidationError(field, 'must be an array'));
      return;
    }
    if (value.length != length) {
      errors.add(ValidationError(field, 'must hold $length numbers'));
      return;
    }
    for (var i = 0; i < value.length; i++) {
      final item = value[i];
      final itemPath = '$field[$i]';
      if (item is! num) {
        errors.add(ValidationError(itemPath, 'must be a number'));
        continue;
      }
      final number = item.toDouble();
      if (number < min) {
        errors.add(
          ValidationError(
            itemPath,
            '${_formatNumber(number)} is below the minimum '
            '${_formatNumber(min)}',
          ),
        );
      } else if (number > max) {
        errors.add(
          ValidationError(
            itemPath,
            '${_formatNumber(number)} is above the maximum '
            '${_formatNumber(max)}',
          ),
        );
      }
    }
  }

  void _checkCurve(Map<String, dynamic> json, String path) {
    final value = json['curve'];
    if (value == null) {
      return;
    }
    final field = _join(path, 'curve');
    if (value is! Map<String, dynamic>) {
      errors.add(ValidationError(field, 'must be an object'));
      return;
    }
    _checkKeys(value, const <String>{'master', 'r', 'g', 'b'}, field);
    for (final channel in const <String>['master', 'r', 'g', 'b']) {
      _checkCurvePoints(value, channel, field);
    }
  }

  void _checkCurvePoints(Map<String, dynamic> json, String key, String path) {
    final value = json[key];
    if (value == null) {
      return;
    }
    final field = _join(path, key);
    if (value is! List) {
      errors.add(ValidationError(field, 'must be an array'));
      return;
    }
    if (value.length < 2) {
      errors.add(ValidationError(field, 'needs at least 2 points'));
      return;
    }
    if (value.length > 16) {
      errors.add(ValidationError(field, 'holds at most 16 points'));
      return;
    }

    var previousX = double.negativeInfinity;
    for (var i = 0; i < value.length; i++) {
      final pointPath = '$field[$i]';
      final point = value[i];
      if (point is! List) {
        errors.add(
          ValidationError(pointPath, 'must be an array of two numbers'),
        );
        return;
      }
      if (point.length != 2) {
        errors.add(ValidationError(pointPath, 'must hold exactly two numbers'));
        return;
      }
      final x = point[0];
      final y = point[1];
      if (x is! num || y is! num) {
        errors.add(ValidationError(pointPath, 'must hold two numbers'));
        return;
      }
      final dx = x.toDouble();
      final dy = y.toDouble();
      if (dx < 0 || dx > 1) {
        errors.add(ValidationError('$pointPath[0]', '$dx is outside 0..1'));
      }
      if (dy < 0 || dy > 1) {
        errors.add(ValidationError('$pointPath[1]', '$dy is outside 0..1'));
      }
      if (i == 0 && dx != 0) {
        errors.add(ValidationError('$pointPath[0]', 'must be 0'));
      }
      if (i == value.length - 1 && dx != 1) {
        errors.add(ValidationError('$pointPath[0]', 'must be 1'));
      }
      if (i > 0 && dx <= previousX) {
        errors.add(
          ValidationError(
            '$pointPath[0]',
            'must be greater than the previous x',
          ),
        );
      }
      previousX = dx;
    }
  }

  void _checkGrain(Map<String, dynamic> json, String path) {
    final value = json['grain'];
    if (value == null) {
      return;
    }
    final field = _join(path, 'grain');
    if (value is! Map<String, dynamic>) {
      errors.add(ValidationError(field, 'must be an object'));
      return;
    }
    _checkKeys(value, const <String>{'amount', 'size'}, field);
    _checkNumber(value, 'amount', field, 0, 1);
    _checkNumber(value, 'size', field, 0.25, 4);
  }

  void _checkHalation(Map<String, dynamic> json, String path) {
    final value = json['halation'];
    if (value == null) {
      return;
    }
    final field = _join(path, 'halation');
    if (value is! Map<String, dynamic>) {
      errors.add(ValidationError(field, 'must be an object'));
      return;
    }
    _checkKeys(value, const <String>{
      'amount',
      'threshold',
      'radius',
      'color',
    }, field);
    _checkNumber(value, 'amount', field, 0, 1);
    _checkNumber(value, 'threshold', field, 0, 1);
    _checkNumber(value, 'radius', field, 0, 0.05);
    _checkNumberArray(value, 'color', field, 3, 0, 1);
  }

  void _checkLeak(Map<String, dynamic> json, String path) {
    final value = json['leak'];
    if (value == null) {
      return;
    }
    final field = _join(path, 'leak');
    if (value is! Map<String, dynamic>) {
      errors.add(ValidationError(field, 'must be an object'));
      return;
    }
    _checkKeys(value, const <String>{
      'amount',
      'position',
      'radius',
      'color',
    }, field);
    _checkNumber(value, 'amount', field, 0, 1);
    _checkNumberArray(value, 'position', field, 2, 0, 1);
    _checkNumber(value, 'radius', field, 0.05, 1.5);
    _checkNumberArray(value, 'color', field, 3, 0, 1);
  }

  void _checkVignette(Map<String, dynamic> json, String path) {
    final value = json['vignette'];
    if (value == null) {
      return;
    }
    final field = _join(path, 'vignette');
    if (value is! Map<String, dynamic>) {
      errors.add(ValidationError(field, 'must be an object'));
      return;
    }
    _checkKeys(value, const <String>{'amount', 'softness'}, field);
    _checkNumber(value, 'amount', field, 0, 1);
    _checkNumber(value, 'softness', field, 0, 1);
  }

  void _checkBandColor(Map<String, dynamic> json, String path) {
    if (!json.containsKey('bandColor')) {
      return;
    }
    final value = json['bandColor'];
    final field = _join(path, 'bandColor');
    if (value is! String) {
      errors.add(ValidationError(field, 'must be a string'));
    } else if (!RegExp(kBandColorPattern).hasMatch(value)) {
      errors.add(ValidationError(field, 'must match $kBandColorPattern'));
    }
  }

  void _checkNotes(Map<String, dynamic> json, String path) {
    final value = json['notes'];
    if (value != null && value is! String) {
      errors.add(ValidationError(_join(path, 'notes'), 'must be a string'));
    }
  }

  // --- helpers --------------------------------------------------------------

  void _checkKeys(Map<String, dynamic> json, Set<String> allowed, String path) {
    for (final key in json.keys) {
      if (!allowed.contains(key)) {
        errors.add(ValidationError(_join(path, key), 'is not a known key'));
      }
    }
  }
}

/// Joins a JSON path with a key.
String _join(String path, String key) => path.isEmpty ? key : '$path.$key';

/// Whether [value] is a number without a fractional part.
bool _isInteger(num value) => value == value.roundToDouble();

/// Writes a number the way the errors of the format do: whole numbers have no
/// decimal part.
String _formatNumber(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : '$value';
