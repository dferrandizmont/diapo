import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

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
class GalleryDayScreen extends ConsumerStatefulWidget {
  const GalleryDayScreen({required this.dayKey, super.key});

  /// The day, as in [GalleryDay.key].
  final String dayKey;

  @override
  ConsumerState<GalleryDayScreen> createState() => _GalleryDayScreenState();
}

class _GalleryDayScreenState extends ConsumerState<GalleryDayScreen> {
  /// Whether this day has been seen with photos on this screen: a day that
  /// never had any keeps showing the "missing day" state instead of popping.
  bool _hadDay = false;
  bool _popped = false;
  bool _viewerOpen = false;

  @override
  void initState() {
    super.initState();
    // React to the day becoming empty while it is open (for example after a
    // delete): pop back to the gallery instead of showing the "missing day"
    // state. A day that was already empty on entry keeps that state.
    ref.listenManual(galleryContentProvider, (previous, next) {
      final hadDay = previous?.value?.dayOf(widget.dayKey) != null;
      if (hadDay) _hadDay = true;
      final hasDay = next.value?.dayOf(widget.dayKey) != null;
      // Navigate only when the data confirms the day is gone: a real empty
      // list, never a read error or a loading state.
      if (_hadDay && !hasDay && next.hasValue && !next.hasError) {
        if (!_viewerOpen) {
          _popToGallery();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = CarretePalette.of(context);
    final content = ref.watch(galleryContentProvider);
    final now = ref.watch(rollClockProvider)();
    final day = content.value?.dayOf(widget.dayKey);
    if (day != null) _hadDay = true;
    final date = parseDayKey(widget.dayKey);

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
            onViewerOpened: () => _viewerOpen = true,
            onViewerClosed: () {
              // The screen may be gone by the time the viewer's route returns.
              if (!mounted || _popped) return;
              _viewerOpen = false;
              // The day may have become empty while the viewer was open, in
              // which case the listener above deferred the navigation. Re-evaluate
              // now that the viewer is closed (Back counts too).
              final content = ref.read(galleryContentProvider);
              if (_hadDay &&
                  content.hasValue &&
                  !content.hasError &&
                  content.value?.dayOf(widget.dayKey) == null) {
                _popToGallery();
              }
            },
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

  void _popToGallery() {
    if (_popped) return;
    _popped = true;
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final router = GoRouter.maybeOf(context);
      if (router != null) {
        // The day is pushed from the gallery: going back keeps that gallery
        // and the camera under it, so Back from the gallery still returns to
        // the camera. `go` would rebuild the whole stack with a new gallery.
        if (router.canPop()) {
          router.pop();
        } else {
          router.go('/gallery');
        }
        return;
      }
      final nav = Navigator.of(context, rootNavigator: true);
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const GalleryScreen()),
        (route) => false,
      );
    });
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
