import 'dart:async';

import 'package:film_recipes/film_recipes.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/l10n/localized_text.dart';
import '../../core/router.dart';
import '../../gallery/gallery_content.dart';
import '../../gallery/photo_library.dart';
import '../../import/import_providers.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/gallery_images.dart';
import '../../render/film_resources.dart';
import '../../roll/roll_providers.dart';
import '../../ui/theme/carrete_tokens.dart';
import '../../ui/widgets/carrete_icon.dart';
import '../roll/develop_view.dart';
import '../roll/roll_name_dialog.dart' show rollFallbackName;
import '../roll/roll_parts.dart';
import '../settings/settings_parts.dart';
import '../viewfinder/viewfinder_state.dart';
import 'gallery_card.dart';
import 'import_entry.dart';

/// The own gallery of the app: the developed rolls and the days of loose
/// photos, the newest first, each as a strip of film. Rolls that are not
/// developed yet are listed apart, without a single photo: the wait stays a
/// secret until the roll is ready. It follows the theme of the system.
class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({
    this.onOpenRoll,
    this.onOpenDay,
    this.onImport,
    super.key,
  });

  /// Opens the roll [id]. The roll screen when null.
  final ValueChanged<int>? onOpenRoll;

  /// Opens the day with the key [key] (see [dayKey]). The day screen when
  /// null.
  final ValueChanged<String>? onOpenDay;

  /// Starts developing photos of the phone. Opens the photo picker and then
  /// the import screen when null.
  final VoidCallback? onImport;

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  @override
  void initState() {
    super.initState();
    ref.invalidate(galleryImagesProvider);
  }

  /// The photos were checked against the gallery of the system once.
  bool _swept = false;

  /// The picker is open: a second tap on the row does nothing.
  bool _picking = false;

  void _openRoll(BuildContext context, int id) {
    final callback = widget.onOpenRoll;
    if (callback != null) {
      callback(id);
    } else {
      unawaited(context.push(AppRoutes.rollOf('$id')));
    }
  }

  void _openDay(BuildContext context, String key) {
    final callback = widget.onOpenDay;
    if (callback != null) {
      callback(key);
    } else {
      unawaited(context.push(AppRoutes.galleryDayOf(key)));
    }
  }

  /// Asks the person for photos with the Photo Picker of the system and, if
  /// they chose some, opens the screen that develops them.
  Future<void> _import(BuildContext context) async {
    final callback = widget.onImport;
    if (callback != null) {
      callback();
      return;
    }
    if (_picking) return;
    _picking = true;
    final l10n = AppLocalizations.of(context);
    final palette = CarretePalette.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      final batch = await ref.read(importIntakeProvider).pick();
      if (!mounted || batch == null) return;
      if (batch.photos.isEmpty) {
        // Every photo was too big to open: there is nothing to develop.
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: palette.plate,
            content: Text(
              l10n.importRejected(batch.rejected),
              style: CarreteText.note(palette.ink),
            ),
          ),
        );
        return;
      }
      unawaited(router.push<void>(AppRoutes.importPhotos, extra: batch));
    } on Object catch (error) {
      if (kDebugMode) debugPrint('Could not pick photos: $error');
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: palette.plate,
          content: Text(
            l10n.importPickFailed,
            style: CarreteText.note(palette.ink),
          ),
        ),
      );
    } finally {
      _picking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = CarretePalette.of(context);
    final content = ref.watch(galleryContentProvider);
    final loaded = content.value;
    if (loaded != null && !_swept) {
      _swept = true;
      _sweep(loaded);
    }
    final book = ref.watch(recipeBookProvider).value;
    final now = ref.watch(rollClockProvider)();

    final List<Widget> body;
    String? subtitle;
    if (content.hasError) {
      body = [RollMessage(title: l10n.galleryLoadFailed, palette: palette)];
    } else if (content.value == null) {
      body = const [];
    } else {
      final data = content.value!;
      if (data.photoCount > 0) subtitle = l10n.rollFramesCount(data.photoCount);
      body = data.isEmpty
          ? [
              RollMessage(
                title: l10n.galleryEmptyTitle,
                body: l10n.galleryEmptyBody,
                palette: palette,
              ),
            ]
          : [
              if (data.developing.isNotEmpty) ...[
                SettingsSection(
                  title: l10n.galleryDevelopingLabel,
                  children: [
                    for (final roll in data.developing)
                      _DevelopingRow(
                        roll: roll,
                        film: book?.byId(roll.filmId),
                        now: now,
                        onTap: () => _openRoll(context, roll.id),
                      ),
                  ],
                ),
                const SizedBox(height: CarreteSpacing.xl),
              ],
              for (final entry in data.entries) ...[
                switch (entry) {
                  GalleryRoll() => _rollCard(context, entry, book),
                  GalleryDay() => _dayCard(context, entry, book, now),
                },
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
                    title: l10n.galleryTitle,
                    subtitle: subtitle,
                    palette: palette,
                  ),
                  const SizedBox(height: CarreteSpacing.l),
                  ImportEntryRow(onTap: () => unawaited(_import(context))),
                  const SizedBox(height: CarreteSpacing.xl),
                  ...body,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _rollCard(BuildContext context, GalleryRoll entry, RecipeBook? book) {
    final l10n = AppLocalizations.of(context);
    final roll = entry.roll;
    final film = book?.byId(roll.filmId);
    final developed = roll.developedAt;
    final filmName = film?.name.of(context) ?? roll.filmId;
    final developedOn = developed == null
        ? null
        : l10n.rollDevelopedOn(
            MaterialLocalizations.of(
              context,
            ).formatShortDate(DateTime.fromMillisecondsSinceEpoch(developed)),
          );
    // A roll with a name shows it, in the hand of the app, where the film was;
    // the film moves to the line under it.
    final name = roll.name;
    return GalleryCard(
      label: rollFallbackName(l10n, roll.id),
      title: name ?? filmName,
      handwritten: name != null,
      subtitle: name == null
          ? developedOn
          : [filmName, ?developedOn].join(' · '),
      count: l10n.rollFramesCount(entry.photos.length),
      swatch: film == null ? null : filmBandColor(film),
      preview: entry.photos.take(CarreteRoll.cardFrames).toList(),
      onTap: () => _openRoll(context, roll.id),
    );
  }

  Widget _dayCard(
    BuildContext context,
    GalleryDay entry,
    RecipeBook? book,
    DateTime now,
  ) {
    final l10n = AppLocalizations.of(context);
    final films = <String>[];
    for (final photo in entry.photos) {
      final name = book?.byId(photo.filmId)?.name.of(context) ?? photo.filmId;
      if (!films.contains(name)) films.add(name);
    }
    return GalleryCard(
      label: l10n.galleryLooseLabel,
      title: dayTitle(context, entry.day, now),
      subtitle: films.join(', '),
      count: l10n.rollFramesCount(entry.photos.length),
      preview: entry.photos.reversed.take(CarreteRoll.cardFrames).toList(),
      onTap: () => _openDay(context, entry.key),
    );
  }

  /// Clears the rows of photos that are not in the gallery of the system any
  /// more: deleted outside the app, or by a delete that was cut short.
  void _sweep(GalleryContent content) {
    final photos = [for (final entry in content.entries) ...entry.photos];
    if (photos.isEmpty) return;
    final library = ref.read(photoLibraryProvider);
    unawaited(
      library
          .dropMissing(photos)
          .then<void>(
            (_) {},
            onError: (Object error) {
              if (kDebugMode) debugPrint('Looking for missing photos: $error');
            },
          ),
    );
  }
}

/// The name of a day over its photos: today, yesterday, or the date (with the
/// year when it is not this one).
String dayTitle(BuildContext context, DateTime day, DateTime now) {
  final l10n = AppLocalizations.of(context);
  final difference = calendarDaysBetween(day, now);
  if (difference == 0) return l10n.galleryToday;
  if (difference == 1) return l10n.galleryYesterday;
  final material = MaterialLocalizations.of(context);
  final date = material.formatMediumDate(day);
  return day.year == now.year ? date : '$date ${day.year}';
}

/// A roll that is closed and not developed yet: where it stands, and nothing
/// of its photos. Opens the screen of the roll.
class _DevelopingRow extends StatelessWidget {
  const _DevelopingRow({
    required this.roll,
    required this.film,
    required this.now,
    required this.onTap,
  });

  final RollRow roll;
  final Recipe? film;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = CarretePalette.of(context);
    final fallback = rollFallbackName(l10n, roll.id);
    final name = roll.name;
    final title = name ?? fallback;
    final waiting = (roll.developAt ?? 0) > now.millisecondsSinceEpoch;
    final detail = [
      if (name != null) fallback,
      film?.name.of(context) ?? roll.filmId,
      waiting ? l10n.rollStateWaiting : l10n.rollStateDeveloping,
    ].join(' · ');
    return Semantics(
      container: true,
      button: true,
      label: '$title, $detail',
      hint: l10n.galleryCardHint,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: CarreteSizes.settingRow),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CarreteSizes.plateInset,
              vertical: CarreteSpacing.s,
            ),
            child: Row(
              children: [
                CarreteIconView(
                  icon: CarreteIcon.roll,
                  color: palette.inkSoft,
                  size: CarreteSizes.settingsIcon,
                ),
                const SizedBox(width: CarreteSpacing.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: name == null
                            ? CarreteText.setting(palette.ink)
                            : CarreteText.handName(
                                palette.ink,
                                size: CarreteText.handNameRow,
                              ),
                      ),
                      const SizedBox(height: CarreteSizes.hair),
                      Text(detail, style: CarreteText.note(palette.inkSoft)),
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
    );
  }
}
