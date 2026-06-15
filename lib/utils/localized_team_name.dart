import 'package:flutter/widgets.dart';

/// Hebrew display names for national teams, keyed by the English name as
/// returned by api-sports.io (the canonical fixture/standings team name).
///
/// DISPLAY-ONLY. These strings may only be substituted inside `Text(...)`
/// widgets. The raw English `team.name` must keep flowing through every other
/// path — navigation, `TeamLinkHandler.linkToTeam`, fuzzy team resolution,
/// `Team(...)` construction, and event/player→team matching — otherwise those
/// lookups break silently.
const Map<String, String> kTeamNamesHe = {
  // ── Hosts / CONCACAF ─────────────────────────────────────────────
  'USA': 'ארצות הברית',
  'United States': 'ארצות הברית',
  'Mexico': 'מקסיקו',
  'Canada': 'קנדה',
  'Costa Rica': 'קוסטה ריקה',
  'Panama': 'פנמה',
  'Honduras': 'הונדורס',
  'Jamaica': "ג'מייקה",
  'El Salvador': 'אל סלבדור',
  'Guatemala': 'גואטמלה',
  'Haiti': 'האיטי',
  'Trinidad and Tobago': 'טרינידד וטובגו',
  'Curacao': 'קוראסאו',

  // ── CONMEBOL (South America) ─────────────────────────────────────
  'Brazil': 'ברזיל',
  'Argentina': 'ארגנטינה',
  'Uruguay': 'אורוגוואי',
  'Colombia': 'קולומביה',
  'Ecuador': 'אקוודור',
  'Paraguay': 'פרגוואי',
  'Peru': 'פרו',
  'Chile': "צ'ילה",
  'Venezuela': 'ונצואלה',
  'Bolivia': 'בוליביה',

  // ── UEFA (Europe) ────────────────────────────────────────────────
  'France': 'צרפת',
  'England': 'אנגליה',
  'Spain': 'ספרד',
  'Germany': 'גרמניה',
  'Portugal': 'פורטוגל',
  'Netherlands': 'הולנד',
  'Belgium': 'בלגיה',
  'Italy': 'איטליה',
  'Croatia': 'קרואטיה',
  'Denmark': 'דנמרק',
  'Switzerland': 'שווייץ',
  'Austria': 'אוסטריה',
  'Poland': 'פולין',
  'Ukraine': 'אוקראינה',
  'Serbia': 'סרביה',
  'Sweden': 'שוודיה',
  'Wales': 'ויילס',
  'Scotland': 'סקוטלנד',
  'Czech Republic': "צ'כיה",
  'Czechia': "צ'כיה",
  'Turkey': 'טורקיה',
  'Türkiye': 'טורקיה',
  'Turkiye': 'טורקיה',
  'Norway': 'נורווגיה',
  'Hungary': 'הונגריה',
  'Romania': 'רומניה',
  'Greece': 'יוון',
  'Slovakia': 'סלובקיה',
  'Slovenia': 'סלובניה',
  'Republic of Ireland': 'אירלנד',
  'Ireland': 'אירלנד',
  'Iceland': 'איסלנד',
  'Finland': 'פינלנד',
  'Albania': 'אלבניה',
  'Bosnia & Herzegovina': 'בוסניה הרצגובינה',
  'North Macedonia': 'מקדוניה הצפונית',
  'Bulgaria': 'בולגריה',
  'Russia': 'רוסיה',
  'Montenegro': 'מונטנגרו',
  'Israel': 'ישראל',
  'Georgia': "ג'ורג'יה",
  'Kosovo': 'קוסובו',
  'Luxembourg': 'לוקסמבורג',
  'Northern Ireland': 'צפון אירלנד',

  // ── CAF (Africa) ─────────────────────────────────────────────────
  'Morocco': 'מרוקו',
  'Senegal': 'סנגל',
  'Tunisia': 'תוניסיה',
  'Algeria': "אלג'יריה",
  'Egypt': 'מצרים',
  'Nigeria': 'ניגריה',
  'Cameroon': 'קמרון',
  'Ghana': 'גאנה',
  'Ivory Coast': 'חוף השנהב',
  "Cote d'Ivoire": 'חוף השנהב',
  'Mali': 'מאלי',
  'Burkina Faso': 'בורקינה פאסו',
  'South Africa': 'דרום אפריקה',
  'DR Congo': 'ר.ד קונגו',
  'Congo DR': 'ר.ד קונגו',
  'Cape Verde': 'קייפ ורדה',
  'Cape Verde Islands': 'קייפ ורדה',
  'Guinea': 'גינאה',
  'Gabon': 'גבון',
  'Zambia': 'זמביה',
  'Angola': 'אנגולה',
  'Equatorial Guinea': 'גינאה המשוונית',
  'Benin': 'בנין',
  'Mauritania': 'מאוריטניה',

  // ── AFC (Asia) ───────────────────────────────────────────────────
  'Japan': 'יפן',
  'South Korea': 'דרום קוריאה',
  'Korea Republic': 'דרום קוריאה',
  'Iran': 'איראן',
  'Saudi Arabia': 'ערב הסעודית',
  'Australia': 'אוסטרליה',
  'Qatar': 'קטאר',
  'Iraq': 'עיראק',
  'United Arab Emirates': 'איחוד האמירויות',
  'UAE': 'איחוד האמירויות',
  'Uzbekistan': 'אוזבקיסטן',
  'Jordan': 'ירדן',
  'Oman': 'עומאן',
  'Bahrain': 'בחריין',
  'China': 'סין',
  'China PR': 'סין',
  'Vietnam': 'וייטנאם',
  'Thailand': 'תאילנד',
  'Indonesia': 'אינדונזיה',
  'Palestine': 'פלסטין',
  'Lebanon': 'לבנון',
  'Syria': 'סוריה',
  'Kuwait': 'כוויית',
  'India': 'הודו',
  'Kyrgyzstan': 'קירגיזסטן',

  // ── OFC (Oceania) ────────────────────────────────────────────────
  'New Zealand': 'ניו זילנד',
  'New Caledonia': 'קלדוניה החדשה',
  'Fiji': "פיג'י",
  'Solomon Islands': 'איי שלמה',
  'Tahiti': 'טהיטי',
};

/// Maps common Latin-1/Latin Extended diacritics to their base ASCII letter, so
/// API names like `Türkiye`, `Curaçao` or `Côte d'Ivoire` resolve against the
/// plain-ASCII keys above.
const Map<String, String> _diacriticFolds = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a',
  'ç': 'c', 'č': 'c', 'ć': 'c',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ě': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i',
  'ñ': 'n', 'ń': 'n',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u',
  'ý': 'y', 'ÿ': 'y',
  'š': 's', 'ś': 's',
  'ž': 'z', 'ź': 'z', 'ż': 'z',
  'ß': 'ss',
};

/// Lowercase, trim, and fold diacritics → a canonical lookup key.
String _foldKey(String s) {
  final lower = s.trim().toLowerCase();
  final buf = StringBuffer();
  for (final ch in lower.split('')) {
    buf.write(_diacriticFolds[ch] ?? ch);
  }
  return buf.toString();
}

/// Diacritic-insensitive index built once from [kTeamNamesHe].
final Map<String, String> _foldedIndex = {
  for (final e in kTeamNamesHe.entries) _foldKey(e.key): e.value,
};

/// Hebrew display name for [englishName] when the app locale is Hebrew and a
/// translation exists; otherwise the original [englishName]. Matching ignores
/// case and diacritics, so `Türkiye`/`Curaçao` resolve like `Turkey`/`Curacao`.
///
/// Use ONLY inside `Text(...)` widgets — never for navigation, links, matching,
/// or data construction (the raw English name must keep flowing everywhere else).
String localizedTeamName(BuildContext context, String englishName) {
  if (Localizations.localeOf(context).languageCode != 'he') return englishName;
  return _lookupHe(englishName);
}

/// Locale-agnostic variant for callers that already know the language code.
String localizedTeamNameFor(String languageCode, String englishName) {
  if (languageCode != 'he') return englishName;
  return _lookupHe(englishName);
}

String _lookupHe(String englishName) {
  return kTeamNamesHe[englishName.trim()] ??
      _foldedIndex[_foldKey(englishName)] ??
      englishName;
}
