import 'package:film_recipes/film_recipes.dart';

import '../render/look_adjust.dart';

/// The flash modes of the camera.
enum CarreteFlash {
  /// Never fires.
  off,

  /// Fires when the scene is dark.
  auto,

  /// Always fires.
  on,

  /// Always fires, and the look burns the highlights a little on purpose, like
  /// a cheap flash at a party.
  party;

  /// Whether the hardware flash is set to fire every time.
  bool get firesAlways => this == on || this == party;
}

/// What the party flash does to the look, on top of the film.
abstract final class PartyFlash {
  /// Extra exposure, in stops: faces and highlights burn a little.
  static const double exposureStops = 0.3;

  /// The halation of the film is multiplied by this: the flash bleeds red
  /// into the highlights.
  static const double halationScale = 1.5;
}

/// The look to use for a shot or a viewfinder frame with [flash] selected:
/// the same look for every mode except [CarreteFlash.party].
ResolvedLook lookWithFlash(ResolvedLook look, CarreteFlash flash) {
  if (flash != CarreteFlash.party) return look;
  return look.adjusted(
    stops: PartyFlash.exposureStops,
    halationScale: PartyFlash.halationScale,
  );
}
