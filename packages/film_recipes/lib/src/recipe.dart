/// The model of a film recipe and of the book that holds them.
///
/// The model is written by hand (no code generation) so that the wire format
/// stays explicit: `assets/recipes.json` is the source of truth for the looks
/// and this file only mirrors it. Every field has a default, so a recipe may
/// leave out whatever it does not want to change.
library;

import 'dart:convert';

import 'validation.dart';

/// The colour kind of a film.
enum FilmKind {
  /// Colour film, negative or slide.
  color('color'),

  /// Black and white film: the resolved look always has zero saturation.
  bw('bw');

  const FilmKind(this.wireName);

  /// The name used in the JSON file.
  final String wireName;

  /// The kind named [value], or null when there is no such kind.
  static FilmKind? tryParse(String value) {
    for (final kind in FilmKind.values) {
      if (kind.wireName == value) {
        return kind;
      }
    }
    return null;
  }
}

/// The frame formats a recipe can default to.
enum FrameFormat {
  /// 3:2, the classic negative frame.
  r3x2('3:2'),

  /// 4:3, the frame of a compact camera.
  r4x3('4:3'),

  /// 1:1, the square frame.
  r1x1('1:1'),

  /// 16:9, the wide frame.
  r16x9('16:9');

  const FrameFormat(this.wireName);

  /// The name used in the JSON file.
  final String wireName;

  /// The format named [value], or null when there is no such format.
  static FrameFormat? tryParse(String value) {
    for (final format in FrameFormat.values) {
      if (format.wireName == value) {
        return format;
      }
    }
    return null;
  }
}

/// A name or a description in the three supported languages.
final class LocalizedText {
  /// Creates a text with its three languages.
  const LocalizedText({required this.es, required this.ca, required this.en});

  /// The Spanish text, the source of every translation.
  final String es;

  /// The Catalan text.
  final String ca;

  /// The English text.
  final String en;

  /// The three languages as a map, in the order of the JSON file.
  Map<String, String> toJson() => <String, String>{
    'es': es,
    'ca': ca,
    'en': en,
  };

  /// Reads a text from its JSON form.
  static LocalizedText fromJson(Map<String, dynamic> json) => LocalizedText(
    es: _string(json, 'es'),
    ca: _string(json, 'ca'),
    en: _string(json, 'en'),
  );
}

/// A control point of a tone curve.
final class CurvePoint {
  /// Creates a point at ([x], [y]).
  const CurvePoint(this.x, this.y);

  /// The input value of the point, from 0 to 1.
  final double x;

  /// The output value of the point, from 0 to 1.
  final double y;

  /// The point as the `[x, y]` pair of the JSON file.
  List<double> toJson() => <double>[x, y];

  @override
  bool operator ==(Object other) =>
      other is CurvePoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'CurvePoint($x, $y)';
}

/// A tone curve: control points from x=0 to x=1.
final class ToneCurve {
  /// Creates a curve from its [points].
  const ToneCurve(this.points);

  /// The curve that leaves every value untouched.
  static const ToneCurve identity = ToneCurve(<CurvePoint>[
    CurvePoint(0, 0),
    CurvePoint(1, 1),
  ]);

  /// The control points, from the lowest x to the highest.
  final List<CurvePoint> points;

  /// The curve as the list of `[x, y]` pairs of the JSON file.
  List<List<double>> toJson() =>
      points.map((CurvePoint point) => point.toJson()).toList(growable: false);
}

/// The four tone curves of a recipe: the master curve and one per channel.
final class CurveSet {
  /// Creates a set of curves.
  const CurveSet({
    this.master = ToneCurve.identity,
    this.r = ToneCurve.identity,
    this.g = ToneCurve.identity,
    this.b = ToneCurve.identity,
  });

  /// The curve applied to every channel first.
  final ToneCurve master;

  /// The curve applied to the red channel after the master curve.
  final ToneCurve r;

  /// The curve applied to the green channel after the master curve.
  final ToneCurve g;

  /// The curve applied to the blue channel after the master curve.
  final ToneCurve b;

  /// The curves as the JSON file writes them.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'master': master.toJson(),
    'r': r.toJson(),
    'g': g.toJson(),
    'b': b.toJson(),
  };
}

/// The choices a recipe makes for the user by default.
final class RecipeDefaults {
  /// Creates the defaults of a recipe.
  const RecipeDefaults({
    this.format = FrameFormat.r3x2,
    this.dateStamp = false,
    this.whiteFrame = false,
    this.cinemaBands = false,
  });

  /// The frame format the app uses when the user does not pick one.
  final FrameFormat format;

  /// Whether the date imprint is on by default.
  final bool dateStamp;

  /// Whether the instant film white border is on by default.
  final bool whiteFrame;

  /// Whether cinema bands are on by default (16:9 only).
  final bool cinemaBands;

  /// The defaults as the JSON file writes them.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'format': format.wireName,
    'dateStamp': dateStamp,
    'whiteFrame': whiteFrame,
    'cinemaBands': cinemaBands,
  };
}

/// The grain of a recipe.
final class GrainSettings {
  /// Creates the grain settings.
  const GrainSettings({this.amount = 0, this.size = 1});

  /// How strong the grain is, from 0 to 1.
  final double amount;

  /// How big the grain cells are, from 0.25 to 4.
  final double size;

  /// The settings as the JSON file writes them.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'amount': amount,
    'size': size,
  };
}

/// The halation of a recipe: the glow of the highlights.
final class HalationSettings {
  /// Creates the halation settings.
  const HalationSettings({
    this.amount = 0,
    this.threshold = 0.75,
    this.radius = 0.01,
    this.color = const <double>[1, 0.35, 0.15],
  });

  /// How strong the glow is, from 0 to 1.
  final double amount;

  /// The luma above which a pixel starts to glow, from 0 to 1.
  final double threshold;

  /// The radius of the glow, as a fraction of the short side.
  final double radius;

  /// The colour of the glow, as red, green and blue.
  final List<double> color;

  /// The settings as the JSON file writes them.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'amount': amount,
    'threshold': threshold,
    'radius': radius,
    'color': color,
  };
}

/// The light leak of a recipe.
final class LeakSettings {
  /// Creates the light leak settings.
  const LeakSettings({
    this.amount = 0,
    this.position = const <double>[0.9, 0.1],
    this.radius = 0.4,
    this.color = const <double>[1, 0.45, 0.1],
  });

  /// How strong the leak is, from 0 to 1.
  final double amount;

  /// Where the leak sits, as a point of the frame.
  final List<double> position;

  /// The radius of the leak, with the short side as 1.
  final double radius;

  /// The colour of the leak, as red, green and blue.
  final List<double> color;

  /// The settings as the JSON file writes them.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'amount': amount,
    'position': position,
    'radius': radius,
    'color': color,
  };
}

/// The vignette of a recipe.
final class VignetteSettings {
  /// Creates the vignette settings.
  const VignetteSettings({this.amount = 0, this.softness = 0.5});

  /// How strong the vignette is, from 0 to 1.
  final double amount;

  /// How soft the edge of the vignette is, from 0 to 1.
  final double softness;

  /// The settings as the JSON file writes them.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'amount': amount,
    'softness': softness,
  };
}

/// One film: everything the renderer needs to reproduce its look.
final class Recipe {
  /// Creates a recipe.
  const Recipe({
    required this.id,
    required this.name,
    required this.description,
    this.kind = FilmKind.color,
    this.defaults = const RecipeDefaults(),
    this.exposure = 0,
    this.saturation = 1,
    this.matrix = const <double>[1, 0, 0, 0, 1, 0, 0, 0, 1],
    this.shadowTint = const <double>[0, 0, 0],
    this.highlightTint = const <double>[0, 0, 0],
    this.curve = const CurveSet(),
    this.grain = const GrainSettings(),
    this.halation = const HalationSettings(),
    this.leak = const LeakSettings(),
    this.vignette = const VignetteSettings(),
    this.wbDrift = 0,
    this.bandColor,
    this.notes,
  });

  /// The stable id of the film, for example `verano-98`.
  final String id;

  /// The name of the film in the three languages.
  final LocalizedText name;

  /// One sentence about the film, in the three languages.
  final LocalizedText description;

  /// Whether the film is colour or black and white.
  final FilmKind kind;

  /// The choices the film makes for the user by default.
  final RecipeDefaults defaults;

  /// The exposure of the film, in stops, from -2 to 2.
  final double exposure;

  /// The saturation of the film, from 0 to 2.
  final double saturation;

  /// The colour matrix, row major, with the identity as the neutral value.
  final List<double> matrix;

  /// The tint added to the shadows, as red, green and blue.
  final List<double> shadowTint;

  /// The tint added to the highlights, as red, green and blue.
  final List<double> highlightTint;

  /// The tone curves of the film.
  final CurveSet curve;

  /// The grain of the film.
  final GrainSettings grain;

  /// The halation of the film.
  final HalationSettings halation;

  /// The light leak of the film.
  final LeakSettings leak;

  /// The vignette of the film.
  final VignetteSettings vignette;

  /// How much the white balance drifts from shot to shot, from 0 to 0.1.
  final double wbDrift;

  /// The colour of the band of the cartridge, as `#RRGGBB`, or null to let the
  /// app derive one from the look of the film.
  final String? bandColor;

  /// Free text for the people who tune the film. Ignored by the engine.
  final String? notes;

  /// The recipe as the JSON file writes it.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name.toJson(),
    'description': description.toJson(),
    'kind': kind.wireName,
    'defaults': defaults.toJson(),
    'exposure': exposure,
    'saturation': saturation,
    'matrix': matrix,
    'shadowTint': shadowTint,
    'highlightTint': highlightTint,
    'curve': curve.toJson(),
    'grain': grain.toJson(),
    'halation': halation.toJson(),
    'leak': leak.toJson(),
    'vignette': vignette.toJson(),
    'wbDrift': wbDrift,
    if (bandColor != null) 'bandColor': bandColor,
    if (notes != null) 'notes': notes,
  };

  /// Reads a recipe from its JSON form, applying the defaults of every
  /// field the JSON leaves out.
  static Recipe fromJson(Map<String, dynamic> json) {
    final curve = _object(json, 'curve');
    return Recipe(
      id: _string(json, 'id'),
      name: LocalizedText.fromJson(_object(json, 'name')),
      description: LocalizedText.fromJson(_object(json, 'description')),
      kind: FilmKind.tryParse(_string(json, 'kind')) ?? FilmKind.color,
      defaults: _defaultsFromJson(_object(json, 'defaults')),
      exposure: _number(json, 'exposure', 0),
      saturation: _number(json, 'saturation', 1),
      matrix: _numbers(json, 'matrix', const <double>[
        1,
        0,
        0,
        0,
        1,
        0,
        0,
        0,
        1,
      ]),
      shadowTint: _numbers(json, 'shadowTint', const <double>[0, 0, 0]),
      highlightTint: _numbers(json, 'highlightTint', const <double>[0, 0, 0]),
      curve: CurveSet(
        master: _curveFromJson(curve, 'master'),
        r: _curveFromJson(curve, 'r'),
        g: _curveFromJson(curve, 'g'),
        b: _curveFromJson(curve, 'b'),
      ),
      grain: GrainSettings(
        amount: _number(_object(json, 'grain'), 'amount', 0),
        size: _number(_object(json, 'grain'), 'size', 1),
      ),
      halation: _halationFromJson(_object(json, 'halation')),
      leak: _leakFromJson(_object(json, 'leak')),
      vignette: VignetteSettings(
        amount: _number(_object(json, 'vignette'), 'amount', 0),
        softness: _number(_object(json, 'vignette'), 'softness', 0.5),
      ),
      wbDrift: _number(json, 'wbDrift', 0),
      bandColor: json['bandColor'] is String
          ? json['bandColor'] as String
          : null,
      notes: json['notes'] is String ? json['notes'] as String : null,
    );
  }
}

/// The result of parsing a recipe book.
final class RecipeBookResult {
  /// Creates a result.
  const RecipeBookResult({required this.book, required this.errors});

  /// The book, when it could be parsed.
  final RecipeBook? book;

  /// Every problem found while parsing.
  final List<ValidationError> errors;

  /// Whether the book was parsed without problems.
  bool get isValid => book != null;
}

/// The recipes of a film book, as they are written in `assets/recipes.json`.
final class RecipeBook {
  /// Creates a book.
  const RecipeBook({
    required this.schemaVersion,
    required this.recipesVersion,
    required this.recipes,
  });

  /// The version of the format the book uses.
  final int schemaVersion;

  /// The version of the recipes themselves.
  final String recipesVersion;

  /// The recipes of the book, in the order they are written.
  final List<Recipe> recipes;

  /// The recipe with [id], or null when the book has no such recipe.
  Recipe? byId(String id) {
    for (final recipe in recipes) {
      if (recipe.id == id) {
        return recipe;
      }
    }
    return null;
  }

  /// The book as the JSON file writes it.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'schemaVersion': schemaVersion,
    'recipesVersion': recipesVersion,
    'recipes': recipes
        .map((Recipe recipe) => recipe.toJson())
        .toList(growable: false),
  };

  /// Reads the [json] of a recipe book.
  ///
  /// Throws a [RecipeFormatException] with every problem found when the book
  /// does not follow the format.
  static RecipeBook parse(String json) {
    final result = tryParse(json);
    final book = result.book;
    if (book == null) {
      throw RecipeFormatException(result.errors);
    }
    return book;
  }

  /// Reads the [json] of a recipe book without throwing.
  static RecipeBookResult tryParse(String json) {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException catch (error) {
      return RecipeBookResult(
        book: null,
        errors: <ValidationError>[
          ValidationError('.', 'invalid JSON: ${error.message}'),
        ],
      );
    }

    final errors = RecipeValidator.validate(decoded);
    if (errors.isNotEmpty) {
      return RecipeBookResult(book: null, errors: errors);
    }

    final json2 = decoded! as Map<String, dynamic>;
    return RecipeBookResult(
      book: RecipeBook(
        schemaVersion: (json2['schemaVersion'] as num).toInt(),
        recipesVersion: json2['recipesVersion'] as String,
        recipes: (json2['recipes'] as List<Object?>)
            .map(
              (Object? recipe) =>
                  Recipe.fromJson(recipe! as Map<String, dynamic>),
            )
            .toList(growable: false),
      ),
      errors: const <ValidationError>[],
    );
  }
}

RecipeDefaults _defaultsFromJson(Map<String, dynamic> json) => RecipeDefaults(
  format: FrameFormat.tryParse(_string(json, 'format')) ?? FrameFormat.r3x2,
  dateStamp: _bool(json, 'dateStamp', false),
  whiteFrame: _bool(json, 'whiteFrame', false),
  cinemaBands: _bool(json, 'cinemaBands', false),
);

HalationSettings _halationFromJson(Map<String, dynamic> json) =>
    HalationSettings(
      amount: _number(json, 'amount', 0),
      threshold: _number(json, 'threshold', 0.75),
      radius: _number(json, 'radius', 0.01),
      color: _numbers(json, 'color', const <double>[1, 0.35, 0.15]),
    );

LeakSettings _leakFromJson(Map<String, dynamic> json) => LeakSettings(
  amount: _number(json, 'amount', 0),
  position: _numbers(json, 'position', const <double>[0.9, 0.1]),
  radius: _number(json, 'radius', 0.4),
  color: _numbers(json, 'color', const <double>[1, 0.45, 0.1]),
);

ToneCurve _curveFromJson(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) {
    return ToneCurve.identity;
  }
  return ToneCurve(
    value
        .map((Object? point) {
          final pair = point! as List<Object?>;
          return CurvePoint(
            (pair[0]! as num).toDouble(),
            (pair[1]! as num).toDouble(),
          );
        })
        .toList(growable: false),
  );
}

Map<String, dynamic> _object(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is Map<String, dynamic> ? value : <String, dynamic>{};
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is String ? value : '';
}

bool _bool(Map<String, dynamic> json, String key, bool fallback) {
  final value = json[key];
  return value is bool ? value : fallback;
}

double _number(Map<String, dynamic> json, String key, double fallback) {
  final value = json[key];
  return value is num ? value.toDouble() : fallback;
}

List<double> _numbers(
  Map<String, dynamic> json,
  String key,
  List<double> fallback,
) {
  final value = json[key];
  if (value is! List) {
    return fallback;
  }
  return value
      .map((Object? number) => (number! as num).toDouble())
      .toList(growable: false);
}
