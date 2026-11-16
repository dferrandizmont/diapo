import 'package:carrete/camera/camera_flash.dart';
import 'package:carrete/l10n/app_localizations.dart';
import 'package:carrete/screens/viewfinder/top_bar.dart';
import 'package:carrete/ui/theme/carrete_tokens.dart';
import 'package:carrete/ui/widgets/carrete_icon.dart';
import 'package:carrete/ui/widgets/plastic_controls.dart';
import 'package:carrete/ui/widgets/plastic_key.dart';
import 'package:carrete/ui/widgets/seven_segment.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  double width = 412,
  double textScale = 1,
  String language = 'en',
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = Size(width, 400);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(language),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CarreteSpacing.margin,
            ),
            child: child,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('the LCD counter', () {
    // The longest roll (36), a loose roll end, a three digit count and the
    // names of the films (one of them long, one empty), on the widest window
    // and the narrowest one.
    final cases = <(String, String, int?)>[
      ('a roll with 0 left', 'Verano 98', 0),
      ('a roll with 7 left', 'Verano 98', 7),
      ('a roll with 36 left', 'Verano 98', 36),
      ('a roll with 123 left', 'Verano 98', 123),
      ('a short film name', 'Verano 98', null),
      ('a long film name', 'Cámara de juguete', null),
      ('no film name', '', null),
    ];
    for (final width in [CarreteSizes.lcdWidth, CarreteSizes.lcdMinWidth]) {
      for (final (name, film, left) in cases) {
        for (final textScale in [1.0, 2.0]) {
          testWidgets('keeps the content and the strip apart '
              '($name, width $width, text x$textScale)', (tester) async {
            final advance = AnimationController(
              vsync: tester,
              duration: CarreteDurations.filmAdvance,
            );
            addTearDown(advance.dispose);
            await _pump(
              tester,
              LcdCounter(
                filmName: film,
                framesLeft: left,
                width: width,
                advance: advance,
              ),
              textScale: textScale,
              language: 'es',
            );

            final window = tester.getRect(find.byType(LcdWindow));
            if (film.isEmpty && left == null) {
              // Nothing to show: the window stays empty and nothing breaks.
              expect(tester.takeException(), isNull);
              return;
            }
            final content = tester.getRect(
              left == null
                  ? find.byKey(const ValueKey('lcd-film-name'))
                  : find.byType(SevenSegmentText),
            );

            void check(String when) {
              // Nothing is clipped by the window.
              final roomy = window.inflate(0.5);
              expect(
                roomy.contains(content.topLeft) &&
                    roomy.contains(content.bottomRight),
                isTrue,
                reason: 'content $content out of the window $window $when',
              );
            }

            check('at rest');
            // Along the film advance the strip runs against the bottom of
            // the window and never reaches the text or the digits.
            for (final t in [0.1, 0.35, 0.5, 0.75, 0.95]) {
              advance.value = t;
              await tester.pump();
              final strip = tester.getRect(
                find.byKey(const ValueKey('lcd-strip')),
              );
              expect(
                strip.overlaps(content),
                isFalse,
                reason: 'strip $strip over $content at $t',
              );
              expect(
                strip.bottom,
                lessThanOrEqualTo(window.bottom),
                reason: 'strip $strip out of the window $window at $t',
              );
              check('at $t');
            }
          });
        }
      }
    }

    testWidgets('without a roll shows the film name and no count', (
      tester,
    ) async {
      await _pump(
        tester,
        const LcdCounter(filmName: 'Verano 98', width: CarreteSizes.lcdWidth),
      );
      expect(find.text('VERANO 98'), findsOneWidget);
      expect(find.byType(SevenSegmentText), findsNothing);
      expect(find.textContaining('00'), findsNothing);
    });

    testWidgets('with a roll shows "Left 08" and no film name', (tester) async {
      await _pump(
        tester,
        const LcdCounter(
          filmName: 'Verano 98',
          framesLeft: 8,
          width: CarreteSizes.lcdWidth,
        ),
      );
      expect(find.text('LEFT'), findsOneWidget);
      expect(find.byType(SevenSegmentText), findsOneWidget);
      expect(
        tester.widget<SevenSegmentText>(find.byType(SevenSegmentText)).text,
        '08',
      );
      expect(find.text('VERANO 98'), findsNothing);
    });

    testWidgets('tells a screen reader the film or the frames left', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(
        tester,
        const LcdCounter(filmName: 'Verano 98', width: CarreteSizes.lcdWidth),
      );
      expect(find.bySemanticsLabel('Verano 98, loose photos'), findsOneWidget);
      await _pump(
        tester,
        const LcdCounter(
          filmName: 'Verano 98',
          framesLeft: 8,
          width: CarreteSizes.lcdWidth,
        ),
      );
      expect(find.bySemanticsLabel('8 frames left'), findsOneWidget);
      handle.dispose();
    });
  });

  group('the top bar', () {
    ViewfinderTopBar bar({
      CarreteFlash flash = CarreteFlash.off,
      ValueChanged<CarreteFlash>? onFlash,
      VoidCallback? onRoll,
    }) => ViewfinderTopBar(
      flash: flash,
      onFlash: onFlash ?? (_) {},
      onSettings: () {},
      onRoll: onRoll ?? () {},
    );

    for (final (language, width) in [
      ('en', 412.0),
      ('es', 412.0),
      ('es', 360.0),
      ('ca', 320.0),
    ]) {
      testWidgets('centres its blocks on one line and aligns the caption '
          '($language, $width)', (tester) async {
        await _pump(tester, bar(), width: width, language: language);

        final lcd = tester.getCenter(find.byType(LcdWindow)).dy;
        // The flash key and the settings key are always on the line of the LCD.
        for (final key in ['flash-key', 'settings-key']) {
          expect(
            tester.getCenter(find.byKey(ValueKey(key))).dy,
            closeTo(lcd, 0.5),
            reason: '$key vs LCD',
          );
        }
        // The roll control shares the line, or, when its text has no room at a
        // legible size, has a row of its own under the others.
        final roll = tester.getRect(find.byKey(const ValueKey('roll-key')));
        final lcdRect = tester.getRect(find.byType(LcdWindow));
        if ((roll.center.dy - lcd).abs() > 0.5) {
          expect(roll.top, greaterThanOrEqualTo(lcdRect.bottom));
          expect(roll.left, closeTo(lcdRect.left, 0.5));
        }
      });
    }

    // The painted text is whole: no line is cut, nothing leaves the key or the
    // window it is in, and no word is wider than its room. Text that shrinks
    // stays at a size a person can read.
    void expectTextWhole(WidgetTester tester, String reason, String film) {
      final windows = <Rect>[
        for (final finder in [
          find.byKey(const ValueKey('roll-key')),
          find.byKey(const ValueKey('flash-key')),
          find.byKey(const ValueKey('settings-key')),
        ])
          tester.getRect(finder).inflate(0.5),
        // The LCD and the caption under it.
        tester
            .getRect(find.byType(LcdWindow))
            .inflate(0.5)
            .expandToInclude(
              tester.getRect(find.byType(LcdWindow)).shift(const Offset(0, 24)),
            ),
      ];
      final paragraphs = find.descendant(
        of: find.byType(ViewfinderTopBar),
        matching: find.byType(RichText),
      );
      for (final element in paragraphs.evaluate()) {
        final render = element.renderObject! as RenderParagraph;
        final text = render.text.toPlainText();
        if (text.trim().isEmpty) continue;
        final where = '$reason "$text"';
        final box = MatrixUtils.transformRect(
          render.getTransformTo(null),
          Offset.zero & render.size,
        );
        // Inside the key or the window it belongs to.
        expect(
          windows.any(
            (w) => w.contains(box.topLeft) && w.contains(box.bottomRight),
          ),
          isTrue,
          reason: '$where is outside its key: $box',
        );
        // The film name of the LCD is cut by an ellipsis by design.
        final isFilmName = text == film.toUpperCase();
        if (isFilmName) continue;
        // Wrapped words fit the width the paragraph was given.
        for (final b in render.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: text.length),
        )) {
          expect(
            b.right,
            // The letter spacing after the last letter counts as room.
            lessThanOrEqualTo(render.size.width + 2),
            reason: '$where has a word wider than its room',
          );
        }
        // Shrunk text is still readable: at least 9 logical pixels.
        final scale = render.getTransformTo(null).getMaxScaleOnAxis();
        final size = (render.text.style?.fontSize ?? 12) * scale;
        expect(size, greaterThanOrEqualTo(9), reason: '$where is too small');
        expect(render.didExceedMaxLines, isFalse, reason: '$where was cut');
      }
    }

    for (final language in ['es', 'ca', 'en']) {
      for (final textScale in [1.0, 1.3, 2.0]) {
        for (final (name, left, paused, film) in [
          ('with no roll', null, null, 'Cámara de juguete'),
          ('with a roll', 8, null, 'Cámara de juguete'),
          ('with a paused disposable', null, 12, 'Verano 98'),
        ]) {
          testWidgets('the painted text is whole at 320 px, x$textScale, '
              '$language, $name', (tester) async {
            await _pump(
              tester,
              ViewfinderTopBar(
                flash: CarreteFlash.party,
                onFlash: (_) {},
                onSettings: () {},
                onRoll: () {},
                rollFramesLeft: left,
                pausedDisposableLeft: paused,
                filmName: film,
              ),
              width: 320,
              textScale: textScale,
              language: language,
            );
            expect(tester.takeException(), isNull);
            expectTextWhole(tester, '$language x$textScale $name', film);
            // The keys grow with the text, up to the cap, and stay reachable.
            final key = tester.getSize(find.byKey(const ValueKey('flash-key')));
            expect(key.height, greaterThanOrEqualTo(44));
            expect(key.height, lessThanOrEqualTo(44 * 1.3 + 0.5));
          });
        }
      }
    }

    testWidgets('the keys grow with the text, up to 1.3x', (tester) async {
      final heights = <double>[];
      for (final textScale in [1.0, 1.15, 1.3, 2.0]) {
        await _pump(tester, bar(), width: 412, textScale: textScale);
        heights.add(
          tester.getSize(find.byKey(const ValueKey('flash-key'))).height,
        );
      }
      expect(heights[0], 44);
      expect(heights[1], closeTo(44 * 1.15, 0.5));
      expect(heights[2], closeTo(44 * 1.3, 0.5));
      expect(heights[3], closeTo(44 * 1.3, 0.5));
    });

    testWidgets('a long film name takes two lines and ends with an ellipsis', (
      tester,
    ) async {
      await _pump(
        tester,
        const LcdCounter(
          filmName: 'Una película con un nombre larguísimo de verdad',
          width: CarreteSizes.lcdMinWidth,
        ),
        textScale: 1.3,
        language: 'es',
      );
      final render = tester.renderObject<RenderParagraph>(
        find.byKey(const ValueKey('lcd-film-name')),
      );
      expect(render.didExceedMaxLines, isTrue);
      final size =
          (render.text.style?.fontSize ?? 0) *
          render.getTransformTo(null).getMaxScaleOnAxis();
      expect(size, greaterThanOrEqualTo(12));
    });

    testWidgets('the rewind strip runs backwards after the last frame', (
      tester,
    ) async {
      final rewind = AnimationController(
        vsync: tester,
        duration: CarreteDurations.rewind,
      );
      addTearDown(rewind.dispose);
      await _pump(
        tester,
        LcdCounter(width: 96, filmName: 'Alpha', framesLeft: 0, rewind: rewind),
      );
      final strip = find.descendant(
        of: find.byKey(const ValueKey('lcd-rewind-strip')),
        matching: find.byType(Transform),
      );
      rewind.value = 0.25;
      await tester.pump();
      final first = tester
          .widget<Transform>(strip.first)
          .transform
          .getTranslation()
          .x;
      rewind.value = 0.75;
      await tester.pump();
      final later = tester
          .widget<Transform>(strip.first)
          .transform
          .getTranslation()
          .x;
      // Forwards the film moves left; rewinding it moves right.
      expect(later, greaterThan(first));
      // The text of the LCD is still the roll: "Left 00".
      expect(find.text('LEFT'), findsOneWidget);
    });

    testWidgets('keeps the line without the roll key', (tester) async {
      await _pump(
        tester,
        ViewfinderTopBar(
          flash: CarreteFlash.auto,
          onFlash: (_) {},
          onSettings: () {},
        ),
      );
      final lcd = tester.getCenter(find.byType(LcdWindow)).dy;
      expect(
        tester.getCenter(find.byKey(const ValueKey('settings-key'))).dy,
        closeTo(lcd, 0.5),
      );
    });

    testWidgets('has one flash key, not four', (tester) async {
      await _pump(tester, bar());
      expect(find.byKey(const ValueKey('flash-key')), findsOneWidget);
      // The flash key, the roll key and the settings key.
      expect(find.byType(PlasticKey), findsNWidgets(3));
    });

    testWidgets('the flash key cycles off, auto, on, party and off', (
      tester,
    ) async {
      final pressed = <CarreteFlash>[];
      var mode = CarreteFlash.off;
      late StateSetter set;
      await _pump(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            set = setState;
            return bar(
              flash: mode,
              onFlash: (next) {
                pressed.add(next);
                setState(() => mode = next);
              },
            );
          },
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byKey(const ValueKey('flash-key')));
        await tester.pump();
      }
      set(() {});
      expect(pressed, [
        CarreteFlash.auto,
        CarreteFlash.on,
        CarreteFlash.party,
        CarreteFlash.off,
        CarreteFlash.auto,
      ]);
    });

    testWidgets('the flash key shows the icon and the name of the mode', (
      tester,
    ) async {
      for (final (mode, name) in [
        (CarreteFlash.off, 'OFF'),
        (CarreteFlash.auto, 'AUTO'),
        (CarreteFlash.on, 'ON'),
        (CarreteFlash.party, 'PARTY'),
      ]) {
        await _pump(tester, bar(flash: mode));
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('flash-key')),
            matching: find.text(name),
          ),
          findsOneWidget,
          reason: name,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('flash-key')),
            matching: find.byType(CarreteIconView),
          ),
          findsOneWidget,
        );
      }
    });

    testWidgets('the flash key tells a screen reader the mode and the way to '
        'change it', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, bar(flash: CarreteFlash.auto));
      final node = tester.getSemantics(find.byKey(const ValueKey('flash-key')));
      expect(node.label, 'Flash: Auto');
      expect(node.hint, 'Tap for the next mode');
      handle.dispose();
    });

    for (final (name, left, paused) in [
      ('a loaded roll', 8, null),
      ('a paused disposable', null, 12),
    ]) {
      for (final width in [320.0, 360.0, 412.0]) {
        for (final textScale in [1.0, 1.6, 3.0]) {
          testWidgets('the roll control of $name fits ($width, x$textScale)', (
            tester,
          ) async {
            await _pump(
              tester,
              ViewfinderTopBar(
                flash: CarreteFlash.party,
                onFlash: (_) {},
                onSettings: () {},
                onRoll: () {},
                rollFramesLeft: left,
                pausedDisposableLeft: paused,
                filmName: 'Cámara de juguete',
              ),
              width: width,
              textScale: textScale,
              language: 'es',
            );
            expect(tester.takeException(), isNull);
            final key = tester.getRect(find.byKey(const ValueKey('roll-key')));
            expect(key.height, greaterThanOrEqualTo(44));
            expect(key.width, greaterThanOrEqualTo(44));
            // The three keys and the LCD never overlap.
            final others = [
              tester.getRect(find.byType(LcdWindow)),
              tester.getRect(find.byKey(const ValueKey('flash-key'))),
              tester.getRect(find.byKey(const ValueKey('settings-key'))),
            ];
            for (final other in others) {
              expect(key.overlaps(other), isFalse, reason: '$key vs $other');
            }
          });
        }
      }
    }

    for (final textScale in [1.0, 2.0, 3.0]) {
      testWidgets('keeps the 44 px touch target and does not overflow '
          '(text x$textScale)', (tester) async {
        await _pump(
          tester,
          bar(flash: CarreteFlash.party),
          width: 360,
          textScale: textScale,
          language: 'es',
        );
        expect(tester.takeException(), isNull);
        for (final key in ['flash-key', 'roll-key', 'settings-key']) {
          final size = tester.getSize(find.byKey(ValueKey(key)));
          expect(size.width, greaterThanOrEqualTo(44), reason: key);
          expect(size.height, greaterThanOrEqualTo(44), reason: key);
        }
      });
    }
  });
}
