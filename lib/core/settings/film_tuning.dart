import 'package:film_recipes/film_recipes.dart';
import 'package:flutter/foundation.dart';

/// The fine tuning of one film, as the long-press panel of the viewfinder
/// edits it.
///
/// The four look values are multipliers of the recipe, from 0 to 2, where 1 is
/// the film as its recipe says. The panel shows them as 0 to 100 with 50 being
/// the recipe. The date imprint and the format are null while the user has not
/// chosen: the film's own default applies. Cinema bands follow the same rule.
@immutable
class FilmTuning {
  const FilmTuning({
    this.grain = 1,
    this.halation = 1,
    this.leak = 1,
    this.vignette = 1,
    this.dateStamp,
    this.cinemaBands,
    this.format,
  });

  /// The film as its recipe says.
  static const FilmTuning defaults = FilmTuning();

  /// The lowest multiplier.
  static const double minMultiplier = 0;

  /// The highest multiplier.
  static const double maxMultiplier = 2;

  /// The value the panel shows for the film as its recipe says.
  static const int displayDefault = 50;

  /// The highest value the panel shows.
  static const int displayMax = 100;

  /// Multiplies the grain of the recipe.
  final double grain;

  /// Multiplies the halation of the recipe.
  final double halation;

  /// Multiplies the light leak of the recipe.
  final double leak;

  /// Multiplies the vignette of the recipe.
  final double vignette;

  /// Whether the date is imprinted; null follows the recipe.
  final bool? dateStamp;

  /// Whether cinema bands are enabled; null follows the recipe.
  final bool? cinemaBands;

  /// The frame format; null follows the recipe.
  final FrameFormat? format;

  /// The multiplier that the panel value [display] (0..100) stands for.
  static double multiplierOf(int display) =>
      (display.clamp(0, displayMax) * maxMultiplier / displayMax).toDouble();

  /// The panel value (0..100) of a [multiplier].
  static int displayOf(double multiplier) =>
      (multiplier.clamp(minMultiplier, maxMultiplier) *
              displayMax /
              maxMultiplier)
          .round();

  /// Whether nothing differs from the recipe.
  bool get isDefault => this == defaults;

  /// The same tuning with the given fields changed. [clearDateStamp],
  /// [clearFormat] and [clearCinemaBands] return to the recipe's default.
  FilmTuning copyWith({
    double? grain,
    double? halation,
    double? leak,
    double? vignette,
    bool? dateStamp,
    bool? cinemaBands,
    FrameFormat? format,
    bool clearDateStamp = false,
    bool clearCinemaBands = false,
    bool clearFormat = false,
  }) => FilmTuning(
    grain: _clamp(grain ?? this.grain),
    halation: _clamp(halation ?? this.halation),
    leak: _clamp(leak ?? this.leak),
    vignette: _clamp(vignette ?? this.vignette),
    dateStamp: clearDateStamp ? null : (dateStamp ?? this.dateStamp),
    cinemaBands: clearCinemaBands ? null : (cinemaBands ?? this.cinemaBands),
    format: clearFormat ? null : (format ?? this.format),
  );

  /// The overrides to hand to `resolve()`.
  LookOverrides get overrides => LookOverrides(
    grain: grain,
    halation: halation,
    leak: leak,
    vignette: vignette,
    dateStamp: dateStamp,
    cinemaBands: cinemaBands,
    format: format,
  );

  /// The tuning as data.
  Map<String, Object?> toJson() => <String, Object?>{
    'grain': grain,
    'halation': halation,
    'leak': leak,
    'vignette': vignette,
    if (dateStamp != null) 'dateStamp': dateStamp,
    if (cinemaBands != null) 'cinemaBands': cinemaBands,
    if (format != null) 'format': format!.wireName,
  };

  /// The tuning of [json]. Anything missing or invalid falls back to the
  /// recipe's value.
  factory FilmTuning.fromJson(Map<String, Object?> json) {
    double multiplier(String key) {
      final value = json[key];
      if (value is num && value.isFinite) return _clamp(value.toDouble());
      return 1;
    }

    final stamp = json['dateStamp'];
    final bands = json['cinemaBands'];
    final format = json['format'];
    return FilmTuning(
      grain: multiplier('grain'),
      halation: multiplier('halation'),
      leak: multiplier('leak'),
      vignette: multiplier('vignette'),
      dateStamp: stamp is bool ? stamp : null,
      cinemaBands: bands is bool ? bands : null,
      format: format is String ? FrameFormat.tryParse(format) : null,
    );
  }

  static double _clamp(double v) => v.clamp(minMultiplier, maxMultiplier);

  @override
  bool operator ==(Object other) =>
      other is FilmTuning &&
      other.grain == grain &&
      other.halation == halation &&
      other.leak == leak &&
      other.vignette == vignette &&
      other.dateStamp == dateStamp &&
      other.cinemaBands == cinemaBands &&
      other.format == format;

  @override
  int get hashCode => Object.hash(
    grain,
    halation,
    leak,
    vignette,
    dateStamp,
    cinemaBands,
    format,
  );

  @override
  String toString() => 'FilmTuning(${toJson()})';
}

/// Whether the film requests cinema bands, before the format guard.
bool cinemaBandsFor(Recipe recipe, FilmTuning tuning) =>
    tuning.cinemaBands ?? recipe.defaults.cinemaBands;
