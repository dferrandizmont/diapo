import 'package:flutter/widgets.dart' show StringCharacters;

/// The most characters a roll name can have. Counted as the user sees them
/// (grapheme clusters), so an accented letter or an emoji takes one.
const int kRollNameMaxLength = 40;

final RegExp _whitespace = RegExp(r'[\s\u0000-\u001F\u007F\u0080-\u009F]+');

/// Bidirectional controls and characters that draw nothing. The zero width
/// joiner (U+200D) and the variation selectors are not here: emoji sequences
/// need them.
final RegExp _invisible = RegExp(
  r'[\u200E\u200F\u202A-\u202E\u2066-\u2069\u061C'
  r'\u200B\u2060-\u2064\uFEFF\u00AD\u180E]',
);

/// What does not show on its own: joiners and variation selectors.
final RegExp _joiners = RegExp(r'[\u200D\uFE00-\uFE0F]');

/// The name to store for [raw], or null when there is none.
///
/// Bidirectional controls and invisible characters are removed, the name is
/// trimmed, every run of whitespace (and of control characters) becomes one
/// space, and it is cut to [kRollNameMaxLength] characters without splitting
/// a character in two. A name that is empty once cleaned, or that is only
/// joiners, is null: it clears the name of the roll.
String? normalizeRollName(String? raw) {
  if (raw == null) return null;
  final collapsed = raw
      .replaceAll(_invisible, '')
      .replaceAll(_whitespace, ' ')
      .trim();
  final cut = collapsed.characters.length > kRollNameMaxLength
      ? collapsed.characters.take(kRollNameMaxLength).toString().trimRight()
      : collapsed;
  // Checked after the cut: cutting can leave only joiners behind.
  return _showsNothing(cut) ? null : cut;
}

bool _showsNothing(String name) => name.replaceAll(_joiners, '').trim().isEmpty;
