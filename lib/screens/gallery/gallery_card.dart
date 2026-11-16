import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/theme/carrete_tokens.dart';
import '../roll/contact_sheet.dart';

/// A card of the gallery: a strip of film with the first photos of a roll or
/// of a day, on the paper of the contact sheet, with what it is, its title and
/// how many photos it holds. Tapping it opens the photos.
class GalleryCard extends StatelessWidget {
  const GalleryCard({
    required this.label,
    required this.title,
    required this.count,
    required this.preview,
    required this.onTap,
    this.subtitle,
    this.swatch,
    this.handwritten = false,
    super.key,
  });

  /// The title is a name the user wrote (the name of a roll): it is set in the
  /// hand of the app.
  final bool handwritten;

  /// What the card is, in small capitals ("Roll 07", "Loose photos").
  final String label;

  /// The title: the film of a roll, the day of loose photos.
  final String title;

  /// The line under the title (when a roll was developed, the films of a day).
  final String? subtitle;

  /// How many photos the card holds, already worded ("24 photos").
  final String count;

  /// The photos drawn on the strip: at most [CarreteRoll.cardFrames].
  final List<ShotRow> preview;

  /// The colour of the film, drawn before the title.
  final Color? swatch;

  /// Called on a tap.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = CarretePalette.of(context);
    final colors = CarreteSheetColors.of(context);
    final locale = Localizations.localeOf(context);
    return Semantics(
      container: true,
      button: true,
      label: [label, title, ?subtitle, count].join(', '),
      hint: l10n.galleryCardHint,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ContactPlate(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              CarreteRoll.stripInset,
              CarreteSpacing.m,
              CarreteRoll.stripInset,
              CarreteSpacing.m,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DecoratedBox(
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            CarreteText.upper(label, locale),
                            style: CarreteText.sectionLabel(palette.ink),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: CarreteSpacing.s),
                        Text(
                          CarreteText.upper(count, locale),
                          style: CarreteText.sectionLabel(palette.inkSoft),
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: CarreteSpacing.s),
                _PreviewStrip(preview: preview, colors: colors),
                const SizedBox(height: CarreteSpacing.s),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CarreteSpacing.xs,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (swatch != null) ...[
                        Padding(
                          padding: const EdgeInsets.only(
                            top: CarreteSizes.hair,
                          ),
                          child: SizedBox.square(
                            dimension: CarreteRoll.swatch,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: swatch,
                                borderRadius: BorderRadius.circular(
                                  CarreteRadii.band,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: CarreteSpacing.s),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: handwritten ? 2 : null,
                              overflow: handwritten
                                  ? TextOverflow.ellipsis
                                  : null,
                              style: handwritten
                                  ? CarreteText.handName(
                                      palette.ink,
                                      size: CarreteText.handNameCard,
                                    )
                                  : CarreteText.setting(palette.ink),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: CarreteSizes.hair),
                              Text(
                                subtitle!,
                                style: CarreteText.note(palette.inkSoft),
                              ),
                            ],
                          ],
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
    );
  }
}

/// The strip of film of a card: [CarreteRoll.cardFrames] frames between two
/// rows of perforations; the frames the card has no photo for stay dark.
class _PreviewStrip extends StatelessWidget {
  const _PreviewStrip({required this.preview, required this.colors});

  final List<ShotRow> preview;
  final CarreteSheetColors colors;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(color: colors.strip),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilmPerforations(color: colors.perf),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CarreteRoll.stripInset,
              ),
              child: Row(
                children: [
                  for (var i = 0; i < CarreteRoll.cardFrames; i++) ...[
                    if (i > 0) const SizedBox(width: CarreteRoll.frameGap),
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: CarreteRoll.frameAspect,
                        child: i < preview.length
                            ? GalleryThumbnail(
                                location: preview[i].galleryUri!,
                                colors: colors,
                                missingLabel: l10n.rollFrameMissing,
                              )
                            : EmptyFrame(colors: colors),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            FilmPerforations(color: colors.perf),
          ],
        ),
      ),
    );
  }
}
