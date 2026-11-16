import 'package:film_recipes/film_recipes.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../camera/camera_flash.dart';
import '../../core/settings/film_tuning.dart';
import '../../core/settings/settings_provider.dart';
import '../../ui/theme/carrete_tokens.dart';

/// What the viewfinder remembers while the app is open.
class ViewfinderState {
  const ViewfinderState({
    this.flash = CarreteFlash.off,
    this.shots = 0,
    this.tuningFilmId,
  });

  /// The flash mode.
  final CarreteFlash flash;

  /// Photos taken since the app opened (the LCD counter).
  final int shots;

  /// The film whose fine-tuning panel is open, or null when it is closed.
  final String? tuningFilmId;

  ViewfinderState copyWith({
    CarreteFlash? flash,
    int? shots,
    String? tuningFilmId,
    bool clearTuning = false,
  }) => ViewfinderState(
    flash: flash ?? this.flash,
    shots: shots ?? this.shots,
    tuningFilmId: clearTuning ? null : (tuningFilmId ?? this.tuningFilmId),
  );
}

/// The state of the viewfinder screen.
final viewfinderProvider =
    NotifierProvider<ViewfinderNotifier, ViewfinderState>(
      ViewfinderNotifier.new,
    );

/// Changes the state of the viewfinder.
class ViewfinderNotifier extends Notifier<ViewfinderState> {
  @override
  ViewfinderState build() => const ViewfinderState();

  /// Selects the flash mode.
  void setFlash(CarreteFlash flash) => state = state.copyWith(flash: flash);

  /// One more photo on the counter.
  void addShot() => state = state.copyWith(shots: state.shots + 1);

  /// Takes a photo back off the counter (it could not be saved).
  void removeShot() =>
      state = state.copyWith(shots: state.shots > 0 ? state.shots - 1 : 0);

  /// Opens the fine-tuning panel of [filmId].
  void openTuning(String filmId) =>
      state = state.copyWith(tuningFilmId: filmId);

  /// Closes the fine-tuning panel.
  void closeTuning() => state = state.copyWith(clearTuning: true);

  /// Selects the film the camera shoots with (and loads the next time).
  void selectFilm(String filmId) =>
      ref.read(settingsProvider.notifier).setDefaultFilmId(filmId);
}

/// The film to shoot with: the one saved in the settings, or the first of the
/// book when that one is no longer in it.
Recipe selectedRecipe(RecipeBook book, String savedId) =>
    book.byId(savedId) ?? book.recipes.first;

/// The look for [recipe] with the [tuning] of the user and the [flash] mode.
/// The viewfinder and the saved photo both use exactly this.
ResolvedLook lookFor(Recipe recipe, FilmTuning tuning, CarreteFlash flash) =>
    lookWithFlash(resolve(recipe, overrides: tuning.overrides), flash);

/// The colour of the band on the cartridge of a film: the `bandColor` the recipe
/// names, or, when it names none, one taken from its look: the tint a mid-grey
/// takes through the colour matrix and the highlight tint, pushed to a clear
/// saturation. Black and white films get a grey.
Color filmBandColor(Recipe recipe) {
  final named = int.tryParse(
    (recipe.bandColor ?? '').replaceFirst('#', ''),
    radix: 16,
  );
  if (named != null && recipe.bandColor!.length == 7) {
    return Color(0xFF000000 | named);
  }
  if (recipe.kind == FilmKind.bw) return CarreteColors.bwBand;
  const grey = 0.6;
  final m = recipe.matrix;
  final t = recipe.highlightTint;
  final r = grey * (m[0] + m[1] + m[2]) + t[0] * 4;
  final g = grey * (m[3] + m[4] + m[5]) + t[1] * 4;
  final b = grey * (m[6] + m[7] + m[8]) + t[2] * 4;
  final luma = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  double push(double c) => (luma + (c - luma) * 8).clamp(0.15, 1.0);
  return Color.from(alpha: 1, red: push(r), green: push(g), blue: push(b));
}
