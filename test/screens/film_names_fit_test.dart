import 'dart:io';

import 'package:diapo/camera/camera_flash.dart';
import 'package:diapo/l10n/app_localizations.dart';
import 'package:diapo/screens/viewfinder/film_carousel.dart';
import 'package:diapo/screens/viewfinder/top_bar.dart';
import 'package:diapo/ui/theme/carrete_tokens.dart';
import 'package:diapo/ui/widgets/fit_name_text.dart';
import 'package:diapo/ui/widgets/plastic_controls.dart';
import 'package:film_recipes/film_recipes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The real fonts: the default test font (Ahem) is as wide as it is tall, so
/// it says nothing about whether a name fits.
Future<void> _loadFonts() async {
  for (final (family, files) in const [
    (
      'ChakraPetch',
      [
        'ChakraPetch-Regular.ttf',
        'ChakraPetch-Medium.ttf',
        'ChakraPetch-SemiBold.ttf',
        'ChakraPetch-Bold.ttf',
      ],
    ),
    (
      'BarlowSemiCondensed',
      [
        'BarlowSemiCondensed-Regular.ttf',
        'BarlowSemiCondensed-Medium.ttf',
        'BarlowSemiCondensed-SemiBold.ttf',
        'BarlowSemiCondensed-Bold.ttf',
      ],
    ),
  ]) {
    final loader = FontLoader(family);
    for (final file in files) {
      final bytes = File('assets/fonts/$file').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}

final RecipeBook _book = RecipeBook.parse(
  File('packages/film_recipes/assets/recipes.json').readAsStringSync(),
);

String _nameIn(Recipe recipe, String language) => switch (language) {
  'es' => recipe.name.es,
  'ca' => recipe.name.ca,
  _ => recipe.name.en,
};

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required String language,
  required double textScale,
  double width = 412,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = Size(width, 600);
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
        body: Align(alignment: Alignment.topCenter, child: child),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

/// What is wrong with the painted name, or null: a word cut by a line break,
/// a cut by the maximum of lines, text too small to read, or text that spills
/// out of [room] (in the coordinates of the screen).
///
/// The size of the render object cannot tell: Flutter clamps it to what its
/// parent allows, even when the painted text is taller. So the height of the
/// text is laid out again, with the same text, scale and width, and compared
/// with the room.
String? _problem(
  RenderParagraph render,
  Rect room, {
  bool oneLineFallback = false,
}) {
  final text = render.text.toPlainText();
  for (final word in RegExp(r'\S+').allMatches(text)) {
    final boxes = render.getBoxesForSelection(
      TextSelection(baseOffset: word.start, extentOffset: word.end),
    );
    final tops = {for (final b in boxes) b.top.round()};
    if (tops.length > 1) return '"${word.group(0)}" is broken inside the word';
  }
  // A word wider than the room even at the floor is ellipsized on one line.
  final fallback = !render.softWrap && render.maxLines == 1;
  if (fallback && !oneLineFallback) return '"$text" had to be ellipsized';
  if (!fallback && render.didExceedMaxLines) {
    return '"$text" is cut by an ellipsis';
  }
  final scale = render.getTransformTo(null).getMaxScaleOnAxis();
  final size =
      render.textScaler.scale(render.text.style?.fontSize ?? 12) * scale;
  if (size < CarreteSizes.nameMinSize - 0.01) {
    return '"$text" is too small ($size)';
  }
  final painter = TextPainter(
    text: render.text,
    textDirection: render.textDirection,
    textAlign: render.textAlign,
    textScaler: render.textScaler,
    maxLines: render.maxLines,
    ellipsis: render.overflow == TextOverflow.ellipsis ? '…' : null,
    locale: render.locale,
  )..layout(maxWidth: fallback ? double.infinity : render.size.width);
  final textHeight = painter.height * scale;
  painter.dispose();
  final origin = MatrixUtils.transformPoint(
    render.getTransformTo(null),
    Offset.zero,
  );
  final roomy = room.inflate(0.5);
  if (origin.dy < roomy.top || origin.dy + textHeight > roomy.bottom) {
    return '"$text" is taller than its room: ${origin.dy}..'
        '${origin.dy + textHeight} in $room';
  }
  final box = MatrixUtils.transformRect(
    render.getTransformTo(null),
    Offset.zero & render.size,
  );
  if (box.left < roomy.left || box.right > roomy.right) {
    return '"$text" is wider than its room: $box in $room';
  }
  return null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  group('film names on the cartridges', () {
    // Every film, selected (bold) or not, one cartridge at a time: the list
    // only builds the cartridges that are near the screen.
    for (final language in ['es', 'ca', 'en']) {
      for (final textScale in [1.0, 1.5, 2.0]) {
        testWidgets('whole and inside the cartridge ($language, x$textScale)', (
          tester,
        ) async {
          for (final recipe in _book.recipes) {
            for (final selected in [false, true]) {
              final name = _nameIn(recipe, language);
              await _pump(
                tester,
                FilmCartridge(
                  name: name,
                  band: Colors.red,
                  selected: selected,
                  onTap: () {},
                  onLongPress: () {},
                  thumbnail: const SizedBox(),
                ),
                language: language,
                textScale: textScale,
              );
              expect(tester.takeException(), isNull, reason: name);
              final render = tester.renderObject<RenderParagraph>(
                find.descendant(
                  of: find.byType(FilmCartridge),
                  matching: find.text(name),
                ),
              );
              // The name sits in a room of its own, as tall and wide as the
              // paragraph is allowed to be.
              final room = MatrixUtils.transformRect(
                render.getTransformTo(null),
                Offset.zero & render.size,
              );
              expect(
                _problem(render, room),
                isNull,
                reason: '$language x$textScale $name selected: $selected',
              );
            }
          }
        });
      }
    }

    testWidgets('at 1x every name that fits keeps its design size', (
      tester,
    ) async {
      for (final recipe in _book.recipes) {
        final name = recipe.name.en;
        await _pump(
          tester,
          FilmCartridge(
            name: name,
            band: Colors.red,
            selected: false,
            onTap: () {},
            onLongPress: () {},
            thumbnail: const SizedBox(),
          ),
          language: 'en',
          textScale: 1,
        );
        final render = tester.renderObject<RenderParagraph>(find.text(name));
        expect(render.text.style?.fontSize, 12, reason: name);
      }
    });
  });

  group('the film name on the LCD', () {
    for (final language in ['es', 'ca', 'en']) {
      for (final width in [320.0, 360.0, 412.0]) {
        for (final textScale in [1.0, 1.5]) {
          testWidgets('whole and inside the window '
              '($language, $width px, x$textScale)', (tester) async {
            for (final recipe in _book.recipes) {
              final name = _nameIn(recipe, language);
              await _pump(
                tester,
                ViewfinderTopBar(
                  flash: CarreteFlash.off,
                  onFlash: (_) {},
                  onSettings: () {},
                  onRoll: () {},
                  filmName: name,
                ),
                language: language,
                textScale: textScale,
                width: width,
              );
              expect(tester.takeException(), isNull, reason: name);
              final window = tester.getRect(find.byType(LcdWindow));
              final render = tester.renderObject<RenderParagraph>(
                find.byKey(const ValueKey('lcd-film-name')),
              );
              // What the name may use: the window without the padding that
              // keeps the content off the film advance strip (the bar can be
              // scaled down as a whole).
              final k = render.getTransformTo(null).getMaxScaleOnAxis();
              final room = Rect.fromLTRB(
                window.left + CarreteSizes.lcdInset * k,
                window.top + CarreteSizes.lcdInsetV * k,
                window.right - CarreteSizes.lcdInset * k,
                window.bottom - CarreteSizes.lcdInsetV * k,
              );
              expect(
                // A phone of 320 px has a window of 52 px inside: some words do
                // not fit there, even at the floor.
                _problem(render, room, oneLineFallback: width <= 320),
                isNull,
                reason: '$language $width x$textScale $name',
              );
            }
          });
        }
      }
    }
  });

  group('FitNameText', () {
    testWidgets('shrinks until the longest word fits, never below the floor', (
      tester,
    ) async {
      await _pump(
        tester,
        const SizedBox(
          width: 60,
          height: 40,
          child: FitNameText(
            'Diapositiva fría',
            style: TextStyle(fontFamily: 'BarlowSemiCondensed', fontSize: 12),
            textKey: ValueKey('name'),
          ),
        ),
        language: 'en',
        textScale: 2,
      );
      final render = tester.renderObject<RenderParagraph>(
        find.byKey(const ValueKey('name')),
      );
      final first = render.getBoxesForSelection(
        const TextSelection(baseOffset: 0, extentOffset: 11),
      );
      expect({for (final b in first) b.top.round()}, hasLength(1));
      final painted = render.textScaler.scale(render.text.style!.fontSize!);
      expect(painted, lessThan(24));
      expect(painted, greaterThanOrEqualTo(CarreteSizes.nameMinSize - 0.01));
    });

    testWidgets('a name that needs more lines than it has ends with an '
        'ellipsis', (tester) async {
      await _pump(
        tester,
        const SizedBox(
          width: 100,
          height: 60,
          child: FitNameText(
            'One two three four five six seven eight nine ten eleven twelve '
            'thirteen fourteen fifteen sixteen seventeen eighteen',
            style: TextStyle(fontFamily: 'BarlowSemiCondensed', fontSize: 12),
            textKey: ValueKey('name'),
          ),
        ),
        language: 'en',
        textScale: 1,
      );
      final render = tester.renderObject<RenderParagraph>(
        find.byKey(const ValueKey('name')),
      );
      expect(render.didExceedMaxLines, isTrue);
      expect(
        render.text.style?.fontSize,
        closeTo(CarreteSizes.nameMinSize, 0.5),
      );
    });
  });
}
