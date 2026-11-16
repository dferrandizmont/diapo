// Renders sample shareable contact sheets to `design/hoja-contactos/`, from
// synthetic photos (the repository has no real ones).
//
// Run from the repository root:
//   sh ~/.agents/scripts/heavy.sh flutter test tool/contact_sheet/generate_samples_test.dart
//
// It is not part of `flutter test` (that only runs `test/`); it is a tool, kept
// as a test file because that is the way to get `toImage` in a headless run.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:carrete/roll/contact_sheet_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/support/synthetic_photos.dart';

const _out = 'design/hoja-contactos';

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    final bytes = File('assets/fonts/$f').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

/// Photos of every shape a roll can hold, in cycling colours.
const _shapes = <(int, int)>[
  (1800, 1200), // 3:2
  (1200, 1800), // 2:3
  (1600, 1200), // 4:3
  (1200, 1200), // 1:1
  (1920, 1080), // 16:9
  (1080, 1920), // 9:16
  (1200, 1600), // 3:4
];

const _hues = <int>[
  0xFFD6902F,
  0xFF2E9CCA,
  0xFFC8372D,
  0xFF2FA84F,
  0xFF7A4DC4,
  0xFFE4C441,
  0xFF3B6EA8,
  0xFFB5547E,
];

ContactSheetFrame _frame(int number, {bool missing = false}) {
  if (missing) return ContactSheetFrame.missing(number);
  final shape = _shapes[(number * 5) % _shapes.length];
  final from = ui.Color(_hues[number % _hues.length]);
  final to = ui.Color(_hues[(number * 3 + 1) % _hues.length]);
  return ContactSheetFrame(
    number: number,
    load: () =>
        syntheticPhoto(shape.$1 ~/ 3, shape.$2 ~/ 3, from: from, to: to),
  );
}

Future<void> _sheet(
  String name,
  int frames, {
  Set<int> missing = const {},
  String film = 'Tungsteno 400',
  ui.Color band = const ui.Color(0xFF2E9CCA),
}) async {
  final bytes = await encodeContactSheet(
    frames: [
      for (var i = 1; i <= frames; i++) _frame(i, missing: missing.contains(i)),
    ],
    filmName: film,
    bandColor: band,
    date: DateTime(2026, 11, 15),
  );
  File('$_out/$name').writeAsBytesSync(bytes);
}

void main() {
  testWidgets('render the sample contact sheets', (tester) async {
    await tester.runAsync(() async {
      await _loadFont('ChakraPetch', [
        'ChakraPetch-Regular.ttf',
        'ChakraPetch-SemiBold.ttf',
      ]);
      await _loadFont('BarlowSemiCondensed', [
        'BarlowSemiCondensed-Regular.ttf',
      ]);
      Directory(_out).createSync(recursive: true);
      await _sheet('hoja-24.png', 24);
      await _sheet(
        'hoja-36-huecos.png',
        36,
        missing: {5, 6, 17, 30},
        film: 'Ambar 200',
        band: const ui.Color(0xFFD6902F),
      );
      await _sheet('hoja-27-desechable.png', 27, film: 'Desechable');
    });
  });
}
