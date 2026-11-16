/// Design tokens of the first-use flow (proposal 1, "viewfinder and shutter",
/// of `design/primer-uso.html`), on top of the tokens of proposal A.
///
/// Nothing is hard-coded in the widgets of the flow: colours, sizes, motion
/// and type come from here or from `carrete_tokens.dart`.
library;

import 'package:flutter/material.dart';

import 'carrete_tokens.dart';

/// The colours of the pictures of the flow: a sunset scene and the bands of
/// the sample cartridges.
abstract final class OnboardingColors {
  /// The sky, from the top to the horizon.
  static const Color skyTop = Color(0xFF6E9BD1);
  static const Color skyMiddle = Color(0xFFF2C98E);
  static const Color skyBottom = Color(0xFFF29A6B);

  /// The sun, and the halo around it.
  static const Color sun = Color(0xFFFFF3C9);

  /// The far hill and the near hill.
  static const Color hillFar = Color(0xFF3E5B49);
  static const Color hillNear = Color(0xFF26382E);

  /// The walls and the roof of the house.
  static const Color houseWall = Color(0xFFE7DCC6);
  static const Color houseRoof = Color(0xFFB24A33);

  /// The bands of the five sample cartridges.
  static const List<Color> cartridgeBands = [
    Color(0xFFE9A94B),
    Color(0xFF4C7FB8),
    Color(0xFF8A5FB0),
    Color(0xFFB8B8B8),
    Color(0xFF6FA36B),
  ];

  /// The dark end of the gradient of a cartridge window.
  static const Color cartridgeShade = Color(0xFF1B1C1E);

  /// The black that holds the pictures: a sunken viewfinder.
  static const Color window = CarreteColors.deep;

  /// The secondary print of the text of a screen (running text).
  static const Color body = Color(0xFFC9CCD0);

  /// The fill of a frame of the roll that is empty.
  static const Color cellEmpty = Color(0xFF4A4D52);

  /// The fill of a frame of the roll that already holds a hidden photo.
  static const Color cellTaken = Color(0xFF17181A);

  /// The soft ring around a taken frame.
  static const Color cellTakenGlow = Color(0x59FFB020);

  /// The unlit cell of the step counter.
  static const Color stepOff = Color(0xFF5A5E64);
}

/// Sizes of the screens of the flow, in logical pixels.
abstract final class OnboardingSizes {
  /// The number of screens.
  static const int steps = 3;

  /// The widest the content of a screen gets (tablets).
  static const double contentMaxWidth = 560;

  /// The shortest and tallest the picture window gets.
  static const double windowMinHeight = 200;
  static const double windowMaxHeight = 380;

  /// The share of the height of a page the picture window takes.
  static const double windowShare = 0.5;

  /// The corner radius of the picture window.
  static const double windowRadius = 14;

  /// The space under the picture window and under the title.
  static const double windowGap = 22;
  static const double titleGap = 14;

  /// The width of the key that skips the flow.
  static const double skipKeyWidth = 96;

  /// The height of the LCD that counts the steps.
  static const double stepLcdHeight = 44;

  /// The height of the digits of the step counter.
  static const double stepDigits = 24;

  /// The cells of the progress under the text: one per step.
  static const double stepCellWidth = 34;
  static const double stepCellHeight = 22;
  static const double stepCellRadius = 3;
  static const double stepCellBorder = 2;

  /// The icon beside the label of the shutter.
  static const double labelIcon = 20;

  /// The room the bottom bar keeps between its edge and the shutter.
  static const double bottomPadding = 12;

  /// The size of the picture of the second and third screens, drawn at this
  /// size and scaled down to fit the window.
  static const double artWidth = 352;
  static const double artHeight = 416;
  static const double artPadding = 14;

  /// The preview picture of the second screen.
  static const double previewRadius = 6;
  static const double previewBorder = 2;

  /// The sample cartridges.
  static const double cartridgeWidth = 58;
  static const double cartridgeHeight = 70;
  static const double cartridgeWindow = 32;
  static const double cartridgeRowHeight = 100;

  /// The gaps between the parts of the pictures.
  static const double sampleGap = 6;
  static const double rowGap = 10;

  /// The roll of the third screen: 24 frames, 8 per row, and 9 already taken.
  static const int rollFrames = 24;
  static const int rollColumns = 8;
  static const int rollTaken = 9;
  static const int rollSelectedDelay = 2;
  static const double cellHeight = 26;
  static const double cellGap = 6;
  static const double cellRadius = 2;
  static const double cellBorder = 2;
  static const double cellInset = 3;
  static const double cellGlowInset = 6;

  /// The sample date printed on the picture of the first screen.
  static const double dateDigits = 16;
  static const double dateInset = 18;

  /// The corner marks and the focus brackets of the first screen.
  static const double chipRadius = 4;
  static const double chipPaddingH = 8;
  static const double chipPaddingV = 8;
  static const double chipsInset = 12;

  /// Where the focus brackets sit in the frame of the first screen.
  static const Alignment focusAlignment = Alignment(-0.1, -0.25);

  /// Under the window of a cartridge, and between that window and its band.
  static const double cartridgeBottomPadding = 3;
  static const double cartridgeBandGap = 3;

  /// The space above the delay keys of the third screen.
  static const double delayGap = 12;

  /// The gap between the cells of the step counter, and the left inset of
  /// the bottom bar.
  static const double stepCellGap = 6;
  static const double bottomInsetLeft = 20;

  /// The most the small labels over the picture grow with the text size.
  static const double chipMaxTextScale = 1.3;

  /// The sun and the scene of the first screen, as shares of the frame.
  static const double sunX = 0.7;
  static const double sunY = 0.5;
  static const double sunRadius = 0.1;
  static const double sunHaloRadius = 0.19;
  static const double sunHaloOpacity = 0.25;

  /// The two hills as shares of the frame: where each starts, the two control
  /// points of its curve, the middle and where it ends (a smooth curve, like
  /// the quadratic path of the proposal).
  static const List<Offset> farHill = [
    Offset(0, 0.66),
    Offset(0.25, 0.5),
    Offset(0.5, 0.64),
    Offset(0.75, 0.78),
    Offset(1, 0.6),
  ];
  static const List<Offset> nearHill = [
    Offset(0, 0.8),
    Offset(0.3, 0.68),
    Offset(0.6, 0.8),
    Offset(0.9, 0.92),
    Offset(1, 0.76),
  ];
  static const double houseX = 0.16;
  static const double houseY = 0.6;
  static const double houseWidth = 0.1;
  static const double houseHeight = 0.09;
  static const double roofRise = 0.07;
  static const double roofOverhang = 0.01;
  static const List<double> skyStops = [0, 0.55, 1];
}

/// Motion of the flow.
abstract final class OnboardingMotion {
  /// The film moving on by one frame when the screen changes.
  static const Duration page = CarreteDurations.carousel;

  /// The curve of that move.
  static const Curve pageCurve = Curves.easeOutCubic;
}

/// Type of the flow.
abstract final class OnboardingText {
  static TextStyle _display(double size, FontWeight weight, Color color) =>
      TextStyle(
        fontFamily: CarreteFonts.display,
        fontFamilyFallback: const [CarreteFonts.text],
        fontSize: size,
        fontWeight: weight,
        height: 1.05,
        color: color,
        decoration: TextDecoration.none,
      );

  /// The title of a screen.
  static final TextStyle title = _display(
    30,
    FontWeight.w700,
    CarreteColors.white,
  );

  /// The running text of a screen.
  static final TextStyle body = TextStyle(
    fontFamily: CarreteFonts.text,
    fontFamilyFallback: const [CarreteFonts.display],
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 1.3,
    color: OnboardingColors.body,
    decoration: TextDecoration.none,
  );

  /// The label next to the shutter ("Next", "Start shooting").
  static final TextStyle shutterLabel = _display(
    15,
    FontWeight.w700,
    CarreteColors.amber,
  ).copyWith(letterSpacing: 15 * 0.08);

  /// A small label over a picture.
  static final TextStyle chip = _display(
    11,
    FontWeight.w600,
    CarreteColors.white,
  ).copyWith(letterSpacing: 11 * 0.08);
}
