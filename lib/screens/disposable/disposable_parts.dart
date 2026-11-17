import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/theme/carrete_tokens.dart';
import '../../ui/theme/disposable_tokens.dart';
import '../../ui/widgets/carrete_icon.dart';

/// A box of paper with an ink outline and a hard shadow with no blur, the way
/// everything of the disposable camera is stuck on.
BoxDecoration paperDecoration({
  Color color = DisposableColors.paper,
  Color shadow = DisposableColors.ink,
  Offset offset = DisposableSizes.shadow,
  double border = 0,
}) => BoxDecoration(
  color: color,
  border: border > 0
      ? Border.all(color: DisposableColors.ink, width: border)
      : null,
  boxShadow: [BoxShadow(color: shadow, offset: offset)],
);

/// The dark band at the top, with the faint ribs of the plastic.
class DisposableBand extends StatelessWidget {
  const DisposableBand({required this.height, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: DisposableColors.band,
          border: Border(
            bottom: BorderSide(
              color: DisposableColors.bandEdge,
              width: DisposableSizes.line,
            ),
          ),
        ),
        child: const CustomPaint(
          painter: _RibPainter(
            color: DisposableColors.bandRib,
            pitch: DisposableSizes.bandRibPitch,
            width: DisposableSizes.ribWidth,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

/// Vertical ribs: the corrugation of the cardboard and of the plastic band.
class _RibPainter extends CustomPainter {
  const _RibPainter({
    required this.color,
    required this.pitch,
    required this.width,
  });

  final Color color;
  final double pitch;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var x = 0.0; x < size.width; x += pitch) {
      canvas.drawRect(Rect.fromLTWH(x, 0, width, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_RibPainter old) =>
      old.color != color || old.pitch != pitch || old.width != width;
}

/// Cuts the jagged edge of torn cardboard on top. The teeth are fixed, so the
/// edge is the same on every build.
class _JaggedTop extends CustomClipper<Path> {
  const _JaggedTop();

  @override
  Path getClip(Size size) {
    final path = Path()..moveTo(0, DisposableSizes.edgeDepth * 0.6);
    var seed = 11;
    const teeth = DisposableSizes.edgeTeeth;
    for (var i = 1; i <= teeth; i++) {
      seed = (seed * 7 + 3) % 9;
      final x = size.width * i / teeth;
      final y = i.isOdd
          ? 0.0
          : DisposableSizes.edgeDepth * (0.5 + seed % 4 / 6);
      path.lineTo(x, y);
    }
    path
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(_JaggedTop old) => false;
}

/// The cardboard of the body, from the jagged edge down to the bottom of the
/// screen.
class Cardboard extends StatelessWidget {
  const Cardboard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const _JaggedTop(),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [DisposableColors.kraftTop, DisposableColors.kraftBottom],
          ),
        ),
        child: CustomPaint(
          painter: const _RibPainter(
            color: DisposableColors.kraftRib,
            pitch: DisposableSizes.kraftRibPitch,
            width: DisposableSizes.ribWidth,
          ),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: DisposableColors.kraftEdge,
                  width: DisposableSizes.lineBold,
                ),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The paper strip across the cardboard: what the camera is and how many
/// photos it has.
class CardboardStrip extends StatelessWidget {
  const CardboardStrip({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: text,
      excludeSemantics: true,
      child: SizedBox(
        height: DisposableSizes.strip,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: DisposableColors.paper,
            border: Border.symmetric(
              horizontal: BorderSide(
                color: DisposableColors.ink,
                width: DisposableSizes.lineBold,
              ),
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CarreteSpacing.margin,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  CarreteText.upper(text, Localizations.localeOf(context)),
                  style: DisposableText.label,
                  maxLines: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The corner marks of the frame.
class DisposableCorners extends StatelessWidget {
  const DisposableCorners({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: ExcludeSemantics(
        child: CustomPaint(size: Size.infinite, painter: _CornersPainter()),
      ),
    );
  }
}

class _CornersPainter extends CustomPainter {
  const _CornersPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const inset = DisposableSizes.cornerInset;
    const arm = DisposableSizes.cornerArm;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = DisposableSizes.cornerStroke
      ..color = DisposableColors.frameMark;
    final r = size.width - inset;
    final b = size.height - inset;
    canvas.drawPath(
      Path()
        ..moveTo(inset, inset + arm)
        ..lineTo(inset, inset)
        ..lineTo(inset + arm, inset)
        ..moveTo(r - arm, inset)
        ..lineTo(r, inset)
        ..lineTo(r, inset + arm)
        ..moveTo(r, b - arm)
        ..lineTo(r, b)
        ..lineTo(r - arm, b)
        ..moveTo(inset + arm, b)
        ..lineTo(inset, b)
        ..lineTo(inset, b - arm),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CornersPainter old) => false;
}

/// The sticker that counts the photos left: a number on paper, stuck on a
/// little crooked, with no screen.
class StickerCounter extends StatelessWidget {
  const StickerCounter({required this.left, super.key});

  final int left;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Transform.rotate(
      angle: DisposableAngles.counter,
      child: Semantics(
        container: true,
        liveRegion: true,
        label: l10n.rollCounterSemantics(left),
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: paperDecoration(shadow: DisposableColors.red),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: DisposableSizes.counterMinWidth,
              minHeight: DisposableSizes.topRow,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CarreteSpacing.s,
                vertical: CarreteSpacing.xs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: DisposableSizes.counterNumberMinWidth,
                    ),
                    child: Text(
                      '$left',
                      textAlign: TextAlign.center,
                      style: DisposableText.number,
                    ),
                  ),
                  const SizedBox(width: CarreteSpacing.s),
                  Flexible(
                    child: Text(
                      CarreteText.upper(
                        l10n.disposableCounterCaption,
                        Localizations.localeOf(context),
                      ),
                      style: DisposableText.caption,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The flash switch: on is red paper with a bolt, off is plain paper with a
/// crossed one.
class FlashSwitch extends StatelessWidget {
  const FlashSwitch({required this.on, required this.onChanged, super.key});

  final bool on;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      container: true,
      button: true,
      toggled: on,
      label: l10n.disposableFlashLabel,
      onTap: () => onChanged(!on),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!on),
        child: DecoratedBox(
          decoration: paperDecoration(
            color: on ? DisposableColors.red : DisposableColors.paper,
            shadow: DisposableColors.yellow,
          ),
          child: SizedBox.square(
            dimension: DisposableSizes.flashBox,
            child: Center(
              child: CarreteIconView(
                icon: on ? CarreteIcon.flashOn : CarreteIcon.flashOff,
                color: on ? DisposableColors.paper : DisposableColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The stamp that leaves the mode. It has to be held down: the yellow ink
/// fills it for [hold], and only then does [onExit] run.
class ExitStamp extends StatefulWidget {
  const ExitStamp({
    required this.onExit,
    this.hold = DisposableDurations.exitHold,
    super.key,
  });

  final VoidCallback onExit;

  /// How long the stamp has to be held.
  final Duration hold;

  @override
  State<ExitStamp> createState() => _ExitStampState();
}

class _ExitStampState extends State<ExitStamp>
    with SingleTickerProviderStateMixin {
  /// The yellow ink filling the stamp. It is only a picture: the system
  /// shortens controllers when it asks for reduced motion, so the time of the
  /// hold is kept by [_timer], which nothing shortens.
  late final AnimationController _held = AnimationController(
    vsync: this,
    duration: widget.hold,
    animationBehavior: AnimationBehavior.preserve,
  );
  Timer? _timer;

  void _press() {
    _timer?.cancel();
    _timer = Timer(widget.hold, _done);
    _held.forward(from: 0);
  }

  void _done() {
    _timer = null;
    _held.value = 0;
    widget.onExit();
  }

  void _release() {
    _timer?.cancel();
    _timer = null;
    _held.value = 0;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _held.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    return Transform.rotate(
      angle: DisposableAngles.exit,
      child: Semantics(
        container: true,
        button: true,
        label: l10n.disposableExitSemantics,
        // A screen reader has no way to hold: its long press does the same.
        onLongPress: widget.onExit,
        excludeSemantics: true,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => _press(),
          onPointerUp: (_) => _release(),
          onPointerCancel: (_) => _release(),
          child: DecoratedBox(
            decoration: paperDecoration(
              color: DisposableColors.kraft,
              shadow: DisposableColors.paper,
              border: DisposableSizes.line,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: DisposableSizes.exitWidth,
                minHeight: DisposableSizes.topRow,
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _held,
                      builder: (context, _) => Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: _held.value,
                          heightFactor: 1,
                          child: const ColoredBox(
                            color: DisposableColors.yellow,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CarreteSpacing.s,
                      vertical: CarreteSpacing.xs,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          CarreteText.upper(l10n.disposableExitWord, locale),
                          style: DisposableText.stamp,
                          maxLines: 1,
                        ),
                        const SizedBox(height: CarreteSizes.hair),
                        Text(
                          CarreteText.upper(l10n.disposableExitHint, locale),
                          style: DisposableText.caption,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The shutter: a paper disc with a dashed ring and a red button that sinks
/// when it is pressed.
class DisposableShutter extends StatefulWidget {
  const DisposableShutter({
    required this.semanticLabel,
    required this.onPressed,
    super.key,
  });

  final String semanticLabel;

  /// Null while there is nothing to shoot with.
  final VoidCallback? onPressed;

  @override
  State<DisposableShutter> createState() => _DisposableShutterState();
}

class _DisposableShutterState extends State<DisposableShutter> {
  bool _down = false;

  void _set(bool value) {
    if (_down != value) setState(() => _down = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final pressed = _down && enabled;
    final offset = pressed
        ? DisposableSizes.shadowPressed
        : DisposableSizes.shadowLarge;
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      onTap: widget.onPressed,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onPressed,
        child: Opacity(
          opacity: enabled ? 1 : CarreteRelief.disabledOpacity,
          child: Transform.translate(
            offset: pressed
                ? DisposableSizes.shadowLarge - DisposableSizes.shadowPressed
                : Offset.zero,
            child: SizedBox.square(
              dimension: DisposableSizes.shutterDisc,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: DisposableColors.paper,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: DisposableColors.ink,
                    width: DisposableSizes.lineBold,
                  ),
                  boxShadow: [
                    BoxShadow(color: DisposableColors.ink, offset: offset),
                  ],
                ),
                child: CustomPaint(
                  painter: const _DashedRingPainter(),
                  child: Center(
                    child: SizedBox.square(
                      dimension: DisposableSizes.shutterButton,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: DisposableColors.red,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: DisposableColors.ink,
                            width: DisposableSizes.line,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedRingPainter extends CustomPainter {
  const _DashedRingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final ring = Path()
      ..addOval(
        (Offset.zero & size).deflate(
          DisposableSizes.shutterRingInset + DisposableSizes.lineBold,
        ),
      );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = DisposableSizes.line
      ..color = DisposableColors.ink;
    for (final metric in ring.computeMetrics()) {
      _dash(canvas, metric, paint);
    }
  }

  void _dash(Canvas canvas, PathMetric metric, Paint paint) {
    var at = 0.0;
    while (at < metric.length) {
      final end = math.min(at + DisposableSizes.shutterDash, metric.length);
      canvas.drawPath(metric.extractPath(at, end), paint);
      at = end + DisposableSizes.shutterGap;
    }
  }

  @override
  bool shouldRepaint(_DashedRingPainter old) => false;
}

/// The thumb wheel that advances the film. It turns in [clicks] dry steps after
/// each photo; [advances] counts the photos so the wheel never jumps back.
///
/// With no [animation] (reduced motion) it simply shows the new position.
class ThumbWheel extends StatelessWidget {
  const ThumbWheel({required this.advances, this.animation, super.key});

  /// The photos taken since the screen opened.
  final int advances;

  /// The advance of the last photo, from 0 to 1.
  final Animation<double>? animation;

  double _angle(double progress) {
    if (advances == 0) return 0;
    const clicks = DisposableAngles.wheelClicks;
    final step = (progress * clicks).floor().clamp(0, clicks);
    return ((advances - 1) * clicks + step) * DisposableAngles.wheelClick;
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final l10n = AppLocalizations.of(context);
    final wheel = animation == null
        ? _wheel(1)
        : AnimatedBuilder(
            animation: animation!,
            builder: (context, _) => _wheel(animation!.value),
          );
    return ExcludeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            CarreteText.upper(l10n.disposableAdvanceLabel, locale),
            style: DisposableText.caption,
            maxLines: 1,
          ),
          const SizedBox(height: CarreteSpacing.xs),
          wheel,
        ],
      ),
    );
  }

  Widget _wheel(double progress) => Transform.rotate(
    angle: _angle(progress),
    child: const SizedBox.square(
      dimension: DisposableSizes.wheel,
      child: CustomPaint(painter: _WheelPainter()),
    ),
  );
}

class _WheelPainter extends CustomPainter {
  const _WheelPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final scale = size.width / DisposableSizes.wheel;
    final ink = Paint()..color = DisposableColors.ink;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(scale);
    for (var i = 0; i < DisposableSizes.wheelTeeth; i++) {
      canvas.save();
      canvas.rotate(i * 2 * math.pi / DisposableSizes.wheelTeeth);
      canvas.drawRect(
        Rect.fromLTWH(
          -DisposableSizes.wheelToothWidth / 2,
          -DisposableSizes.wheel / 2,
          DisposableSizes.wheelToothWidth,
          DisposableSizes.wheelToothHeight,
        ),
        ink,
      );
      canvas.restore();
    }
    canvas.drawCircle(Offset.zero, DisposableSizes.wheelRim, ink);
    canvas.drawCircle(
      Offset.zero,
      DisposableSizes.wheelFace,
      Paint()..color = DisposableColors.paper,
    );
    final arc = Rect.fromCircle(
      center: Offset.zero,
      radius: DisposableSizes.wheelArc,
    );
    final red = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = DisposableSizes.wheelArcStroke
      ..color = DisposableColors.red;
    canvas.drawArc(arc, -math.pi / 2, math.pi * 1.55, false, red);
    canvas.drawCircle(Offset.zero, DisposableSizes.wheelHub, ink);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WheelPainter old) => false;
}

/// A small paper label stuck on the cardboard: the name of the film.
class FilmSticker extends StatelessWidget {
  const FilmSticker({required this.name, super.key});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: DisposableAngles.counter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: DisposableSizes.labelMaxWidth,
        ),
        child: DecoratedBox(
          decoration: paperDecoration(border: DisposableSizes.line),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CarreteSpacing.s,
              vertical: CarreteSpacing.xs,
            ),
            // A decorative label of the camera body: large text must not
            // break its word in two.
            child: MediaQuery.withClampedTextScaling(
              maxScaleFactor: DisposableSizes.labelMaxTextScale,
              child: Text(
                CarreteText.upper(name, Localizations.localeOf(context)),
                style: DisposableText.caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A notice over the frame: a strip of paper with a yellow shadow.
class DisposableNotice extends StatelessWidget {
  const DisposableNotice({required this.text, this.style, super.key});

  final String text;

  /// The style of the text. When null, the display face of the mode while the
  /// longest word of [text] fits a line at the text scale of the system, and
  /// a narrow face made for reading when it would not (large text on a small
  /// phone).
  final TextStyle? style;

  /// The style for [text] on a line of [maxWidth], measured the way the
  /// [Text] below lays it out: same inherited style, text scale, direction
  /// and locale.
  static TextStyle _fittingStyle(
    BuildContext context,
    String text,
    double maxWidth,
  ) {
    final display = DisposableText.notice;
    final measured = DefaultTextStyle.of(context).style.merge(display);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final locale = Localizations.maybeLocaleOf(context);
    var widest = 0.0;
    for (final word in text.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      final painter = TextPainter(
        text: TextSpan(text: word, style: measured, locale: locale),
        textDirection: direction,
        textScaler: scaler,
        locale: locale,
      )..layout();
      widest = math.max(widest, painter.width);
      painter.dispose();
    }
    return widest <= maxWidth ? display : DisposableText.noticeReadable;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: paperDecoration(
          shadow: DisposableColors.yellow,
          border: DisposableSizes.line,
        ),
        child: Padding(
          padding: const EdgeInsets.all(CarreteSpacing.m),
          // Measured inside the padding: the width the paragraph really gets.
          child: LayoutBuilder(
            builder: (context, constraints) => Text(
              text,
              textAlign: TextAlign.center,
              style:
                  style ?? _fittingStyle(context, text, constraints.maxWidth),
            ),
          ),
        ),
      ),
    );
  }
}

/// A key of paper with an ink outline and a hard shadow: the keys of the
/// dialogs of the mode.
class PaperKey extends StatelessWidget {
  const PaperKey({
    required this.label,
    required this.onPressed,
    this.primary = false,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;

  /// Red paper for the key that does what the dialog is about.
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final text = DisposableText.key.copyWith(
      color: primary ? DisposableColors.paper : DisposableColors.ink,
    );
    return Semantics(
      container: true,
      button: true,
      label: label,
      onTap: onPressed,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: DecoratedBox(
          decoration: paperDecoration(
            color: primary ? DisposableColors.red : DisposableColors.paper,
            border: DisposableSizes.line,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: CarreteSpacing.minTouch,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CarreteSpacing.s,
                  vertical: CarreteSpacing.s,
                ),
                child: Text(
                  CarreteText.upper(label, Localizations.localeOf(context)),
                  style: text,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks to leave the disposable camera. Resolves to true on confirm.
Future<bool> confirmLeaveDisposable(
  BuildContext context, {
  required int left,
}) async {
  final l10n = AppLocalizations.of(context);
  final result = await showDialog<bool>(
    context: context,
    barrierColor: DisposableColors.scrim,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(DisposableSizes.dialogInset),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: DisposableSizes.dialogMaxWidth,
        ),
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          scopesRoute: true,
          namesRoute: true,
          label: l10n.disposableExitTitle,
          child: DecoratedBox(
            decoration: paperDecoration(
              shadow: DisposableColors.yellow,
              offset: DisposableSizes.shadowLarge,
              border: DisposableSizes.lineBold,
            ),
            // Large text on a small screen: the keys scroll into view.
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(CarreteSpacing.l),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      l10n.disposableExitTitle,
                      style: DisposableText.title,
                    ),
                  ),
                  const SizedBox(height: CarreteSpacing.s),
                  Text(
                    l10n.disposableExitBody(left),
                    style: DisposableText.body,
                  ),
                  const SizedBox(height: CarreteSpacing.l),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: PaperKey(
                            label: l10n.disposableExitStay,
                            onPressed: () => Navigator.of(context).pop(false),
                          ),
                        ),
                        const SizedBox(width: CarreteSpacing.m),
                        Expanded(
                          child: PaperKey(
                            label: l10n.disposableExitConfirm,
                            primary: true,
                            onPressed: () => Navigator.of(context).pop(true),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return result ?? false;
}
