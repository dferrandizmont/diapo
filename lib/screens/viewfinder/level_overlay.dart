import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../camera/level_tilt.dart';
import '../../ui/theme/carrete_tokens.dart';

/// The level of the viewfinder: two fixed ticks and, between them, a thin line
/// that stays on the horizon while the phone turns. It is white and turns to
/// the accent colour when the phone is level within about 1 degree. It counts
/// from the nearest quarter turn, so it reads level with the phone held on its
/// side too (the ticks then turn to the vertical axis).
///
/// It listens to the accelerometer only while it is on the screen: not while
/// the app is in the background, nor while another route (settings, gallery,
/// a roll) covers the camera, which stays mounted underneath. Each reading changes a [ValueNotifier] that only this
/// widget listens to, so the film shader and the rest of the screen are never
/// rebuilt. The line follows the readings directly (they are already
/// smoothed), with no tween, so it needs no special case for reduced motion.
class LevelOverlay extends ConsumerStatefulWidget {
  const LevelOverlay({super.key});

  @override
  ConsumerState<LevelOverlay> createState() => _LevelOverlayState();
}

class _LevelOverlayState extends ConsumerState<LevelOverlay>
    with WidgetsBindingObserver {
  final ValueNotifier<_Reading?> _reading = ValueNotifier<_Reading?>(null);
  StreamSubscription<LevelTilt?>? _subscription;
  bool _foreground = true;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The navigator turns the tickers off under a route that covers this one.
    _visible = TickerMode.valuesOf(context).enabled;
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    _reading.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  /// Listens while the screen is seen, and only then.
  void _sync() {
    if (_foreground && _visible) {
      _subscription ??= ref.read(levelSourceProvider).tilts.listen(_onTilt);
    } else if (_subscription != null) {
      unawaited(_subscription!.cancel());
      _subscription = null;
    }
  }

  void _onTilt(LevelTilt? tilt) {
    if (tilt == null) {
      _reading.value = null;
      return;
    }
    final previous = _reading.value;
    final wasLevel = previous?.level ?? false;
    final wasLandscape = previous?.landscape ?? false;
    _reading.value = _Reading(
      tilt.degrees,
      tilt.isLevel(wasLevel: wasLevel, wasLandscape: wasLandscape),
      tilt.isLandscape(wasLandscape: wasLandscape),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: ValueListenableBuilder<_Reading?>(
          valueListenable: _reading,
          builder: (context, reading, _) {
            if (reading == null) return const SizedBox.shrink();
            return CustomPaint(
              size: Size.infinite,
              painter: LevelPainter(
                degrees: reading.degrees,
                level: reading.level,
                landscape: reading.landscape,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Reading {
  const _Reading(this.degrees, this.level, this.landscape);

  final double degrees;
  final bool level;
  final bool landscape;
}

/// Draws the level at the centre of the box it is given.
class LevelPainter extends CustomPainter {
  const LevelPainter({
    required this.degrees,
    required this.level,
    this.landscape = false,
  });

  /// The tilt of the phone in degrees, clockwise positive.
  final double degrees;

  /// Whether the phone counts as level: the colour of the marks.
  final bool level;

  /// Whether the phone is held on its side: the fixed ticks are drawn on the
  /// vertical axis, so the line sits between them when the phone is straight.
  final bool landscape;

  /// The colour the marks are drawn in.
  Color get color =>
      level ? CarreteColors.levelAligned : CarreteColors.frameMark;

  @override
  void paint(Canvas canvas, Size size) {
    const half = CarreteMarks.levelHalfLength;
    const gap = CarreteMarks.levelGap;
    const tick = CarreteMarks.levelTick;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = CarreteMarks.strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    // The fixed ticks, turned a quarter when the phone is on its side.
    for (final side in const [-1.0, 1.0]) {
      final from = side * (half + gap);
      final to = side * (half + gap + tick);
      canvas.drawLine(
        landscape ? Offset(0, from) : Offset(from, 0),
        landscape ? Offset(0, to) : Offset(to, 0),
        paint,
      );
    }
    // The horizon turns against the phone.
    canvas.rotate(-degrees * math.pi / 180);
    canvas.drawLine(const Offset(-half, 0), const Offset(half, 0), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(LevelPainter old) =>
      old.degrees != degrees ||
      old.level != level ||
      old.landscape != landscape;
}
