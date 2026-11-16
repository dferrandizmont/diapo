import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../gallery/gallery_content.dart';
import '../../l10n/app_localizations.dart';
import '../../roll/roll_providers.dart';
import '../../ui/theme/carrete_tokens.dart';
import '../roll/contact_sheet.dart';
import '../roll/develop_view.dart';
import '../roll/roll_parts.dart';
import 'gallery_screen.dart';

/// The loose photos of one day as contact sheets, like a developed roll. A
/// long day is cut into sheets of [CarreteRoll.sheetFrames] frames; the viewer
/// still swipes through the whole day.
class GalleryDayScreen extends ConsumerWidget {
  const GalleryDayScreen({required this.dayKey, super.key});

  /// The day, as in [GalleryDay.key].
  final String dayKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final palette = CarretePalette.of(context);
    final content = ref.watch(galleryContentProvider);
    final now = ref.watch(rollClockProvider)();
    final day = content.value?.dayOf(dayKey);
    final date = parseDayKey(dayKey);

    final String title = date == null
        ? l10n.galleryLooseLabel
        : dayTitle(context, date, now);
    String? subtitle;
    final List<Widget> body;
    if (day == null) {
      body = [
        if (content.hasValue || content.hasError)
          RollMessage(title: l10n.galleryDayMissingTitle, palette: palette),
      ];
    } else {
      subtitle = l10n.rollFramesCount(day.photos.length);
      body = [
        for (final sheet in _sheets(day.photos)) ...[
          ContactSheet(
            shots: sheet,
            viewerShots: day.photos,
            title: l10n.galleryLooseLabel,
          ),
          const SizedBox(height: CarreteSpacing.l),
        ],
      ];
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: palette.brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: palette.background,
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: CarreteRoll.bodyMaxWidth,
              ),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  CarreteSpacing.margin,
                  CarreteSpacing.s,
                  CarreteSpacing.margin,
                  CarreteSpacing.xxl,
                ),
                children: [
                  RollHeader(
                    title: title,
                    subtitle: subtitle,
                    palette: palette,
                  ),
                  const SizedBox(height: CarreteSpacing.l),
                  ...body,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<List<ShotRow>> _sheets(List<ShotRow> photos) => [
    for (var i = 0; i < photos.length; i += CarreteRoll.sheetFrames)
      photos.sublist(
        i,
        i + CarreteRoll.sheetFrames > photos.length
            ? photos.length
            : i + CarreteRoll.sheetFrames,
      ),
  ];
}
