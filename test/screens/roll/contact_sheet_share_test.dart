import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:carrete/capture/capture_providers.dart';
import 'package:carrete/core/database/app_database.dart';
import 'package:carrete/core/database/tables.dart';
import 'package:carrete/platform/photo_actions.dart';
import 'package:carrete/roll/contact_sheet_image.dart';
import 'package:carrete/roll/contact_sheet_share.dart';
import 'package:carrete/screens/roll/roll_screen.dart';
import 'package:carrete/screens/viewfinder/viewfinder_state.dart';
import 'package:carrete/screens/roll/roll_parts.dart';
import 'package:carrete/ui/theme/carrete_tokens.dart';
import 'package:carrete/ui/widgets/plastic_key.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart';
import '../../support/import_fakes.dart';
import '../../support/review_fakes.dart';
import '../../support/roll_fakes.dart';
import '../../support/roll_harness.dart';

/// Writes a small image to a temp folder, the way the renderer writes a
/// sheet, and records what it was asked to paint.
class _Renderer {
  _Renderer() : dir = Directory.systemTemp.createTempSync('sheet-share-test');

  final Directory dir;
  final List<_Call> calls = <_Call>[];

  /// The next render waits for this when it is set.
  Completer<void>? gate;

  /// The next render fails with this when it is set.
  Object? error;

  /// What the files hold; an image that cannot be read, say.
  Uint8List bytes = tinyPng;
  final List<File> files = <File>[];

  Future<File> call({
    required List<ContactSheetFrame> frames,
    required String filmName,
    String? rollName,
    required Color bandColor,
    required DateTime date,
    required Directory cache,
  }) async {
    calls.add(_Call(frames, filmName, bandColor, date, cache, rollName));
    await gate?.future;
    final failure = error;
    if (failure != null) throw failure;
    final file = File('${dir.path}/sheet-${files.length}.png')
      ..writeAsBytesSync(bytes);
    files.add(file);
    return file;
  }
}

class _Call {
  _Call(
    this.frames,
    this.filmName,
    this.bandColor,
    this.date,
    this.cache,
    this.rollName,
  );

  final List<ContactSheetFrame> frames;
  final String filmName;
  final String? rollName;
  final Color bandColor;
  final DateTime date;
  final Directory cache;
}

class _Actions extends FakePhotoActions {
  final List<String> sharedFiles = <String>[];
  bool opens = true;

  /// The next share waits for this when it is set.
  Completer<void>? gate;

  /// When it is not empty, every share takes the next answer of this list
  /// instead of [opens].
  final List<bool> answers = <bool>[];

  @override
  Future<bool> shareFile(String path) async {
    sharedFiles.add(path);
    await gate?.future;
    if (answers.isNotEmpty) return answers.removeAt(0);
    return opens;
  }
}

final _developedAt = DateTime(2026, 11, 14, 9);
final _developed = rollRow(
  state: RollState.developed,
  closedAt: DateTime(2026, 11, 13, 12).millisecondsSinceEpoch,
  developedAt: _developedAt.millisecondsSinceEpoch,
);
final _shots = [
  shotRow(1, galleryUri: 'content://media/1'),
  shotRow(2, galleryUri: 'content://media/2'),
  shotRow(3, failure: 'vault_corrupt'),
  shotRow(4, galleryUri: 'content://media/deleted'),
  shotRow(5),
  shotRow(6, galleryUri: 'content://media/6'),
];

final _shareKey = find.byKey(const ValueKey('share-sheet-key'));
final _previewShare = find.byKey(const ValueKey('sheet-share-key'));
final _previewCancel = find.byKey(const ValueKey('sheet-cancel-key'));

bool _enabled(WidgetTester tester, Finder key) =>
    tester
        .widget<PlasticKey>(
          find.descendant(of: key, matching: find.byType(PlasticKey)),
        )
        .onPressed !=
    null;

void main() {
  late _Renderer renderer;
  late _Actions actions;
  late FakeGalleryImages gallery;

  setUp(() {
    renderer = _Renderer();
    actions = _Actions();
    gallery = FakeGalleryImages({
      'content://media/1': tinyPng,
      'content://media/2': tinyPng,
      'content://media/6': tinyPng,
    });
  });
  tearDown(() {
    if (renderer.dir.existsSync()) renderer.dir.deleteSync(recursive: true);
  });

  Future<void> pump(
    WidgetTester tester, {
    RollRow? roll,
    List<ShotRow>? shots,
    Size size = const Size(412, 915),
    List<Override> review = const [],
  }) async {
    final row = roll ?? _developed;
    await pumpRollApp(
      tester,
      RollScreen(id: '${row.id}'),
      size: size,
      overrides: [
        ...rollOverrides(
          rolls: [row],
          shots: {row.id: shots ?? _shots},
          gallery: gallery,
        ),
        photoActionsProvider.overrideWithValue(actions),
        contactSheetRendererProvider.overrideWithValue(renderer.call),
        cacheDirectoryProvider.overrideWithValue(renderer.dir),
        ...review,
      ],
    );
    await tester.pumpAndSettle();
  }

  /// Gives the real file operations (the image reading the file, the preview
  /// deleting it) time to finish: they run on the real clock, one step per
  /// turn, and the test's clock only moves them when it is pumped.
  Future<void> settleFiles(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump();
    }
  }

  group('the action', () {
    testWidgets('is on a developed roll that has photos', (tester) async {
      await pump(tester);
      expect(find.text('Share contact sheet'), findsOneWidget);
      expect(_shareKey, findsOneWidget);
      // Opening the screen paints nothing yet.
      expect(renderer.calls, isEmpty);
    });

    testWidgets('is not on a developed roll with no photo left', (
      tester,
    ) async {
      await pump(
        tester,
        shots: [
          shotRow(1),
          shotRow(2, failure: 'x'),
        ],
      );
      expect(find.text('Share contact sheet'), findsNothing);
    });

    for (final state in [
      RollState.open,
      RollState.developing,
      RollState.lost,
      RollState.discarded,
    ]) {
      testWidgets('is never on a ${state.name} roll', (tester) async {
        await pump(
          tester,
          roll: rollRow(
            state: state,
            closedAt: 1,
            developAt: DateTime(2030).millisecondsSinceEpoch,
          ),
          // Even if the rows already hold photos.
          shots: [shotRow(1, galleryUri: 'content://media/1')],
        );
        expect(find.text('Share contact sheet'), findsNothing);
        expect(_shareKey, findsNothing);
      });
    }
  });

  group('the preview', () {
    testWidgets('shows a progress state while the sheet is painted', (
      tester,
    ) async {
      renderer.gate = Completer<void>();
      await pump(tester);
      await tester.tap(_shareKey);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('sheet-rendering')), findsOneWidget);
      expect(find.text('Preparing the sheet'), findsOneWidget);
      expect(_enabled(tester, _previewShare), isFalse);
      // Leaving is always possible.
      expect(_enabled(tester, _previewCancel), isTrue);

      renderer.gate!.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('sheet-rendering')), findsNothing);
      expect(find.byKey(const ValueKey('sheet-preview')), findsOneWidget);
      expect(_enabled(tester, _previewShare), isTrue);
      expect(
        find.bySemanticsLabel('Preview of the contact sheet of roll 07'),
        findsOneWidget,
      );
    });

    testWidgets('paints the frames of the roll in order, with their numbers', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(_shareKey);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final call = renderer.calls.single;
      expect([for (final f in call.frames) f.number], [1, 2, 3, 4, 5, 6]);
      // The failed frame and the one with no place in the gallery are empty;
      // the others read their photo, one at a time.
      expect(
        [for (final f in call.frames) f.load != null],
        [true, true, false, true, false, true],
      );
      expect(gallery.fullsAsked, isEmpty);
      expect(await call.frames[0].load!(), tinyPng);
      // A photo the user deleted from the gallery comes back empty.
      expect(await call.frames[3].load!(), isNull);
      expect(gallery.fullsAsked, [
        'content://media/1',
        'content://media/deleted',
      ]);
      // The film, its band, the date of the roll and the cache folder.
      expect(call.filmName, 'Alpha');
      expect(call.bandColor, filmBandColor(testBook().recipes.first));
      expect(call.date, _developedAt);
      expect(call.cache, renderer.dir);
    });

    testWidgets('hands the name of the roll to the sheet, when it has one', (
      tester,
    ) async {
      await pump(tester, roll: _developed.copyWith(name: const Value('Boda')));
      await tester.tap(_shareKey);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(renderer.calls.single.rollName, 'Boda');
    });

    testWidgets('hands no name to the sheet when the roll has none', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(_shareKey);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(renderer.calls.single.rollName, isNull);
    });

    testWidgets('says so when it fails, and tries again', (tester) async {
      renderer.error = StateError('no memory');
      await pump(tester);
      await tester.tap(_shareKey);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.text('The sheet could not be prepared. Try again.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('sheet-preview')), findsNothing);
      expect(_enabled(tester, _previewShare), isFalse);

      renderer.error = null;
      await tester.tap(find.byKey(const ValueKey('sheet-retry-key')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('sheet-error')), findsNothing);
      expect(find.byKey(const ValueKey('sheet-preview')), findsOneWidget);
      expect(renderer.calls, hasLength(2));
    });

    testWidgets('scrolls and reads at 2x on a small phone', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      renderer.error = StateError('no');
      await pump(tester, size: const Size(320, 568));
      await tester.tap(_shareKey);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('sheet-error')), findsOneWidget);
      // The keys are reachable: scrolled into view if they are not already.
      await tester.ensureVisible(_previewCancel);
      await tester.pump();
      expect(tester.getRect(_previewCancel).bottom, lessThanOrEqualTo(568.5));
    });

    for (final scenario in [
      (name: 'a short phone', size: const Size(360, 520), scale: 1.0),
      (
        name: 'a phone just above the limit',
        size: const Size(360, 510),
        scale: 1.0,
      ),
      (name: '1.3x text on a phone', size: const Size(360, 600), scale: 1.3),
      (name: '1.5x text on a phone', size: const Size(360, 720), scale: 1.5),
      (name: '2x text on a phone', size: const Size(360, 640), scale: 2.0),
      (name: 'a phone on its side', size: const Size(640, 360), scale: 1.0),
      (name: '2x text on its side', size: const Size(640, 360), scale: 2.0),
    ]) {
      testWidgets('keeps a minimum preview and scrolls: ${scenario.name}', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = scenario.scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pump(tester, size: scenario.size);
        await tester.tap(_shareKey);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
        final preview = find.byKey(const ValueKey('sheet-preview'));
        expect(preview, findsOneWidget);
        // The preview area is never squeezed below the token.
        final area = find.ancestor(
          of: preview,
          matching: find.byType(SingleChildScrollView),
        );
        expect(
          tester.getSize(area.first).height,
          greaterThanOrEqualTo(CarreteRoll.sharePreviewMinHeight),
        );
        // The keys are one scroll away, and work from there.
        await tester.ensureVisible(_previewCancel);
        await tester.pump();
        expect(tester.takeException(), isNull);
        final cancel = tester.getRect(_previewCancel);
        expect(cancel.bottom, lessThanOrEqualTo(scenario.size.height + 0.5));
        await tester.tap(_previewShare);
        await tester.pump();
        expect(actions.sharedFiles, hasLength(1));
      });
    }

    testWidgets('the error title and the share note use the warning colour', (
      tester,
    ) async {
      renderer.error = StateError('no');
      await pump(tester);
      await tester.tap(_shareKey);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      Color colorOf(String key) =>
          tester.widget<Text>(find.byKey(ValueKey(key))).style!.color!;
      final warn = RollTone(
        CarretePalette.of(
          tester.element(find.byKey(const ValueKey('sheet-error'))),
        ),
      ).warn;
      expect(colorOf('sheet-error'), warn);

      renderer.error = null;
      actions.opens = false;
      await tester.tap(find.byKey(const ValueKey('sheet-retry-key')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(_previewShare);
      await tester.pump();
      await tester.pump();
      expect(colorOf('sheet-share-failed'), warn);
    });
  });

  group('sharing', () {
    Future<void> open(WidgetTester tester) async {
      await pump(tester);
      await tester.tap(_shareKey);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('hands the file to the system and keeps the preview', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(_previewShare);
      await tester.pump();
      await tester.pump();
      expect(actions.sharedFiles, [renderer.files.single.path]);
      // Still there, and the file too, so it can be shared again.
      expect(find.byKey(const ValueKey('sheet-preview')), findsOneWidget);
      expect(renderer.files.single.existsSync(), isTrue);
      expect(find.byKey(const ValueKey('sheet-share-failed')), findsNothing);
    });

    testWidgets('says so when the share menu does not open', (tester) async {
      actions.opens = false;
      await open(tester);
      await tester.tap(_previewShare);
      await tester.pump();
      await tester.pump();
      expect(find.text('The share menu could not be opened.'), findsOneWidget);
      expect(_enabled(tester, _previewShare), isTrue);
    });

    testWidgets('a share that fails after a successful one keeps the file', (
      tester,
    ) async {
      // The first share opens the menu; the second one does not.
      actions.answers.addAll([true, false]);
      await open(tester);
      final file = renderer.files.single;
      await settleFiles(tester);

      await tester.tap(_previewShare);
      await tester.pump();
      await tester.pump();
      expect(actions.sharedFiles, [file.path]);
      expect(find.byKey(const ValueKey('sheet-share-failed')), findsNothing);

      // The second share of the same file fails: nothing read it.
      await tester.tap(_previewShare);
      await tester.pump();
      await tester.pump();
      expect(actions.sharedFiles, [file.path, file.path]);
      expect(find.text('The share menu could not be opened.'), findsOneWidget);

      // The preview closes: the file was already handed to the system, so
      // it stays for the receiver that may still be reading it.
      await tester.tap(_previewCancel);
      await tester.pumpAndSettle();
      await settleFiles(tester);
      expect(file.existsSync(), isTrue);
    });

    testWidgets('ignores a second tap while it opens', (tester) async {
      actions.gate = Completer<void>();
      await open(tester);
      await tester.tap(_previewShare);
      await tester.pump();
      expect(_enabled(tester, _previewShare), isFalse);
      actions.gate!.complete();
      await tester.pump();
      await tester.pump();
      expect(actions.sharedFiles, hasLength(1));
      expect(_enabled(tester, _previewShare), isTrue);
    });
  });

  group('the request for a review', () {
    late CountingStoreReview storeReview;
    late List<Override> review;

    setUp(() async {
      storeReview = CountingStoreReview();
      review = await reviewReadyOverrides(storeReview);
    });

    Future<void> open(WidgetTester tester) async {
      await pump(tester, review: review);
      await tester.tap(_shareKey);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await flushReview(tester);
    }

    testWidgets('is made only after a successful share', (tester) async {
      await open(tester);
      // Opening the screen, painting the sheet and showing it ask nothing.
      expect(storeReview.requests, 0);

      await tester.tap(_previewShare);
      await tester.pump();
      await tester.pump();
      await flushReview(tester);
      expect(storeReview.requests, 1);

      // The same sheet shared again: the version was already asked for.
      await tester.tap(_previewShare);
      await tester.pump();
      await tester.pump();
      await flushReview(tester);
      expect(storeReview.requests, 1);
    });

    testWidgets('is not made while the share menu is opening', (tester) async {
      actions.gate = Completer<void>();
      await open(tester);
      await tester.tap(_previewShare);
      await tester.pump();
      await flushReview(tester);
      expect(storeReview.requests, 0);
      actions.gate!.complete();
      await tester.pump();
      await tester.pump();
      await flushReview(tester);
      expect(storeReview.requests, 1);
    });

    testWidgets('is not made when the share menu does not open', (
      tester,
    ) async {
      actions.opens = false;
      await open(tester);
      await tester.tap(_previewShare);
      await tester.pump();
      await tester.pump();
      await flushReview(tester);
      expect(find.text('The share menu could not be opened.'), findsOneWidget);
      expect(storeReview.requests, 0);
    });

    testWidgets(
      'is not made when the sheet cannot be prepared or is cancelled',
      (tester) async {
        renderer.error = StateError('no memory');
        await open(tester);
        expect(storeReview.requests, 0);

        renderer.error = null;
        await tester.tap(find.byKey(const ValueKey('sheet-retry-key')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(_previewCancel);
        await tester.pumpAndSettle();
        await flushReview(tester);
        expect(actions.sharedFiles, isEmpty);
        expect(storeReview.requests, 0);
      },
    );
  });

  group('the file', () {
    testWidgets('is deleted when the preview closes', (tester) async {
      await pump(tester);
      await tester.tap(_shareKey);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final file = renderer.files.single;
      expect(file.existsSync(), isTrue);
      // The image reads the file on the real clock; on Windows an open file
      // cannot be deleted, so let it finish before closing.
      await settleFiles(tester);

      await tester.tap(_previewCancel);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sheet-preview')), findsNothing);
      await settleFiles(tester);
      expect(file.existsSync(), isFalse);
    });

    testWidgets('stays when it was shared, until the next start', (
      tester,
    ) async {
      actions.gate = Completer<void>();
      await pump(tester);
      await tester.tap(_shareKey);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final file = renderer.files.single;
      await settleFiles(tester);
      await tester.tap(_previewShare);
      await tester.pump();

      // Closed while the share menu is still opening.
      await tester.tap(_previewCancel);
      await tester.pumpAndSettle();
      await settleFiles(tester);
      expect(file.existsSync(), isTrue);

      // The share returned, and the receiver may still be reading the file.
      actions.gate!.complete();
      await settleFiles(tester);
      expect(file.existsSync(), isTrue);
    });

    testWidgets('a shared one also stays when the preview closes after it', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(_shareKey);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final file = renderer.files.single;
      await settleFiles(tester);
      await tester.tap(_previewShare);
      await tester.pump();
      await tester.pump();
      await tester.tap(_previewCancel);
      await tester.pumpAndSettle();
      await settleFiles(tester);
      expect(file.existsSync(), isTrue);
    });

    testWidgets('goes when the share menu never opened', (tester) async {
      actions.opens = false;
      await pump(tester);
      await tester.tap(_shareKey);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final file = renderer.files.single;
      await settleFiles(tester);
      await tester.tap(_previewShare);
      await tester.pump();
      await tester.pump();
      await tester.tap(_previewCancel);
      await tester.pumpAndSettle();
      await settleFiles(tester);
      expect(file.existsSync(), isFalse);
    });

    testWidgets('the one a retry replaces is deleted, whatever comes next', (
      tester,
    ) async {
      // The first sheet cannot be read as an image.
      renderer.bytes = Uint8List.fromList([1, 2, 3, 4]);
      await pump(tester);
      await tester.tap(_shareKey);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await settleFiles(tester);
      final first = renderer.files.single;
      expect(first.existsSync(), isTrue);
      expect(find.byKey(const ValueKey('sheet-error')), findsOneWidget);

      // The retry fails too.
      renderer.error = StateError('no memory');
      await tester.tap(find.byKey(const ValueKey('sheet-retry-key')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await settleFiles(tester);
      expect(first.existsSync(), isFalse);
      expect(find.byKey(const ValueKey('sheet-error')), findsOneWidget);

      await tester.tap(_previewCancel);
      await tester.pumpAndSettle();
      await settleFiles(tester);
      expect(renderer.files, hasLength(1));
      expect(renderer.dir.listSync().whereType<File>(), isEmpty);
    });

    testWidgets('is deleted too when the preview closes while painting', (
      tester,
    ) async {
      renderer.gate = Completer<void>();
      await pump(tester);
      await tester.tap(_shareKey);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(_previewCancel);
      await tester.pumpAndSettle();

      renderer.gate!.complete();
      await settleFiles(tester);
      expect(renderer.files.single.existsSync(), isFalse);
      expect(tester.takeException(), isNull);
    });
  });
}
