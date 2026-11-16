import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../camera/camera_flash.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme/carrete_tokens.dart';
import '../../ui/widgets/carrete_icon.dart';
import '../../ui/widgets/plastic_controls.dart';
import '../../ui/widgets/plastic_key.dart';
import '../../ui/widgets/seven_segment.dart';

/// How the top bar is laid out for the width and the text size of the phone.
///
/// The keys grow with the text, up to [CarreteSizes.topBarMaxScale]; above it
/// the text shrinks to fit the key (and is never cut). When the roll control
/// has no room for its text at a legible size it moves to a row of its own,
/// under the LCD and the keys, and the bar is taller.
///
/// The camera screen asks for the same layout to reserve the room, so the
/// picture never goes under the bar.
@immutable
class TopBarLayout {
  const TopBarLayout({required this.scale, required this.stacked});

  /// The factor the keys and the LCD grow by (1 to the cap).
  final double scale;

  /// Whether the roll control has a row of its own.
  final bool stacked;

  /// The height of a row of keys.
  double get rowHeight => CarreteSizes.topBarRow * scale;

  /// The height of a key.
  double get keyHeight => CarreteSpacing.minTouch * scale;

  /// The height of the LCD window.
  double get lcdHeight => CarreteSizes.lcdHeight * scale;

  /// What the camera reserves under the status bar for the bar.
  double get reserve =>
      CarreteSizes.topBarReserve +
      (scale - 1) * (CarreteSizes.topBarRow + CarreteSizes.lcdCaptionHeight) +
      (stacked ? CarreteSpacing.s + keyHeight : 0);

  /// The factor the text of the bar grows by: the text scale of the phone,
  /// capped.
  static double scaleOf(BuildContext context) =>
      MediaQuery.textScalerOf(context)
          .scale(1)
          .clamp(1.0, CarreteSizes.topBarMaxScale);

  /// The layout for a bar [width] wide. The other values are what the roll
  /// control will say.
  static TopBarLayout of(
    BuildContext context, {
    required double width,
    required bool hasRoll,
    String? filmName,
    int? framesLeft,
    int? pausedDisposableLeft,
  }) {
    final scale = scaleOf(context);
    if (!hasRoll) return TopBarLayout(scale: scale, stacked: false);
    final l10n = AppLocalizations.of(context);
    final scaler = TextScaler.linear(scale);
    double natural(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final w = painter.width;
      painter.dispose();
      return w;
    }

    final loaded = framesLeft != null;
    final paused = !loaded && pausedDisposableLeft != null;
    // What the text of the control needs: the longest line, or the longest
    // word of the label (which wraps onto two lines).
    final double needed;
    if (loaded || paused) {
      final left = rollLeftText(framesLeft ?? pausedDisposableLeft!);
      needed =
          math.max(
            natural(
              paused ? l10n.rollKeyPausedTitle : filmName ?? l10n.rollKeyLoad,
              CarreteText.keyCaption,
            ),
            natural(l10n.rollKeyLeft(left), CarreteText.keyDetail),
          ) *
          CarreteSizes.rollTextLegible;
    } else {
      needed = l10n.rollKeyLoad
          .split(RegExp(r'\s+'))
          .map((word) => natural(word, CarreteText.keyCaption))
          .reduce(math.max);
    }
    final shared =
        width -
        CarreteSizes.flashKeyWidth -
        CarreteSpacing.minTouch -
        3 * CarreteSpacing.s;
    final lcd = (shared * CarreteSizes.lcdShare).clamp(
      CarreteSizes.lcdMinWidth,
      CarreteSizes.lcdWidth,
    );
    final text = rollKeyTextWidth(shared - lcd);
    return TopBarLayout(scale: scale, stacked: text < needed);
  }

  /// The width the text of the roll control has inside a key [keyWidth] wide.
  static double rollKeyTextWidth(double keyWidth) => math.max(
    0.0,
    keyWidth -
        2 * CarreteSpacing.s -
        CarreteSizes.captionedKeyIcon -
        CarreteSpacing.xs,
  );

  /// The frames left as the roll control and the LCD print them: "08".
  static String rollLeftText(int left) => left.toString().padLeft(2, '0');
}

/// The top bar of the viewfinder: the LCD counter, the labelled roll control,
/// the flash key (one key that cycles the modes) and the settings key.
class ViewfinderTopBar extends StatelessWidget {
  const ViewfinderTopBar({
    required this.flash,
    required this.onFlash,
    required this.onSettings,
    this.rollFramesLeft,
    this.pausedDisposableLeft,
    this.filmName,
    this.onRoll,
    this.advance,
    this.rewind,
    super.key,
  });

  /// The frames the loaded roll has left, or null when no roll is loaded. The
  /// LCD then shows them: with a roll the photos are never shown, only how
  /// many frames are left.
  final int? rollFramesLeft;

  /// The frames a disposable camera that is set aside has left, or null when
  /// there is none. The camera shoots loose photos meanwhile; only the roll
  /// control says the disposable is waiting.
  final int? pausedDisposableLeft;

  /// The name of the film the camera has now: the LCD shows it while there
  /// is no roll, and the roll control while there is one.
  final String? filmName;

  /// Called by the roll control. The control is not drawn when this is null.
  final VoidCallback? onRoll;

  /// The selected flash mode.
  final CarreteFlash flash;

  /// Called with the mode the flash key goes on to.
  final ValueChanged<CarreteFlash> onFlash;

  /// Opens the settings.
  final VoidCallback onSettings;

  /// The film advance animation of the LCD, or null when it is not running.
  final Animation<double>? advance;

  /// The rewind animation of the LCD after the last frame of a roll, or null.
  final Animation<double>? rewind;

  static const double _gap = CarreteSpacing.s;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final scale = TopBarLayout.scaleOf(context);
    // Everything in the bar follows the text size of the phone up to the cap.
    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(scale)),
      child: LayoutBuilder(
        builder: (context, constraints) => _bar(context, constraints.maxWidth),
      ),
    );
  }

  Widget _bar(BuildContext context, double width) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final colors = CarreteCameraColors.of(context);
    final label = CarreteText.label.copyWith(color: colors.inkSoft);
    final hasRoll = onRoll != null;
    final layout = TopBarLayout.of(
      context,
      width: width,
      hasRoll: hasRoll,
      filmName: filmName,
      framesLeft: rollFramesLeft,
      pausedDisposableLeft: pausedDisposableLeft,
    );
    final stacked = layout.stacked;
    Widget slot(Widget child) => SizedBox(
      height: layout.rowHeight,
      child: Center(child: child),
    );

    // What the LCD and the roll control share once the flash key and the
    // settings key have their room. Stacked, the roll control has its own row
    // and the LCD takes what is left.
    final inRow = (hasRoll && !stacked) ? 4 : 3;
    final shared =
        width -
        CarreteSizes.flashKeyWidth -
        CarreteSpacing.minTouch -
        (inRow - 1) * _gap;
    final double lcdWidth;
    if (hasRoll && !stacked) {
      lcdWidth = (shared * CarreteSizes.lcdShare).clamp(
        CarreteSizes.lcdMinWidth,
        CarreteSizes.lcdWidth,
      );
    } else {
      lcdWidth = shared.clamp(
        CarreteSizes.lcdMinWidth,
        stacked ? CarreteSizes.lcdStackedWidth : CarreteSizes.lcdWidth,
      );
    }
    final rollWidth = stacked
        ? width
        : math.max(shared - lcdWidth, CarreteSpacing.minTouch);
    final needed =
        lcdWidth +
        (hasRoll && !stacked ? rollWidth : 0) +
        CarreteSizes.flashKeyWidth +
        CarreteSpacing.minTouch +
        (inRow - 1) * _gap;

    final roll = hasRoll
        ? _RollControl(
            width: rollWidth,
            height: layout.keyHeight,
            stacked: stacked,
            filmName: filmName,
            framesLeft: rollFramesLeft,
            pausedDisposableLeft: pausedDisposableLeft,
            onPressed: onRoll!,
          )
        : null;

    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SizedBox(
          width: lcdWidth,
          child: Column(
            children: [
              slot(
                LcdCounter(
                  filmName: filmName ?? '',
                  framesLeft: rollFramesLeft,
                  width: lcdWidth,
                  height: layout.lcdHeight,
                  advance: advance,
                  rewind: rewind,
                ),
              ),
              const SizedBox(height: CarreteSpacing.xs),
              // With a roll the LCD already says what it counts.
              if (rollFramesLeft == null)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    key: const ValueKey('lcd-caption'),
                    CarreteText.upper(l10n.cameraCounterLabel, locale),
                    style: label,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
        if (roll != null && !stacked) slot(roll),
        slot(
          _FlashKey(flash: flash, onFlash: onFlash, height: layout.keyHeight),
        ),
        slot(
          PlasticKey(
            key: const ValueKey('settings-key'),
            semanticLabel: l10n.settingsTitle,
            height: layout.keyHeight,
            onPressed: onSettings,
            child: const CarreteIconView(icon: CarreteIcon.sliders),
          ),
        ),
      ],
    );

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: math.max(width, needed),
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  row,
                  const SizedBox(height: CarreteSpacing.s),
                  Align(alignment: Alignment.centerLeft, child: roll),
                ],
              )
            : row,
      ),
    );
  }
}

/// The labelled control that opens the roll sheet. Without a roll it says
/// "Load roll"; with one it shows the film and how many frames are left; with
/// a disposable camera set aside it says so.
///
/// Its text is never cut: the label wraps onto two lines, and the other lines
/// shrink to fit.
class _RollControl extends StatelessWidget {
  const _RollControl({
    required this.width,
    required this.height,
    required this.stacked,
    required this.onPressed,
    this.filmName,
    this.framesLeft,
    this.pausedDisposableLeft,
  });

  final double width;
  final double height;
  final bool stacked;
  final VoidCallback onPressed;
  final String? filmName;
  final int? framesLeft;
  final int? pausedDisposableLeft;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final loaded = framesLeft != null;
    final paused = !loaded && pausedDisposableLeft != null;
    final semantic = loaded
        ? l10n.rollKeyOpen(framesLeft!)
        : paused
        ? l10n.rollKeyPaused(pausedDisposableLeft!)
        : l10n.rollKeyLoad;
    final textWidth = TopBarLayout.rollKeyTextWidth(width);
    return PlasticKey(
      key: const ValueKey('roll-key'),
      semanticLabel: semantic,
      selected: loaded || paused,
      width: width,
      height: height,
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: CarreteSpacing.s),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CarreteIconView(
                icon: CarreteIcon.roll,
                size: CarreteSizes.captionedKeyIcon,
              ),
              const SizedBox(width: CarreteSpacing.xs),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: textWidth),
                child: Builder(
                  builder: (context) {
                    final color = DefaultTextStyle.of(context).style.color;
                    final title = CarreteText.keyCaption.copyWith(color: color);
                    final detail = CarreteText.keyDetail.copyWith(color: color);
                    if (!loaded && !paused) {
                      // Two lines when the control shares the row, one when
                      // it has a row of its own.
                      return stacked
                          ? Text(
                              l10n.rollKeyLoad,
                              key: const ValueKey('roll-key-label'),
                              maxLines: 1,
                              softWrap: false,
                              style: title,
                            )
                          : Text(
                              l10n.rollKeyLoad,
                              key: const ValueKey('roll-key-label'),
                              maxLines: 2,
                              style: title,
                            );
                    }
                    final left = TopBarLayout.rollLeftText(
                      loaded ? framesLeft! : pausedDisposableLeft!,
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Fit(
                          child: Text(
                            paused
                                ? l10n.rollKeyPausedTitle
                                : filmName ?? l10n.rollKeyLoad,
                            key: const ValueKey('roll-key-label'),
                            maxLines: 1,
                            style: title,
                          ),
                        ),
                        _Fit(
                          child: Text(
                            l10n.rollKeyLeft(left),
                            key: const ValueKey('roll-key-left'),
                            maxLines: 1,
                            style: detail,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shrinks a line of text that is longer than its room instead of cutting it.
class _Fit extends StatelessWidget {
  const _Fit({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: AlignmentDirectional.centerStart,
    child: child,
  );
}

/// The name of a flash mode in the language of the app.
String flashModeName(AppLocalizations l10n, CarreteFlash flash) =>
    switch (flash) {
      CarreteFlash.off => l10n.flashOff,
      CarreteFlash.auto => l10n.flashAuto,
      CarreteFlash.on => l10n.flashOn,
      CarreteFlash.party => l10n.flashParty,
    };

const Map<CarreteFlash, CarreteIcon> _flashIcons = {
  CarreteFlash.off: CarreteIcon.flashOff,
  CarreteFlash.auto: CarreteIcon.flashAuto,
  CarreteFlash.on: CarreteIcon.flashOn,
  CarreteFlash.party: CarreteIcon.flashParty,
};

/// The one flash key: it shows the mode with its icon and its name, and each
/// press goes on to the next mode (off, auto, on, party, and off again).
class _FlashKey extends StatelessWidget {
  const _FlashKey({
    required this.flash,
    required this.onFlash,
    required this.height,
  });

  final CarreteFlash flash;
  final ValueChanged<CarreteFlash> onFlash;
  final double height;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final name = flashModeName(l10n, flash);
    final next =
        CarreteFlash.values[(flash.index + 1) % CarreteFlash.values.length];
    return PlasticKey(
      key: const ValueKey('flash-key'),
      semanticLabel: l10n.flashKeyLabel(name),
      semanticHint: l10n.flashKeyHint,
      selected: flash != CarreteFlash.off,
      width: CarreteSizes.flashKeyWidth,
      height: height,
      onPressed: () => onFlash(next),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: CarreteSizes.hair),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CarreteIconView(
                icon: _flashIcons[flash]!,
                size: CarreteSizes.captionedKeyIcon,
              ),
              const SizedBox(height: CarreteSizes.hair),
              Builder(
                builder: (context) => Text(
                  CarreteText.upper(name, locale),
                  key: const ValueKey('flash-name'),
                  maxLines: 1,
                  style: CarreteText.keyCaption.copyWith(
                    color: DefaultTextStyle.of(context).style.color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The LCD window. Without a roll it shows the name of the film of the camera
/// and, under the window, that the photos are loose; with a roll it shows how
/// many frames are left ("Left 08"). While a photo is taken a strip of eight
/// frames runs along the bottom in dry motor steps; after the last frame of a
/// roll the strip runs backwards, like a rewind.
///
/// A long film name takes two lines and ends with an ellipsis; it is never
/// shrunk below the size of the text of the LCD.
class LcdCounter extends StatelessWidget {
  const LcdCounter({
    required this.width,
    this.height = CarreteSizes.lcdHeight,
    this.filmName = '',
    this.framesLeft,
    this.advance,
    this.rewind,
    super.key,
  });

  /// The name of the film of the camera, shown while there is no roll.
  final String filmName;

  /// The frames left of the loaded roll (it counts down, like a compact camera
  /// of the 90s), or null when no roll is loaded.
  final int? framesLeft;

  /// The width of the window.
  final double width;

  /// The height of the window.
  final double height;

  /// The film advance animation, or null.
  final Animation<double>? advance;

  /// The rewind animation, or null.
  final Animation<double>? rewind;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final left = framesLeft;
    final Widget? content;
    if (left != null) {
      content = FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              CarreteText.upper(l10n.rollCounterLabel, locale),
              key: const ValueKey('lcd-left-label'),
              maxLines: 1,
              style: CarreteText.lcdSmall,
            ),
            const SizedBox(width: CarreteSpacing.s),
            SevenSegmentText(
              text: TopBarLayout.rollLeftText(left),
              height: CarreteSizes.lcdDigits,
              color: CarreteColors.lcdInk,
              ghost: true,
            ),
          ],
        ),
      );
    } else if (filmName.isEmpty) {
      content = null;
    } else {
      content = Center(
        child: Text(
          CarreteText.upper(filmName, locale),
          key: const ValueKey('lcd-film-name'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: CarreteText.lcdSmall,
        ),
      );
    }
    return Semantics(
      label: left != null
          ? l10n.rollCounterSemantics(left)
          : l10n.cameraCounterSemantics(filmName),
      excludeSemantics: true,
      child: LcdWindow(
        width: width,
        height: height,
        // The stack fills the window: the strip is placed against the bottom
        // of the window, not against the bottom of the text.
        child: Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Padding(
                // Room above and below so the content never touches the
                // strip of the film advance.
                padding: const EdgeInsets.symmetric(
                  horizontal: CarreteSizes.lcdInset,
                  vertical: CarreteSizes.lcdInsetV,
                ),
                child: content,
              ),
            ),
            if (advance != null)
              _Strip(
                key: const ValueKey('lcd-strip'),
                animation: advance!,
                steps: CarreteDurations.filmAdvanceSteps,
                direction: -1,
              ),
            if (rewind != null)
              _Strip(
                key: const ValueKey('lcd-rewind-strip'),
                animation: rewind!,
                steps: CarreteDurations.rewindSteps,
                direction: 1,
              ),
          ],
        ),
      ),
    );
  }
}

/// The strip of eight frames that runs along the bottom of the LCD while
/// [animation] is between 0 and 1, in dry steps, to the left ([direction] -1)
/// or to the right (1).
class _Strip extends StatelessWidget {
  const _Strip({
    required this.animation,
    required this.steps,
    required this.direction,
    super.key,
  });

  final Animation<double> animation;
  final int steps;
  final int direction;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: CarreteSizes.stripBottom,
      height: CarreteSizes.stripHeight,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = animation.value;
          if (t <= 0 || t >= 1) return const SizedBox.shrink();
          final step = (t * steps).floor() / steps;
          return ClipRect(
            child: Transform.translate(
              offset: Offset(direction * CarreteSizes.stripTravel * step, 0),
              child: const _FilmStrip(),
            ),
          );
        },
      ),
    );
  }
}

class _FilmStrip extends StatelessWidget {
  const _FilmStrip();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CarreteSizes.lcdInset),
      child: Row(
        children: [
          for (var i = 0; i < CarreteSizes.stripFrames; i++) ...[
            if (i > 0) const SizedBox(width: CarreteSizes.hair),
            const Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(color: CarreteColors.lcdInk),
                child: SizedBox.expand(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
