import 'package:carrete/roll/roll_name.dart';
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeRollName', () {
    test('trims the ends', () {
      expect(normalizeRollName('  Verano  '), 'Verano');
    });

    test('collapses every run of whitespace into one space', () {
      expect(normalizeRollName('Boda   de\t\tLaia'), 'Boda de Laia');
      expect(normalizeRollName('Boda\n\r\nde Laia'), 'Boda de Laia');
      expect(normalizeRollName('Boda  de Laia'), 'Boda de Laia');
    });

    test('control characters read as spaces', () {
      expect(normalizeRollName('Boda\u0000de\u007FLaia'), 'Boda de Laia');
    });

    test('empty, blank and null clear the name', () {
      expect(normalizeRollName(null), isNull);
      expect(normalizeRollName(''), isNull);
      expect(normalizeRollName('   \n\t '), isNull);
    });

    test('keeps a name of exactly 40 characters whole', () {
      final name = 'a' * kRollNameMaxLength;
      expect(normalizeRollName(name), name);
    });

    test('cuts a longer name to 40 characters', () {
      expect(normalizeRollName('a' * 41), 'a' * 40);
      expect(normalizeRollName('b' * 500), 'b' * 40);
    });

    test('cuts by what the user sees: an emoji or an accent is one', () {
      // A family (several code points joined) is one character.
      const family = '👨\u200D👩\u200D👧';
      expect(family.length, greaterThan(2));
      final cut = normalizeRollName(family * 45)!;
      expect(cut.characters.length, 40);
      expect(cut, family * 40);
      // A letter and its combining accent are one character too.
      const accented = 'é';
      final cutAccents = normalizeRollName(accented * 45)!;
      expect(cutAccents, accented * 40);
      // A flag (two regional indicators) is not split in half.
      const flag = '🇪🇸';
      expect(normalizeRollName(flag * 50), flag * 40);
    });

    test('a cut never leaves a space at the end', () {
      final name = '${'a' * 39} bbbb';
      expect(normalizeRollName(name), 'a' * 39);
    });

    test('keeps Spanish, Catalan and emoji names as they are', () {
      expect(
        normalizeRollName('Cumpleaños de l\'àvia 🎂'),
        'Cumpleaños de l\'àvia 🎂',
      );
    });

    test('removes bidi controls and invisible characters', () {
      expect(normalizeRollName('\u200B\u2060\uFEFF\u00AD\u180E'), isNull);
      expect(normalizeRollName('\u200E\u061C \u2066'), isNull);
      expect(normalizeRollName('\u202EBoda\u202C'), 'Boda');
      expect(
        normalizeRollName('Bo\u200Bda\u0085de\u009F\u00ADLaia'),
        'Boda de Laia',
      );
      expect(normalizeRollName('Boda\u2067 de\u200F Laia'), 'Boda de Laia');
    });

    test('a name of only joiners is null, a family emoji is kept', () {
      expect(normalizeRollName('\u200D\u200D'), isNull);
      expect(normalizeRollName('\uFE0F \u200D'), isNull);
      const family = '\u{1F468}\u200D\u{1F469}\u200D\u{1F467}';
      expect(normalizeRollName(family), family);
      expect(normalizeRollName('\u202E$family\u200B'), family);
    });

    test('is idempotent', () {
      final once = normalizeRollName('  Muy   largo ' * 10);
      expect(normalizeRollName(once), once);
      const mixed = '\u202E  Bo\u200Bda \u{1F468}\u200D\u{1F469}\t\u00AD de ';
      final cleaned = normalizeRollName(mixed);
      expect(normalizeRollName(cleaned), cleaned);
    });

    test('the invisible operators U+2061 to U+2064 are removed', () {
      for (final code in [0x2061, 0x2062, 0x2063, 0x2064]) {
        final char = String.fromCharCode(code);
        expect(normalizeRollName(char), isNull);
        expect(normalizeRollName('Bo${char}da'), 'Boda');
      }
    });

    test('a name that the cut leaves with only joiners is null', () {
      final raw = '${'‍ ' * 40}A';
      expect(normalizeRollName(raw), isNull);
      expect(normalizeRollName(normalizeRollName(raw)), isNull);
    });
  });
}
