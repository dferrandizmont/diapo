import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../capture/capture_providers.dart';
import '../../capture/error_log.dart';
import '../../core/database/app_database.dart';
import '../../core/l10n/localized_text.dart';
import '../../l10n/app_localizations.dart';
import '../../platform/gallery_images.dart';
import '../../platform/photo_actions.dart';
import '../../render/film_resources.dart';
import '../../review/review_service.dart';
import '../../roll/contact_sheet_share.dart';
import '../../ui/theme/carrete_tokens.dart';
import '../viewfinder/viewfinder_state.dart';
import 'roll_parts.dart';

/// Opens the preview of the contact sheet of a developed roll, with the keys
/// that share it or leave. It renders the sheet when it opens and deletes the
/// file when it closes, unless the file was shared (see
/// [ContactSheetSharePreview]).
Future<void> showContactSheetShare(
  BuildContext context, {
  required RollRow roll,
  required List<ShotRow> shots,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => ContactSheetSharePreview(roll: roll, shots: shots),
    ),
  );
}

/// The preview of the shareable contact sheet: a progress state while it is
/// painted, the picture (scrollable) once it is ready, and an error state with
/// a retry. "Share" opens the share sheet of the system; "Cancel" closes.
///
/// The sheet is a plaintext copy of the user's photos in the cache. A sheet
/// that was never shared is deleted when the preview closes (and so is the one
/// a retry replaces). One that was handed to the share sheet is not: sharing
/// returns when the system menu opens, not when the receiving app has read the
/// file, so it stays in the cache until the next app start, which sweeps the
/// whole folder (`cleanStartupTemps`).
class ContactSheetSharePreview extends ConsumerStatefulWidget {
  const ContactSheetSharePreview({
    required this.roll,
    required this.shots,
    super.key,
  });

  final RollRow roll;

  /// The frames of the roll, in order.
  final List<ShotRow> shots;

  @override
  ConsumerState<ContactSheetSharePreview> createState() =>
      _ContactSheetSharePreviewState();
}

class _ContactSheetSharePreviewState
    extends ConsumerState<ContactSheetSharePreview> {
  /// Null while the sheet is painting; the file once it is ready.
  File? _file;
  bool _failed = false;
  bool _started = false;
  bool _closed = false;
  bool _sharing = false;
  bool _shareFailed = false;

  /// What is still opening the share sheet.
  Future<bool>? _share;

  /// The files that were handed to the share sheet. The app never deletes
  /// them while it runs: the receiver may still be reading one.
  final Set<String> _shared = <String>{};

  /// The painting that is in flight; a retry never runs two at a time.
  int _attempt = 0;

  late final PhotoActions _actions = ref.read(photoActionsProvider);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    unawaited(_render());
  }

  @override
  void dispose() {
    _closed = true;
    final file = _file;
    if (file != null) unawaited(_discard(file));
    super.dispose();
  }

  /// Deletes a sheet of this preview that nobody else may be reading: one that
  /// was shared stays for the sweep of the next start.
  Future<void> _discard(File file) async {
    if (_shared.contains(file.path)) return;
    await deleteContactSheet(file);
  }

  Future<void> _render() async {
    final attempt = ++_attempt;
    // The sheet a retry replaces (one that could not be read, say) goes now.
    final replaced = _file;
    if (replaced != null) unawaited(_discard(replaced));
    setState(() {
      _file = null;
      _failed = false;
    });
    // Everything the painter needs from the context is read before any wait.
    final languageCode = Localizations.localeOf(context).languageCode;
    final renderer = ref.read(contactSheetRendererProvider);
    final gallery = ref.read(galleryImagesProvider);
    final cache = ref.read(cacheDirectoryProvider);
    final roll = widget.roll;
    try {
      final book = await ref.read(recipeBookProvider.future);
      final film = book.byId(roll.filmId);
      final file = await renderer(
        frames: contactSheetFrames(
          widget.shots,
          gallery,
          rollLength: roll.length,
        ),
        filmName: film?.name.forLanguage(languageCode) ?? roll.filmId,
        rollName: roll.name,
        bandColor: film == null ? CarreteColors.bwBand : filmBandColor(film),
        date: DateTime.fromMillisecondsSinceEpoch(
          roll.developedAt ?? roll.closedAt ?? roll.createdAt,
        ),
        cache: cache,
      );
      if (_closed || attempt != _attempt) {
        // The preview went away (or a retry took over) while it was painting;
        // nobody has seen this file, let alone shared it.
        await deleteContactSheet(file);
        return;
      }
      setState(() => _file = file);
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('Contact sheet failed: ${errorLogToken(error)}');
      }
      if (!_closed && attempt == _attempt) setState(() => _failed = true);
    }
  }

  Future<void> _shareNow() async {
    final file = _file;
    if (file == null || _sharing) return;
    // Read before the waits: the screen may be gone when the share returns.
    final review = ref.read(reviewServiceProvider);
    setState(() {
      _sharing = true;
      _shareFailed = false;
    });
    // From here on the system may read the file: it is not deleted by the app.
    // A file that was already protected by an earlier, successful share stays
    // protected for good: only the provisional protection added by this attempt
    // may be withdrawn when this attempt fails.
    final alreadyProtected = _shared.contains(file.path);
    if (!alreadyProtected) _shared.add(file.path);
    final share = _actions.shareFile(file.path);
    _share = share;
    var shared = false;
    try {
      shared = await share;
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('Sharing the sheet failed: ${errorLogToken(error)}');
      }
    }
    if (identical(_share, share)) _share = null;
    // A menu that never opened read nothing: the file is the preview's again,
    // unless an earlier share already handed it to the system.
    if (!shared && !alreadyProtected) {
      _shared.remove(file.path);
      if (_closed) unawaited(deleteContactSheet(file));
    }
    // A success moment: the sheet was handed to the system. One call that
    // never blocks and swallows every error, whatever happens to this screen.
    if (shared) {
      unawaited(review.maybeAskAfterSuccess());
    }
    if (!mounted) return;
    setState(() {
      _sharing = false;
      _shareFailed = !shared;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = CarretePalette.of(context);
    final tone = RollTone(palette);
    final ready = _file != null;
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: CarreteRoll.bodyMaxWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                CarreteSpacing.margin,
                CarreteSpacing.s,
                CarreteSpacing.margin,
                CarreteSpacing.m,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // The header, the notes and the keys grow with the text
                  // size; the preview never gets less than its minimum. When
                  // the screen cannot hold both (a big text size, the phone
                  // on its side) the whole page scrolls and the keys stay one
                  // scroll away; when there is room, the preview takes it.
                  final scale = MediaQuery.textScalerOf(context).scale(1);
                  final room =
                      CarreteRoll.sharePreviewMinHeight +
                      CarreteRoll.shareChromeHeight * scale;
                  final scrolls = constraints.maxHeight < room;
                  final body = _body(l10n, palette, tone);
                  final children = <Widget>[
                    RollHeader(
                      title: l10n.rollShareSheetAction,
                      subtitle: null,
                      palette: palette,
                    ),
                    const SizedBox(height: CarreteSpacing.m),
                    if (scrolls)
                      SizedBox(
                        height: CarreteRoll.sharePreviewMinHeight,
                        child: body,
                      )
                    else
                      Expanded(child: body),
                    const SizedBox(height: CarreteSpacing.m),
                    if (_shareFailed)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: CarreteSpacing.s,
                        ),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            l10n.rollShareSheetFailed,
                            key: const ValueKey('sheet-share-failed'),
                            textAlign: TextAlign.center,
                            style: CarreteText.note(tone.warn),
                          ),
                        ),
                      ),
                    RollWideKey(
                      key: const ValueKey('sheet-share-key'),
                      palette: palette,
                      label: l10n.viewerShare,
                      onPressed: ready && !_sharing
                          ? () => unawaited(_shareNow())
                          : null,
                    ),
                    const SizedBox(height: CarreteSpacing.s),
                    RollWideKey(
                      key: const ValueKey('sheet-cancel-key'),
                      palette: palette,
                      label: l10n.dialogCancel,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ];
                  final column = Column(
                    mainAxisSize: scrolls ? MainAxisSize.min : MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  );
                  return scrolls
                      ? SingleChildScrollView(child: column)
                      : column;
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(AppLocalizations l10n, CarretePalette palette, RollTone tone) {
    final file = _file;
    if (file != null) {
      return Semantics(
        container: true,
        image: true,
        label: l10n.rollShareSheetPreview(
          widget.roll.id.toString().padLeft(2, '0'),
        ),
        child: Scrollbar(
          child: SingleChildScrollView(
            child: Image.file(
              file,
              key: const ValueKey('sheet-preview'),
              fit: BoxFit.fitWidth,
              filterQuality: FilterQuality.medium,
              excludeFromSemantics: true,
              errorBuilder: (context, _, _) => _message(
                l10n.rollShareSheetError,
                tone,
                retry: l10n.cameraRetry,
              ),
            ),
          ),
        ),
      );
    }
    if (_failed) {
      return _message(l10n.rollShareSheetError, tone, retry: l10n.cameraRetry);
    }
    return Center(
      child: Semantics(
        container: true,
        liveRegion: true,
        label: l10n.rollShareSheetRendering,
        excludeSemantics: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: CarreteRoll.shareSpinner,
              child: CircularProgressIndicator(
                key: const ValueKey('sheet-rendering'),
                strokeWidth: CarreteRoll.shareSpinnerStroke,
                color: tone.active,
              ),
            ),
            const SizedBox(height: CarreteSpacing.m),
            Text(
              l10n.rollShareSheetRendering,
              textAlign: TextAlign.center,
              style: tone.note,
            ),
          ],
        ),
      ),
    );
  }

  /// A message with a retry key, in the place of the picture.
  Widget _message(String text, RollTone tone, {required String retry}) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                text,
                key: const ValueKey('sheet-error'),
                textAlign: TextAlign.center,
                // The same warning colour as the note of a share that failed.
                style: CarreteText.pageTitle(tone.warn),
              ),
            ),
            const SizedBox(height: CarreteSpacing.m),
            RollWideKey(
              key: const ValueKey('sheet-retry-key'),
              palette: tone.palette,
              label: retry,
              onPressed: () => unawaited(_render()),
            ),
          ],
        ),
      ),
    );
  }
}
