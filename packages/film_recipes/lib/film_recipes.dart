/// The film recipe engine of Carrete.
///
/// Recipes are data: they live in a versioned JSON file, are validated
/// against a schema and are turned into the exact values the shader of
/// `shaders/film.frag` expects. This package is pure Dart, so it runs in the
/// app, in the tests and in the tools without pulling Flutter in.
library;

export 'src/curve.dart';
export 'src/recipe.dart';
export 'src/reference_renderer.dart';
export 'src/resolve.dart';
export 'src/test_chart.dart';
export 'src/uniforms.dart';
export 'src/validation.dart';
