/// Design tokens of the disposable camera (proposal C, "cardboard and paper
/// disposable", of `design/propuestas.html`), next to the tokens of proposal A.
///
/// The camera keeps design A everywhere else; only the disposable mode uses
/// these. Nothing is hard-coded in the widgets of the mode: colours, sizes,
/// motion and type come from here or from `carrete_tokens.dart`.
///
/// The proposal sets its type in Bowlby One, Space Mono and Caveat, bundled in
/// `assets/fonts/` (SIL OFL 1.1). [DisposableFonts] names the families; the
/// two fonts of design A ([CarreteFonts]) stay as the fallback for any glyph
/// they lack.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'carrete_tokens.dart';

/// The families of the type of the mode.
abstract final class DisposableFonts {
  /// Numbers and titles (Bowlby One, a single regular weight).
  static const String display = 'BowlbyOne';

  /// Labels and running text (Space Mono, regular and bold).
  static const String text = 'SpaceMono';

  /// The pencil marks written by hand (Caveat, variable weight 400-700).
  static const String hand = 'Caveat';
}

/// The palette: kraft cardboard, paper, ink and three flat stamp colours.
abstract final class DisposableColors {
  /// The black behind the viewfinder.
  static const Color backdrop = Color(0xFF0E0D0C);

  /// The dark band at the top, under the stickers.
  static const Color band = Color(0xF2151311);

  /// The thin line under the band.
  static const Color bandEdge = Color(0xFF000000);

  /// The faint ribbing of the band and of the cardboard, in light and dark.
  static const Color bandRib = Color(0x09FFFFFF);
  static const Color kraftRib = Color(0x245A3814);

  /// The ink: text, outlines and hard shadows.
  static const Color ink = Color(0xFF1A1713);

  /// The paper of the labels and the stickers.
  static const Color paper = Color(0xFFF2E8D3);

  /// A brighter paper for a box that is ticked.
  static const Color paperLight = Color(0xFFFFF8E6);

  /// The cardboard, from the lit top edge to the bottom.
  static const Color kraftTop = Color(0xFFCBA36C);
  static const Color kraftBottom = Color(0xFFB68B54);

  /// The flat cardboard of a stamp.
  static const Color kraft = Color(0xFFC49A63);

  /// The edge light on top of the cardboard.
  static const Color kraftEdge = Color(0x2EFFFFFF);

  /// The red of the shutter and of the stamp when it is pressed.
  static const Color red = Color(0xFFBA2E1C);

  /// The yellow of the hard shadow of the flash and of the notices.
  static const Color yellow = Color(0xFFF2C230);

  /// The small print on the dark band.
  static const Color bandLabel = Color(0xFFD8CBB0);

  /// The corner marks of the frame.
  static const Color frameMark = Color(0xCCFFFFFF);

  /// The white of the shutter flash over the frame.
  static const Color flash = Color(0xFFFFFFFF);

  /// The scrim behind the dialogs.
  static const Color scrim = Color(0xB3000000);
}

/// Sizes, in logical pixels.
abstract final class DisposableSizes {
  /// The height of the row of stickers at the top.
  static const double topRow = 46;

  /// The space above and under the row of stickers.
  static const double topGap = CarreteSpacing.m;

  /// The hard shadows: small (stickers) and large (shutter, stamps).
  static const Offset shadow = Offset(3, 3);
  static const Offset shadowLarge = Offset(4, 5);

  /// The shadow of a pressed shutter.
  static const Offset shadowPressed = Offset(1, 1);

  /// The width of the outlines.
  static const double line = 2;
  static const double lineBold = 3;

  /// The sticker that counts the photos left: its smallest width, and the
  /// size of its number.
  static const double counterMinWidth = 106;
  static const double counterNumber = 30;

  /// The least room the number of the counter takes, so it does not jump when
  /// it goes from two digits to one.
  static const double counterNumberMinWidth = 38;

  /// The ribs of the dark band and of the cardboard: the distance between two
  /// and their width.
  static const double bandRibPitch = 6;
  static const double kraftRibPitch = 5;
  static const double ribWidth = 2;

  /// The side of the flash box.
  static const double flashBox = 46;

  /// The exit stamp: its width and the height of the bar that fills as it is
  /// held.
  static const double exitWidth = 112;

  /// The width of the label on the cardboard.
  static const double labelMaxWidth = 150;

  /// The height of the paper strip on the cardboard.
  static const double strip = 40;

  /// The height of the row of the shutter and the wheel.
  static const double shutterRow = 100;

  /// The shutter: the paper disc, the red button and the dashed ring.
  static const double shutterDisc = 84;
  static const double shutterButton = 52;
  static const double shutterRingInset = 5;
  static const double shutterDash = 4;
  static const double shutterGap = 3;

  /// The thumb wheel.
  static const double wheel = 64;
  static const int wheelTeeth = 18;
  static const double wheelToothWidth = 6;
  static const double wheelToothHeight = 9;
  static const double wheelRim = 25;
  static const double wheelFace = 19;
  static const double wheelHub = 4;
  static const double wheelArc = 14;
  static const double wheelArcStroke = 4;

  /// The corner marks of the frame: inset and arm length.
  static const double cornerInset = 12;
  static const double cornerArm = 14;
  static const double cornerStroke = 3;

  /// The jagged top edge of the cardboard: the teeth and their depth.
  static const int edgeTeeth = 20;
  static const double edgeDepth = 6;

  /// The widest the dialogs get.
  static const double dialogMaxWidth = 360;

  /// The inset of the dialogs from the edge of the screen.
  static const double dialogInset = 24;
}

/// Angles, in radians: the stickers are stuck on a little crooked.
abstract final class DisposableAngles {
  /// The counter sticker, anticlockwise.
  static const double counter = -2 * math.pi / 180;

  /// The exit stamp, clockwise.
  static const double exit = 2 * math.pi / 180;

  /// One click of the thumb wheel, and the clicks of one advance.
  static const double wheelClick = -40 * math.pi / 180;
  static const int wheelClicks = 3;
}

/// Motion.
abstract final class DisposableDurations {
  /// The thumb wheel advancing the film: three dry clicks.
  static const Duration advance = Duration(milliseconds: 660);

  /// The flash over the frame; the first of the advance.
  static const Duration flash = Duration(milliseconds: 240);

  /// How long the exit stamp has to be held.
  static const Duration exitHold = Duration(seconds: 2);

  /// How long the "film finished" notice shows before the roll opens.
  static const Duration doneNotice = Duration(milliseconds: 1600);

  /// The most the flash over the frame shows, and how soon it gets there
  /// (a share of [flash]).
  static const double flashPeak = 0.7;
  static const double flashRise = 0.08;
}

/// Type.
abstract final class DisposableText {
  static TextStyle _display(double size, Color color) => TextStyle(
    fontFamily: DisposableFonts.display,
    fontFamilyFallback: const [DisposableFonts.text, CarreteFonts.display],
    fontSize: size,
    // Bowlby One only has a regular weight: asking for bold would fake it.
    fontWeight: FontWeight.w400,
    height: 1,
    color: color,
    decoration: TextDecoration.none,
  );

  static TextStyle _text(
    double size,
    Color color, {
    FontWeight weight = FontWeight.w700,
    double height = 1.1,
  }) => TextStyle(
    fontFamily: DisposableFonts.text,
    fontFamilyFallback: const [DisposableFonts.display, CarreteFonts.text],
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: size * 0.02,
    color: color,
    decoration: TextDecoration.none,
  );

  /// The number on the counter sticker.
  static TextStyle get number =>
      _display(DisposableSizes.counterNumber, DisposableColors.ink);

  /// The small capitals on stickers and stamps.
  static TextStyle get caption => _text(11, DisposableColors.ink);

  /// The word on the exit stamp.
  static TextStyle get stamp => _display(15, DisposableColors.ink);

  /// The label on the cardboard.
  static TextStyle get label => _display(14, DisposableColors.ink);

  /// The title of a dialog.
  static TextStyle get title => _display(22, DisposableColors.ink);

  /// The running text of a dialog.
  static TextStyle get body =>
      _text(15, DisposableColors.ink, weight: FontWeight.w500, height: 1.3);

  /// The text of a notice over the frame.
  static TextStyle get notice => _display(15, DisposableColors.ink);

  /// The text of a key of a dialog.
  static TextStyle get key => _text(14, DisposableColors.ink);

  /// A note written by hand, as the pencil marks on a contact sheet.
  static TextStyle get hand => const TextStyle(
    fontFamily: DisposableFonts.hand,
    fontFamilyFallback: [CarreteFonts.text],
    fontSize: 28,
    fontVariations: [FontVariation('wght', 700)],
    height: 1,
    color: DisposableColors.ink,
    decoration: TextDecoration.none,
  );
}
