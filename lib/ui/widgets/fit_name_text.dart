import 'package:flutter/widgets.dart';

import '../theme/carrete_tokens.dart';

/// A name on a plastic element of a fixed size (a cartridge, the LCD): up to
/// [maxLines] lines, never broken inside a word and never cut by the edge of
/// its room.
///
/// When the longest word is wider than the room, or the lines are taller than
/// it (large system text), the text shrinks just enough to fit, down to
/// [minSize]. Below that it ends with an ellipsis: on [maxLines] lines, or on
/// one line when a single word is wider than the room even at [minSize].
///
/// The result is remembered while the name, the style, the text scale and the
/// room stay the same, so a rebuild does not measure the text again.
class FitNameText extends StatefulWidget {
  const FitNameText(
    this.text, {
    required this.style,
    this.textKey,
    this.maxLines = 2,
    this.textAlign = TextAlign.center,
    this.minSize = CarreteSizes.nameMinSize,
    super.key,
  });

  /// The name, already in the case it is shown in.
  final String text;

  /// The style at the size the name has when it fits at once. It has a font
  /// size, or the default style of the place does.
  final TextStyle style;

  /// The key of the [Text] that paints the name.
  final Key? textKey;

  /// The most lines the name takes.
  final int maxLines;

  /// How the lines are aligned.
  final TextAlign textAlign;

  /// The smallest size the name shrinks to, as painted (the text scale of the
  /// phone included).
  final double minSize;

  @override
  State<FitNameText> createState() => _FitNameTextState();
}

/// Everything the fit depends on.
@immutable
class _FitInputs {
  const _FitInputs({
    required this.text,
    required this.style,
    required this.scaler,
    required this.direction,
    required this.locale,
    required this.textAlign,
    required this.maxLines,
    required this.minSize,
    required this.width,
    required this.height,
  });

  final String text;
  final TextStyle style;
  final TextScaler scaler;
  final TextDirection direction;
  final Locale? locale;
  final TextAlign textAlign;
  final int maxLines;
  final double minSize;
  final double width;
  final double height;

  @override
  bool operator ==(Object other) =>
      other is _FitInputs &&
      other.text == text &&
      other.style == style &&
      other.scaler == scaler &&
      other.direction == direction &&
      other.locale == locale &&
      other.textAlign == textAlign &&
      other.maxLines == maxLines &&
      other.minSize == minSize &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(
    text,
    style,
    scaler,
    direction,
    locale,
    textAlign,
    maxLines,
    minSize,
    width,
    height,
  );
}

/// How a name is painted: its font size and whether its words stay whole on
/// [FitNameText.maxLines] lines (false: one ellipsized line).
typedef _Fit = ({double size, bool whole});

_Fit _fit(_FitInputs i, double base) {
  final words = i.text
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  final painter = TextPainter(
    textDirection: i.direction,
    textScaler: i.scaler,
    textAlign: i.textAlign,
    locale: i.locale,
  );

  void measure(String string, double size, int? lines) {
    painter
      ..text = TextSpan(
        text: string,
        style: i.style.copyWith(fontSize: size),
      )
      ..maxLines = lines
      ..ellipsis = lines == null ? null : '\u2026'
      ..layout(maxWidth: lines == 1 ? double.infinity : i.width);
  }

  bool wordsFit(double size) {
    for (final word in words) {
      measure(word, size, 1);
      if (painter.width > i.width + 0.01) return false;
    }
    return true;
  }

  bool fits(double size) {
    if (!wordsFit(size)) return false;
    measure(i.text, size, i.maxLines);
    return !painter.didExceedMaxLines &&
        (!i.height.isFinite || painter.height <= i.height + 0.01);
  }

  var size = base;
  // The text shrinks in small steps (letter spacing does not scale with the
  // size, so a straight ratio would be a little short).
  while (!fits(size)) {
    final next = size * 0.94;
    if (i.scaler.scale(next) < i.minSize) {
      // The floor: the size that paints at the minimum, if that is a shrink at
      // all.
      final floor = size * i.minSize / i.scaler.scale(size);
      if (floor < size) size = floor;
      break;
    }
    size = next;
  }
  // A word that does not fit even at the floor is ellipsized on one line
  // rather than broken in the middle.
  final whole = wordsFit(size);
  painter.dispose();
  return (size: size, whole: whole);
}

class _FitNameTextState extends State<FitNameText> {
  _FitInputs? _inputs;
  _Fit? _result;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // What the [Text] below paints: the style over the default of the
        // place, so the measures are the ones of the real text.
        final resolved = DefaultTextStyle.of(context).style.merge(widget.style);
        final base = resolved.fontSize;
        if (base == null) {
          return Text(
            widget.text,
            key: widget.textKey,
            textAlign: widget.textAlign,
            maxLines: widget.maxLines,
            overflow: TextOverflow.ellipsis,
            style: widget.style,
          );
        }
        final inputs = _FitInputs(
          text: widget.text,
          style: resolved,
          scaler: MediaQuery.textScalerOf(context),
          direction: Directionality.of(context),
          locale: Localizations.maybeLocaleOf(context),
          textAlign: widget.textAlign,
          maxLines: widget.maxLines,
          minSize: widget.minSize,
          width: constraints.maxWidth,
          height: constraints.maxHeight,
        );
        if (inputs != _inputs) {
          _result = _fit(inputs, base);
          _inputs = inputs;
        }
        final fit = _result!;
        return Text(
          widget.text,
          key: widget.textKey,
          textAlign: widget.textAlign,
          maxLines: fit.whole ? widget.maxLines : 1,
          softWrap: fit.whole,
          overflow: TextOverflow.ellipsis,
          style: widget.style.copyWith(fontSize: fit.size),
        );
      },
    );
  }
}
