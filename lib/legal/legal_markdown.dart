/// A small Markdown reader for the legal texts bundled with the app.
///
/// It understands only what those texts use: `#` headings, paragraphs, `-`
/// bullet lists, tables, `**bold**`, `*italic*`, `` `code` `` and
/// `[text](target)` links. HTML comments are dropped. It is not a general
/// Markdown parser and has no dependencies.
library;

/// A piece of text inside a block, with one style.
class MdSpan {
  const MdSpan(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.code = false,
    this.link,
  });

  final String text;
  final bool bold;
  final bool italic;
  final bool code;

  /// Where the link points, or null when the span is not a link.
  final String? link;

  @override
  bool operator ==(Object other) =>
      other is MdSpan &&
      other.text == text &&
      other.bold == bold &&
      other.italic == italic &&
      other.code == code &&
      other.link == link;

  @override
  int get hashCode => Object.hash(text, bold, italic, code, link);

  @override
  String toString() =>
      'MdSpan($text${bold ? ', bold' : ''}${italic ? ', italic' : ''}'
      '${code ? ', code' : ''}${link != null ? ', link: $link' : ''})';
}

/// One block of a document.
sealed class MdBlock {
  const MdBlock();
}

/// A heading; [level] is the number of `#` (1 to 6).
class MdHeading extends MdBlock {
  const MdHeading(this.level, this.spans);
  final int level;
  final List<MdSpan> spans;
}

class MdParagraph extends MdBlock {
  const MdParagraph(this.spans);
  final List<MdSpan> spans;
}

/// A list; each item is its own run of spans.
class MdBulletList extends MdBlock {
  const MdBulletList(this.items);
  final List<List<MdSpan>> items;
}

/// A table: the cells of the header and of each row.
class MdTable extends MdBlock {
  const MdTable(this.header, this.rows);
  final List<List<MdSpan>> header;
  final List<List<List<MdSpan>>> rows;
}

final RegExp _comment = RegExp(r'<!--[\s\S]*?-->');
final RegExp _heading = RegExp(r'^(#{1,6})\s+(.*?)\s*#*\s*$');
final RegExp _bullet = RegExp(r'^\s*[-+]\s+(.*)$');
final RegExp _separatorCell = RegExp(r'^:?-+:?$');

/// Removes the HTML comments (they can span many lines).
String stripComments(String source) => source.replaceAll(_comment, '');

/// Reads [source] into blocks.
List<MdBlock> parseLegalMarkdown(String source) {
  final lines = stripComments(source).replaceAll('\r\n', '\n').split('\n');
  final blocks = <MdBlock>[];
  var i = 0;

  bool isBlank(String line) => line.trim().isEmpty;
  bool startsBlock(String line) =>
      _heading.hasMatch(line) ||
      _bullet.hasMatch(line) ||
      line.trimLeft().startsWith('|');

  while (i < lines.length) {
    final line = lines[i];
    if (isBlank(line)) {
      i++;
      continue;
    }

    final heading = _heading.firstMatch(line);
    if (heading != null) {
      blocks.add(
        MdHeading(heading.group(1)!.length, parseInline(heading.group(2)!)),
      );
      i++;
      continue;
    }

    if (line.trimLeft().startsWith('|')) {
      final rows = <List<String>>[];
      while (i < lines.length && lines[i].trimLeft().startsWith('|')) {
        rows.add(_splitRow(lines[i]));
        i++;
      }
      final table = _table(rows);
      if (table != null) {
        blocks.add(table);
      } else {
        // Not a table after all: keep the text.
        for (final row in rows) {
          blocks.add(MdParagraph(parseInline(row.join(' | '))));
        }
      }
      continue;
    }

    if (_bullet.hasMatch(line)) {
      final items = <List<MdSpan>>[];
      while (i < lines.length && _bullet.hasMatch(lines[i])) {
        var text = _bullet.firstMatch(lines[i])!.group(1)!;
        i++;
        // A continuation line (indented, not a new block) belongs to the item.
        while (i < lines.length &&
            !isBlank(lines[i]) &&
            !startsBlock(lines[i]) &&
            lines[i].startsWith(' ')) {
          text = '$text ${lines[i].trim()}';
          i++;
        }
        items.add(parseInline(text));
      }
      blocks.add(MdBulletList(items));
      continue;
    }

    // A paragraph: consecutive lines up to a blank line or another block.
    final buffer = StringBuffer(line.trim());
    i++;
    while (i < lines.length && !isBlank(lines[i]) && !startsBlock(lines[i])) {
      buffer
        ..write(' ')
        ..write(lines[i].trim());
      i++;
    }
    blocks.add(MdParagraph(parseInline(buffer.toString())));
  }
  return blocks;
}

/// The cells of a `| a | b |` line; `\|` is a bar inside a cell.
List<String> _splitRow(String line) {
  var text = line.trim();
  if (text.startsWith('|')) text = text.substring(1);
  if (text.endsWith('|') && !text.endsWith(r'\|')) {
    text = text.substring(0, text.length - 1);
  }
  final cells = <String>[];
  final cell = StringBuffer();
  for (var k = 0; k < text.length; k++) {
    final c = text[k];
    if (c == r'\' && k + 1 < text.length && text[k + 1] == '|') {
      cell.write('|');
      k++;
    } else if (c == '|') {
      cells.add(cell.toString().trim());
      cell.clear();
    } else {
      cell.write(c);
    }
  }
  cells.add(cell.toString().trim());
  return cells;
}

MdTable? _table(List<List<String>> rows) {
  if (rows.length < 2) return null;
  if (!rows[1].every(_separatorCell.hasMatch)) return null;
  final columns = rows[0].length;
  List<List<MdSpan>> cells(List<String> row) => [
    for (var c = 0; c < columns; c++) parseInline(c < row.length ? row[c] : ''),
  ];
  return MdTable(cells(rows[0]), [for (final row in rows.skip(2)) cells(row)]);
}

/// Reads the inline marks of [text] into styled spans. A mark that is never
/// closed is kept as plain text.
List<MdSpan> parseInline(String text) {
  final spans = <MdSpan>[];
  final plain = StringBuffer();
  var bold = false;
  var italic = false;

  void flush() {
    if (plain.isEmpty) return;
    spans.add(MdSpan(plain.toString(), bold: bold, italic: italic));
    plain.clear();
  }

  var i = 0;
  while (i < text.length) {
    final c = text[i];
    if (c == r'\' &&
        i + 1 < text.length &&
        r'\`*[]()|_'.contains(text[i + 1])) {
      plain.write(text[i + 1]);
      i += 2;
    } else if (c == '`') {
      final end = text.indexOf('`', i + 1);
      if (end > i + 1) {
        flush();
        spans.add(
          MdSpan(
            text.substring(i + 1, end),
            bold: bold,
            italic: italic,
            code: true,
          ),
        );
        i = end + 1;
      } else {
        plain.write(c);
        i++;
      }
    } else if (c == '*' && text.startsWith('**', i)) {
      if (bold || text.indexOf('**', i + 2) > i + 2) {
        flush();
        bold = !bold;
        i += 2;
      } else {
        plain.write('**');
        i += 2;
      }
    } else if (c == '*') {
      if (italic || _closesItalic(text, i + 1)) {
        flush();
        italic = !italic;
        i++;
      } else {
        plain.write(c);
        i++;
      }
    } else if (c == '[') {
      final close = text.indexOf('](', i + 1);
      final end = close < 0 ? -1 : text.indexOf(')', close + 2);
      if (close > i + 1 && end > close) {
        flush();
        spans.add(
          MdSpan(
            text.substring(i + 1, close),
            bold: bold,
            italic: italic,
            link: text.substring(close + 2, end).trim(),
          ),
        );
        i = end + 1;
      } else {
        plain.write(c);
        i++;
      }
    } else {
      plain.write(c);
      i++;
    }
  }
  flush();
  return spans;
}

/// Whether a single `*` closes later in [text], from [from] on; pairs of `**`
/// inside do not count.
bool _closesItalic(String text, int from) {
  var j = from;
  while (j < text.length) {
    if (text[j] == '*') {
      if (j + 1 < text.length && text[j + 1] == '*') {
        j += 2;
        continue;
      }
      return j > from;
    }
    j++;
  }
  return false;
}
