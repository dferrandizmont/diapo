import 'package:film_recipes/film_recipes.dart';
import 'package:flutter/material.dart';

import '../../camera/frame_geometry.dart';
import '../../core/l10n/localized_text.dart';
import '../../core/settings/film_tuning.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme/carrete_tokens.dart';
import '../../ui/widgets/carrete_icon.dart';
import '../../ui/widgets/plastic_controls.dart';
import '../../ui/widgets/plastic_key.dart';
import '../../ui/widgets/seven_segment.dart';

/// The fine-tuning panel that opens on a long press on a cartridge: grain,
/// halation, light leak and vignette (0 to 100, 50 being the recipe), the date
/// imprint, the cinema bands (16:9 only) and, where [showFormat] is set, the
/// frame format.
class FilmTuningPanel extends StatelessWidget {
  const FilmTuningPanel({
    required this.recipe,
    required this.tuning,
    required this.effectiveFormat,
    required this.effectiveDateStamp,
    required this.effectiveCinemaBands,
    required this.sampleStamp,
    required this.onChanged,
    required this.onClose,
    this.showFormat = false,
    super.key,
  });

  /// The film being tuned.
  final Recipe recipe;

  /// Its tuning.
  final FilmTuning tuning;

  /// The format in force: the tuning's, or the recipe's.
  final FrameFormat effectiveFormat;

  /// Whether the date is imprinted: the tuning's, or the recipe's.
  final bool effectiveDateStamp;

  /// Whether the cinema bands are on: the tuning's, or the recipe's. The switch
  /// is shown only when [effectiveFormat] supports them (16:9).
  final bool effectiveCinemaBands;

  /// The date as the imprint will show it, for the little preview.
  final String sampleStamp;

  /// Called with a function that makes the new tuning out of the old one.
  final void Function(FilmTuning Function(FilmTuning current) change) onChanged;

  /// Closes the panel.
  final VoidCallback onClose;

  /// Whether the panel has a row to choose the frame format. The camera does
  /// not: its format key sits beside the shutter. The import screen has no such
  /// key, so it shows the row.
  final bool showFormat;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final name = recipe.name.of(context);
    final colors = CarreteCameraColors.of(context);
    final row = CarreteText.row.copyWith(color: colors.ink);

    Widget slider(
      String label,
      double multiplier,
      FilmTuning Function(FilmTuning t, double m) apply,
    ) {
      final value = FilmTuning.displayOf(multiplier);
      return SizedBox(
        height: CarreteSizes.sliderRow,
        child: Row(
          children: [
            SizedBox(
              width: CarreteSizes.sliderLabel,
              child: Text(
                label,
                style: row,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: CarreteSizes.sliderGap),
            Expanded(
              child: PlasticSlider(
                label: label,
                value: value,
                onChanged: (v) =>
                    onChanged((t) => apply(t, FilmTuning.multiplierOf(v))),
              ),
            ),
            const SizedBox(width: CarreteSizes.sliderGap),
            SizedBox(
              width: CarreteSizes.sliderValue,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  '$value',
                  maxLines: 1,
                  softWrap: false,
                  style: CarreteText.value.copyWith(color: colors.active),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Semantics(
      container: true,
      explicitChildNodes: true,
      scopesRoute: true,
      namesRoute: true,
      label: l10n.tunePanelLabel(name),
      child: PlasticPlateSurface(
        child: Padding(
          padding: CarreteSizes.panelPadding,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: CarreteSizes.panelHeader,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: CarreteText.panelTitle.copyWith(
                                color: colors.panelTitle,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: CarreteSizes.hair),
                            Text(
                              CarreteText.upper(l10n.tuneSubtitle, locale),
                              style: CarreteText.panelSubtitle.copyWith(
                                color: colors.inkSoft,
                              ),
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                      PlasticKey(
                        semanticLabel: l10n.tuneClose,
                        onPressed: onClose,
                        child: const CarreteIconView(icon: CarreteIcon.close),
                      ),
                    ],
                  ),
                ),
                slider(
                  l10n.tuneGrain,
                  tuning.grain,
                  (t, m) => t.copyWith(grain: m),
                ),
                slider(
                  l10n.tuneHalation,
                  tuning.halation,
                  (t, m) => t.copyWith(halation: m),
                ),
                slider(
                  l10n.tuneLeak,
                  tuning.leak,
                  (t, m) => t.copyWith(leak: m),
                ),
                slider(
                  l10n.tuneVignette,
                  tuning.vignette,
                  (t, m) => t.copyWith(vignette: m),
                ),
                SizedBox(
                  height: CarreteSizes.panelRow,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.tuneDateStamp,
                          style: row,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: CarreteColors.black,
                          borderRadius: BorderRadius.circular(
                            CarreteRadii.dateBox,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: CarreteSpacing.s,
                            vertical: CarreteSizes.dateBoxInsetV,
                          ),
                          child: ExcludeSemantics(
                            child: SevenSegmentText(
                              text: sampleStamp,
                              height: CarreteSizes.dateSample,
                              color: CarreteColors.date,
                              glow: true,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: CarreteSpacing.m),
                      PlasticSwitch(
                        label: l10n.tuneDateStamp,
                        value: effectiveDateStamp,
                        onChanged: (v) =>
                            onChanged((t) => t.copyWith(dateStamp: v)),
                      ),
                    ],
                  ),
                ),
                if (effectiveFormat.supportsCinemaBands)
                  SizedBox(
                    height: CarreteSizes.panelRow,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.tuneCinemaBands,
                            style: row,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        PlasticSwitch(
                          label: l10n.tuneCinemaBands,
                          value: effectiveCinemaBands,
                          onChanged: (v) =>
                              onChanged((t) => t.copyWith(cinemaBands: v)),
                        ),
                      ],
                    ),
                  ),
                if (showFormat)
                  SizedBox(
                    height: CarreteSizes.panelRow,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(l10n.tuneFormat, style: row, maxLines: 1),
                        ),
                        for (final format in FrameFormat.values) ...[
                          const SizedBox(width: CarreteSpacing.xs),
                          PlasticKey(
                            semanticLabel: l10n.formatKeyLabel(format.label),
                            selected: format == effectiveFormat,
                            width: CarreteSizes.formatKey,
                            onPressed: () =>
                                onChanged((t) => t.copyWith(format: format)),
                            child: Text(format.label),
                          ),
                        ],
                      ],
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

/// The plate of the panel with its rounded edge and a soft shadow, in the
/// plastic of the camera.
class PlasticPlateSurface extends StatelessWidget {
  const PlasticPlateSurface({required this.child, super.key});

  /// What is on the plate.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = CarreteCameraColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(CarreteRadii.panel),
        border: Border.all(color: colors.panelEdge),
        boxShadow: [colors.plateShadow],
      ),
      child: child,
    );
  }
}
