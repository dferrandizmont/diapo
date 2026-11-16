import 'dart:io';

import 'package:flutter/painting.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_database.dart';
import '../platform/gallery_images.dart';
import 'contact_sheet_image.dart';

/// Paints a contact sheet and writes it to a file in the cache. The real one
/// is [renderContactSheet]; the tests replace it.
typedef ContactSheetRenderer = Future<File> Function({
  required List<ContactSheetFrame> frames,
  required String filmName,
  String? rollName,
  required Color bandColor,
  required DateTime date,
  required Directory cache,
});

/// The renderer the share preview uses. Overridden in the tests.
final contactSheetRendererProvider = Provider<ContactSheetRenderer>(
  (ref) => renderContactSheet,
);

/// The frames of the sheet of a developed roll, by their original place in the
/// roll: each photo keeps its frame number (or its place in the list when it
/// has none, as the contact sheet of the screen numbers them), and a frame
/// whose row is gone (the photo was deleted from the app) stays on the sheet as
/// an empty cell with its number.
///
/// Gaps in the numbering are filled from frame 1 up to the last photo that is
/// left, but never beyond [rollLength] (the frames of the roll), so a damaged
/// number cannot grow the sheet. A deleted frame after the last photo that is
/// left cannot be told from a roll that was closed early: the database keeps
/// no count of the photos taken, only the frames the roll could hold, so those
/// trailing frames are not drawn.
///
/// A frame whose photo failed to develop or has no place in the gallery is a
/// [ContactSheetFrame.missing]. A photo the user deleted from the gallery
/// meanwhile is read as nothing when its turn comes, and the renderer leaves
/// that frame empty too. Each photo is read through [gallery] only when the
/// renderer asks for it, so one is in memory at a time.
List<ContactSheetFrame> contactSheetFrames(
  List<ShotRow> shots,
  GalleryImages gallery, {
  required int rollLength,
}) {
  final frames = <ContactSheetFrame>[];
  var next = 1;
  for (var i = 0; i < shots.length; i++) {
    final shot = shots[i];
    final number = shot.frameNumber ?? i + 1;
    // The frames that were taken in between and no longer have a row.
    while (next < number && next <= rollLength) {
      frames.add(ContactSheetFrame.missing(next++));
    }
    if (shot.developFailure != null || shot.galleryUri == null) {
      frames.add(ContactSheetFrame.missing(number));
    } else {
      final uri = shot.galleryUri!;
      frames.add(
        ContactSheetFrame(number: number, load: () => gallery.full(uri)),
      );
    }
    if (number >= next) next = number + 1;
  }
  return frames;
}

/// Whether [shots] has at least one photo to put on a sheet.
bool hasSharableFrames(List<ShotRow> shots) =>
    shots.any((s) => s.developFailure == null && s.galleryUri != null);

/// Deletes a rendered sheet that was never handed to another app. Best effort:
/// a file that is still in use goes at the next app start
/// ([cleanContactSheets]). A sheet that was shared is not deleted by the app
/// while it runs: the receiver may still be reading it.
Future<void> deleteContactSheet(File file) async {
  try {
    if (await file.exists()) await file.delete();
  } on FileSystemException {
    // The next start sweeps the folder.
  }
}
