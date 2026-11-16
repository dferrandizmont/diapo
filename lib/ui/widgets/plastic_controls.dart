import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../theme/carrete_tokens.dart';
import 'plastic_surface.dart';

/// The sunken LCD window: a greenish-grey gradient with an inner shadow.
class LcdWindow extends StatelessWidget {
  const LcdWindow({
    required this.child,
    this.width = CarreteSizes.lcdWidth,
    this.height = CarreteSizes.lcdHeight,
    super.key,
  });

  /// What the window shows.
  final Widget child;

  /// The width of the window.
  final double width;

  /// The height of the window.
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(CarreteRadii.lcd),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [CarreteColors.lcdTop, CarreteColors.lcdBottom],
            ),
          ),
          child: CustomPaint(
            foregroundPainter: const _LcdInnerShadowPainter(),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class _LcdInnerShadowPainter extends CustomPainter {
  const _LcdInnerShadowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final hole = Path()..addRect(rect.inflate(CarreteRelief.innerOffset));
    final window = Path()
      ..addRect(rect.translate(0, CarreteRelief.innerOffset));
    canvas.save();
    canvas.clipRect(rect);
    canvas.drawPath(
      Path.combine(PathOperation.difference, hole, window),
      Paint()
        ..color = CarreteRelief.lcdShadow
        ..maskFilter = const MaskFilter.blur(
          BlurStyle.normal,
          CarreteRelief.innerBlur,
        ),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LcdInnerShadowPainter old) => false;
}

/// A slider with a knurled knob that runs from 0 to [max] in whole steps.
///
/// The track is [CarreteSizes.minTouch] tall so it is easy to hit; the screen
/// reader gets a proper slider with increase and decrease actions.
class PlasticSlider extends StatelessWidget {
  const PlasticSlider({
    required this.label,
    required this.value,
    required this.onChanged,
    this.max = 100,
    this.step = 5,
    super.key,
  });

  /// What a screen reader calls the slider.
  final String label;

  /// The current value, from 0 to [max].
  final int value;

  /// Called while the knob moves.
  final ValueChanged<int> onChanged;

  /// The highest value.
  final int max;

  /// The change a screen reader's increase or decrease makes.
  final int step;

  int _valueAt(double dx, double width) {
    final usable = width - CarreteSlider.knobWidth;
    final fraction = ((dx - CarreteSlider.knobWidth / 2) / usable).clamp(
      0.0,
      1.0,
    );
    return (fraction * max).round();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      slider: true,
      label: label,
      value: '$value',
      increasedValue: '${(value + step).clamp(0, max)}',
      decreasedValue: '${(value - step).clamp(0, max)}',
      onIncrease: () => onChanged((value + step).clamp(0, max)),
      onDecrease: () => onChanged((value - step).clamp(0, max)),
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => onChanged(_valueAt(d.localPosition.dx, width)),
            onHorizontalDragStart: (d) =>
                onChanged(_valueAt(d.localPosition.dx, width)),
            onHorizontalDragUpdate: (d) =>
                onChanged(_valueAt(d.localPosition.dx, width)),
            child: SizedBox(
              height: CarreteSpacing.minTouch,
              child: CustomPaint(
                painter: _SliderPainter(
                  fraction: value / max,
                  colors: CarreteCameraColors.of(context),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SliderPainter extends CustomPainter {
  const _SliderPainter({required this.fraction, required this.colors});

  final double fraction;
  final CarreteCameraColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    const knobW = CarreteSlider.knobWidth;
    const knobH = CarreteSlider.knobHeight;
    const half = CarreteSlider.trackHeight / 2;
    final mid = size.height / 2;
    final usable = size.width - knobW;
    final x = knobW / 2 + usable * fraction;

    final trackRect = Rect.fromLTWH(
      0,
      mid - half,
      size.width,
      CarreteSlider.trackHeight,
    );
    final track = RRect.fromRectAndRadius(
      trackRect,
      const Radius.circular(CarreteRadii.track),
    );
    // Groove.
    canvas.drawRRect(
      track.shift(const Offset(0, CarreteRelief.edgeWidth)),
      Paint()..color = colors.grooveEdge,
    );
    canvas.drawRRect(track, Paint()..color = colors.groove);
    // Amber fill up to the knob.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(0, mid - half, x, mid + half),
        const Radius.circular(CarreteRadii.track),
      ),
      Paint()..color = colors.active,
    );
    // Ticks every 10 %.
    final tick = Paint()..color = colors.tick;
    for (var i = 0; i <= CarreteSlider.tickCount; i++) {
      final tx = knobW / 2 + usable * i / CarreteSlider.tickCount;
      canvas.drawRect(
        Rect.fromLTWH(
          tx - CarreteSlider.tickWidth / 2,
          mid + CarreteSlider.tickOffset,
          CarreteSlider.tickWidth,
          CarreteSlider.tickLength,
        ),
        tick,
      );
    }
    // Knob.
    final knob = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(x, mid), width: knobW, height: knobH),
      const Radius.circular(CarreteRadii.knob),
    );
    canvas.drawRRect(
      knob.shift(const Offset(0, CarreteSlider.shadowOffset)),
      Paint()
        ..color = colors.knobShadow
        ..maskFilter = const MaskFilter.blur(
          BlurStyle.normal,
          CarreteSlider.shadowBlur,
        ),
    );
    canvas.drawRRect(
      knob.shift(const Offset(0, CarreteSlider.footOffset)),
      Paint()..color = colors.knobFoot,
    );
    canvas.drawRRect(knob, Paint()..color = colors.knob);
    // Knurling: alternating light and dark ribs.
    canvas.save();
    canvas.clipRRect(knob);
    final rib = Paint()..color = colors.knobRib;
    for (var rx = knob.left; rx < knob.right; rx += CarreteSlider.ribPitch) {
      canvas.drawRect(
        Rect.fromLTWH(rx, knob.top, CarreteSlider.ribWidth, knobH),
        rib,
      );
    }
    canvas.restore();
    canvas.drawRRect(
      knob.deflate(CarreteRelief.edgeWidth / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = colors.highlight,
    );
  }

  @override
  bool shouldRepaint(_SliderPainter old) =>
      old.fraction != fraction || old.colors != colors;
}

/// An on/off switch shaped like a pill, with an amber lamp when it is on.
class PlasticSwitch extends StatelessWidget {
  const PlasticSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// What a screen reader calls the switch.
  final String label;

  /// Whether it is on.
  final bool value;

  /// Called with the new value on a tap.
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final instant = MediaQuery.disableAnimationsOf(context);
    final colors = CarreteCameraColors.of(context);
    return Semantics(
      container: true,
      toggled: value,
      label: label,
      onTap: () => onChanged(!value),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!value),
        child: SizedBox(
          width: CarreteSwitch.width,
          height: CarreteSpacing.minTouch,
          child: Center(
            child: SizedBox(
              width: CarreteSwitch.width,
              height: CarreteSwitch.height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: value ? colors.switchOn : colors.switchOff,
                        borderRadius: BorderRadius.circular(
                          CarreteSwitch.height / 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colors.grooveEdge,
                            offset: Offset(0, CarreteRelief.edgeWidth),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (value)
                    Positioned(
                      left: CarreteSwitch.lampLeft,
                      top: CarreteSwitch.lampTop,
                      child: Container(
                        width: CarreteSwitch.lamp,
                        height: CarreteSwitch.lamp,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.lamp,
                          boxShadow: [
                            BoxShadow(
                              color: colors.lamp,
                              blurRadius: CarreteSwitch.lampGlow,
                            ),
                          ],
                        ),
                      ),
                    ),
                  AnimatedPositioned(
                    duration: instant
                        ? Duration.zero
                        : CarreteDurations.keyPress,
                    top: CarreteSwitch.knobInset,
                    left: value
                        ? CarreteSwitch.width -
                              CarreteSwitch.knob -
                              CarreteSwitch.knobInset
                        : CarreteSwitch.knobInset,
                    child: Container(
                      width: CarreteSwitch.knob,
                      height: CarreteSwitch.knob,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            colors.switchKnobTop,
                            colors.switchKnobBottom,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colors.knobShadow,
                            offset: Offset(0, CarreteSwitch.knobShadowOffset),
                            blurRadius: CarreteSwitch.knobShadowBlur,
                          ),
                        ],
                      ),
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

/// The red shutter button: a ribbed ring around a red cap that sinks 4 px
/// when it is pressed.
class ShutterButton extends StatefulWidget {
  const ShutterButton({
    required this.semanticLabel,
    required this.onPressed,
    super.key,
  });

  /// What a screen reader says.
  final String semanticLabel;

  /// Called the moment the finger goes down: the shutter never waits.
  final VoidCallback? onPressed;

  @override
  State<ShutterButton> createState() => _ShutterButtonState();
}

class _ShutterButtonState extends State<ShutterButton> {
  bool _down = false;

  void _setDown(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      onTap: widget.onPressed,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled
            ? (_) {
                _setDown(true);
                widget.onPressed!();
              }
            : null,
        onTapUp: enabled ? (_) => _setDown(false) : null,
        onTapCancel: enabled ? () => _setDown(false) : null,
        child: SizedBox(
          width: CarreteSpacing.shutter,
          height: CarreteSpacing.shutter,
          child: CustomPaint(
            painter: _ShutterPainter(
              pressed: _down,
              colors: CarreteCameraColors.of(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShutterPainter extends CustomPainter {
  const _ShutterPainter({required this.pressed, required this.colors});

  final bool pressed;
  final CarreteCameraColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    // The well.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: CarreteShutter.wellCentre,
          radius: CarreteShutter.wellRadius,
          colors: [colors.wellTop, colors.wellBottom],
          stops: CarreteShutter.wellStops,
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // The ribbed ring.
    final ring = r - CarreteShutter.ringInset;
    canvas.drawCircle(
      c.translate(0, CarreteShutter.ringShadowOffset),
      ring,
      Paint()
        ..color = colors.ringShadow
        ..maskFilter = const MaskFilter.blur(
          BlurStyle.normal,
          CarreteShutter.ringShadowBlur,
        ),
    );
    canvas.drawCircle(c, ring, Paint()..color = colors.ringDark);
    final rib = Paint()
      ..color = colors.ringLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = CarreteShutter.ribWidth;
    for (var i = 0; i < CarreteShutter.ribs; i++) {
      final a = i * 2 * math.pi / CarreteShutter.ribs;
      final from = c + Offset.fromDirection(a, ring * CarreteShutter.ribStart);
      final to = c + Offset.fromDirection(a, ring);
      canvas.drawLine(from, to, rib);
    }
    // The red cap.
    final sink = pressed ? CarreteShutter.capSink : 0.0;
    final capCenter = c.translate(0, -CarreteShutter.capRaise + sink);
    const capR = CarreteShutter.capRadius;
    final foot = pressed
        ? CarreteShutter.footPressed
        : CarreteShutter.footRaised;
    canvas.drawCircle(
      capCenter.translate(0, foot + CarreteShutter.capShadowGap),
      capR,
      Paint()
        ..color = colors.capShadow
        ..maskFilter = const MaskFilter.blur(
          BlurStyle.normal,
          CarreteShutter.capShadowBlur,
        ),
    );
    canvas.drawCircle(
      capCenter.translate(0, foot),
      capR,
      Paint()..color = CarreteColors.shutterFoot,
    );
    canvas.drawCircle(
      capCenter,
      capR,
      Paint()
        ..shader = RadialGradient(
          center: CarreteShutter.capCentre,
          radius: CarreteShutter.capGradientRadius,
          colors: [
            pressed ? CarreteColors.shutterCapMid : CarreteColors.shutterCapTop,
            CarreteColors.shutterCapMid,
            CarreteColors.shutterCapBottom,
          ],
          stops: CarreteShutter.capStops,
        ).createShader(Rect.fromCircle(center: capCenter, radius: capR)),
    );
  }

  @override
  bool shouldRepaint(_ShutterPainter old) =>
      old.pressed != pressed || old.colors != colors;
}

/// A plate of raised plastic around [child]: the body of a film cartridge.
class PlasticPlate extends StatelessWidget {
  const PlasticPlate({
    required this.child,
    required this.radius,
    this.selected = false,
    super.key,
  });

  /// What sits on the plate.
  final Widget child;

  /// The corner radius.
  final double radius;

  /// Whether the plate is the highlighted one (a selected cartridge).
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = CarreteCameraColors.of(context);
    return CustomPaint(
      painter: PlasticSurfacePainter(
        radius: radius,
        top: selected ? colors.cartridgeSelectedTop : colors.cartridgeTop,
        bottom: selected
            ? colors.cartridgeSelectedBottom
            : colors.cartridgeBottom,
        hardShadow: colors.hard,
        diffuseShadow: colors.diffuse,
        highlight: colors.highlight,
      ),
      child: child,
    );
  }
}

/// A one-line announcement for screen readers (for example a photo saved).
void announce(BuildContext context, String message) {
  SemanticsService.sendAnnouncement(
    View.of(context),
    message,
    Directionality.of(context),
  );
}
