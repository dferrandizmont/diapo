import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/theme/carrete_tokens.dart';
import '../../ui/widgets/carrete_icon.dart';
import '../roll/roll_parts.dart';
import 'tuning_panel.dart' show PlasticPlateSurface;

/// The hint of a new user's first minute: a dark pill over the camera, above
/// the films, that says to swipe them. It goes away with its key, or when the
/// user changes the film. The pill is dark enough to read over a bright scene.
class SwipeHint extends StatelessWidget {
  const SwipeHint({required this.onClose, super.key});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CarreteColors.notice,
          borderRadius: BorderRadius.circular(CarreteRadii.key),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: CarreteSizes.pillInsetH),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.viewfinderSwipeHint,
                  style: CarreteText.notice,
                ),
              ),
              Semantics(
                button: true,
                label: l10n.swipeHintClose,
                onTap: onClose,
                excludeSemantics: true,
                child: GestureDetector(
                  key: const ValueKey('swipe-hint-close'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onClose,
                  child: const SizedBox.square(
                    dimension: CarreteSpacing.minTouch,
                    child: Center(
                      child: CarreteIconView(
                        icon: CarreteIcon.close,
                        color: CarreteColors.white,
                        size: CarreteSizes.settingsIcon,
                      ),
                    ),
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

/// The offer of a first roll of 12, shown once after the second loose photo.
/// It is on the plate of the camera, so it follows the theme of the camera.
///
/// It says where undeveloped photos live (they are lost with the app or the
/// phone) before the roll is loaded. It never grows taller than [maxHeight]:
/// when the text is large it scrolls, and the two keys go one over the other
/// when the text is large or the screen is narrow.
class RollOfferCard extends StatelessWidget {
  const RollOfferCard({
    required this.film,
    required this.onAccept,
    required this.onDismiss,
    this.maxHeight = double.infinity,
    super.key,
  });

  /// The name of the selected film, the one the roll would have.
  final String film;

  /// Loads the roll.
  final VoidCallback onAccept;

  /// Closes the offer.
  final VoidCallback onDismiss;

  /// The most height the card may take.
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = CarreteCameraColors.of(context);
    final tone = RollTone(null, camera: colors);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        liveRegion: true,
        child: PlasticPlateSurface(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked =
                  scale > CarreteSizes.offerStackScale ||
                  constraints.maxWidth < CarreteSizes.offerStackWidth;
              final dismiss = RollWideKey(
                key: const ValueKey('roll-offer-dismiss'),
                label: l10n.rollOfferDismiss,
                onPressed: onDismiss,
              );
              final accept = RollWideKey(
                key: const ValueKey('roll-offer-accept'),
                label: l10n.rollOfferAction,
                color: colors.active,
                onPressed: onAccept,
              );
              return SingleChildScrollView(
                padding: CarreteRoll.sheetPadding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        l10n.rollOfferTitle,
                        style: CarreteText.panelTitle.copyWith(
                          color: colors.panelTitle,
                        ),
                      ),
                    ),
                    const SizedBox(height: CarreteSpacing.xs),
                    Text(l10n.rollOfferBody(film), style: tone.note),
                    const SizedBox(height: CarreteSpacing.xs),
                    Text(
                      l10n.rollLossNote,
                      key: const ValueKey('roll-offer-loss'),
                      style: tone.note,
                    ),
                    const SizedBox(height: CarreteSpacing.m),
                    if (stacked) ...[
                      accept,
                      const SizedBox(height: CarreteSpacing.s),
                      dismiss,
                    ] else
                      Row(
                        children: [
                          Expanded(child: dismiss),
                          const SizedBox(width: CarreteSpacing.s),
                          Expanded(child: accept),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
