import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../ui/theme/carrete_tokens.dart';
import '../../ui/widgets/carrete_icon.dart';

/// The row of the gallery that opens the picker to develop photos the person
/// already took: a plate with a film icon, the name and one line of
/// explanation.
class ImportEntryRow extends StatelessWidget {
  const ImportEntryRow({required this.onTap, super.key});

  /// Called on a tap: opens the picker of the system.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = CarretePalette.of(context);
    return Semantics(
      container: true,
      button: true,
      label: l10n.galleryImportRow,
      hint: l10n.galleryImportHint,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
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
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: CarreteSizes.settingRow,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CarreteSizes.plateInset,
                vertical: CarreteSpacing.s,
              ),
              child: Row(
                children: [
                  CarreteIconView(
                    icon: CarreteIcon.film,
                    color: palette.accent,
                    size: CarreteSizes.settingsIcon,
                  ),
                  const SizedBox(width: CarreteSpacing.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.galleryImportRow,
                          style: CarreteText.setting(palette.ink),
                        ),
                        const SizedBox(height: CarreteSizes.hair),
                        Text(
                          l10n.galleryImportHint,
                          style: CarreteText.note(palette.inkSoft),
                        ),
                      ],
                    ),
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
      ),
    );
  }
}
