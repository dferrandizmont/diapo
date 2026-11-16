import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../ui/theme/carrete_tokens.dart';
import '../../ui/widgets/carrete_icon.dart';
import '../../ui/widgets/plastic_controls.dart';
import '../../ui/widgets/plastic_key.dart';

/// A group of settings: a title in small capitals over a hairline, and a plate
/// that holds the rows.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    required this.title,
    required this.children,
    super.key,
  });

  /// The title of the group, in sentence case (it is printed in capitals).
  final String title;

  /// The rows of the plate.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = CarretePalette.of(context);
    final locale = Localizations.localeOf(context);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            container: true,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: palette.ink,
                    width: CarreteSizes.hairlineWidth,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  CarreteSpacing.xs,
                  0,
                  CarreteSpacing.xs,
                  CarreteSpacing.s,
                ),
                child: Text(
                  CarreteText.upper(title, locale),
                  style: CarreteText.sectionLabel(palette.ink),
                ),
              ),
            ),
          ),
          const SizedBox(height: CarreteSpacing.s),
          _Plate(children: children),
        ],
      ),
    );
  }
}

class _Plate extends StatelessWidget {
  const _Plate({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = CarretePalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.plate,
        borderRadius: BorderRadius.circular(CarreteRadii.panel),
        border: Border.all(
          color: palette.hairline,
          width: CarreteSizes.hairlineWidth,
        ),
        boxShadow: [
          BoxShadow(color: palette.plateShadow, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              SizedBox(
                height: CarreteSizes.hairlineWidth,
                child: ColoredBox(color: palette.hairline),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// The padding every row of a plate has.
const EdgeInsets _rowPadding = EdgeInsets.symmetric(
  horizontal: CarreteSizes.plateInset,
  vertical: CarreteSpacing.s,
);

/// A row with a name on the left and a plastic switch on the right.
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.footer,
    super.key,
  });

  /// The name of the setting.
  final String label;

  /// A short sentence under the name, or null for none.
  final String? hint;

  /// Anything shown under the hint (a warning with its action), or null.
  final Widget? footer;

  /// Whether it is on.
  final bool value;

  /// Called with the new value.
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = CarretePalette.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: CarreteSizes.settingRow),
      child: Padding(
        padding: _rowPadding,
        child: Row(
          children: [
            Expanded(
              // The switch carries the name for screen readers.
              child: hint == null && footer == null
                  ? ExcludeSemantics(
                      child: Text(
                        label,
                        style: CarreteText.setting(palette.ink),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ExcludeSemantics(
                          child: Text(
                            label,
                            style: CarreteText.setting(palette.ink),
                          ),
                        ),
                        if (hint != null) ...[
                          const SizedBox(height: CarreteSpacing.xs),
                          Text(hint!, style: CarreteText.note(palette.inkSoft)),
                        ],
                        if (footer != null) ...[
                          const SizedBox(height: CarreteSpacing.xs),
                          footer!,
                        ],
                      ],
                    ),
            ),
            const SizedBox(width: CarreteSpacing.m),
            PlasticSwitch(label: label, value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// A row with a name over a control that takes the whole width.
class SettingsBlock extends StatelessWidget {
  const SettingsBlock({required this.label, required this.child, super.key});

  /// The name of the setting.
  final String label;

  /// The control.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = CarretePalette.of(context);
    return Padding(
      padding: _rowPadding.copyWith(
        top: CarreteSpacing.m,
        bottom: CarreteSpacing.m,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            child: Text(label, style: CarreteText.setting(palette.ink)),
          ),
          const SizedBox(height: CarreteSpacing.s),
          child,
        ],
      ),
    );
  }
}

/// One option of [SettingsChoiceKeys].
class SettingsChoice<T> {
  const SettingsChoice(this.value, this.label);

  /// What the option stands for.
  final T value;

  /// What the key says.
  final String label;
}

/// A few plastic keys of which exactly one is selected (the theme, the
/// language). The keys share the width; when the text is enlarged they wrap
/// onto more rows instead of squeezing.
class SettingsChoiceKeys<T> extends StatelessWidget {
  const SettingsChoiceKeys({
    required this.options,
    required this.selected,
    required this.onSelected,
    this.columns = 3,
    super.key,
  });

  /// The options.
  final List<SettingsChoice<T>> options;

  /// The value that is selected.
  final T selected;

  /// Called with the value of the key that was pressed.
  final ValueChanged<T> onSelected;

  /// The most keys on a row.
  final int columns;

  @override
  Widget build(BuildContext context) {
    final palette = CarretePalette.of(context);
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
                  semanticLabel: option.label,
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

/// A row with a name and a value in LCD print.
class SettingsValueRow extends StatelessWidget {
  const SettingsValueRow({required this.label, required this.value, super.key});

  /// The name.
  final String label;

  /// The value.
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = CarretePalette.of(context);
    return Semantics(
      container: true,
      label: label,
      value: value,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: CarreteSizes.settingRow),
        child: Padding(
          padding: _rowPadding,
          // Side by side when they fit; the value drops under the label with
          // large text or a long value (a prerelease version, for example).
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: CarreteSpacing.m,
            runSpacing: CarreteSpacing.xs,
            children: [
              Text(label, style: CarreteText.setting(palette.ink)),
              Text(value, style: CarreteText.settingValue(palette.ink)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A row that goes on to another screen when it is tapped.
class SettingsLinkRow extends StatelessWidget {
  const SettingsLinkRow({required this.label, required this.onTap, super.key});

  /// The name.
  final String label;

  /// Called on a tap.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = CarretePalette.of(context);
    return Semantics(
      container: true,
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: CarreteSizes.settingRow),
          child: Padding(
            padding: _rowPadding,
            child: Row(
              children: [
                Expanded(
                  child: Text(label, style: CarreteText.setting(palette.ink)),
                ),
                const SizedBox(width: CarreteSpacing.m),
                CarreteIconView(
                  icon: CarreteIcon.chevron,
                  color: palette.inkSoft,
                  size: CarreteSizes.settingsIcon,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A row that opens and closes a group of rows under it: its name and a
/// chevron that turns down while the group is open.
class SettingsExpanderRow extends StatelessWidget {
  const SettingsExpanderRow({
    required this.label,
    required this.expanded,
    required this.onTap,
    super.key,
  });

  /// The name.
  final String label;

  /// Whether the group under the row is open.
  final bool expanded;

  /// Called on a tap, to open or close the group.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = CarretePalette.of(context);
    return Semantics(
      container: true,
      button: true,
      expanded: expanded,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: CarreteSizes.settingRow),
          child: Padding(
            padding: _rowPadding,
            child: Row(
              children: [
                Expanded(
                  child: Text(label, style: CarreteText.setting(palette.ink)),
                ),
                const SizedBox(width: CarreteSpacing.m),
                RotatedBox(
                  key: const ValueKey('expander-chevron'),
                  quarterTurns: expanded ? 1 : 0,
                  child: CarreteIconView(
                    icon: CarreteIcon.chevron,
                    color: palette.inkSoft,
                    size: CarreteSizes.settingsIcon,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A sentence of explanation inside a plate.
class SettingsNote extends StatelessWidget {
  const SettingsNote({required this.text, this.selectable = false, super.key});

  /// The sentence.
  final String text;

  /// Whether the text can be selected and copied (an address, for example).
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final palette = CarretePalette.of(context);
    return Padding(
      padding: _rowPadding.copyWith(
        top: CarreteSpacing.m,
        bottom: CarreteSpacing.m,
      ),
      child: Semantics(
        container: true,
        child: selectable
            ? SelectableText(text, style: CarreteText.note(palette.inkSoft))
            : Text(text, style: CarreteText.note(palette.inkSoft)),
      ),
    );
  }
}

/// A row of a list of which one is selected (the default film): a colour
/// swatch, the name and a lamp that is lit on the selected one.
class SettingsChoiceRow extends StatelessWidget {
  const SettingsChoiceRow({
    required this.label,
    required this.swatch,
    required this.selected,
    required this.onTap,
    super.key,
  });

  /// The name.
  final String label;

  /// The colour that stands for the item.
  final Color swatch;

  /// Whether this is the selected one.
  final bool selected;

  /// Called on a tap.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = CarretePalette.of(context);
    final dark = palette.brightness == Brightness.dark;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: CarreteSizes.filmRow),
          child: Padding(
            padding: _rowPadding,
            child: Row(
              children: [
                SizedBox.square(
                  dimension: CarreteSizes.swatch,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: swatch,
                      borderRadius: BorderRadius.circular(CarreteRadii.band),
                      border: Border.all(
                        color: palette.hairline,
                        width: CarreteSizes.hairlineWidth,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: CarreteSpacing.m),
                Expanded(
                  child: Text(
                    label,
                    style: CarreteText.setting(
                      selected ? palette.ink : palette.inkSoft,
                    ),
                  ),
                ),
                const SizedBox(width: CarreteSpacing.m),
                SizedBox.square(
                  dimension: CarreteSizes.lampSmall,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? palette.accent : null,
                      border: selected
                          ? null
                          : Border.all(color: palette.inkSoft),
                      boxShadow: selected && dark
                          ? [
                              BoxShadow(
                                color: palette.accent,
                                blurRadius: CarreteSwitch.lampGlow,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A row that runs an action when it is tapped (export, import): a name, a
/// short sentence under it and, while the action runs, a small spinner. With
/// [onTap] null the row is disabled, so a second tap does nothing.
class SettingsActionRow extends StatelessWidget {
  const SettingsActionRow({
    required this.label,
    required this.onTap,
    this.hint,
    this.busy = false,
    super.key,
  });

  /// The name.
  final String label;

  /// A short sentence under the name, or null for none.
  final String? hint;

  /// Called on a tap; null while the row is disabled.
  final VoidCallback? onTap;

  /// Whether the action is running (the row shows a spinner).
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final palette = CarretePalette.of(context);
    final enabled = onTap != null;
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: label,
      hint: hint,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: CarreteSizes.settingRow),
          child: Padding(
            padding: _rowPadding,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: CarreteText.setting(
                          enabled ? palette.ink : palette.inkSoft,
                        ),
                      ),
                      if (hint != null) ...[
                        const SizedBox(height: CarreteSpacing.xs),
                        Text(hint!, style: CarreteText.note(palette.inkSoft)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: CarreteSpacing.m),
                if (busy)
                  SizedBox.square(
                    dimension: CarreteSizes.settingsIcon,
                    child: CircularProgressIndicator(
                      strokeWidth: CarreteSizes.settingsSpinnerStroke,
                      color: palette.inkSoft,
                    ),
                  )
                else
                  CarreteIconView(
                    icon: CarreteIcon.chevron,
                    color: palette.inkSoft,
                    size: CarreteSizes.settingsIcon,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A warning sentence with a text action under it, shown under the hint of a
/// row (the location permission that was removed).
class SettingsWarning extends StatelessWidget {
  const SettingsWarning({
    required this.text,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  /// The warning.
  final String text;

  /// The name of the action, or null for a warning without action.
  final String? actionLabel;

  /// Called when the action is tapped.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = CarretePalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: CarreteText.note(palette.accent)),
        if (actionLabel != null)
          Semantics(
            container: true,
            button: true,
            label: actionLabel,
            onTap: onAction,
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onAction,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: CarreteSpacing.minTouch,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    actionLabel!,
                    style: CarreteText.setting(palette.ink)
                        .copyWith(decoration: TextDecoration.underline),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
