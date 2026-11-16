import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/localized_text.dart';
import '../../gallery/photo_library.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/gallery_images.dart';
import '../../platform/photo_actions.dart';
import '../../render/film_resources.dart';
import '../../ui/theme/carrete_tokens.dart';
import '../../ui/widgets/carrete_icon.dart';
import '../../ui/widgets/plastic_key.dart';
import 'roll_parts.dart';

/// One photo of the viewer.
class ViewerFrame {
  const ViewerFrame({
    required this.number,
    required this.location,
    this.shotId,
    this.filmId,
    this.takenAt,
  });

  /// The number of the frame in the roll.
  final int number;

  /// The `galleryUri` of the photo.
  final String location;

  /// The row of the photo in the database. Without it the viewer only shows
  /// the photo: it can neither share nor delete it.
  final int? shotId;

  /// The film of the photo, shown under it.
  final String? filmId;

  /// When the photo was taken, shown under it.
  final DateTime? takenAt;
}

/// A simple viewer: a photo full size on black, swipe for the next one, a key
/// to go back, and under the photo its film and date with the keys to share
/// and to delete it. It is always dark.
class FrameViewer extends ConsumerStatefulWidget {
  const FrameViewer({
    required this.frames,
    required this.initialIndex,
    super.key,
  });

  /// The photos, in order.
  final List<ViewerFrame> frames;

  /// The photo that opens first.
  final int initialIndex;

  @override
  ConsumerState<FrameViewer> createState() => _FrameViewerState();
}

class _FrameViewerState extends ConsumerState<FrameViewer> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late final List<ViewerFrame> _frames = [...widget.frames];
  late int _index = widget.initialIndex;
  bool _busy = false;
  String? _notice;
  Timer? _noticeTimer;

  @override
  void dispose() {
    _noticeTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _showNotice(String message) {
    _noticeTimer?.cancel();
    setState(() => _notice = message);
    _noticeTimer = Timer(CarreteDurations.notice, () {
      if (mounted) setState(() => _notice = null);
    });
  }

  Future<void> _share(ViewerFrame frame) async {
    if (_busy) return;
    final library = ref.read(photoLibraryProvider);
    final failed = AppLocalizations.of(context).viewerActionFailed;
    setState(() => _busy = true);
    var shared = false;
    try {
      shared = await library.share(frame.location);
    } on Object {
      shared = false;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (!shared) _showNotice(failed);
  }

  Future<void> _delete(ViewerFrame frame) async {
    final id = frame.shotId;
    if (_busy || id == null) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmRollAction(
      context,
      title: l10n.viewerDeleteTitle,
      body: l10n.viewerDeleteBody,
      confirmLabel: l10n.viewerDeleteConfirm,
      cancelLabel: l10n.dialogCancel,
    );
    if (!confirmed || !mounted) return;
    final library = ref.read(photoLibraryProvider);
    setState(() => _busy = true);
    PhotoDeletion outcome;
    try {
      outcome = await library.delete(id, frame.location);
    } on Object {
      outcome = PhotoDeletion.failed;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    switch (outcome) {
      case PhotoDeletion.deleted:
      case PhotoDeletion.gone:
        _remove(frame);
      case PhotoDeletion.deletedKeptOriginal:
        // The last photo closes the viewer: the notice goes to the screen the
        // user returns to (see [FrameViewer]), not to one that is leaving.
        if (!_remove(frame, closeWith: outcome)) {
          _showNotice(l10n.viewerOriginalKept);
        }
      case PhotoDeletion.cancelled:
        break;
      case PhotoDeletion.failed:
        _showNotice(l10n.viewerActionFailed);
    }
  }

  /// Takes a deleted photo out of the viewer; the last one closes it, handing
  /// [closeWith] to the screen that opened the viewer. True when it closed.
  bool _remove(ViewerFrame frame, {PhotoDeletion? closeWith}) {
    final at = _frames.indexOf(frame);
    if (at < 0) return false;
    if (_frames.length == 1) {
      unawaited(Navigator.of(context).maybePop(closeWith));
      return true;
    }
    setState(() {
      _frames.removeAt(at);
      if (_index >= _frames.length) _index = _frames.length - 1;
    });
    // The page the controller sits on may be past the end now.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      if (_controller.page?.round() != _index) _controller.jumpToPage(_index);
    });
    return false;
  }

  /// The film and the day and time of [frame], on one line.
  String _info(BuildContext context, ViewerFrame frame) {
    final book = ref.watch(recipeBookProvider).value;
    final id = frame.filmId;
    final film = id == null ? null : (book?.byId(id)?.name.of(context) ?? id);
    final taken = frame.takenAt;
    String? when;
    if (taken != null) {
      final material = MaterialLocalizations.of(context);
      final time = material.formatTimeOfDay(
        TimeOfDay.fromDateTime(taken),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      );
      when = '${material.formatMediumDate(taken)} $time';
    }
    return [?film, ?when].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final total = _frames.length;
    final padding = MediaQuery.paddingOf(context);
    final current = _frames[_index];
    final info = _info(context, current);
    final canAct = current.shotId != null;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: CarreteColors.viewfinder,
        body: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: total,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => Semantics(
                container: true,
                label: l10n.viewerSemantics(i + 1, total),
                child: _Photo(
                  key: ValueKey(_frames[i].location),
                  location: _frames[i].location,
                ),
              ),
            ),
            Positioned(
              left: CarreteSpacing.margin,
              right: CarreteSpacing.margin,
              top: padding.top + CarreteSpacing.s,
              child: Row(
                children: [
                  PlasticKey(
                    semanticLabel: MaterialLocalizations.of(context)
                        .backButtonTooltip,
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const CarreteIconView(icon: CarreteIcon.back),
                  ),
                  const Spacer(),
                  _Pill(
                    child: ExcludeSemantics(
                      child: Text(
                        l10n.viewerPosition(_index + 1, total),
                        style: CarreteText.hint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_notice != null)
              Positioned(
                left: CarreteSpacing.margin,
                right: CarreteSpacing.margin,
                top: padding.top + CarreteRoll.viewerNoticeTop,
                child: Semantics(
                  liveRegion: true,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: CarreteColors.notice,
                      borderRadius: BorderRadius.circular(CarreteRadii.key),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(CarreteSpacing.m),
                      child: Text(
                        _notice!,
                        textAlign: TextAlign.center,
                        style: CarreteText.notice,
                      ),
                    ),
                  ),
                ),
              ),
            if (info.isNotEmpty || canAct)
              Positioned(
                left: CarreteSpacing.margin,
                right: CarreteSpacing.margin,
                bottom: padding.bottom + CarreteSpacing.s,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: info.isEmpty
                            ? const SizedBox.shrink()
                            : _Pill(
                                child: Semantics(
                                  container: true,
                                  label: info,
                                  excludeSemantics: true,
                                  child: Text(info, style: CarreteText.hint),
                                ),
                              ),
                      ),
                    ),
                    if (canAct) ...[
                      const SizedBox(width: CarreteSpacing.s),
                      PlasticKey(
                        key: const ValueKey('viewer-share'),
                        semanticLabel: l10n.viewerShare,
                        onPressed: _busy
                            ? null
                            : () => unawaited(_share(current)),
                        child: const CarreteIconView(icon: CarreteIcon.share),
                      ),
                      const SizedBox(width: CarreteSpacing.s),
                      PlasticKey(
                        key: const ValueKey('viewer-delete'),
                        semanticLabel: l10n.viewerDelete,
                        onPressed: _busy
                            ? null
                            : () => unawaited(_delete(current)),
                        child: const CarreteIconView(icon: CarreteIcon.trash),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The little dark label over the photo.
class _Pill extends StatelessWidget {
  const _Pill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CarreteColors.pill,
        borderRadius: BorderRadius.circular(CarreteRadii.key),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CarreteSizes.pillInsetH,
          vertical: CarreteSizes.pillInsetV,
        ),
        child: child,
      ),
    );
  }
}

/// The photo of a page: read whole from the gallery and decoded no bigger
/// than [CarreteRoll.viewerExtent], so a 24 MP photo does not fill memory.
class _Photo extends ConsumerStatefulWidget {
  const _Photo({required this.location, super.key});

  final String location;

  @override
  ConsumerState<_Photo> createState() => _PhotoState();
}

class _PhotoState extends ConsumerState<_Photo> {
  late Future<Uint8List?> _bytes = ref
      .read(galleryImagesProvider)
      .full(widget.location);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    ref.listen(galleryImagesProvider, (_, images) {
      setState(() {
        _bytes = images.full(widget.location);
      });
    });
    return FutureBuilder<Uint8List?>(
      future: _bytes,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes != null) {
          return SizedBox.expand(
            child: Image(
              image: ResizeImage(
                MemoryImage(bytes),
                width: CarreteRoll.viewerExtent,
                height: CarreteRoll.viewerExtent,
                policy: ResizeImagePolicy.fit,
              ),
              fit: BoxFit.contain,
              gaplessPlayback: true,
              excludeFromSemantics: true,
              errorBuilder: (context, _, _) => _Unavailable(l10n: l10n),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.done) {
          return _Unavailable(l10n: l10n);
        }
        return const SizedBox.expand();
      },
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(CarreteSpacing.xl),
        child: Text(
          l10n.viewerUnavailable,
          textAlign: TextAlign.center,
          style: CarreteText.message,
        ),
      ),
    );
  }
}
