/// Design tokens of proposal A, "plastic compact of the 90s".
///
/// Everything the camera screen draws takes its colours, type, radii,
/// spacing and timings from here (see the token sheet of
/// `design/propuestas.html`, proposal A). Nothing is hard-coded in the
/// widgets.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The family names of the two OFL fonts of the design (bundled, see the
/// `fonts:` entries of `pubspec.yaml`).
abstract final class CarreteFonts {
  /// Labels, numbers, keys and titles: square and angular, like a 90s LCD.
  static const String display = 'ChakraPetch';

  /// Running text, film names and small labels: narrow and legible at 12 px.
  static const String text = 'BarlowSemiCondensed';

  /// The names a person writes by hand, such as the name of a roll (Caveat,
  /// bundled, variable weight 400-700).
  static const String hand = 'Caveat';
}

/// The palette of the camera.
abstract final class CarreteColors {
  /// The viewfinder: matt black.
  static const Color viewfinder = Color(0xFF0B0C0D);

  /// The plastic body.
  static const Color plastic = Color(0xFF232528);

  /// The raised plastic.
  static const Color plasticHigh = Color(0xFF33363A);

  /// Silkscreen print on the body.
  static const Color silk = Color(0xFFE4E1D8);

  /// Secondary silkscreen print.
  static const Color silk2 = Color(0xFFA9ADB2);

  /// The LCD window.
  static const Color lcd = Color(0xFFB7C2A2);

  /// The ink of the LCD digits.
  static const Color lcdInk = Color(0xFF18200F);

  /// The red shutter button.
  static const Color shutter = Color(0xFFC93A20);

  /// The amber of an active control.
  static const Color amber = Color(0xFFFFB020);

  /// The orange of the date imprint.
  static const Color date = Color(0xFFFF7A1A);

  /// Paper (light gallery).
  static const Color paper = Color(0xFFF1F0EB);

  /// Ink (light gallery).
  static const Color ink = Color(0xFF1B1C1E);

  /// Accent (light gallery).
  static const Color accentLight = Color(0xFFB93420);

  /// Table (dark gallery).
  static const Color table = Color(0xFF111214);

  /// Accent (dark gallery).
  static const Color accentDark = Color(0xFFFF7A59);

  // Shades the relief of the controls is drawn with.

  /// The darkest shade, used for hard shadows and sunken parts.
  static const Color deep = Color(0xFF050506);

  /// Top of a raised key.
  static const Color keyTop = Color(0xFF3D4045);

  /// Bottom of a raised key.
  static const Color keyBottom = Color(0xFF2A2C30);

  /// Top of a pressed key.
  static const Color keyPressedTop = Color(0xFF17181A);

  /// Bottom of a pressed key.
  static const Color keyPressedBottom = Color(0xFF222427);

  /// Top of a cartridge.
  static const Color cartridgeTop = Color(0xFF34373B);

  /// Top of the selected cartridge.
  static const Color cartridgeSelectedTop = Color(0xFF41444A);

  /// Bottom of the selected cartridge.
  static const Color cartridgeSelectedBottom = Color(0xFF2B2D31);

  /// Top of the LCD gradient.
  static const Color lcdTop = Color(0xFFC3CDAF);

  /// Bottom of the LCD gradient.
  static const Color lcdBottom = Color(0xFFAEBA98);

  /// The body of the tuning panel.
  static const Color panel = Color(0xF7161719);

  /// The orange-brown track of an active switch.
  static const Color switchOn = Color(0xFF6E4A07);

  /// Top of the knob of a switch or a slider.
  static const Color knobTop = Color(0xFF52555B);

  /// Bottom of the knob of a switch or a slider.
  static const Color knobBottom = Color(0xFF32353A);

  /// Border of the instant-film white frame.
  static const Color whiteFrame = Color(0xFFF4F1E8);

  /// The ring of the shutter button.
  static const Color shutterRingLight = Color(0xFF3F4247);

  /// The dark ribs of the shutter ring.
  static const Color shutterRingDark = Color(0xFF17181A);

  /// Top of the red shutter cap.
  static const Color shutterCapTop = Color(0xFFFF9A80);

  /// Middle of the red shutter cap.
  static const Color shutterCapMid = Color(0xFFE5442A);

  /// Bottom of the red shutter cap.
  static const Color shutterCapBottom = Color(0xFFAE2D18);

  /// The foot of the red shutter cap.
  static const Color shutterFoot = Color(0xFF741C0E);

  /// Pure white: the title of the panel, the hint print and the flash.
  static const Color white = Color(0xFFFFFFFF);

  /// Pure black: the edge of the panel and the box behind the date.
  static const Color black = Color(0xFF000000);

  /// What is drawn over the picture to frame it: the corner marks of the
  /// frame, the brackets and the padlock of the focus lock. White at 75 %.
  static const Color frameMark = Color(0xBFFFFFFF);

  /// The lines of the grid of thirds. White at 40 %.
  static const Color gridLine = Color(0x66FFFFFF);

  /// The line of the level when the phone is level: the coral accent of the
  /// dark gallery, which the camera uses whatever the theme.
  static const Color levelAligned = accentDark;

  /// The background of a notice over the picture. Black at 80 %.
  static const Color notice = Color(0xCC000000);

  /// The background of a small pill over the picture. Black at 60 %.
  static const Color pill = Color(0x99000000);

  /// The band of the cartridge of a black and white film.
  static const Color bwBand = Color(0xFFB8B8B8);

  /// The ribs of the knob of a slider.
  static const Color knobRib = Color(0xFF4A4D52);

  /// The centre of the well of the shutter button.
  static const Color shutterWellTop = Color(0xFF2D3034);

  /// The edge of the well of the shutter button.
  static const Color shutterWellBottom = Color(0xFF0D0E10);
}

/// The colours of the screens that are not the camera, which follow the theme
/// of the system: the light and the dark gallery of proposal A. The camera
/// follows the theme too, with its own [CarreteCameraColors].
@immutable
class CarretePalette {
  const CarretePalette({
    required this.brightness,
    required this.background,
    required this.plate,
    required this.plateShadow,
    required this.hairline,
    required this.ink,
    required this.inkSoft,
    required this.accent,
    required this.keyTop,
    required this.keyBottom,
    required this.keyPressedTop,
    required this.keyPressedBottom,
    required this.keyHardShadow,
    required this.keyHighlight,
  });

  /// Whether the palette is for a light or a dark theme.
  final Brightness brightness;

  /// The page.
  final Color background;

  /// The plate that holds the rows of a section.
  final Color plate;

  /// The soft shadow under a plate (transparent when there is none).
  final Color plateShadow;

  /// The thin lines between rows and around a plate.
  final Color hairline;

  /// The main print.
  final Color ink;

  /// The secondary print.
  final Color inkSoft;

  /// The colour of what is on or selected.
  final Color accent;

  /// Top of a raised key.
  final Color keyTop;

  /// Bottom of a raised key.
  final Color keyBottom;

  /// Top of a pressed key.
  final Color keyPressedTop;

  /// Bottom of a pressed key.
  final Color keyPressedBottom;

  /// The hard shadow under a key.
  final Color keyHardShadow;

  /// The light edge on top of a key.
  final Color keyHighlight;

  /// The light gallery: warm paper, black ink and a red accent.
  static const CarretePalette light = CarretePalette(
    brightness: Brightness.light,
    background: CarreteColors.paper,
    plate: Color(0xFFFBFAF6),
    plateShadow: Color(0x1F000000),
    hairline: Color(0xFFD9D6CC),
    ink: CarreteColors.ink,
    inkSoft: Color(0xFF55595F),
    accent: CarreteColors.accentLight,
    keyTop: Color(0xFFEFEDE6),
    keyBottom: Color(0xFFE3E1DA),
    keyPressedTop: Color(0xFFD3D0C7),
    keyPressedBottom: Color(0xFFDCD9D0),
    keyHardShadow: Color(0x59000000),
    keyHighlight: Color(0x66FFFFFF),
  );

  /// The dark gallery: a dark table, warm print and a coral accent. The keys
  /// are those of the camera.
  static const CarretePalette dark = CarretePalette(
    brightness: Brightness.dark,
    background: CarreteColors.table,
    plate: Color(0xFF17181A),
    plateShadow: Color(0x00000000),
    hairline: Color(0xFF2C2E32),
    ink: Color(0xFFECEAE3),
    inkSoft: Color(0xFFA4A8AE),
    accent: CarreteColors.accentDark,
    keyTop: CarreteColors.keyTop,
    keyBottom: CarreteColors.keyBottom,
    keyPressedTop: CarreteColors.keyPressedTop,
    keyPressedBottom: CarreteColors.keyPressedBottom,
    keyHardShadow: CarreteColors.deep,
    keyHighlight: CarreteRelief.highlight,
  );

  /// The palette of the theme in force.
  static CarretePalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// The colours of the camera screen (the viewfinder chrome, its tuning panel
/// and its sheets), which follow the theme of the app: the dark plastic of
/// proposal A, or the same camera in a warm light plastic with the ink and
/// the red accent of the light gallery.
///
/// [dark] is exactly [CarreteColors]. The picture itself (the live image, its
/// marks and what is drawn over it) does not change with the theme.
@immutable
class CarreteCameraColors {
  const CarreteCameraColors({
    required this.brightness,
    required this.body,
    required this.surround,
    required this.ink,
    required this.inkSoft,
    required this.active,
    required this.warn,
    required this.lamp,
    required this.keyTop,
    required this.keyBottom,
    required this.keyPressedTop,
    required this.keyPressedBottom,
    required this.hardShadow,
    required this.diffuseShadow,
    required this.highlight,
    required this.pressedEdge,
    required this.innerShadow,
    required this.tray,
    required this.cartridgeTop,
    required this.cartridgeBottom,
    required this.cartridgeSelectedTop,
    required this.cartridgeSelectedBottom,
    required this.cartridgeSelectedInk,
    required this.panel,
    required this.panelEdge,
    required this.panelShadow,
    required this.panelTitle,
    required this.rule,
    required this.groove,
    required this.grooveEdge,
    required this.tick,
    required this.knobFoot,
    required this.knob,
    required this.knobRib,
    required this.knobShadow,
    required this.switchOff,
    required this.switchOn,
    required this.switchKnobTop,
    required this.switchKnobBottom,
    required this.wellTop,
    required this.wellBottom,
    required this.ringDark,
    required this.ringLight,
    required this.ringShadow,
    required this.capShadow,
    required this.systemOverlay,
  });

  /// Whether the camera is light or dark.
  final Brightness brightness;

  /// The body of the camera: the background of the screen.
  final Color body;

  /// What is behind the picture, between the top bar and the carousel: the
  /// viewfinder black in both themes.
  final Color surround;

  /// The main silkscreen print: keys, labels, rows.
  final Color ink;

  /// The secondary print.
  final Color inkSoft;

  /// What is on: a selected key, the border of the selected cartridge, the
  /// fill of a slider and its value.
  final Color active;

  /// What warns or throws away.
  final Color warn;

  /// The lamp of a switch that is on.
  final Color lamp;

  /// Top of a raised key.
  final Color keyTop;

  /// Bottom of a raised key.
  final Color keyBottom;

  /// Top of a pressed key.
  final Color keyPressedTop;

  /// Bottom of a pressed key.
  final Color keyPressedBottom;

  /// The hard shadow under a raised part.
  final Color hardShadow;

  /// The diffuse shadow under a raised part.
  final Color diffuseShadow;

  /// The 1 px light edge on top of a raised part.
  final Color highlight;

  /// The light on the lower edge of a sunken part or a tray.
  final Color pressedEdge;

  /// The inner shadow of a sunken part.
  final Color innerShadow;

  /// The tray the flash keys sit in.
  final Color tray;

  /// Top of a cartridge.
  final Color cartridgeTop;

  /// Bottom of a cartridge.
  final Color cartridgeBottom;

  /// Top of the selected cartridge.
  final Color cartridgeSelectedTop;

  /// Bottom of the selected cartridge.
  final Color cartridgeSelectedBottom;

  /// The name on the selected cartridge.
  final Color cartridgeSelectedInk;

  /// The plate of the tuning panel and of the sheets.
  final Color panel;

  /// The edge of the plate.
  final Color panelEdge;

  /// The shadow under the plate.
  final Color panelShadow;

  /// The title of the plate.
  final Color panelTitle;

  /// A line between the rows of a plate.
  final Color rule;

  /// The groove of a slider.
  final Color groove;

  /// The light edge under the groove of a slider or the track of a switch.
  final Color grooveEdge;

  /// The ticks of a slider.
  final Color tick;

  /// The hard shadow under the knob of a slider.
  final Color knobFoot;

  /// The knob of a slider.
  final Color knob;

  /// The ribs of the knob of a slider.
  final Color knobRib;

  /// The soft shadow under the knob of a slider or a switch.
  final Color knobShadow;

  /// The track of a switch that is off.
  final Color switchOff;

  /// The track of a switch that is on.
  final Color switchOn;

  /// Top of the knob of a switch.
  final Color switchKnobTop;

  /// Bottom of the knob of a switch.
  final Color switchKnobBottom;

  /// The centre of the well of the shutter button.
  final Color wellTop;

  /// The edge of the well of the shutter button.
  final Color wellBottom;

  /// The ring of the shutter button.
  final Color ringDark;

  /// The ribs of the ring of the shutter button.
  final Color ringLight;

  /// The shadow of the ring of the shutter button.
  final Color ringShadow;

  /// The shadow of the red cap of the shutter button.
  final Color capShadow;

  /// The icons of the status and navigation bars over the camera.
  final SystemUiOverlayStyle systemOverlay;

  /// The hard shadow under a raised part ([CarreteRelief.hard] in dark).
  BoxShadow get hard =>
      BoxShadow(color: hardShadow, offset: CarreteRelief.hard.offset);

  /// The diffuse shadow under a raised part ([CarreteRelief.diffuse] in
  /// dark).
  BoxShadow get diffuse => BoxShadow(
    color: diffuseShadow,
    offset: CarreteRelief.diffuse.offset,
    blurRadius: CarreteRelief.diffuse.blurRadius,
  );

  /// The shadow under the plate ([CarreteRelief.panel] in dark).
  BoxShadow get plateShadow => BoxShadow(
    color: panelShadow,
    offset: CarreteRelief.panel.offset,
    blurRadius: CarreteRelief.panel.blurRadius,
  );

  /// The dark camera of proposal A: [CarreteColors], unchanged.
  static const CarreteCameraColors dark = CarreteCameraColors(
    brightness: Brightness.dark,
    body: CarreteColors.viewfinder,
    surround: CarreteColors.viewfinder,
    ink: CarreteColors.silk,
    inkSoft: CarreteColors.silk2,
    active: CarreteColors.amber,
    warn: CarreteColors.shutterCapTop,
    lamp: CarreteColors.amber,
    keyTop: CarreteColors.keyTop,
    keyBottom: CarreteColors.keyBottom,
    keyPressedTop: CarreteColors.keyPressedTop,
    keyPressedBottom: CarreteColors.keyPressedBottom,
    hardShadow: CarreteColors.deep,
    diffuseShadow: Color(0x80000000),
    highlight: CarreteRelief.highlight,
    pressedEdge: CarreteRelief.pressedEdge,
    innerShadow: CarreteRelief.innerShadow,
    tray: CarreteColors.deep,
    cartridgeTop: CarreteColors.cartridgeTop,
    cartridgeBottom: CarreteColors.plastic,
    cartridgeSelectedTop: CarreteColors.cartridgeSelectedTop,
    cartridgeSelectedBottom: CarreteColors.cartridgeSelectedBottom,
    cartridgeSelectedInk: CarreteColors.white,
    panel: CarreteColors.panel,
    panelEdge: CarreteColors.black,
    panelShadow: CarreteColors.pill,
    panelTitle: CarreteColors.white,
    rule: CarreteRelief.grooveEdge,
    groove: CarreteColors.deep,
    grooveEdge: CarreteRelief.grooveEdge,
    tick: CarreteSlider.tick,
    knobFoot: CarreteColors.deep,
    knob: CarreteColors.knobBottom,
    knobRib: CarreteColors.knobRib,
    knobShadow: CarreteSlider.shadow,
    switchOff: CarreteColors.deep,
    switchOn: CarreteColors.switchOn,
    switchKnobTop: CarreteColors.knobTop,
    switchKnobBottom: CarreteColors.knobBottom,
    wellTop: CarreteColors.shutterWellTop,
    wellBottom: CarreteColors.shutterWellBottom,
    ringDark: CarreteColors.shutterRingDark,
    ringLight: CarreteColors.shutterRingLight,
    ringShadow: CarreteShutter.ringShadow,
    capShadow: CarreteShutter.capShadow,
    systemOverlay: SystemUiOverlayStyle.light,
  );

  /// The body of the light camera: a warm light-grey plastic.
  static const Color _lightBody = Color(0xFFE2DFD6);

  /// The light camera: the same compact in a warm light-grey plastic, black
  /// print, the deep red of the light gallery for what is on (darkened from
  /// [CarreteColors.accentLight] to read on a pressed key) and the same red
  /// shutter. The LCD, the date sample and the picture do not change.
  static const CarreteCameraColors light = CarreteCameraColors(
    brightness: Brightness.light,
    body: _lightBody,
    // A dark window behind the picture, like the viewfinder well of a
    // compact: film colours are judged against a dark surround.
    surround: CarreteColors.viewfinder,
    ink: CarreteColors.ink,
    inkSoft: Color(0xFF55595F),
    active: Color(0xFFA32B18),
    warn: Color(0xFFA32B18),
    lamp: CarreteColors.amber,
    keyTop: Color(0xFFF6F4EE),
    keyBottom: Color(0xFFE9E6DE),
    keyPressedTop: Color(0xFFD3D0C7),
    keyPressedBottom: Color(0xFFDCD9D0),
    hardShadow: Color(0x59000000),
    diffuseShadow: Color(0x26000000),
    highlight: Color(0xE6FFFFFF),
    pressedEdge: Color(0x99FFFFFF),
    innerShadow: Color(0x73000000),
    tray: Color(0xFFC9C5BA),
    cartridgeTop: Color(0xFFF3F1EB),
    cartridgeBottom: Color(0xFFE6E3DB),
    cartridgeSelectedTop: Color(0xFFFFFFFF),
    cartridgeSelectedBottom: Color(0xFFE9E6DE),
    cartridgeSelectedInk: CarreteColors.ink,
    panel: Color(0xF7F7F5EF),
    panelEdge: Color(0xFFC9C5BA),
    panelShadow: Color(0x40000000),
    panelTitle: CarreteColors.ink,
    rule: Color(0xFFD9D6CC),
    // Groove and off track at 3:1 on the panel, so their shape reads.
    groove: Color(0xFF948F84),
    grooveEdge: Color(0xB3FFFFFF),
    tick: Color(0x59000000),
    knobFoot: Color(0x59000000),
    knob: Color(0xFFEDEBE4),
    knobRib: Color(0xFFD6D2C8),
    knobShadow: Color(0x40000000),
    switchOff: Color(0xFF948F84),
    switchOn: Color(0xFFA32B18),
    switchKnobTop: Color(0xFFFBFAF6),
    switchKnobBottom: Color(0xFFE3E0D8),
    wellTop: Color(0xFFD9D5CB),
    wellBottom: Color(0xFFADA99E),
    ringDark: Color(0xFFC4C0B5),
    ringLight: Color(0xFFEDEAE2),
    ringShadow: Color(0x59000000),
    capShadow: Color(0x66000000),
    systemOverlay: SystemUiOverlayStyle.dark,
  );

  /// The camera for a theme of [brightness].
  static CarreteCameraColors forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// The camera of the nearest [CarreteCameraTheme], or [dark] when there is
  /// none (the screens that keep the dark plastic, like importing).
  static CarreteCameraColors of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<CarreteCameraTheme>()
          ?.colors ??
      dark;
}

/// Hands the [CarreteCameraColors] of the camera to its controls.
class CarreteCameraTheme extends InheritedWidget {
  const CarreteCameraTheme({
    required this.colors,
    required super.child,
    super.key,
  });

  /// The colours of the camera.
  final CarreteCameraColors colors;

  @override
  bool updateShouldNotify(CarreteCameraTheme old) => old.colors != colors;
}

/// Corner radii.
abstract final class CarreteRadii {
  /// Keys.
  static const double key = 8;

  /// Film cartridges.
  static const double cartridge = 9;

  /// The LCD window.
  static const double lcd = 6;

  /// Thumbnails inside the cartridges.
  static const double thumbnail = 4;

  /// The tuning panel.
  static const double panel = 12;

  /// The tray that holds the flash keys.
  static const double keyGroup = 11;

  /// The little box behind the sample of the date imprint.
  static const double dateBox = 3;

  /// The coloured band of a cartridge.
  static const double band = 1;

  /// The knob of a slider.
  static const double knob = 5;

  /// The groove of a slider.
  static const double track = 3;

  /// The body of the padlock of the focus lock.
  static const double padlock = 2;
}

/// The spacing scale (base 4) and the touch sizes.
abstract final class CarreteSpacing {
  /// 4.
  static const double xs = 4;

  /// 8.
  static const double s = 8;

  /// 12.
  static const double m = 12;

  /// 16.
  static const double l = 16;

  /// 24.
  static const double xl = 24;

  /// 32.
  static const double xxl = 32;

  /// The side margin of the screen.
  static const double margin = 16;

  /// The smallest size of any touch target.
  static const double minTouch = 44;

  /// The big keys (switch camera, format).
  static const double keyBig = 52;

  /// The shutter button.
  static const double shutter = 88;
}

/// Durations of the motion (80 ms to 3 s).
abstract final class CarreteDurations {
  /// A key going down: the design's `.08s`.
  static const Duration keyPress = Duration(milliseconds: 80);

  /// The carousel centring a cartridge.
  static const Duration carousel = Duration(milliseconds: 300);

  /// The flash of the shutter.
  static const Duration shutterFlash = Duration(milliseconds: 320);

  /// The film advancing in the LCD.
  static const Duration filmAdvance = Duration(milliseconds: 600);

  /// The film rewinding in the LCD after the last frame of a roll.
  static const Duration rewind = Duration(milliseconds: 1200);

  /// The number of dry steps of the rewind.
  static const int rewindSteps = 12;

  /// The number of dry steps of the film motor.
  static const int filmAdvanceSteps = 6;

  /// How often the grain of the viewfinder changes: a 24 fps projection.
  static const Duration grain = Duration(milliseconds: 42);

  /// How long the zoom pill stays after the last pinch.
  static const Duration zoomPill = Duration(milliseconds: 900);

  /// How long a notice stays over the viewfinder.
  static const Duration notice = Duration(seconds: 3);

  /// How long a short message of the settings (a snack bar) stays.
  static const Duration snack = Duration(seconds: 4);

  /// How long a message of the settings with several sentences stays.
  static const Duration longNotice = Duration(seconds: 7);

  /// How long the notice of a roll that closed itself stays before the roll
  /// opens.
  static const Duration rollClosedPause = Duration(milliseconds: 1400);

  /// A frame of the developing roll turning from empty to exposed.
  static const Duration developStep = Duration(milliseconds: 300);

  /// The whole reveal of a developed roll the first time it is opened: the
  /// frames come in one after another within this time.
  static const Duration reveal = Duration(milliseconds: 1300);
}

/// Text styles.
abstract final class CarreteText {
  /// [text] in capitals, the way the small labels of the design are printed
  /// (`text-transform: uppercase`).
  ///
  /// Capitals depend on the language: Turkish and Azeri have a dotted and a
  /// dotless i. The ARB values stay in sentence case; every small label goes
  /// through here.
  static String upper(String text, Locale locale) {
    switch (locale.languageCode) {
      case 'tr':
      case 'az':
        return text.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
      default:
        return text.toUpperCase();
    }
  }

  static TextStyle _display(
    double size,
    FontWeight weight,
    Color color, {
    double letterSpacing = 0.02,
    double height = 1,
  }) => TextStyle(
    fontFamily: CarreteFonts.display,
    fontFamilyFallback: const [CarreteFonts.text],
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: size * letterSpacing,
    color: color,
    decoration: TextDecoration.none,
  );

  static TextStyle _text(
    double size,
    FontWeight weight,
    Color color, {
    double letterSpacing = 0.01,
    double height = 1.05,
  }) => TextStyle(
    fontFamily: CarreteFonts.text,
    fontFamilyFallback: const [CarreteFonts.display],
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: size * letterSpacing,
    color: color,
    decoration: TextDecoration.none,
  );

  /// Text on a key.
  static final TextStyle key = _display(
    14,
    FontWeight.w700,
    CarreteColors.silk,
  );

  /// The caption of a key that has an icon above it. The colour is the one
  /// of the key.
  static final TextStyle keyCaption = _display(
    12,
    FontWeight.w700,
    CarreteColors.silk,
    letterSpacing: 0.06,
  );

  /// The second line of a key that has a caption: lighter than the caption.
  static final TextStyle keyDetail = keyCaption.copyWith(
    fontWeight: FontWeight.w500,
  );

  /// Small uppercase label under the top bar.
  static final TextStyle label = _display(
    11,
    FontWeight.w600,
    CarreteColors.silk2,
    letterSpacing: 0.1,
  );

  /// The same label with the value in brighter print.
  static final TextStyle labelStrong = _display(
    11,
    FontWeight.w700,
    CarreteColors.silk,
    letterSpacing: 0.1,
  );

  /// The name of a cartridge.
  static final TextStyle cartridge = _text(
    12,
    FontWeight.w500,
    CarreteColors.silk2,
  );

  /// The name of the selected cartridge.
  static final TextStyle cartridgeSelected = _text(
    12,
    FontWeight.w700,
    Colors.white,
  );

  /// The title of the tuning panel.
  static final TextStyle panelTitle = _display(
    20,
    FontWeight.w700,
    Colors.white,
  );

  /// The subtitle of the tuning panel.
  static final TextStyle panelSubtitle = _display(
    12,
    FontWeight.w500,
    CarreteColors.silk2,
    letterSpacing: 0.1,
    height: 1.2,
  );

  /// The label of a row of the tuning panel.
  static final TextStyle row = _text(
    14,
    FontWeight.w600,
    CarreteColors.silk,
    height: 1,
  );

  /// The value of a slider.
  static final TextStyle value = _display(
    15,
    FontWeight.w600,
    CarreteColors.amber,
  );

  /// A message in the middle of the screen.
  static final TextStyle message = _text(
    18,
    FontWeight.w500,
    CarreteColors.silk,
    height: 1.3,
  );

  /// A short hint over the viewfinder.
  static final TextStyle hint = _display(
    11,
    FontWeight.w600,
    Colors.white,
    letterSpacing: 0.08,
  );

  /// A notice over the viewfinder: the hint a little bigger, with the
  /// letter spacing of the hint.
  static final TextStyle notice = hint.copyWith(fontSize: 13);

  // The text of the settings screen. The colour comes from the
  // [CarretePalette] of the theme.

  /// The title of a page.
  static TextStyle pageTitle(Color color) =>
      _display(22, FontWeight.w700, color, height: 1.05);

  /// The small capitals over a section.
  static TextStyle sectionLabel(Color color) =>
      _display(11, FontWeight.w600, color, letterSpacing: 0.1);

  /// The name of a setting.
  static TextStyle setting(Color color) =>
      _text(16, FontWeight.w600, color, height: 1.15);

  /// The value of a setting, in LCD print.
  static TextStyle settingValue(Color color) =>
      _display(15, FontWeight.w600, color);

  /// A name written by hand (the name of a roll). Caveat runs small, so it
  /// is set larger than the print around it; the weight is 600 of its 400-700.
  static const double handNameTitle = 32;
  static const double handNameCard = 26;
  static const double handNameRow = 24;
  static const double handNameField = 28;

  static TextStyle handName(Color color, {double size = handNameField}) =>
      TextStyle(
        fontFamily: CarreteFonts.hand,
        fontFamilyFallback: const [CarreteFonts.text],
        fontSize: size,
        fontVariations: const [FontVariation('wght', 600)],
        height: 1.1,
        color: color,
        decoration: TextDecoration.none,
      );

  /// A sentence of explanation.
  static TextStyle note(Color color) =>
      _text(14, FontWeight.w400, color, height: 1.35);

  /// The running text of the legal pages (the privacy policy, the legal
  /// notice): a little larger than a note, for reading.
  static TextStyle legalBody(Color color) =>
      _text(15, FontWeight.w400, color, height: 1.45);

  /// The text of a key, in the colour of the theme.
  static TextStyle keyOn(Color color) => key.copyWith(color: color);

  /// The frame number printed on the edge of a strip of the contact sheet.
  static TextStyle frameNumber(Color color) =>
      _display(10, FontWeight.w600, color, letterSpacing: 0.06);

  /// The short label inside an empty frame of the contact sheet.
  static TextStyle frameLabel(Color color) =>
      _display(10, FontWeight.w600, color, letterSpacing: 0.08, height: 1.1);

  /// The ink of the LCD, for the small print inside the LCD window.
  static final TextStyle lcdSmall = _display(
    12,
    FontWeight.w700,
    CarreteColors.lcdInk,
    letterSpacing: 0.08,
  );
}

/// Sizes of the parts of the camera screen and of its controls, in logical
/// pixels. The layout of the widgets is made of these and of
/// [CarreteSpacing].
abstract final class CarreteSizes {
  /// The width of the border of the name field of a roll while it has focus.
  static const double handFieldFocusBorder = 2;

  // Icons.

  /// The side of an icon.
  static const double icon = 24;

  /// The width of the stroke of an icon, in units of its grid.
  static const double iconStroke = 1.9;

  /// The side of the grid the icons are drawn on.
  static const double iconGrid = 24;

  /// Three pixels: the gap of the film strip, the space between the parts
  /// of a cartridge and the line under the title of the panel.
  static const double hair = 3;

  // The LCD and the top bar.

  /// The width of the LCD window.
  static const double lcdWidth = 96;

  /// The narrowest the LCD window gets on a small screen.
  static const double lcdMinWidth = 64;

  /// The height of the LCD window.
  static const double lcdHeight = 46;

  /// The side padding inside the LCD window.
  static const double lcdInset = 6;

  /// The room above and below the content of the LCD: the strip of the film
  /// advance (its distance to the bottom, its height and a pixel of air).
  static const double lcdInsetV = stripBottom + stripHeight + 1;

  /// The film icon of the LCD.
  static const double lcdIcon = 18;

  /// The stroke of the film icon of the LCD.
  static const double lcdIconStroke = 2.2;

  /// The height of the digits of the LCD.
  static const double lcdDigits = 28;

  /// How far the strip of the film advance travels.
  static const double stripTravel = 18;

  /// The distance from the strip to the bottom of the LCD.
  static const double stripBottom = 3;

  /// The height of the strip.
  static const double stripHeight = 4;

  /// How many frames the strip has.
  static const int stripFrames = 8;

  /// The tray around the flash keys.
  static const double keyTray = 3;

  /// The height of the row of the top bar. The LCD and the keys are centred
  /// in it, so they share one centre line.
  static const double topBarRow = 2 * keyTray + CarreteSpacing.minTouch;

  /// The width of the flash key: its icon with the name of the mode under it.
  static const double flashKeyWidth = 78;

  /// The share of the room between the flash key and the settings key that
  /// the LCD takes when the roll control takes the rest.
  static const double lcdShare = 0.42;

  /// The most the keys of the top bar grow with the size of the text, as a
  /// factor of their height. Above it the text shrinks to fit instead.
  static const double topBarMaxScale = 1.3;

  /// How much of its natural size a line of the roll control may shrink to
  /// before the control moves to a row of its own.
  static const double rollTextLegible = 0.85;

  /// The widest the LCD gets when the roll control has a row of its own.
  static const double lcdStackedWidth = 140;

  /// The text scale above which the two keys of the offer of a roll go one
  /// over the other, and the width of the card under which they do too.
  static const double offerStackScale = 1.3;
  static const double offerStackWidth = 300;

  /// The height of the caption under the LCD, at the normal text size.
  static const double lcdCaptionHeight = 14;

  /// The icon of a key that also carries a caption.
  static const double captionedKeyIcon = 18;

  /// How far a pressed key sinks, as a share of its height (1 px on a
  /// 44 px key).
  static const double keySink = 1 / 44;

  // The camera screen.

  /// What the top bar reserves under the status bar: the LCD, its label and
  /// some air.
  static const double topBarReserve = 82;

  /// The least room under the shutter row, whatever the gesture bar takes.
  static const double bottomInset = 12;

  /// The side padding of the shutter row.
  static const double shutterRowInset = 38;

  /// The side margin of the tuning panel.
  static const double panelMargin = 14;

  /// How far the tuning panel overlaps the carousel.
  static const double panelOverlap = 2;

  /// The least height of the tuning panel.
  static const double panelMinHeight = 200;

  /// The most height of the tuning panel.
  static const double panelMaxHeight = 420;

  /// The side padding of a pill over the picture.
  static const double pillInsetH = 10;

  /// The top and bottom padding of a pill over the picture.
  static const double pillInsetV = 6;

  /// The width of the retry key of the camera problem.
  static const double retryKey = 140;

  /// The width of the key that opens the settings of the system.
  static const double wideKey = 200;

  // The carousel.

  /// The height of the carousel.
  static const double carouselHeight = 90;

  /// The width of a cartridge.
  static const double cartridgeWidth = 70;

  /// The height of a cartridge.
  static const double cartridgeHeight = 82;

  /// The gap between two cartridges.
  static const double cartridgeGap = 6;

  /// How far the selected cartridge rises.
  static const double cartridgeLift = 5;

  /// The amber border of the selected cartridge.
  static const double cartridgeBorder = 2;

  /// The height of the live window of a cartridge.
  static const double thumbnailHeight = 36;

  /// The height of the colour band of a cartridge.
  static const double bandHeight = 3;

  // The tuning panel.

  /// The padding of the plate of the panel.
  static const EdgeInsets panelPadding = EdgeInsets.fromLTRB(14, 6, 14, 10);

  /// The height of the title row of the panel.
  static const double panelHeader = 50;

  /// The height of a row with a switch or the format keys.
  static const double panelRow = 56;

  /// The height of a row with a slider.
  static const double sliderRow = 48;

  /// The width of the label of a slider.
  static const double sliderLabel = 92;

  /// The gap between the label, the slider and the value of a slider row
  /// (the design's `gap: 10px`).
  static const double sliderGap = 10;

  /// The width of the value of a slider row.
  ///
  /// The design draws it 34 px wide, but "100" does not keep that width
  /// when the user enlarges the text: in the 15 px Chakra Petch it measures
  /// 25.8 px at the normal scale, 33.3 at 1.3x, 38.3 at 1.5x and 50.8 at 2x.
  /// 38 px keeps it on one line up to a 1.45x text scale (34 px only up to
  /// 1.3x); beyond that the value shrinks to fit instead of wrapping.
  static const double sliderValue = 38;

  /// The top and bottom padding of the box behind the sample of the date.
  static const double dateBoxInsetV = 5;

  /// The height of the digits of the sample of the date.
  static const double dateSample = 16;

  /// The width of a key of the row of formats.
  static const double formatKey = 56;

  // The settings screen.

  /// The widest the settings page gets (on a tablet).
  static const double settingsMaxWidth = 560;

  /// The height of the header of the settings page.
  static const double settingsHeader = 64;

  /// The least height of a row of settings.
  static const double settingRow = 56;

  /// The least height of the row of a film.
  static const double filmRow = 52;

  /// The side padding inside a plate of settings.
  static const double plateInset = 16;

  /// The height of the keys that choose among a few options.
  static const double choiceKey = 48;

  /// The least width of a key that chooses among a few options at the normal
  /// text size; it grows with the text.
  static const double choiceKeyMin = 88;

  /// The height of the black box with the sample of a date style.
  static const double dateTile = 52;

  /// The height of the digits of the sample of a date style.
  static const double dateTileDigits = 20;

  /// The side of the colour swatch of a film.
  static const double swatch = 14;

  /// The diameter of the lamp that marks the selected film.
  static const double lampSmall = 12;

  /// The side of the icons of the settings page.
  static const double settingsIcon = 20;

  /// The stroke of the small spinner that shows a settings row is working.
  static const double settingsSpinnerStroke = 2;

  /// The width of a hairline.
  static const double hairlineWidth = 1;
}

/// The slider of the tuning panel.
abstract final class CarreteSlider {
  /// The width of the knob.
  static const double knobWidth = 22;

  /// The height of the knob.
  static const double knobHeight = 36;

  /// The height of the groove.
  static const double trackHeight = 6;

  /// How many sections the ticks divide the groove in.
  static const int tickCount = 10;

  /// The distance from the middle of the groove to the top of a tick.
  static const double tickOffset = 9;

  /// The length of a tick.
  static const double tickLength = 5;

  /// The width of a tick.
  static const double tickWidth = 1;

  /// The colour of the ticks. White at 35 %.
  static const Color tick = Color(0x59FFFFFF);

  /// The diffuse shadow under the knob. Black at 60 %.
  static const Color shadow = Color(0x99000000);

  /// How far the diffuse shadow of the knob is pushed down.
  static const double shadowOffset = 4;

  /// The blur sigma of the shadow of the knob.
  static const double shadowBlur = 3;

  /// How far the hard shadow under the knob is pushed down.
  static const double footOffset = 2;

  /// The distance between two ribs of the knob.
  static const double ribPitch = 4;

  /// The width of a rib of the knob.
  static const double ribWidth = 2;
}

/// The switch of the tuning panel.
abstract final class CarreteSwitch {
  /// The width of the switch.
  static const double width = 60;

  /// The height of the switch (the track is a pill).
  static const double height = 34;

  /// The diameter of the knob.
  static const double knob = 28;

  /// The distance from the knob to the track when it rests.
  static const double knobInset = 3;

  /// The diameter of the amber lamp.
  static const double lamp = 12;

  /// The distance from the lamp to the left edge.
  static const double lampLeft = 8;

  /// The distance from the lamp to the top edge.
  static const double lampTop = 11;

  /// The blur of the glow of the lamp.
  static const double lampGlow = 8;

  /// The shadow under the knob. Black at 60 %.
  static const Color knobShadow = Color(0x99000000);

  /// How far the shadow of the knob is pushed down.
  static const double knobShadowOffset = 2;

  /// The blur of the shadow of the knob.
  static const double knobShadowBlur = 3;
}

/// The shutter button.
abstract final class CarreteShutter {
  /// The centre of the radial gradient of the well.
  static const Alignment wellCentre = Alignment(0, -0.4);

  /// The radius of the gradient of the well.
  static const double wellRadius = 0.8;

  /// The stops of the gradient of the well.
  static const List<double> wellStops = [0, 0.9];

  /// How far the ring is inside the well.
  static const double ringInset = 5;

  /// The shadow of the ring. Black at 70 %.
  static const Color ringShadow = Color(0xB3000000);

  /// How far the shadow of the ring is pushed down.
  static const double ringShadowOffset = 2;

  /// The blur sigma of the shadow of the ring.
  static const double ringShadowBlur = 1.5;

  /// How many ribs the ring has.
  static const int ribs = 60;

  /// The width of a rib.
  static const double ribWidth = 3;

  /// Where a rib starts, as a share of the radius of the ring.
  static const double ribStart = 0.82;

  /// The radius of the red cap.
  static const double capRadius = 33;

  /// How far the cap sinks when it is pressed.
  static const double capSink = 4;

  /// How far the cap rests above the centre of the well.
  static const double capRaise = 1;

  /// The height of the foot of the cap at rest.
  static const double footRaised = 5;

  /// The height of the foot of the cap when it is pressed.
  static const double footPressed = 1;

  /// The shadow of the cap. Black at 65 %.
  static const Color capShadow = Color(0xA6000000);

  /// How far the shadow of the cap is below its foot.
  static const double capShadowGap = 4;

  /// The blur sigma of the shadow of the cap.
  static const double capShadowBlur = 6;

  /// The centre of the radial gradient of the cap.
  static const Alignment capCentre = Alignment(-0.24, -0.48);

  /// The radius of the gradient of the cap.
  static const double capGradientRadius = 1;

  /// The stops of the gradient of the cap.
  static const List<double> capStops = [0, 0.46, 1];
}

/// What is drawn over the picture of the viewfinder to frame it.
abstract final class CarreteMarks {
  /// The distance from the corner marks to the edge of the frame.
  static const double cornerInset = 12;

  /// The length of the arms of a corner mark.
  static const double cornerArm = 18;

  /// The width of the strokes of the marks and the lock.
  static const double strokeWidth = 2;

  /// The width of the lines of the grid of thirds.
  static const double gridWidth = 1;

  /// The width of the focus lock indicator.
  static const double lockWidth = 80;

  /// The height of the focus lock indicator.
  static const double lockHeight = 64;

  /// The length of the arms of the brackets of the focus lock.
  static const double bracketArm = 14;

  /// The width of the body of the padlock.
  static const double padlockWidth = 14;

  /// The height of the body of the padlock.
  static const double padlockHeight = 10;

  /// How far the body of the padlock is below the centre.
  static const double padlockDrop = 3;

  /// Half the width of the shackle of the padlock (and its radius).
  static const double shackleHalf = 4;

  /// How far above the centre the legs of the shackle end.
  static const double shackleFoot = 2;

  /// How far above the centre the arc of the shackle starts.
  static const double shackleTop = 5;

  /// Half the length of the moving line of the level.
  static const double levelHalfLength = 44;

  /// The length of each of the two fixed ticks of the level.
  static const double levelTick = 14;

  /// The space between the moving line and a fixed tick.
  static const double levelGap = 10;
}

/// The proportions of the seven-segment digits (token sheet of proposal A),
/// as shares of the height of a digit unless said otherwise.
abstract final class CarreteSegment {
  /// The width of a digit.
  static const double digitWidth = 0.56;

  /// The width of the strokes.
  static const double stroke = 0.13;

  /// How far the digits lean, in degrees.
  static const double leanDegrees = 8;

  /// The space between two digits.
  static const double gap = 0.22;

  /// The width of a space, as a share of the width of a digit.
  static const double space = 0.6;

  /// The width of an apostrophe, as a share of the width of a digit.
  static const double apostrophe = 0.5;

  /// Where the top of the apostrophe is, as a share of the width of a digit.
  static const double apostropheTop = 0.3;

  /// Where the foot of the apostrophe is, as a share of the width of a
  /// digit.
  static const double apostropheFoot = 0.12;

  /// How far the apostrophe drops.
  static const double apostropheDrop = 0.3;

  /// The distance from the edge of the digit to the segments, as a share of
  /// the width of the stroke.
  static const double edgeInset = 0.6;

  /// The gap left between two segments at a corner, as a share of the width
  /// of the stroke.
  static const double cornerGap = 0.62;

  /// The opacity of the segments that are off.
  static const double ghostAlpha = 0.13;

  /// The opacity of the glow.
  static const double glowAlpha = 0.55;

  /// The width of the stroke of the glow, as a share of the stroke.
  static const double glowStroke = 1.8;

  /// The blur sigma of the glow.
  static const double glowBlur = 0.1;
}

/// The motion effects that are not a plain duration.
abstract final class CarreteMotion {
  /// The opacity of the shutter flash at its peak.
  static const double flashPeak = 0.55;

  /// How much of the flash it takes to reach the peak.
  static const double flashRise = 0.1;
}

/// The relief shadows of raised parts: a hard 0 2 black one, a diffuse
/// 0 4 7 one and a 1 px light edge on top.
abstract final class CarreteRelief {
  /// The hard shadow under a raised part.
  static const BoxShadow hard = BoxShadow(
    color: CarreteColors.deep,
    offset: Offset(0, 2),
  );

  /// The diffuse shadow under a raised part.
  static const BoxShadow diffuse = BoxShadow(
    color: Color(0x80000000),
    offset: Offset(0, 4),
    blurRadius: 7,
  );

  /// The 1 px light edge on top of a raised part.
  static const Color highlight = Color(0x33FFFFFF);

  /// The light that catches the lower edge of a sunken part, and the edge
  /// of a groove or a tray. White at 10 %.
  static const Color pressedEdge = Color(0x1AFFFFFF);

  /// The light edge under a groove (the track of a slider). White at 12 %.
  static const Color grooveEdge = Color(0x1FFFFFFF);

  /// The inner shadow of a sunken part.
  static const Color innerShadow = Color(0xFF000000);

  /// The blur sigma of the inner shadows.
  static const double innerBlur = 2.5;

  /// How far the inner shadow of a sunken part is pushed down.
  static const double innerOffset = 2;

  /// How far past the part the shadow mask extends, so the blur is even.
  static const double innerBleed = 20;

  /// The height of the strip of the light edge on top of a raised part.
  static const double edgeStrip = 2;

  /// The width of the light edge.
  static const double edgeWidth = 1;

  /// The opacity of the content of a disabled key.
  static const double disabledOpacity = 0.4;

  /// How much of the rule colour tints a row of a list while it is pressed.
  static const double pressedRowOpacity = 0.35;

  /// The inner shadow of the LCD window. Black at 50 %.
  static const Color lcdShadow = Color(0x80000000);

  /// The shadow under the tuning panel.
  static const BoxShadow panel = BoxShadow(
    color: CarreteColors.pill,
    offset: Offset(0, 12),
    blurRadius: 30,
  );
}

/// The row under the carousel: the gallery and camera keys on the left, the
/// shutter in the middle and the format key on the right.
abstract final class CarreteShutterRow {
  /// The least margin at the edge of the screen.
  static const double minInset = 12;

  /// The size of the keys, the gap between the two on the left and the margin
  /// that fit [width]: big keys with the usual margin when there is room,
  /// otherwise keys of the minimum touch size with a tight gap and the margin
  /// giving way (never under [minInset]).
  static ({double key, double gap, double inset}) fit(double width) {
    final room = (width - CarreteSpacing.shutter) / 2;
    const roomy = 2 * CarreteSpacing.keyBig + CarreteSpacing.s;
    if (room >= CarreteSizes.shutterRowInset + roomy) {
      return (
        key: CarreteSpacing.keyBig,
        gap: CarreteSpacing.s,
        inset: CarreteSizes.shutterRowInset,
      );
    }
    const tight = 2 * CarreteSpacing.minTouch + CarreteSpacing.xs;
    return (
      key: CarreteSpacing.minTouch,
      gap: CarreteSpacing.xs,
      inset: (room - tight).clamp(minInset, CarreteSizes.shutterRowInset),
    );
  }
}

/// The colours of the contact sheet (design A): the paper, the strips of film
/// with their perforations and the numbers printed on the edge. It follows the
/// theme of the app.
@immutable
class CarreteSheetColors {
  const CarreteSheetColors({
    required this.sheet,
    required this.strip,
    required this.perf,
    required this.edge,
    required this.empty,
    required this.emptyInk,
  });

  /// The sheet of paper under the strips.
  final Color sheet;

  /// The base of the film.
  final Color strip;

  /// The perforations.
  final Color perf;

  /// The numbers printed on the edge of the film.
  final Color edge;

  /// The inside of a frame with no photo.
  final Color empty;

  /// The small print inside a frame with no photo.
  final Color emptyInk;

  /// Positive on paper: black strips and white perforations.
  static const CarreteSheetColors light = CarreteSheetColors(
    sheet: Color(0xFFFBFAF6),
    strip: Color(0xFF0C0C0D),
    perf: CarreteColors.paper,
    edge: CarreteColors.paper,
    empty: Color(0xFF26272A),
    emptyInk: CarreteColors.silk2,
  );

  /// Light table: strips with an amber base, lit perforations and orange
  /// numbering.
  static const CarreteSheetColors dark = CarreteSheetColors(
    sheet: Color(0xFF17181A),
    strip: Color(0xFF2A1D12),
    perf: Color(0xFFE9D9B8),
    edge: Color(0xFFD6902F),
    empty: Color(0xFF3A2915),
    emptyInk: Color(0xFFD6902F),
  );

  /// The colours of the theme in force.
  static CarreteSheetColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// Sizes of the roll screens: the roll sheet of the camera, the developing
/// screen and the contact sheet.
abstract final class CarreteRoll {
  /// The frames of one strip of the contact sheet.
  static const int stripFrames = 4;

  /// The shape of a frame of the contact sheet, width over height: a 35 mm
  /// frame. Photos are cropped to it; the viewer shows them whole.
  static const double frameAspect = 3 / 2;

  /// The gap between the frames of a strip.
  static const double frameGap = 4;

  /// The space between the film and the edge of its strip.
  static const double stripInset = 6;

  /// The space under a strip.
  static const double stripGap = 9;

  /// The height of a row of perforations.
  static const double perfHeight = 9;

  /// The distance between two perforations.
  static const double perfPitch = 10;

  /// The size of a perforation.
  static const double perfWidth = 6;
  static const double perfHole = 5;
  static const double perfRadius = 1.3;

  /// The share of the reveal each frame takes to come in (the rest is the
  /// stagger between the first frame and the last).
  static const double revealFrameShare = 0.25;

  /// How far a frame rises while it comes in, as a share of its own height.
  static const double revealRise = 0.12;

  /// The side of the thumbnails asked of the gallery, in pixels.
  static const int thumbnailExtent = 320;

  /// The side photos are decoded to in the viewer, in pixels.
  static const int viewerExtent = 2560;

  /// The most thumbnails kept in memory.
  static const int thumbnailCache = 120;

  /// The most rolls the sheet of the camera lists.
  static const int recentRolls = 5;

  /// The width of the sheet of the camera.
  static const double sheetMaxWidth = 560;

  /// The width of the confirmation dialogs.
  static const double dialogMaxWidth = 360;

  /// The inset of the dialogs from the edge of the screen.
  static const double dialogInset = 24;

  /// The side of the colour swatch of a film in a list.
  static const double swatch = 14;

  /// The height of a row of the lists of the roll sheet.
  static const double rowHeight = 56;

  /// The padding of the sheet of the camera.
  static const EdgeInsets sheetPadding = EdgeInsets.fromLTRB(16, 12, 16, 16);

  /// The size of the LCD of the developing screen and its digits.
  static const double lcdWidth = 200;
  static const double lcdHeight = 84;
  static const double lcdDigits = 48;
  static const double lcdTotalDigits = 24;
  static const double lcdIcon = 28;

  /// A frame of the progress strip of the developing screen.
  static const double progressCellWidth = 24;
  static const double progressCellHeight = 16;
  static const double progressCellGap = 4;
  static const double progressCellRadius = 2;

  /// The most a column of text grows on a wide screen.
  static const double bodyMaxWidth = 560;

  /// The least height the preview of the shareable sheet (or its message)
  /// gets: on a shorter screen the whole page scrolls instead.
  static const double sharePreviewMinHeight = 240;

  /// What the header, the keys and the gaps of the share preview take at the
  /// normal text size (it grows with the text). With the preview's minimum it
  /// tells when the page has to scroll.
  static const double shareChromeHeight = 260;

  /// The spinner shown while the sheet is painted, and its line.
  static const double shareSpinner = 28;
  static const double shareSpinnerStroke = 2.5;

  /// The space around the viewer's page counter.
  static const double viewerBar = 64;

  /// How far under the status bar the notice of the viewer sits: under the
  /// back key.
  static const double viewerNoticeTop = 64;

  /// The most frames of one contact sheet of loose photos: a long day is cut
  /// into sheets of a roll of 35 mm film, so a screen never builds hundreds
  /// of thumbnails at once.
  static const int sheetFrames = 36;

  /// The frames shown on the card of a roll or a day in the gallery.
  static const int cardFrames = 4;
}

/// The status of the photos being saved, over the picture of the camera.
///
/// It sits on the picture like the other pills, so it is dark whatever the
/// theme: its colours are the ones of a notice over the picture.
abstract final class CarreteSaveStatus {
  /// How long saving must last before the camera says so: a single fast save
  /// never flickers on the screen.
  static const Duration showDelay = Duration(milliseconds: 400);

  /// The pill coming in or going out. Not used with reduced motion.
  static const Duration fade = Duration(milliseconds: 160);

  /// The size of the progress mark.
  static const double mark = 12;

  /// The line of the progress mark.
  static const double markStroke = 1.5;

  /// The size of the dot of the chip of photos that wait.
  static const double dot = 8;

  /// The gap between the mark or the dot and the text.
  static const double gap = 8;

  /// The most width the pill takes, so a long text wraps instead of reaching
  /// the keys of the top bar.
  static const double maxWidth = 320;

  /// The dot of the chip: the coral of the shutter, the warning colour of the
  /// dark camera.
  static const Color warn = CarreteColors.shutterCapTop;
}
