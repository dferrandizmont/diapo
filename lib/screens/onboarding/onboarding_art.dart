import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/theme/carrete_tokens.dart';
import '../../ui/theme/onboarding_tokens.dart';
import '../../ui/widgets/plastic_controls.dart';
import '../../ui/widgets/seven_segment.dart';
import '../roll/develop_view.dart';
import '../roll/roll_parts.dart';
import '../viewfinder/frame_overlays.dart';

/// The picture of the first screen: a viewfinder with a scene, the corner
/// marks and the focus brackets, the date stamp and three small promises.
///
/// It fills the window it is given.
class OnboardingCameraArt extends StatelessWidget {
  const OnboardingCameraArt({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(OnboardingSizes.windowRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: SunsetPainter()),
          const FrameCorners(),
          const Align(
            alignment: OnboardingSizes.focusAlignment,
            child: SizedBox(
              width: CarreteMarks.lockWidth,
              height: CarreteMarks.lockHeight,
              child: CustomPaint(painter: _BracketsPainter()),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(OnboardingSizes.chipsInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(right: OnboardingSizes.dateInset),
                    child: SevenSegmentText(
                      text: "'98 7 14",
                      height: OnboardingSizes.dateDigits,
                      color: CarreteColors.date,
                      glow: true,
                    ),
                  ),
                  const SizedBox(height: CarreteSpacing.s),
                  SizedBox(
                    width: double.infinity,
                    // The promises are a reminder, not the message: they stop
                    // growing before they would cover the picture.
                    child: MediaQuery.withClampedTextScaling(
                      maxScaleFactor: OnboardingSizes.chipMaxTextScale,
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: CarreteSpacing.s,
                        runSpacing: CarreteSpacing.s,
                        children: [
                          _Chip(l10n.onboardingChipNoAccount),
                          _Chip(l10n.onboardingChipNoWatermark),
                          _Chip(l10n.onboardingChipOnDevice),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CarreteColors.pill,
        borderRadius: BorderRadius.circular(OnboardingSizes.chipRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: OnboardingSizes.chipPaddingH,
          vertical: OnboardingSizes.chipPaddingV,
        ),
        child: Text(
          CarreteText.upper(label, locale),
          style: OnboardingText.chip,
        ),
      ),
    );
  }
}

/// The picture of the second screen: a film look and the cartridges to swipe.
///
/// Drawn at [OnboardingSizes.artWidth] by [OnboardingSizes.artHeight]; wrap it
/// in a `FittedBox`.
class OnboardingFilmArt extends StatelessWidget {
  const OnboardingFilmArt({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: OnboardingSizes.artWidth,
      height: OnboardingSizes.artHeight,
      child: Padding(
        padding: const EdgeInsets.all(OnboardingSizes.artPadding),
        child: Column(
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    OnboardingSizes.previewRadius,
                  ),
                  border: Border.all(
                    color: CarreteColors.black,
                    width: OnboardingSizes.previewBorder,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    OnboardingSizes.previewRadius,
                  ),
                  child: const SizedBox.expand(
                    child: CustomPaint(painter: SunsetPainter()),
                  ),
                ),
              ),
            ),
            const SizedBox(height: OnboardingSizes.rowGap),
            const _Cartridges(),
          ],
        ),
      ),
    );
  }
}

/// Five cartridges, the first one selected.
class _Cartridges extends StatelessWidget {
  const _Cartridges();

  @override
  Widget build(BuildContext context) {
    const bands = OnboardingColors.cartridgeBands;
    return SizedBox(
      height: OnboardingSizes.cartridgeRowHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < bands.length; i++) ...[
            if (i > 0) const SizedBox(width: CarreteSizes.cartridgeGap),
            _Cartridge(band: bands[i], selected: i == 0),
          ],
        ],
      ),
    );
  }
}

class _Cartridge extends StatelessWidget {
  const _Cartridge({required this.band, required this.selected});

  final Color band;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final cartridge = SizedBox(
      width: OnboardingSizes.cartridgeWidth,
      height: OnboardingSizes.cartridgeHeight,
      child: PlasticPlate(
        radius: CarreteRadii.cartridge,
        selected: selected,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            CarreteSpacing.xs,
            CarreteSpacing.xs,
            CarreteSpacing.xs,
            OnboardingSizes.cartridgeBottomPadding,
          ),
          child: Column(
            children: [
              SizedBox(
                height: OnboardingSizes.cartridgeWindow,
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(CarreteRadii.thumbnail),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [band, OnboardingColors.cartridgeShade],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: OnboardingSizes.cartridgeBandGap),
              SizedBox(
                height: CarreteSizes.bandHeight,
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: band,
                    borderRadius: BorderRadius.circular(CarreteRadii.band),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return cartridge;
  }
}

/// The picture of the third screen: the counter of a roll, its frames (nine
/// taken, hidden), the develop time and the optional alert.
///
/// Drawn at [OnboardingSizes.artWidth] by [OnboardingSizes.artHeight]; wrap it
/// in a `FittedBox`.
class OnboardingRollArt extends StatelessWidget {
  const OnboardingRollArt({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final rows = OnboardingSizes.rollFrames ~/ OnboardingSizes.rollColumns;
    return SizedBox(
      width: OnboardingSizes.artWidth,
      height: OnboardingSizes.artHeight,
      child: Padding(
        padding: const EdgeInsets.all(OnboardingSizes.artPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const RollLcd(value: OnboardingSizes.rollTaken, total: 24),
            const SizedBox(height: OnboardingSizes.sampleGap),
            Text(
              CarreteText.upper(l10n.onboardingRollHidden, locale),
              style: CarreteText.label,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: OnboardingSizes.rowGap),
            for (var r = 0; r < rows; r++) ...[
              if (r > 0) const SizedBox(height: OnboardingSizes.cellGap),
              Row(
                children: [
                  for (var c = 0; c < OnboardingSizes.rollColumns; c++) ...[
                    if (c > 0) const SizedBox(width: OnboardingSizes.cellGap),
                    Expanded(
                      child: _Frame(
                        taken:
                            r * OnboardingSizes.rollColumns + c <
                            OnboardingSizes.rollTaken,
                      ),
                    ),
                  ],
                ],
              ),
            ],
            const SizedBox(height: OnboardingSizes.delayGap),
            RollChoiceKeys<int>(
              columns: 2,
              selected: OnboardingSizes.rollSelectedDelay,
              onSelected: (_) {},
              options: [
                RollChoice(0, l10n.delayInstant),
                RollChoice(1, l10n.delayOneHour),
                RollChoice(2, l10n.delayNextMorning),
                RollChoice(3, l10n.delayThreeDays),
              ],
            ),
            const SizedBox(height: OnboardingSizes.rowGap),
            Row(
              children: [
                PlasticSwitch(
                  label: l10n.onboardingReminder,
                  value: true,
                  onChanged: (_) {},
                ),
                const SizedBox(width: CarreteSpacing.m),
                Expanded(
                  child: Text(l10n.onboardingReminder, style: CarreteText.row),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A frame of the roll: empty, or holding a photo nobody sees yet.
class _Frame extends StatelessWidget {
  const _Frame({required this.taken});

  final bool taken;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: OnboardingSizes.cellHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(OnboardingSizes.cellRadius),
          border: Border.all(
            color: taken ? CarreteColors.amber : OnboardingColors.cellEmpty,
            width: OnboardingSizes.cellBorder,
          ),
        ),
        child: taken
            ? Padding(
                padding: const EdgeInsets.all(OnboardingSizes.cellInset),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: OnboardingColors.cellTaken,
                    border: Border.all(
                      color: OnboardingColors.cellTakenGlow,
                      width:
                          OnboardingSizes.cellGlowInset -
                          OnboardingSizes.cellInset,
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

/// The sunset the pictures are made of: sky, sun, two hills and a house.
class SunsetPainter extends CustomPainter {
  const SunsetPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            OnboardingColors.skyTop,
            OnboardingColors.skyMiddle,
            OnboardingColors.skyBottom,
          ],
          stops: OnboardingSizes.skyStops,
        ).createShader(rect),
    );
    final sun = Offset(
      size.width * OnboardingSizes.sunX,
      size.height * OnboardingSizes.sunY,
    );
    canvas.drawCircle(
      sun,
      size.height * OnboardingSizes.sunHaloRadius,
      Paint()
        ..color = OnboardingColors.sun.withValues(
          alpha: OnboardingSizes.sunHaloOpacity,
        ),
    );
    canvas.drawCircle(
      sun,
      size.height * OnboardingSizes.sunRadius,
      Paint()..color = OnboardingColors.sun,
    );
    canvas.drawPath(
      _hill(size, OnboardingSizes.farHill),
      Paint()..color = OnboardingColors.hillFar,
    );
    canvas.drawPath(
      _hill(size, OnboardingSizes.nearHill),
      Paint()..color = OnboardingColors.hillNear,
    );
    final wall = Rect.fromLTWH(
      size.width * OnboardingSizes.houseX,
      size.height * OnboardingSizes.houseY,
      size.width * OnboardingSizes.houseWidth,
      size.height * OnboardingSizes.houseHeight,
    );
    canvas.drawRect(wall, Paint()..color = OnboardingColors.houseWall);
    final overhang = size.width * OnboardingSizes.roofOverhang;
    canvas.drawPath(
      Path()
        ..moveTo(wall.left - overhang, wall.top)
        ..lineTo(
          wall.center.dx,
          wall.top - size.height * OnboardingSizes.roofRise,
        )
        ..lineTo(wall.right + overhang, wall.top)
        ..close(),
      Paint()..color = OnboardingColors.houseRoof,
    );
  }

  /// A hill from five points given as shares of [size]: start, control, middle,
  /// control, end; closed down to the bottom of the frame.
  Path _hill(Size size, List<Offset> p) {
    Offset at(Offset o) => Offset(o.dx * size.width, o.dy * size.height);
    final start = at(p[0]);
    final c1 = at(p[1]);
    final mid = at(p[2]);
    final c2 = at(p[3]);
    final end = at(p[4]);
    return Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(c1.dx, c1.dy, mid.dx, mid.dy)
      ..quadraticBezierTo(c2.dx, c2.dy, end.dx, end.dy)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldRepaint(SunsetPainter old) => false;
}

/// Four corner brackets: the focus mark of the viewfinder, without the lock.
class _BracketsPainter extends CustomPainter {
  const _BracketsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const arm = CarreteMarks.bracketArm;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = CarreteMarks.strokeWidth
      ..color = CarreteColors.frameMark;
    final r = Offset.zero & size;
    final path = Path()
      ..moveTo(r.left, r.top + arm)
      ..lineTo(r.left, r.top)
      ..lineTo(r.left + arm, r.top)
      ..moveTo(r.right - arm, r.top)
      ..lineTo(r.right, r.top)
      ..lineTo(r.right, r.top + arm)
      ..moveTo(r.right, r.bottom - arm)
      ..lineTo(r.right, r.bottom)
      ..lineTo(r.right - arm, r.bottom)
      ..moveTo(r.left + arm, r.bottom)
      ..lineTo(r.left, r.bottom)
      ..lineTo(r.left, r.bottom - arm);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BracketsPainter old) => false;
}
