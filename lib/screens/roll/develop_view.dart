import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme/carrete_tokens.dart';
import '../../ui/widgets/carrete_icon.dart';
import '../../ui/widgets/plastic_controls.dart';
import '../../ui/widgets/seven_segment.dart';
import 'contact_sheet.dart';
import 'roll_parts.dart';

/// An LCD window of the roll screens: the film icon and big digits, and
/// optionally a smaller number after them (the total).
class RollLcd extends StatelessWidget {
  const RollLcd({required this.value, this.total, super.key});

  /// The big number.
  final int value;

  /// The small number after the big one, or null.
  final int? total;

  @override
  Widget build(BuildContext context) {
    return LcdWindow(
      width: CarreteRoll.lcdWidth,
      height: CarreteRoll.lcdHeight,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CarreteSizes.lcdInset,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: CarreteSpacing.xs),
                child: CarreteIconView(
                  icon: CarreteIcon.film,
                  color: CarreteColors.lcdInk,
                  size: CarreteRoll.lcdIcon,
                  strokeWidth: CarreteSizes.lcdIconStroke,
                ),
              ),
              const SizedBox(width: CarreteSpacing.m),
              SevenSegmentText(
                text: value.toString().padLeft(2, '0'),
                height: CarreteRoll.lcdDigits,
                color: CarreteColors.lcdInk,
                ghost: true,
              ),
              if (total != null) ...[
                const SizedBox(width: CarreteSpacing.s),
                Padding(
                  padding: const EdgeInsets.only(bottom: CarreteSpacing.xs),
                  child: SevenSegmentText(
                    text: total.toString().padLeft(2, '0'),
                    height: CarreteRoll.lcdTotalDigits,
                    color: CarreteColors.lcdInk,
                    ghost: true,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A closed roll that is waiting for its time: the LCD with its frames, when
/// it will be ready and the ways out (develop now, throw it away).
class RollWaitingView extends StatelessWidget {
  const RollWaitingView({
    required this.frames,
    required this.readyAt,
    required this.palette,
    required this.onDevelopNow,
    required this.onDiscard,
    this.failed = false,
    super.key,
  });

  final int frames;
  final DateTime readyAt;
  final CarretePalette palette;

  /// Null while the photos of the roll are not known: it cannot be
  /// developed now before that.
  final VoidCallback? onDevelopNow;
  final VoidCallback onDiscard;

  /// Whether the last action on the roll failed.
  final bool failed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tone = RollTone(palette);
    final material = MaterialLocalizations.of(context);
    final date = material.formatMediumDate(readyAt);
    final time = material.formatTimeOfDay(
      TimeOfDay.fromDateTime(readyAt),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: CarreteSpacing.xl),
        Center(
          child: ExcludeSemantics(child: RollLcd(value: frames)),
        ),
        const SizedBox(height: CarreteSpacing.xl),
        Semantics(
          header: true,
          child: Text(
            l10n.rollWaitingTitle,
            textAlign: TextAlign.center,
            style: tone.title,
          ),
        ),
        const SizedBox(height: CarreteSpacing.s),
        Text(
          l10n.rollReadyOn(date, time),
          textAlign: TextAlign.center,
          style: tone.row,
        ),
        const SizedBox(height: CarreteSpacing.s),
        Text(
          l10n.rollWaitingNote,
          textAlign: TextAlign.center,
          style: tone.note,
        ),
        const SizedBox(height: CarreteSpacing.xs),
        Text(
          l10n.rollLossNote,
          key: const ValueKey('roll-loss-note'),
          textAlign: TextAlign.center,
          style: tone.note,
        ),
        if (failed) ...[
          const SizedBox(height: CarreteSpacing.m),
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.rollActionFailed,
              textAlign: TextAlign.center,
              style: CarreteText.note(palette.accent),
            ),
          ),
        ],
        const SizedBox(height: CarreteSpacing.xl),
        RollWideKey(
          palette: palette,
          label: l10n.rollDevelopNowAction,
          onPressed: onDevelopNow,
        ),
        const SizedBox(height: CarreteSpacing.s),
        RollWideKey(
          palette: palette,
          label: l10n.rollDiscardAction,
          color: tone.warn,
          onPressed: onDiscard,
        ),
      ],
    );
  }
}

/// A roll that is being developed: the LCD counts the frames done and the
/// contact sheet fills as each photo finishes saving, with no artificial wait.
/// No spinner: the film advances.
class RollDevelopingView extends StatelessWidget {
  const RollDevelopingView({
    required this.done,
    required this.total,
    required this.palette,
    this.shots,
    super.key,
  });

  final int done;
  final int total;
  final CarretePalette palette;

  /// The frames of the roll, as the database holds them: a frame shows its
  /// thumbnail as soon as its photo is saved. Null or empty while they are not
  /// known: the strip of cells stands in for the sheet.
  final List<ShotRow>? shots;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tone = RollTone(palette);
    final instant = MediaQuery.disableAnimationsOf(context);
    final frames = shots;
    final sheet = frames != null && frames.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: CarreteSpacing.xl),
        Semantics(
          container: true,
          liveRegion: true,
          label: l10n.rollDevelopProgressSemantics(done, total),
          excludeSemantics: true,
          child: Column(
            children: [
              RollLcd(value: done, total: total),
              if (!sheet) ...[
                const SizedBox(height: CarreteSpacing.xl),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: CarreteRoll.progressCellGap,
                  runSpacing: CarreteRoll.progressCellGap,
                  children: [
                    for (var i = 0; i < total; i++)
                      AnimatedContainer(
                        key: ValueKey('develop-cell-$i'),
                        duration: instant
                            ? Duration.zero
                            : CarreteDurations.developStep,
                        width: CarreteRoll.progressCellWidth,
                        height: CarreteRoll.progressCellHeight,
                        decoration: BoxDecoration(
                          color: i < done ? palette.accent : Colors.transparent,
                          borderRadius: BorderRadius.circular(
                            CarreteRoll.progressCellRadius,
                          ),
                          border: Border.all(
                            color: i < done ? palette.accent : palette.inkSoft,
                            width: CarreteSizes.hairlineWidth,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (sheet) ...[
          const SizedBox(height: CarreteSpacing.l),
          ContactSheet(shots: frames, developing: true),
        ],
        const SizedBox(height: CarreteSpacing.xl),
        Semantics(
          header: true,
          child: Text(
            l10n.rollDevelopingTitle,
            textAlign: TextAlign.center,
            style: tone.title,
          ),
        ),
        const SizedBox(height: CarreteSpacing.s),
        Text(l10n.rollKeepOpen, textAlign: TextAlign.center, style: tone.note),
      ],
    );
  }
}

/// A short message in place of a roll: lost, thrown away, not found.
class RollMessage extends StatelessWidget {
  const RollMessage({
    required this.title,
    required this.palette,
    this.body,
    super.key,
  });

  final String title;
  final String? body;
  final CarretePalette palette;

  @override
  Widget build(BuildContext context) {
    final tone = RollTone(palette);
    return Padding(
      padding: const EdgeInsets.only(top: CarreteSpacing.xxl),
      child: Column(
        children: [
          Semantics(
            header: true,
            liveRegion: true,
            child: Text(title, textAlign: TextAlign.center, style: tone.title),
          ),
          if (body != null) ...[
            const SizedBox(height: CarreteSpacing.s),
            Text(body!, textAlign: TextAlign.center, style: tone.note),
          ],
        ],
      ),
    );
  }
}
