/// Design tokens of the screen that develops photos of the gallery, on top of
/// the tokens of proposal A. Nothing is hard-coded in its widgets.
library;

import 'package:flutter/painting.dart';

import 'carrete_tokens.dart';

/// Sizes of the import screen.
abstract final class CarreteImport {
  /// The width of a thumbnail of the strip of photos.
  static const double stripThumbWidth = 48;

  /// The height of a thumbnail of the strip of photos.
  static const double stripThumbHeight = 60;

  /// The gap between two thumbnails of the strip.
  static const double stripGap = 6;

  /// The border of the selected thumbnail of the strip.
  static const double stripBorder = 2;

  /// The padding around the strip.
  static const EdgeInsets stripPadding = EdgeInsets.symmetric(
    horizontal: CarreteSpacing.margin,
    vertical: CarreteSpacing.s,
  );

  /// The distance of the pills from the edges of the frame.
  static const double pillInset = 10;

  /// The height of the progress bar of the export.
  static const double progressHeight = 6;

  /// The side of the spinner shown while the films load.
  static const double spinner = 28;

  /// The width of the line of that spinner.
  static const double spinnerStroke = 2.5;

  /// The width of the panel of the export (the width of a confirmation).
  static const double resultMaxWidth = CarreteRoll.dialogMaxWidth;

  /// The padding of the panel of the export.
  static const EdgeInsets resultPadding = EdgeInsets.fromLTRB(16, 16, 16, 16);

  /// The most height the tuning panel takes of the preview area, as a share
  /// of it.
  static const double panelShare = 0.92;

  /// The space between the top bar and the preview.
  static const double barGap = CarreteSpacing.s;
}

/// Colours of the import screen.
abstract final class CarreteImportColors {
  /// The empty part of the progress bar.
  static const Color progressTrack = Color(0xFF2C2E32);

  /// The photo that is not loaded yet: a sunken window.
  static const Color window = CarreteColors.deep;
}
