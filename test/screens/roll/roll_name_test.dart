import 'dart:async';

import 'package:carrete/core/database/app_database.dart';
import 'package:carrete/core/database/database_provider.dart';
import 'package:carrete/core/database/rolls_dao.dart';
import 'package:carrete/core/database/tables.dart';
import 'package:carrete/gallery/gallery_content.dart';
import 'package:carrete/gallery/photo_library.dart';
import 'package:carrete/render/film_resources.dart';
import 'package:carrete/roll/roll_name.dart';
import 'package:carrete/roll/roll_providers.dart';
import 'package:carrete/screens/gallery/gallery_screen.dart';
import 'package:carrete/screens/roll/roll_name_dialog.dart';
import 'package:carrete/screens/roll/roll_screen.dart';
import 'package:carrete/ui/theme/carrete_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fakes.dart' show testBook;
import '../../support/roll_fakes.dart';
import '../../support/roll_harness.dart';
import '../../support/test_database.dart';

const _family = '👨‍👩‍👧';

final _noon = DateTime(2026, 11, 13, 12);

RollRow _developed({String? name, int id = 7}) => rollRow(
  id: id,
  name: name,
  state: RollState.developed,
  closedAt: _noon.millisecondsSinceEpoch,
  developedAt: DateTime(2026, 11, 14, 9).millisecondsSinceEpoch,
);

RollRow _waiting({String? name}) => rollRow(
  name: name,
  state: RollState.developing,
  closedAt: _noon.millisecondsSinceEpoch,
  developAt: _noon.add(const Duration(hours: 22)).millisecondsSinceEpoch,
);

/// The family of the type of the text [finder] finds.
String? _fontOf(WidgetTester tester, Finder finder) =>
    tester.widget<Text>(finder).style?.fontFamily;

/// A service that writes the names to a database, so the screen that
/// watches the roll sees them change.
class _DatabaseService extends FakeRollService {
  _DatabaseService(this.db);

  final AppDatabase db;

  @override
  Future<String?> renameRoll(int rollId, String? name) async {
    final clean = normalizeRollName(name);
    calls.add('rename $rollId $name');
    if (failWith != null) throw failWith!;
    await RollsDao(db).renameRoll(rollId, clean);
    return clean;
  }
}

/// Opens the dialog from a button and keeps what it resolved to.
class _DialogHost extends StatefulWidget {
  const _DialogHost({this.current});

  final String? current;

  @override
  State<_DialogHost> createState() => _DialogHostState();
}

class _DialogHostState extends State<_DialogHost> {
  String? result = 'unset';

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        TextButton(
          onPressed: () async {
            final name = await showRollNameDialog(
              context,
              rollId: 7,
              current: widget.current,
              palette: CarretePalette.of(context),
            );
            setState(() => result = name);
          },
          child: const Text('open'),
        ),
        Text('result: $result'),
      ],
    ),
  );
}

Future<void> _openDialog(WidgetTester tester, {String? current}) async {
  await pumpRollApp(tester, _DialogHost(current: current));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('the dialog that names a roll', () {
    testWidgets('asks for a name, says what happens without one', (
      tester,
    ) async {
      await _openDialog(tester);
      expect(find.text('Roll name'), findsOneWidget);
      expect(find.byKey(const ValueKey('roll-name-field')), findsOneWidget);
      // The fallback is the hint of the empty field, and in the note.
      expect(find.text('Roll 07'), findsOneWidget);
      expect(
        find.text(
          'It is optional. Without a name, the roll is called "Roll 07".',
        ),
        findsOneWidget,
      );
      expect(find.text('0/40'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('starts with the name the roll has', (tester) async {
      await _openDialog(tester, current: 'Verano');
      expect(find.text('Verano'), findsOneWidget);
      expect(find.text('6/40'), findsOneWidget);
    });

    testWidgets('writes in the hand of the app', (tester) async {
      await _openDialog(tester, current: 'Verano');
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('roll-name-field')),
      );
      expect(field.style?.fontFamily, CarreteFonts.hand);
    });

    testWidgets('pasted line breaks and tabs read as one space', (
      tester,
    ) async {
      await _openDialog(tester);
      await tester.enterText(
        find.byKey(const ValueKey('roll-name-field')),
        'Boda\nde\t\r\nLaia',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('result: Boda de Laia'), findsOneWidget);
    });

    testWidgets('keeps the length at 40 and counts what it holds', (
      tester,
    ) async {
      await _openDialog(tester);
      final field = find.byKey(const ValueKey('roll-name-field'));
      await tester.enterText(field, 'a' * 60);
      await tester.pump();
      expect(tester.widget<TextField>(field).controller!.text, 'a' * 40);
      expect(find.text('40/40'), findsOneWidget);
    });

    testWidgets('an emoji is one character, never cut in half', (tester) async {
      await _openDialog(tester);
      final field = find.byKey(const ValueKey('roll-name-field'));
      await tester.enterText(field, _family * 60);
      await tester.pump();
      final text = tester.widget<TextField>(field).controller!.text;
      expect(text, _family * 40);
      expect(find.text('40/40'), findsOneWidget);
    });

    testWidgets('the counter has a spoken form', (tester) async {
      await _openDialog(tester);
      await tester.enterText(
        find.byKey(const ValueKey('roll-name-field')),
        'Verano',
      );
      await tester.pump();
      expect(find.bySemanticsLabel('6 of 40 characters'), findsOneWidget);
    });

    testWidgets('Save resolves to what was written', (tester) async {
      await _openDialog(tester);
      await tester.enterText(
        find.byKey(const ValueKey('roll-name-field')),
        'Verano en la playa',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('result: Verano en la playa'), findsOneWidget);
    });

    testWidgets('the keyboard key saves too', (tester) async {
      await _openDialog(tester);
      await tester.enterText(
        find.byKey(const ValueKey('roll-name-field')),
        'Boda',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('result: Boda'), findsOneWidget);
    });

    testWidgets('an empty field saves an empty name, which clears it', (
      tester,
    ) async {
      await _openDialog(tester, current: 'Verano');
      await tester.enterText(find.byKey(const ValueKey('roll-name-field')), '');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('result: '), findsOneWidget);
    });

    testWidgets('Cancel resolves to nothing and keeps the name', (
      tester,
    ) async {
      await _openDialog(tester, current: 'Verano');
      await tester.enterText(
        find.byKey(const ValueKey('roll-name-field')),
        'Otro',
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('result: null'), findsOneWidget);
    });

    testWidgets('its keys are at least 44 high', (tester) async {
      await _openDialog(tester);
      for (final label in ['Save', 'Cancel']) {
        final key = find.ancestor(
          of: find.text(label),
          matching: find.byType(ConstrainedBox),
        );
        final size = tester.getSize(key.first);
        expect(size.height, greaterThanOrEqualTo(44), reason: label);
      }
    });

    for (final mode in ThemeMode.values.where((m) => m != ThemeMode.system)) {
      testWidgets('shows in the ${mode.name} theme at twice the text size '
          'without overflowing', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        await pumpRollApp(
          tester,
          const _DialogHost(current: 'Un nombre de carrete bastante largo'),
          mode: mode,
          size: const Size(360, 640),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Save'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('roll-name-field')),
          'W' * 40,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('the screen of a roll', () {
    testWidgets('without a name it says Roll 07, in the usual type', (
      tester,
    ) async {
      await pumpRollApp(
        tester,
        const RollScreen(id: '7'),
        overrides: rollOverrides(rolls: [_developed()]),
      );
      expect(find.text('Roll 07'), findsOneWidget);
      expect(_fontOf(tester, find.text('Roll 07')), isNot(CarreteFonts.hand));
      expect(find.textContaining('Alpha'), findsOneWidget);
    });

    testWidgets('with a name it shows it in Caveat and keeps the number', (
      tester,
    ) async {
      await pumpRollApp(
        tester,
        const RollScreen(id: '7'),
        overrides: rollOverrides(
          rolls: [_developed(name: 'Verano en Cadaqués')],
        ),
      );
      expect(find.text('Verano en Cadaqués'), findsOneWidget);
      expect(
        _fontOf(tester, find.text('Verano en Cadaqués')),
        CarreteFonts.hand,
      );
      expect(find.text('Roll 07'), findsNothing);
      // The number is still there, in the line under the name.
      expect(find.textContaining('Roll 07 · Alpha'), findsOneWidget);
    });

    testWidgets('a roll that is still waiting can be named too', (
      tester,
    ) async {
      await pumpRollApp(
        tester,
        const RollScreen(id: '7'),
        overrides: rollOverrides(rolls: [_waiting(name: 'Para después')]),
      );
      expect(find.text('Para después'), findsOneWidget);
      expect(find.byKey(const ValueKey('roll-name-edit')), findsOneWidget);
      // Nothing of its photos shows: it is not developed.
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('the edit key is at least 44 by 44 and has a label', (
      tester,
    ) async {
      await pumpRollApp(
        tester,
        const RollScreen(id: '7'),
        overrides: rollOverrides(rolls: [_developed()]),
      );
      final key = find.byKey(const ValueKey('roll-name-edit'));
      expect(key, findsOneWidget);
      final size = tester.getSize(key);
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
      expect(find.bySemanticsLabel('Edit roll name'), findsOneWidget);
    });

    testWidgets('has no edit key when the roll is gone or thrown away', (
      tester,
    ) async {
      await pumpRollApp(
        tester,
        const RollScreen(id: '7'),
        overrides: rollOverrides(),
      );
      expect(find.byKey(const ValueKey('roll-name-edit')), findsNothing);
      await pumpRollApp(
        tester,
        const RollScreen(id: '7'),
        overrides: rollOverrides(rolls: [rollRow(state: RollState.discarded)]),
      );
      expect(find.byKey(const ValueKey('roll-name-edit')), findsNothing);
    });

    testWidgets('naming it asks the service and shows the name', (
      tester,
    ) async {
      final database = openMemoryDatabase();
      addTearDown(database.close);
      final roll = await RollsDao(database)
          .openRoll(filmId: 'alpha', length: 12);
      final service = _DatabaseService(database);
      await pumpRollApp(
        tester,
        RollScreen(id: '${roll.id}'),
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          recipeBookProvider.overrideWith((ref) async => testBook()),
          rollServiceProvider.overrideWithValue(service),
        ],
      );
      await tester.pumpAndSettle();
      expect(find.text('Roll 01'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('roll-name-edit')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('roll-name-field')),
        '  Verano   de 98 ',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(service.calls, ['rename ${roll.id}   Verano   de 98 ']);
      expect(find.text('Verano de 98'), findsOneWidget);
      expect(_fontOf(tester, find.text('Verano de 98')), CarreteFonts.hand);
      expect(find.text('Roll 01'), findsNothing);

      // An empty name takes the roll back to the one it had.
      await tester.tap(find.byKey(const ValueKey('roll-name-edit')));
      await tester.pumpAndSettle();
      expect(find.text('Verano de 98'), findsWidgets);
      await tester.enterText(find.byKey(const ValueKey('roll-name-field')), '');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Roll 01'), findsOneWidget);
      expect(find.text('Verano de 98'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('cancelling leaves the roll as it was', (tester) async {
      final service = FakeRollService();
      await pumpRollApp(
        tester,
        const RollScreen(id: '7'),
        overrides: rollOverrides(rolls: [_developed()], service: service),
      );
      await tester.tap(find.byKey(const ValueKey('roll-name-edit')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('roll-name-field')),
        'Nada',
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(service.calls, isEmpty);
      expect(find.text('Roll 07'), findsOneWidget);
    });

    testWidgets('says so when the name could not be saved', (tester) async {
      final service = FakeRollService()..failWith = StateError('disk');
      await pumpRollApp(
        tester,
        const RollScreen(id: '7'),
        overrides: rollOverrides(rolls: [_developed()], service: service),
      );
      await tester.tap(find.byKey(const ValueKey('roll-name-edit')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('roll-name-field')),
        'Nada',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('That did not work. Try again.'), findsOneWidget);
      expect(find.text('Roll 07'), findsOneWidget);
    });

    testWidgets('a failed rename logs no name', (tester) async {
      final service = FakeRollService()
        ..failWith = StateError('UPDATE rolls SET name = Secreto');
      final lines = <String>[];
      final previous = debugPrint;
      debugPrint = (message, {wrapWidth}) => lines.add(message ?? '');
      await pumpRollApp(
        tester,
        const RollScreen(id: '7'),
        overrides: rollOverrides(rolls: [_developed()], service: service),
      );
      await tester.tap(find.byKey(const ValueKey('roll-name-edit')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('roll-name-field')),
        'Secreto',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      debugPrint = previous;
      expect(find.text('That did not work. Try again.'), findsOneWidget);
      expect(lines.where((l) => l.contains('Naming the roll failed')), [
        'Naming the roll failed: StateError',
      ]);
      expect(lines.any((l) => l.contains('Secreto')), isFalse);
    });

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('a long name fits at twice the text size in the '
          '${mode.name} theme', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        await pumpRollApp(
          tester,
          const RollScreen(id: '7'),
          mode: mode,
          size: const Size(360, 740),
          overrides: rollOverrides(rolls: [_developed(name: 'W' * 40)]),
        );
        expect(tester.takeException(), isNull);
        expect(find.text('W' * 40), findsOneWidget);
        expect(find.byKey(const ValueKey('roll-name-edit')), findsOneWidget);
      });
    }

    testWidgets('a name with emoji shows whole', (tester) async {
      await pumpRollApp(
        tester,
        const RollScreen(id: '7'),
        overrides: rollOverrides(
          rolls: [_developed(name: 'Playa 🏖️ $_family')],
        ),
      );
      expect(find.text('Playa 🏖️ $_family'), findsOneWidget);
    });
  });

  group('the gallery', () {
    List<Override> overrides({
      required List<RollRow> rolls,
      FakeGalleryImages? images,
    }) => [
      ...rollOverrides(rolls: rolls, gallery: images, now: _noon),
      photoLibraryProvider.overrideWithValue(FakePhotoLibrary()),
      galleryShotsProvider.overrideWith(
        (ref) => Stream.value([
          shotRow(1, galleryUri: 'content://media/1'),
          shotRow(2, galleryUri: 'content://media/2'),
        ]),
      ),
    ];

    FakeGalleryImages photos() => FakeGalleryImages({
      'content://media/1': tinyPng,
      'content://media/2': tinyPng,
    });

    const tall = Size(412, 2400);

    testWidgets('a developed roll with a name shows it, in Caveat', (
      tester,
    ) async {
      await pumpRollApp(
        tester,
        const GalleryScreen(),
        overrides: overrides(
          rolls: [_developed(name: 'Verano en Cadaqués')],
          images: photos(),
        ),
        size: tall,
      );
      expect(find.text('Verano en Cadaqués'), findsOneWidget);
      expect(
        _fontOf(tester, find.text('Verano en Cadaqués')),
        CarreteFonts.hand,
      );
      // The number stays on the label and the film goes under the name.
      expect(find.text('ROLL 07'), findsOneWidget);
      expect(find.textContaining('Alpha · Developed on'), findsOneWidget);
    });

    testWidgets('a developed roll without a name keeps the film as title', (
      tester,
    ) async {
      await pumpRollApp(
        tester,
        const GalleryScreen(),
        overrides: overrides(rolls: [_developed()], images: photos()),
        size: tall,
      );
      expect(find.text('ROLL 07'), findsOneWidget);
      expect(find.text('Alpha'), findsOneWidget);
      expect(_fontOf(tester, find.text('Alpha')), isNot(CarreteFonts.hand));
      expect(find.textContaining('Developed on'), findsOneWidget);
    });

    testWidgets('a roll that is still developing shows its name and no '
        'photo', (tester) async {
      final images = photos();
      await pumpRollApp(
        tester,
        const GalleryScreen(),
        overrides: overrides(
          rolls: [_waiting(name: 'Para después')],
          images: images,
        ),
        size: tall,
      );
      expect(find.text('Para después'), findsOneWidget);
      expect(_fontOf(tester, find.text('Para después')), CarreteFonts.hand);
      expect(find.textContaining('Roll 07 · Alpha'), findsOneWidget);
      expect(images.thumbnailsAsked, isEmpty);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('a roll that is still developing without a name says Roll 07', (
      tester,
    ) async {
      await pumpRollApp(
        tester,
        const GalleryScreen(),
        overrides: overrides(rolls: [_waiting()], images: photos()),
        size: tall,
      );
      expect(find.text('Roll 07'), findsOneWidget);
      expect(_fontOf(tester, find.text('Roll 07')), isNot(CarreteFonts.hand));
    });

    testWidgets('the card reads the name aloud with the number', (
      tester,
    ) async {
      await pumpRollApp(
        tester,
        const GalleryScreen(),
        overrides: overrides(
          rolls: [_developed(name: 'Verano')],
          images: photos(),
        ),
        size: tall,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'^Roll 07, Verano, Alpha')),
        findsOneWidget,
      );
    });

    testWidgets('a long name fits a card at twice the text size', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await pumpRollApp(
        tester,
        const GalleryScreen(),
        overrides: overrides(
          rolls: [_developed(name: 'W' * 40)],
          images: photos(),
        ),
        size: const Size(360, 3000),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('W' * 40), findsOneWidget);
    });
  });
}
