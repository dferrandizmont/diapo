import 'dart:typed_data';

import 'package:film_recipes/film_recipes.dart';

/// Capture settings must survive recipe updates during a delayed roll.
Map<String, Object?> encodeResolvedLook(ResolvedLook look) => {
  'exposure': look.exposure,
  'saturation': look.saturation,
  'matrix': look.matrix,
  'shadowTint': look.shadowTint,
  'highlightTint': look.highlightTint,
  'grainAmount': look.grainAmount,
  'grainSize': look.grainSize,
  'vignetteAmount': look.vignetteAmount,
  'vignetteSoftness': look.vignetteSoftness,
  'halationAmount': look.halationAmount,
  'halationThreshold': look.halationThreshold,
  'halationRadius': look.halationRadius,
  'halationColor': look.halationColor,
  'leakAmount': look.leakAmount,
  'leakPosition': look.leakPosition,
  'leakRadius': look.leakRadius,
  'leakColor': look.leakColor,
  'wbDrift': look.wbDrift,
  'curveR': look.curveR.toList(),
  'curveG': look.curveG.toList(),
  'curveB': look.curveB.toList(),
  'format': look.format.wireName,
  'dateStamp': look.dateStamp,
  'whiteFrame': look.whiteFrame,
  'cinemaBands': look.cinemaBands,
};

ResolvedLook decodeResolvedLook(Map<String, Object?> json) {
  double scalar(String key) {
    final value = json[key];
    if (value is! num || !value.isFinite) {
      throw FormatException('Invalid look $key');
    }
    return value.toDouble();
  }

  List<double> vector(String key, int length) {
    final value = json[key];
    if (value is! List ||
        value.length != length ||
        value.any((v) => v is! num || !v.isFinite)) {
      throw FormatException('Invalid look $key');
    }
    return value.cast<num>().map((v) => v.toDouble()).toList();
  }

  return ResolvedLook(
    exposure: scalar('exposure'),
    saturation: scalar('saturation'),
    matrix: vector('matrix', 9),
    shadowTint: vector('shadowTint', 3),
    highlightTint: vector('highlightTint', 3),
    grainAmount: scalar('grainAmount'),
    grainSize: scalar('grainSize'),
    vignetteAmount: scalar('vignetteAmount'),
    vignetteSoftness: scalar('vignetteSoftness'),
    halationAmount: scalar('halationAmount'),
    halationThreshold: scalar('halationThreshold'),
    halationRadius: scalar('halationRadius'),
    halationColor: vector('halationColor', 3),
    leakAmount: scalar('leakAmount'),
    leakPosition: vector('leakPosition', 2),
    leakRadius: scalar('leakRadius'),
    leakColor: vector('leakColor', 3),
    wbDrift: scalar('wbDrift'),
    curveR: Float64List.fromList(vector('curveR', 256)),
    curveG: Float64List.fromList(vector('curveG', 256)),
    curveB: Float64List.fromList(vector('curveB', 256)),
    format: FrameFormat.tryParse(json['format'] as String)!,
    dateStamp: json['dateStamp'] as bool,
    whiteFrame: json['whiteFrame'] as bool,
    cinemaBands: json['cinemaBands'] == true,
  );
}
