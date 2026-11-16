import 'dart:ui';

import 'package:carrete/legal/legal_document.dart';
import 'package:carrete/legal/legal_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseLegalMarkdown', () {
    test('reads headings and paragraphs, joining the lines of a paragraph', () {
      final blocks = parseLegalMarkdown(
        '# Title\n\n## Section\n\nFirst line\nsecond line.\n\nNext.\n',
      );
      expect(blocks, hasLength(4));
      expect((blocks[0] as MdHeading).level, 1);
      expect((blocks[0] as MdHeading).spans.single.text, 'Title');
      expect((blocks[1] as MdHeading).level, 2);
      expect(
        (blocks[2] as MdParagraph).spans.single.text,
        'First line second line.',
      );
      expect((blocks[3] as MdParagraph).spans.single.text, 'Next.');
    });

    test('reads a bullet list with its continuation lines', () {
      final blocks = parseLegalMarkdown(
        'Intro:\n\n- one\n- **two** here\n  and more\n- three\n\nAfter.',
      );
      expect(blocks, hasLength(3));
      final list = blocks[1] as MdBulletList;
      expect(list.items, hasLength(3));
      expect(list.items[0].single.text, 'one');
      expect(list.items[1].first, const MdSpan('two', bold: true));
      expect(list.items[1].last.text, ' here and more');
      expect(list.items[2].single.text, 'three');
    });

    test('reads a table into a header and rows', () {
      final blocks = parseLegalMarkdown(
        '| Data | Why | Where |\n'
        '| --- | --- | --- |\n'
        '| Photos | To `save` them | In the gallery |\n'
        '| Settings | Preferences |\n',
      );
      final table = blocks.single as MdTable;
      expect(table.header.map((c) => c.single.text), ['Data', 'Why', 'Where']);
      expect(table.rows, hasLength(2));
      expect(table.rows[0][1], [
        const MdSpan('To '),
        const MdSpan('save', code: true),
        const MdSpan(' them'),
      ]);
      // A short row is padded with empty cells.
      expect(table.rows[1], hasLength(3));
      expect(table.rows[1][2], isEmpty);
    });

    test('a bar escaped inside a cell stays in the cell', () {
      final table =
          parseLegalMarkdown('| A | B |\n| - | - |\n| x \\| y | z |\n').single
              as MdTable;
      expect(table.rows.single[0].single.text, 'x | y');
      expect(table.rows.single[1].single.text, 'z');
    });

    test('drops HTML comments, also across many lines', () {
      final blocks = parseLegalMarkdown(
        'Before.\n\n<!-- one line -->\n\n<!-- many\n'
        '## Hidden heading\n\n- hidden bullet\n-->\n\nAfter.\n',
      );
      expect(blocks.map((b) => (b as MdParagraph).spans.single.text), [
        'Before.',
        'After.',
      ]);
      expect(stripComments('a<!-- x\ny -->b'), 'ab');
    });

    test('a text with CRLF line ends reads the same', () {
      expect(parseLegalMarkdown('# A\r\n\r\ntext\r\n'), hasLength(2));
    });
  });

  group('parseInline', () {
    test('bold, italic and code', () {
      expect(parseInline('a **b** *c* `d`'), [
        const MdSpan('a '),
        const MdSpan('b', bold: true),
        const MdSpan(' '),
        const MdSpan('c', italic: true),
        const MdSpan(' '),
        const MdSpan('d', code: true),
      ]);
    });

    test('bold inside an italic line keeps both', () {
      expect(parseInline('*Updated **today** ok*'), [
        const MdSpan('Updated ', italic: true),
        const MdSpan('today', bold: true, italic: true),
        const MdSpan(' ok', italic: true),
      ]);
    });

    test('links keep their text and target', () {
      expect(parseInline('see [the policy](politica-privacidad.md).'), [
        const MdSpan('see '),
        const MdSpan('the policy', link: 'politica-privacidad.md'),
        const MdSpan('.'),
      ]);
    });

    test('an unclosed mark is plain text', () {
      expect(parseInline('2 * 3 and **open'), [
        const MdSpan('2 * 3 and **open'),
      ]);
      expect(parseInline('a [b] c'), [const MdSpan('a [b] c')]);
    });

    test('placeholders with braces are plain text', () {
      expect(parseInline('{{NAME}} here'), [const MdSpan('{{NAME}} here')]);
    });
  });

  group('LegalDocument', () {
    test('picks the file of the language, English for any other', () {
      expect(
        LegalDocument.privacyPolicy.assetFor(const Locale('es')),
        'docs/legal/politica-privacidad.md',
      );
      expect(
        LegalDocument.privacyPolicy.assetFor(const Locale('ca')),
        'docs/legal/politica-privacidad.ca.md',
      );
      expect(
        LegalDocument.legalNotice.assetFor(const Locale('en', 'GB')),
        'docs/legal/aviso-legal.en.md',
      );
      expect(
        LegalDocument.legalNotice.assetFor(const Locale('fr')),
        'docs/legal/aviso-legal.en.md',
      );
    });

    test('recognises a link to another bundled text', () {
      expect(
        LegalDocument.fromLink('politica-privacidad.ca.md'),
        LegalDocument.privacyPolicy,
      );
      expect(
        LegalDocument.fromLink('./aviso-legal.md#x'),
        LegalDocument.legalNotice,
      );
      expect(LegalDocument.fromLink('https://example.com/a.md'), isNull);
    });
  });
}
