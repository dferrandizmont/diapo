import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/database/tables.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme/carrete_tokens.dart';
import '../../ui/widgets/carrete_icon.dart';
import '../../ui/widgets/plastic_key.dart';

/// The colours and type of the parts of the roll screens, which live both on
/// the camera and on screens that follow the theme.
///
/// A null [CarretePalette] stands for the plastic of the camera, [camera]
/// (the dark one unless said otherwise).
class RollTone {
  const RollTone(this.palette, {this.camera = CarreteCameraColors.dark});

  /// The palette of the theme, or null on the camera.
  final CarretePalette? palette;

  /// The plastic of the camera, used when [palette] is null.
  final CarreteCameraColors camera;

  /// The plate things sit on.
  Color get plate => palette?.plate ?? camera.panel;

  /// The edge of the plate.
  Color get edge => palette?.hairline ?? camera.panelEdge;

  /// The main ink.
  Color get ink => palette?.ink ?? camera.ink;

  /// The secondary ink.
  Color get soft => palette?.inkSoft ?? camera.inkSoft;

  /// The colour of what warns or throws away.
  Color get warn => palette?.accent ?? camera.warn;

  /// A line between rows.
  Color get line => palette?.hairline ?? camera.rule;

  /// The colour of what is on or selected.
  Color get active => palette?.accent ?? camera.active;

  TextStyle get title => CarreteText.pageTitle(ink);
  TextStyle get row => CarreteText.setting(ink);
  TextStyle get rowSoft => CarreteText.setting(soft);
  TextStyle get note => CarreteText.note(soft);
  TextStyle get label => CarreteText.sectionLabel(soft);
  TextStyle get value => CarreteText.settingValue(active);
}

/// One option of [RollChoiceKeys].
class RollChoice<T> {
  const RollChoice(this.value, this.label, {this.semanticLabel});

  /// What the option stands for.
  final T value;

  /// What the key says.
  final String label;

  /// What a screen reader says, when it is not the label.
  final String? semanticLabel;
}

/// Plastic keys of which exactly one is selected. They share the width and
/// wrap onto more rows when the text is large.
class RollChoiceKeys<T> extends StatelessWidget {
  const RollChoiceKeys({
    required this.options,
    required this.selected,
    required this.onSelected,
    this.columns = 3,
    this.palette,
    super.key,
  });

  final List<RollChoice<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;

  /// The most keys on a row.
  final int columns;

  /// The palette of the theme, or null on the camera.
  final CarretePalette? palette;

  @override
  Widget build(BuildContext context) {
    final scale = math.max(
      1.0,
      MediaQuery.textScalerOf(context).scale(CarreteSizes.choiceKeyMin) /
          CarreteSizes.choiceKeyMin,
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = CarreteSpacing.s;
          final minWidth = CarreteSizes.choiceKeyMin * scale;
          final perRow = ((constraints.maxWidth + gap) / (minWidth + gap))
              .floor()
              .clamp(1, columns);
          final width = (constraints.maxWidth - gap * (perRow - 1)) / perRow;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final option in options)
                PlasticKey(
                  palette: palette,
                  semanticLabel: option.semanticLabel ?? option.label,
                  selected: option.value == selected,
                  width: width,
                  height: CarreteSizes.choiceKey,
                  onPressed: () => onSelected(option.value),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CarreteSpacing.xs,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(option.label, maxLines: 1),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// A key as wide as its parent: the actions of the roll screens.
class RollWideKey extends StatelessWidget {
  const RollWideKey({
    required this.label,
    required this.onPressed,
    this.color,
    this.palette,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  /// The colour of the text, when it is not the usual one (throwing away).
  final Color? color;

  /// The palette of the theme, or null on the camera.
  final CarretePalette? palette;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => PlasticKey(
        palette: palette,
        semanticLabel: label,
        width: constraints.maxWidth,
        height: CarreteSizes.choiceKey,
        onPressed: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: CarreteSpacing.s),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: color == null ? null : TextStyle(color: color),
            ),
          ),
        ),
      ),
    );
  }
}

/// A confirmation dialog in the style of the plates: a title, a sentence and
/// two keys. Resolves to true when the user confirms.
Future<bool> confirmRollAction(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  required String cancelLabel,
  CarretePalette? palette,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => _RollConfirm(
      tone: RollTone(palette),
      title: title,
      body: body,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
    ),
  );
  return result ?? false;
}

class _RollConfirm extends StatelessWidget {
  const _RollConfirm({
    required this.tone,
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  final RollTone tone;
  final String title;
  final String body;
  final String confirmLabel;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(CarreteRoll.dialogInset),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: CarreteRoll.dialogMaxWidth),
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          scopesRoute: true,
          namesRoute: true,
          label: title,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tone.plate,
              borderRadius: BorderRadius.circular(CarreteRadii.panel),
              border: Border.all(color: tone.edge),
              boxShadow: tone.palette == null
                  ? const [CarreteRelief.panel]
                  : null,
            ),
            child: Padding(
              padding: CarreteRoll.sheetPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(title, style: tone.title),
                  ),
                  const SizedBox(height: CarreteSpacing.s),
                  Text(body, style: tone.note),
                  const SizedBox(height: CarreteSpacing.l),
                  Row(
                    children: [
                      Expanded(
                        child: RollWideKey(
                          palette: tone.palette,
                          label: cancelLabel,
                          onPressed: () => Navigator.of(context).pop(false),
                        ),
                      ),
                      const SizedBox(width: CarreteSpacing.s),
                      Expanded(
                        child: RollWideKey(
                          palette: tone.palette,
                          label: confirmLabel,
                          color: tone.warn,
                          onPressed: () => Navigator.of(context).pop(true),
                        ),
                      ),
                    ],
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

/// The two confirmations of the roll: developing early (the wait is lost) and
/// throwing it away (the photos are lost). Both resolve to true on confirm.
abstract final class RollConfirmations {
  /// [photos] is how many photos the roll has: the confirmation says how many
  /// are developed now.
  static Future<bool> developNow(
    BuildContext context, {
    required int photos,
    CarretePalette? palette,
  }) {
    final l10n = AppLocalizations.of(context);
    return confirmRollAction(
      context,
      title: l10n.rollDevelopNowTitle,
      body: l10n.rollDevelopNowBody(photos),
      confirmLabel: l10n.rollDevelopNowAction,
      cancelLabel: l10n.rollDevelopKeepWaiting,
      palette: palette,
    );
  }

  static Future<bool> discard(BuildContext context, {CarretePalette? palette}) {
    final l10n = AppLocalizations.of(context);
    return confirmRollAction(
      context,
      title: l10n.rollDiscardTitle,
      body: l10n.rollDiscardBody,
      confirmLabel: l10n.rollDiscardConfirm,
      cancelLabel: l10n.dialogCancel,
      palette: palette,
    );
  }
}

/// The name of a develop delay in the language of the app.
String delayName(AppLocalizations l10n, DevelopDelay delay) => switch (delay) {
  DevelopDelay.instant => l10n.delayInstant,
  DevelopDelay.oneHour => l10n.delayOneHour,
  DevelopDelay.nextMorning => l10n.delayNextMorning,
  DevelopDelay.threeDays => l10n.delayThreeDays,
};

/// The back key, the title and the line under it: the top of the screens
/// that follow the theme (a roll, the gallery).
class RollHeader extends StatelessWidget {
  const RollHeader({
    required this.title,
    required this.subtitle,
    required this.palette,
    this.handwritten = false,
    this.onEdit,
    super.key,
  });

  final String title;
  final String? subtitle;
  final CarretePalette palette;

  /// The title is a name the user wrote: it is set in the hand of the app.
  final bool handwritten;

  /// Opens the dialog to name the roll. Null leaves the key out.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: CarreteSizes.settingsHeader),
      child: Row(
        children: [
          PlasticKey(
            palette: palette,
            semanticLabel: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: () => Navigator.of(context).maybePop(),
            child: const CarreteIconView(
              icon: CarreteIcon.back,
              size: CarreteSizes.settingsIcon,
            ),
          ),
          const SizedBox(width: CarreteSpacing.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  container: true,
                  child: Text(
                    title,
                    style: handwritten
                        ? CarreteText.handName(
                            palette.ink,
                            size: CarreteText.handNameTitle,
                          )
                        : CarreteText.pageTitle(palette.ink),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: CarreteSizes.hair),
                  Text(subtitle!, style: CarreteText.note(palette.inkSoft)),
                ],
              ],
            ),
          ),
          if (onEdit != null) ...[
            const SizedBox(width: CarreteSpacing.s),
            PlasticKey(
              key: const ValueKey('roll-name-edit'),
              palette: palette,
              semanticLabel: AppLocalizations.of(context).rollNameEdit,
              onPressed: onEdit,
              child: const CarreteIconView(
                icon: CarreteIcon.edit,
                size: CarreteSizes.settingsIcon,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
