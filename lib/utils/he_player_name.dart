import 'package:flutter/widgets.dart';
import 'package:football/utils/player_names_he.dart';

/// Latin → Hebrew player names: a curated map ([PlayerNamesHe]) in front of an
/// approximate transliteration fallback (so every player still renders, even
/// when not in the map).
///
/// DISPLAY-ONLY. Like team names, this may only be used inside `Text(...)`.
/// The raw Latin name must keep flowing through event↔lineup matching, links,
/// navigation and any data construction — otherwise those lookups break.

/// Hebrew display name when the app locale is Hebrew; otherwise the original.
/// Set [abbreviate] for tight spots (pitch dots): shortens the first name to an
/// initial in whichever script is shown (e.g. "פראנק קסייה" → "פ. קסייה").
String localizedPlayerName(BuildContext context, String name, {bool abbreviate = false}) {
  final isHe = Localizations.localeOf(context).languageCode == 'he';
  final base = isHe ? (PlayerNamesHe.lookup(name) ?? transliterateToHebrew(name)) : name;
  return abbreviate ? _abbreviate(base) : base;
}

/// Locale-agnostic variant for callers that already know the language code.
String localizedPlayerNameFor(String languageCode, String name, {bool abbreviate = false}) {
  final base = languageCode == 'he'
      ? (PlayerNamesHe.lookup(name) ?? transliterateToHebrew(name))
      : name;
  return abbreviate ? _abbreviate(base) : base;
}

/// "Franck Kessié" → "F. Kessié"; "פראנק קסייה" → "פ. קסייה". Script-agnostic.
String _abbreviate(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length <= 1 || parts.first.isEmpty) return name;
  return '${parts.first[0]}. ${parts.sublist(1).join(' ')}';
}

/// Transliterate a full name (may contain spaces, initials like "F.", hyphens).
String transliterateToHebrew(String name) {
  if (name.isEmpty) return name;
  // Split on spaces/hyphens but keep the separators so "Al-Amin" stays joined.
  final out = StringBuffer();
  final buf = StringBuffer();
  void flush() {
    if (buf.isNotEmpty) {
      out.write(_transliterateToken(buf.toString()));
      buf.clear();
    }
  }

  for (final ch in name.split('')) {
    if (ch == ' ' || ch == '-' || ch == "'" || ch == '’') {
      flush();
      out.write(ch);
    } else {
      buf.write(ch);
    }
  }
  flush();
  return out.toString();
}

// ── one token (word / initial) ──────────────────────────────────────────────

String _transliterateToken(String token) {
  // Initials like "F." → transliterate the letter, keep the dot.
  String trailingDot = '';
  var t = token;
  if (t.endsWith('.')) {
    trailingDot = '.';
    t = t.substring(0, t.length - 1);
  }
  if (t.isEmpty) return token;

  final folded = _fold(t.toLowerCase());
  final letters = <String>[];
  int i = 0;
  while (i < folded.length) {
    // Try a 3-char, then 2-char digraph, then single letter.
    final three = i + 3 <= folded.length ? folded.substring(i, i + 3) : null;
    final two = i + 2 <= folded.length ? folded.substring(i, i + 2) : null;
    if (three != null && _trigraphs.containsKey(three)) {
      letters.add(_trigraphs[three]!);
      i += 3;
      continue;
    }
    if (two != null && _digraphs.containsKey(two)) {
      letters.add(_digraphs[two]!);
      i += 2;
      continue;
    }
    final one = folded[i];
    // Collapse doubled consonants ("ss"→one ס, "ll"→one ל).
    if (i + 1 < folded.length && folded[i + 1] == one && _isCollapsible(one)) {
      i += 1; // skip the duplicate; the letter is emitted on next/this pass
    }
    // Bare 'e' is dropped mid-word, but a word-initial vowel needs an aleph so
    // the name doesn't start on a consonant ("Embolo" → אמבולו, not מבולו).
    final mapped = (one == 'e' && letters.isEmpty) ? 'א' : _letters[one];
    if (mapped != null && mapped.isNotEmpty) letters.add(mapped);
    i += 1;
  }

  if (letters.isEmpty) return token;
  // Don't apply the final (sofit) form to single-letter initials like "F." —
  // only to genuine word endings.
  if (trailingDot.isEmpty) _applyFinalForm(letters);
  return letters.join() + trailingDot;
}

bool _isCollapsible(String c) => 'bcdfgklmnprstz'.contains(c);

// Convert a word-final letter to its Hebrew sofit (final) form.
void _applyFinalForm(List<String> letters) {
  const finals = {
    'מ': 'ם',
    'נ': 'ן',
    'צ': 'ץ',
    'פ': 'ף',
    'כ': 'ך',
  };
  final last = letters.last;
  if (finals.containsKey(last)) letters[letters.length - 1] = finals[last]!;
}

// Diacritic fold so accented letters map through the base-letter tables.
String _fold(String s) {
  final b = StringBuffer();
  for (final ch in s.split('')) {
    b.write(_diacritics[ch] ?? ch);
  }
  return b.toString();
}

const Map<String, String> _trigraphs = {
  'sch': 'ש',
  'tch': "צ'",
  'tsch': 'ש',
};

const Map<String, String> _digraphs = {
  'sh': 'ש',
  'ch': "צ'",
  'ph': 'פ',
  'th': 'ת',
  'ck': 'ק',
  'kh': 'ח',
  'gh': 'ג',
  'qu': 'קוו',
  'oo': 'ו',
  'ee': 'י',
  'ou': 'ו',
  'au': 'או',
  'ai': 'איי',
  'ay': 'יי',
  'ei': 'יי',
  'ey': 'יי',
  'ie': 'י',
  'oi': 'ואי',
  'ya': 'יא',
  'yu': 'יו',
  'yo': 'יו',
  'ze': 'ז',
  'ts': 'צ',
  'tz': 'צ',
};

const Map<String, String> _letters = {
  'a': 'א',
  'b': 'ב',
  'c': 'ק',
  'd': 'ד',
  'e': '', // medial 'e' dropped; readability handled by surrounding consonants
  'f': 'פ',
  'g': 'ג',
  'h': 'ה',
  'i': 'י',
  'j': "ג'",
  'k': 'ק',
  'l': 'ל',
  'm': 'מ',
  'n': 'נ',
  'o': 'ו',
  'p': 'פ',
  'q': 'ק',
  'r': 'ר',
  's': 'ס',
  't': 'ט',
  'u': 'ו',
  'v': 'ב',
  'w': 'ו',
  'x': 'קס',
  'y': 'י',
  'z': 'ז',
};

const Map<String, String> _diacritics = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a', 'ă': 'a', 'ą': 'a',
  'ç': 'c', 'č': 'c', 'ć': 'c', 'ċ': 'c',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ě': 'e', 'ė': 'e', 'ę': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', 'į': 'i',
  'ñ': 'n', 'ń': 'n', 'ň': 'n',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o', 'ő': 'o',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ů': 'u', 'ű': 'u',
  'ý': 'y', 'ÿ': 'y',
  'š': 's', 'ś': 's', 'ş': 's',
  'ž': 'z', 'ź': 'z', 'ż': 'z',
  'ð': 'd', 'þ': 't', 'ł': 'l', 'ğ': 'g',
};
