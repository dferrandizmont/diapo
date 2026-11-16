import 'dart:ui' as ui;

import 'package:film_recipes/film_recipes.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'look_adjust.dart';

/// The asset key of the book of films.
const String kRecipeBookAsset = 'packages/film_recipes/assets/recipes.json';

/// The asset key of the film shader.
const String kFilmShaderAsset = 'shaders/film.frag';

/// The book of films, read from the bundled JSON. Add a film to the JSON and
/// it shows up in the carousel: nothing in the code is per film.
final recipeBookProvider = FutureProvider<RecipeBook>((ref) async {
  final json = await rootBundle.loadString(kRecipeBookAsset);
  return RecipeBook.parse(json);
});

/// What the GPU needs to draw every film: the shader and the 256 x 1 tone
/// curve of each recipe.
class FilmResources {
  FilmResources({required this.program, required this.curves});

  /// The compiled film shader.
  final ui.FragmentProgram program;

  /// The tone curve image of each film, by film id.
  final Map<String, ui.Image> curves;

  /// Releases the images.
  void dispose() {
    for (final image in curves.values) {
      image.dispose();
    }
  }
}

/// The shader and the curves of the films of the book. Overridden in the
/// widget tests, which have no GPU: the viewfinder then shows the plain
/// preview.
final filmResourcesProvider = FutureProvider<FilmResources?>((ref) async {
  final book = await ref.watch(recipeBookProvider.future);
  final program = await ui.FragmentProgram.fromAsset(kFilmShaderAsset);
  final curves = <String, ui.Image>{};
  for (final recipe in book.recipes) {
    curves[recipe.id] = await curveImageOf(resolve(recipe));
  }
  final resources = FilmResources(program: program, curves: curves);
  ref.onDispose(resources.dispose);
  return resources;
});
