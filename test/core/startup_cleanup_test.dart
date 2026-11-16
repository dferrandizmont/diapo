import 'dart:io';

import 'package:diapo/core/startup_cleanup.dart';
import 'package:diapo/roll/contact_sheet_image.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory cache;

  setUp(() => cache = Directory.systemTemp.createTempSync('startup-cleanup'));
  tearDown(() => cache.deleteSync(recursive: true));

  File touch(String relative) => File('${cache.path}/$relative')
    ..createSync(recursive: true)
    ..writeAsBytesSync([1, 2, 3]);

  test('removes the contact sheets left in the cache', () async {
    final sheets = [
      touch('$contactSheetFolder/sheet-1.jpg'),
      touch('$contactSheetFolder/sheet-2.png'),
    ];
    await cleanStartupTemps(cache);
    for (final sheet in sheets) {
      expect(sheet.existsSync(), isFalse, reason: sheet.path);
    }
  });

  test('works with no folder, and sweeps the other temps too', () async {
    await cleanStartupTemps(cache);
    final leftover = touch('roll-develop/roll_1_shot_1.jpg');
    final failed = touch('failed/keep.json');
    await cleanStartupTemps(cache);
    expect(leftover.existsSync(), isFalse);
    // What must survive a restart is not touched.
    expect(failed.existsSync(), isTrue);
  });
}
