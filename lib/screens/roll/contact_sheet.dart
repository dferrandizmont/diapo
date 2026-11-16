import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/after_build.dart';
import '../../core/database/app_database.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/gallery_images.dart';
import '../../platform/photo_actions.dart';
import '../../ui/theme/carrete_tokens.dart';
import 'frame_viewer.dart';

/// The contact sheet of a developed roll (design A): all its frames as small
/// pictures on strips of film, each with its number, under a header with the
/// frame count. It follows the theme of the app.
class ContactSheet extends StatelessWidget {
  const ContactSheet({
    required this.shots,
    this.title,
    this.viewerShots,
    this.developing = false,
    this.reveal,
    this.onLastPhotoDeleted,
    this.popToGalleryOnLastDelete = false,
    this.onViewerOpened,
    this.onViewerClosed,
    super.key,
  });

  /// The frames of the roll (or the loose photos of a day), in order.
  final List<ShotRow> shots;

  /// Every photo the viewer swipes through when this sheet holds only a part
  /// of them (a long day is split into several sheets). [shots] by default.
  final List<ShotRow>? viewerShots;

  /// The title over the sheet; "Contact sheet" when null.
  final String? title;

  /// Whether the roll is still being developed: a frame with no photo yet is
  /// an empty frame that is waiting, not a photo that is missing.
  final bool developing;

  /// Brings the frames in one after another as it runs from 0 to 1, in order.
  /// Null shows them all at once. While it is set the frames do not react to
  /// taps (the screen puts a layer over the sheet that skips the reveal).
  final Animation<double>? reveal;

  /// Called when the viewer closes because its last photo was deleted. The
  /// screen that owns this sheet can then leave (for example back to the
  /// gallery) when that photo was the last one of its content.
  final void Function(PhotoDeletion outcome)? onLastPhotoDeleted;

  /// Whether the owner wants to be taken to the gallery when the last photo
  /// of the sheet is deleted. Kept for compatibility; navigation now lives in
  /// the owner (see [GalleryDayScreen]).
  final bool popToGalleryOnLastDelete;

  /// Called just before the viewer is pushed onto the navigator.
  final VoidCallback? onViewerOpened;

  /// Called when the viewer closes, however it closed.
  final VoidCallback? onViewerClosed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = CarretePalette.of(context);
    final colors = CarreteSheetColors.of(context);
    final locale = Localizations.localeOf(context);
    final sheetTitle = title ?? l10n.contactSheetTitle;
    final all = viewerShots ?? shots;
    final openable = [
      for (final shot in all)
        if (_isPhoto(shot)) shot,
    ];
    final strips = <List<ShotRow>>[
      for (var i = 0; i < shots.length; i += CarreteRoll.stripFrames)
        shots.sublist(
          i,
          i + CarreteRoll.stripFrames > shots.length
              ? shots.length
              : i + CarreteRoll.stripFrames,
        ),
    ];
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: sheetTitle,
      child: ContactPlate(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            CarreteRoll.stripInset,
            CarreteSpacing.m,
            CarreteRoll.stripInset,
            CarreteSpacing.s,
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
                        child: Semantics(
                          header: true,
                          child: Text(
                            CarreteText.upper(sheetTitle, locale),
                            style: CarreteText.sectionLabel(palette.ink),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: CarreteSpacing.s),
                      Text(
                        CarreteText.upper(
                          l10n.rollFramesCount(all.length),
                          locale,
                        ),
                        style: CarreteText.sectionLabel(palette.inkSoft),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: CarreteSpacing.s),
              for (final strip in strips)
                Padding(
                  padding: const EdgeInsets.only(bottom: CarreteRoll.stripGap),
                  child: _Strip(
                    shots: strip,
                    colors: colors,
                    developing: developing,
                    reveal: reveal,
                    firstIndex: strips.indexOf(strip) * CarreteRoll.stripFrames,
                    count: shots.length,
                    numberOf: (shot) => _number(shot, all),
                    onOpen: (shot) => _open(context, openable, all, shot),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(
    BuildContext context,
    List<ShotRow> openable,
    List<ShotRow> all,
    ShotRow shot,
  ) {
    final index = openable.indexWhere((s) => s.id == shot.id);
    if (index < 0) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final notice = AppLocalizations.of(context).viewerOriginalKept;
    final palette = CarretePalette.of(context);
    onViewerOpened?.call();
    final closed = Navigator.of(context).push(
      MaterialPageRoute<PhotoDeletion>(
        builder: (context) => FrameViewer(
          frames: [
            for (final s in openable)
              ViewerFrame(
                number: _number(s, all),
                location: s.galleryUri!,
                shotId: s.id,
                filmId: s.filmId,
                takenAt: DateTime.fromMillisecondsSinceEpoch(s.takenAt),
              ),
          ],
          initialIndex: index,
        ),
      ),
    );
    // Deleting the last photo closes the viewer: the notice that its original
    // stayed behind is told here, on the screen the user returns to. The owner
    // of the sheet is also told, so it can leave when that photo was the last
    // one of its content.
    unawaited(
      closed.then((outcome) {
        onViewerClosed?.call();
        if (outcome == null) return;
        if (outcome == PhotoDeletion.deletedKeptOriginal) {
          messenger?.showSnackBar(
            SnackBar(
              backgroundColor: palette.plate,
              content: Text(notice, style: CarreteText.note(palette.ink)),
            ),
          );
        }
        if (outcome == PhotoDeletion.deleted ||
            outcome == PhotoDeletion.gone ||
            outcome == PhotoDeletion.deletedKeptOriginal) {
          onLastPhotoDeleted?.call(outcome);
        }
      }),
    );
  }
}

/// The number printed under a frame: its frame number, or its place in the
/// roll when it has none.
int _number(ShotRow shot, List<ShotRow> shots) =>
    shot.frameNumber ?? shots.indexOf(shot) + 1;

/// Whether the frame has a photo to show.
bool _isPhoto(ShotRow shot) =>
    shot.developFailure == null && shot.galleryUri != null;

class _Strip extends StatelessWidget {
  const _Strip({
    required this.shots,
    required this.colors,
    required this.developing,
    required this.reveal,
    required this.firstIndex,
    required this.count,
    required this.numberOf,
    required this.onOpen,
  });

  final List<ShotRow> shots;
  final CarreteSheetColors colors;
  final bool developing;
  final Animation<double>? reveal;

  /// The place of the first frame of the strip in the whole sheet, and how many
  /// frames the sheet has: the order of the reveal.
  final int firstIndex;
  final int count;
  final int Function(ShotRow shot) numberOf;
  final ValueChanged<ShotRow> onOpen;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.strip),
      child: Padding(
        padding: const EdgeInsets.only(bottom: CarreteSizes.hair),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilmPerforations(color: colors.perf),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: CarreteRoll.stripInset,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < CarreteRoll.stripFrames; i++) ...[
                    if (i > 0) const SizedBox(width: CarreteRoll.frameGap),
                    Expanded(
                      child: i < shots.length
                          ? ContactFrame(
                              shot: shots[i],
                              number: numberOf(shots[i]),
                              colors: colors,
                              developing: developing,
                              reveal: reveal,
                              revealIndex: firstIndex + i,
                              revealCount: count,
                              onOpen: () => onOpen(shots[i]),
                            )
                          : const SizedBox.shrink(),
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

/// The sheet of paper of the contact sheet, with its edge in the dark theme
/// and its soft shadow. The cards of the gallery sit on the same paper.
class ContactPlate extends StatelessWidget {
  const ContactPlate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = CarretePalette.of(context);
    final colors = CarreteSheetColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.sheet,
        border: palette.brightness == Brightness.dark
            ? Border.all(
                color: palette.hairline,
                width: CarreteSizes.hairlineWidth,
              )
            : null,
        boxShadow: [
          BoxShadow(color: palette.plateShadow, offset: const Offset(0, 2)),
        ],
      ),
      child: child,
    );
  }
}

/// A row of perforations of the film.
class FilmPerforations extends StatelessWidget {
  const FilmPerforations({required this.color, super.key});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: CarreteRoll.perfHeight,
        child: CustomPaint(painter: _PerforationPainter(color)),
      ),
    );
  }
}

class _PerforationPainter extends CustomPainter {
  const _PerforationPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const inset = (CarreteRoll.perfPitch - CarreteRoll.perfWidth) / 2;
    final top = (size.height - CarreteRoll.perfHole) / 2;
    for (
      var x = 0.0;
      x + CarreteRoll.perfPitch <= size.width;
      x += CarreteRoll.perfPitch
    ) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x + inset,
            top,
            CarreteRoll.perfWidth,
            CarreteRoll.perfHole,
          ),
          const Radius.circular(CarreteRoll.perfRadius),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_PerforationPainter old) => old.color != color;
}

/// One frame of the contact sheet: the photo (or an empty frame when it
/// failed or was deleted) and its number.
class ContactFrame extends StatelessWidget {
  const ContactFrame({
    required this.shot,
    required this.number,
    required this.colors,
    required this.onOpen,
    this.developing = false,
    this.reveal,
    this.revealIndex = 0,
    this.revealCount = 1,
    super.key,
  });

  final ShotRow shot;
  final int number;
  final CarreteSheetColors colors;
  final VoidCallback onOpen;

  /// The roll is being developed: a frame with no photo yet is waiting.
  final bool developing;

  /// The reveal this frame comes in with, as the [revealIndex]th of
  /// [revealCount] frames; null for a frame that is simply there.
  final Animation<double>? reveal;
  final int revealIndex;
  final int revealCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failed = shot.developFailure != null;
    final photo = _isPhoto(shot);
    final waiting = developing && !failed && !photo;
    final label = failed
        ? l10n.rollFrameFailed
        : photo || waiting
        ? null
        : l10n.rollFrameMissing;
    final semantics = failed
        ? l10n.frameFailedSemantics(number)
        : photo
        ? l10n.frameSemantics(number)
        : waiting
        ? l10n.frameDevelopingSemantics(number)
        : l10n.frameMissingSemantics(number);
    final instant = MediaQuery.disableAnimationsOf(context);
    final frame = Semantics(
      container: true,
      button: photo,
      label: semantics,
      hint: photo ? l10n.frameOpenHint : null,
      onTap: photo ? onOpen : null,
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('frame-$number'),
        behavior: HitTestBehavior.opaque,
        onTap: photo ? onOpen : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: CarreteRoll.frameAspect,
              // A photo that finishes saving while the sheet is on screen
              // comes in over its empty frame.
              child: AnimatedSwitcher(
                duration: instant
                    ? Duration.zero
                    : CarreteDurations.developStep,
                layoutBuilder: (current, previous) => Stack(
                  fit: StackFit.expand,
                  children: [...previous, ?current],
                ),
                child: photo
                    ? GalleryThumbnail(
                        key: const ValueKey('photo'),
                        location: shot.galleryUri!,
                        colors: colors,
                        missingLabel: l10n.rollFrameMissing,
                      )
                    : EmptyFrame(
                        key: ValueKey(waiting ? 'waiting' : 'empty'),
                        colors: colors,
                        label: label,
                      ),
              ),
            ),
            const SizedBox(height: CarreteSizes.hair),
            Text(
              '$number',
              style: CarreteText.frameNumber(colors.edge),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
    final reveal = this.reveal;
    if (reveal == null) return frame;
    return _RevealIn(
      animation: reveal,
      index: revealIndex,
      count: revealCount,
      child: frame,
    );
  }
}

/// A frame that fades in and rises a little at its turn of the reveal: the
/// frames come in one after another over the length of the animation.
class _RevealIn extends StatelessWidget {
  const _RevealIn({
    required this.animation,
    required this.index,
    required this.count,
    required this.child,
  });

  final Animation<double> animation;
  final int index;
  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const share = CarreteRoll.revealFrameShare;
    final begin = count <= 1 ? 0.0 : (1 - share) * index / (count - 1);
    final progress = animation.drive(
      CurveTween(curve: Interval(begin, begin + share, curve: Curves.easeOut)),
    );
    return FadeTransition(
      opacity: progress,
      child: SlideTransition(
        position: progress.drive(
          Tween<Offset>(
            begin: const Offset(0, CarreteRoll.revealRise),
            end: Offset.zero,
          ),
        ),
        child: child,
      ),
    );
  }
}

/// A frame with no photo: the dark film with a short label.
class EmptyFrame extends StatelessWidget {
  const EmptyFrame({required this.colors, this.label, super.key});

  final CarreteSheetColors colors;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return ColoredBox(
      color: colors.empty,
      child: label == null
          ? const SizedBox.expand()
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(CarreteSizes.hair),
                child: Text(
                  CarreteText.upper(label!, locale),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: CarreteText.frameLabel(colors.emptyInk),
                ),
              ),
            ),
    );
  }
}

/// A thumbnail read from the gallery. While it loads the frame is empty; when
/// the photo is gone (the user deleted it) it stays empty with a label.
class GalleryThumbnail extends ConsumerStatefulWidget {
  const GalleryThumbnail({
    required this.location,
    required this.colors,
    required this.missingLabel,
    super.key,
  });

  /// The `galleryUri` of the photo.
  final String location;
  final CarreteSheetColors colors;
  final String missingLabel;

  @override
  ConsumerState<GalleryThumbnail> createState() => _GalleryThumbnailState();
}

class _GalleryThumbnailState extends ConsumerState<GalleryThumbnail> {
  late Future<Uint8List?> _bytes = _load();

  Future<Uint8List?> _load() =>
      ref.read(galleryImagesProvider).thumbnail(widget.location);

  @override
  void didUpdateWidget(GalleryThumbnail old) {
    super.didUpdateWidget(old);
    if (old.location != widget.location) _bytes = _load();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(galleryImagesProvider, (_, images) {
      runOutsideBuild(() {
        if (!mounted) return;
        setState(() {
          _bytes = images.thumbnail(widget.location);
        });
      });
    });
    return FutureBuilder<Uint8List?>(
      future: _bytes,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes != null) {
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.low,
            excludeFromSemantics: true,
            errorBuilder: (context, _, _) =>
                EmptyFrame(colors: widget.colors, label: widget.missingLabel),
          );
        }
        if (snapshot.connectionState == ConnectionState.done) {
          return EmptyFrame(colors: widget.colors, label: widget.missingLabel);
        }
        return EmptyFrame(colors: widget.colors);
      },
    );
  }
}
