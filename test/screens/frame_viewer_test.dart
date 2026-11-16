import 'dart:typed_data';

import 'package:diapo/gallery/photo_library.dart';
import 'package:diapo/platform/photo_actions.dart';
import 'package:diapo/screens/roll/frame_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/roll_fakes.dart';
import '../support/roll_harness.dart';

final _taken = DateTime(2026, 11, 13, 9, 30);

List<ViewerFrame> _frames(int count, {bool withRows = true}) => [
  for (var i = 1; i <= count; i++)
    ViewerFrame(
      number: i,
      location: 'content://media/$i',
      shotId: withRows ? i : null,
      filmId: withRows ? 'alpha' : null,
      takenAt: withRows ? _taken : null,
    ),
];

/// A home with a button that opens the viewer, so closing it can be seen.
Future<FakePhotoLibrary> _pump(
  WidgetTester tester, {
  int count = 3,
  bool withRows = true,
  Map<String, Uint8List>? photos,
  int initial = 0,
}) async {
  final library = FakePhotoLibrary();
  await pumpRollApp(
    tester,
    Builder(
      builder: (context) => TextButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => FrameViewer(
              frames: _frames(count, withRows: withRows),
              initialIndex: initial,
            ),
          ),
        ),
        child: const Text('open viewer'),
      ),
    ),
    overrides: [
      ...rollOverrides(
        gallery: FakeGalleryImages(
          photos ??
              {for (var i = 1; i <= count; i++) 'content://media/$i': tinyPng},
        ),
      ),
      photoLibraryProvider.overrideWithValue(library),
    ],
  );
  await tester.tap(find.text('open viewer'));
  await tester.pumpAndSettle();
  return library;
}

final _share = find.byKey(const ValueKey('viewer-share'));
final _delete = find.byKey(const ValueKey('viewer-delete'));

void main() {
  group('under the photo', () {
    testWidgets('shows its film and the day and time it was taken', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.textContaining('Alpha'), findsOneWidget);
      expect(find.textContaining('Nov 13'), findsOneWidget);
      expect(find.textContaining('9:30'), findsOneWidget);
    });

    testWidgets('follows the photo that is on screen', (tester) async {
      await _pump(tester, count: 2);
      expect(find.text('1 of 2'), findsOneWidget);

      await tester.fling(find.byType(PageView), const Offset(-400, 0), 2000);
      await tester.pumpAndSettle();

      expect(find.text('2 of 2'), findsOneWidget);
    });

    testWidgets('has a key to share and a key to delete, both labelled', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.bySemanticsLabel('Share'), findsOneWidget);
      expect(find.bySemanticsLabel('Delete'), findsOneWidget);
      expect(tester.getSize(_share).width, greaterThanOrEqualTo(44));
      expect(tester.getSize(_delete).height, greaterThanOrEqualTo(44));
    });

    testWidgets('a photo with no row can be seen but not shared or deleted', (
      tester,
    ) async {
      await _pump(tester, withRows: false);

      expect(find.text('1 of 3'), findsOneWidget);
      expect(_share, findsNothing);
      expect(_delete, findsNothing);
    });
  });

  group('share', () {
    testWidgets('hands the photo on screen to the system', (tester) async {
      final library = await _pump(tester, initial: 1);

      await tester.tap(_share);
      await tester.pumpAndSettle();

      expect(library.shared, ['content://media/2']);
      expect(find.text('That did not work. Try again.'), findsNothing);
    });

    testWidgets('says so when the system could not share it', (tester) async {
      final library = await _pump(tester);
      library.shares = false;

      await tester.tap(_share);
      await tester.pump();
      await tester.pump();

      expect(find.text('That did not work. Try again.'), findsOneWidget);
      // The notice goes away by itself.
      await tester.pump(const Duration(seconds: 4));
      expect(find.text('That did not work. Try again.'), findsNothing);
    });
  });

  group('delete', () {
    testWidgets('asks first, and keeping the photo changes nothing', (
      tester,
    ) async {
      final library = await _pump(tester);

      await tester.tap(_delete);
      await tester.pumpAndSettle();
      expect(find.text('Delete this photo?'), findsOneWidget);
      expect(find.textContaining('cannot be undone'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(library.deleted, isEmpty);
      expect(find.text('1 of 3'), findsOneWidget);
    });

    testWidgets('confirming deletes it and moves to the next photo', (
      tester,
    ) async {
      final library = await _pump(tester);

      await tester.tap(_delete);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(library.deleted, [(1, 'content://media/1')]);
      expect(find.text('1 of 2'), findsOneWidget);
    });

    testWidgets('deleting the last photo of the list leaves the one before', (
      tester,
    ) async {
      final library = await _pump(tester, count: 2, initial: 1);
      expect(find.text('2 of 2'), findsOneWidget);

      await tester.tap(_delete);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(library.deleted, [(2, 'content://media/2')]);
      expect(find.text('1 of 1'), findsOneWidget);
      expect(find.byType(FrameViewer), findsOneWidget);
    });

    testWidgets('deleting the only photo closes the viewer', (tester) async {
      await _pump(tester, count: 1);

      await tester.tap(_delete);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.byType(FrameViewer), findsNothing);
      expect(find.text('open viewer'), findsOneWidget);
    });

    testWidgets('a photo the user already deleted can be cleared away', (
      tester,
    ) async {
      final library = await _pump(tester, count: 2, photos: {});
      library.deletion = PhotoDeletion.gone;
      expect(find.text('The photo cannot be shown.'), findsOneWidget);

      await tester.tap(_delete);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('1 of 1'), findsOneWidget);
    });

    testWidgets('a photo whose original stayed behind goes, with a notice', (
      tester,
    ) async {
      final library = await _pump(tester, count: 2);
      library.deletion = PhotoDeletion.deletedKeptOriginal;

      await tester.tap(_delete);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pump();
      await tester.pump();

      expect(find.text('1 of 1'), findsOneWidget);
      expect(
        find.text(
          'Photo deleted, but its original is still in '
          'Pictures/Diapo/Originales.',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'deleting the last photo hands the notice to the screen it returns to',
      (tester) async {
        PhotoDeletion? returned = PhotoDeletion.failed;
        final library = FakePhotoLibrary()
          ..deletion = PhotoDeletion.deletedKeptOriginal;
        await pumpRollApp(
          tester,
          Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                returned = await Navigator.of(context).push(
                  MaterialPageRoute<PhotoDeletion>(
                    builder: (_) =>
                        FrameViewer(frames: _frames(1), initialIndex: 0),
                  ),
                );
              },
              child: const Text('open viewer'),
            ),
          ),
          overrides: [
            ...rollOverrides(
              gallery: FakeGalleryImages({'content://media/1': tinyPng}),
            ),
            photoLibraryProvider.overrideWithValue(library),
          ],
        );
        await tester.tap(find.text('open viewer'));
        await tester.pumpAndSettle();

        await tester.tap(_delete);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        expect(find.byType(FrameViewer), findsNothing);
        expect(returned, PhotoDeletion.deletedKeptOriginal);
        // Not shown on the viewer that was closing.
        expect(find.textContaining('still in'), findsNothing);
      },
    );

    testWidgets('refusing the dialog of the system keeps the photo', (
      tester,
    ) async {
      final library = await _pump(tester);
      library.deletion = PhotoDeletion.cancelled;

      await tester.tap(_delete);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('1 of 3'), findsOneWidget);
      expect(find.text('That did not work. Try again.'), findsNothing);
    });

    testWidgets('a delete that fails keeps the photo and says so', (
      tester,
    ) async {
      final library = await _pump(tester);
      library.deletion = PhotoDeletion.failed;

      await tester.tap(_delete);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pump();
      await tester.pump();

      expect(find.text('1 of 3'), findsOneWidget);
      expect(find.text('That did not work. Try again.'), findsOneWidget);
    });
  });
}
