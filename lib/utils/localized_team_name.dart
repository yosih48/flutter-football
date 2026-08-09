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

/// Hebrew display names for CLUB sides, keyed by the English name as returned
/// by api-sports.io. Same DISPLAY-ONLY contract as [kTeamNamesHe] above — these
/// may only be substituted inside `Text(...)`.
///
/// Covers the leagues in config/leagues.json plus the clubs that regularly
/// appear in the European competitions. Anything not listed falls back to the
/// English name, so partial coverage degrades gracefully rather than breaking.
const Map<String, String> kClubNamesHe = {
  // ── Premier League ───────────────────────────────────────────────
  'Arsenal': 'ארסנל',
  'Aston Villa': 'אסטון וילה',
  'Bournemouth': 'בורנמות׳',
  'Brentford': 'ברנטפורד',
  'Brighton': 'ברייטון',
  'Burnley': 'ברנלי',
  'Chelsea': "צ'לסי",
  'Crystal Palace': 'קריסטל פאלאס',
  'Everton': 'אברטון',
  'Fulham': 'פולהאם',
  'Ipswich': 'איפסוויץ׳',
  'Leeds': 'לידס',
  'Leicester': 'לסטר',
  'Liverpool': 'ליברפול',
  'Manchester City': "מנצ'סטר סיטי",
  'Manchester United': "מנצ'סטר יונייטד",
  'Newcastle': 'ניוקאסל',
  'Nottingham Forest': 'נוטינגהאם פורסט',
  'Southampton': 'סאות׳מפטון',
  'Sunderland': 'סנדרלנד',
  'Tottenham': 'טוטנהאם',
  'West Ham': 'ווסטהאם',
  'Wolves': 'וולבס',
  'Coventry': 'קובנטרי',
  'Hull City': 'האל סיטי',

  // ── La Liga ──────────────────────────────────────────────────────
  'Alaves': 'אלאבס',
  'Athletic Club': 'אתלטיק בילבאו',
  'Atletico Madrid': 'אתלטיקו מדריד',
  'Barcelona': 'ברצלונה',
  'Celta Vigo': 'סלטה ויגו',
  'Elche': 'אלצ׳ה',
  'Espanyol': 'אספניול',
  'Getafe': 'חטאפה',
  'Girona': 'ז׳ירונה',
  'Las Palmas': 'לאס פלמאס',
  'Levante': 'לבאנטה',
  'Mallorca': 'מיורקה',
  'Osasuna': 'אוססונה',
  'Rayo Vallecano': 'ראיו ואייקאנו',
  'Real Betis': 'ריאל בטיס',
  'Deportivo La Coruna': 'דפורטיבו לה קורוניה',
  'Malaga': 'מלאגה',
  'Racing Santander': 'ראסינג סנטאנדר',
  'Real Madrid': 'ריאל מדריד',
  'Real Oviedo': 'ריאל אוביידו',
  'Real Sociedad': 'ריאל סוסיאדד',
  'Sevilla': 'סביליה',
  'Valencia': 'ולנסיה',
  'Villarreal': 'ויאריאל',

  // ── Serie A ──────────────────────────────────────────────────────
  'AC Milan': 'מילאן',
  'Milan': 'מילאן',
  'Atalanta': 'אטלנטה',
  'Bologna': 'בולוניה',
  'Cagliari': 'קליארי',
  'Como': 'קומו',
  'Cremonese': 'קרמונזה',
  'Fiorentina': 'פיורנטינה',
  'Genoa': 'גנואה',
  'Inter': 'אינטר',
  'Juventus': 'יובנטוס',
  'Lazio': 'לאציו',
  'Lecce': 'לצ׳ה',
  'Napoli': 'נאפולי',
  'Parma': 'פארמה',
  'Pisa': 'פיזה',
  'Roma': 'רומא',
  'Sassuolo': 'ססואולו',
  'Torino': 'טורינו',
  'Udinese': 'אודינזה',
  'Verona': 'ורונה',
  'Hellas Verona': 'ורונה',
  'AS Roma': 'רומא',
  'Monza': 'מוצה',
  'Frosinone': 'פרוזינונה',
  'Venezia': 'ונציה',

  // ── Ligue 1 ──────────────────────────────────────────────────────
  'Angers': 'אנז׳ה',
  'Auxerre': 'אוסר',
  'Brest': 'ברסט',
  'Le Havre': 'לה האבר',
  'Lens': 'לאנס',
  'Lille': 'ליל',
  'Lorient': 'לוריאן',
  'Lyon': 'ליון',
  'Marseille': 'מארסיי',
  'Metz': 'מץ',
  'Monaco': 'מונאקו',
  'Montpellier': 'מונפלייה',
  'Nantes': 'נאנט',
  'Nice': 'ניס',
  'Paris FC': 'פריז אף.סי',
  'Paris Saint Germain': 'פריז סן ז׳רמן',
  'Paris Saint-Germain': 'פריז סן ז׳רמן',
  'Reims': 'ריימס',
  'Rennes': 'רן',
  'Saint Etienne': 'סנט אטיין',
  'Strasbourg': 'שטרסבורג',
  'Toulouse': 'טולוז',
  'Le Mans': 'לה מאן',
  'Estac Troyes': 'טרואה',
  'Stade Brestois 29': 'ברסט',

  // ── Ligat Haal (Israel) ──────────────────────────────────────────
  'Ashdod': 'מ.ס. אשדוד',
  'Beitar Jerusalem': 'בית״ר ירושלים',
  'Bnei Sakhnin': 'בני סכנין',
  'Hapoel Beer Sheva': 'הפועל באר שבע',
  'Hapoel Hadera': 'הפועל חדרה',
  'Hapoel Haifa': 'הפועל חיפה',
  'Hapoel Jerusalem': 'הפועל ירושלים',
  'Hapoel Katamon': 'הפועל ירושלים',
  'Hapoel Ramat Gan': 'הפועל רמת גן',
  'Hapoel Ramat Gan Givataim': 'הפועל רמת גן',
  'Hapoel Petah Tikva': 'הפועל פתח תקווה',
  'Hapoel Petach Tikva': 'הפועל פתח תקווה',
  'Hapoel Tel Aviv': 'הפועל תל אביב',
  'Ironi Kiryat Shmona': 'עירוני קרית שמונה',
  'Hapoel Ironi Kiryat Shmona': 'עירוני קרית שמונה',
  'Ironi Tiberias': 'עירוני טבריה',
  'Ironi Dorot Tiberias': 'עירוני טבריה',
  'Maccabi Bnei Raina': 'מכבי בני ריינה',
  'Maccabi Haifa': 'מכבי חיפה',
  'Maccabi Netanya': 'מכבי נתניה',
  'Maccabi Petah Tikva': 'מכבי פתח תקווה',
  'Maccabi Petach Tikva': 'מכבי פתח תקווה',
  
  'Maccabi Tel Aviv': 'מכבי תל אביב',
  'Sektzia Ness Ziona': 'סקציה נס ציונה',


// ── Bundesliga ───────────────────────────────────────────────────
  'Bayern Munich': 'באיירן מינכן',
  'FC Bayern München': 'באיירן מינכן',
  'Bayern München': 'באיירן מינכן',
  'Borussia Dortmund': 'בורוסיה דורטמונד',
  'Dortmund': 'בורוסיה דורטמונד',
  'RB Leipzig': 'ר.ב. לייפציג',
  'Leipzig': 'ר.ב. לייפציג',
  'Bayer Leverkusen': 'באייר לברקוזן',
  'Leverkusen': 'באייר לברקוזן',
  'VfB Stuttgart': 'שטוטגרט',
  'Stuttgart': 'שטוטגרט',
  'Eintracht Frankfurt': 'איינטרכט פרנקפורט',
  'Frankfurt': 'איינטרכט פרנקפורט',
  'Hoffenheim 1899': 'הופנהיים',
  '1899 Hoffenheim': 'הופנהיים',
  'TSG Hoffenheim': 'הופנהיים',
  'Hoffenheim': 'הופנהיים',
  'SC Freiburg': 'פרייבורג',
  'Freiburg': 'פרייבורג',
  'Werder Bremen': 'ורדר ברמן',
  'Bremen': 'ורדר ברמן',
  'Borussia Mönchengladbach': 'בורוסיה מנשנגלדבאך',
  'Mönchengladbach': 'בורוסיה מנשנגלדבאך',
  'Union Berlin': 'אוניון ברלין',
  'Mainz 05': 'מיינץ',
  'Mainz': 'מיינץ',
  'FSV Mainz 05': 'מיינץ',
  'FC Augsburg': 'אוגסבורג',
  'Augsburg': 'אוגסבורג',
  '1. FC Köln': 'פ.צ. קלן',
  'Köln': 'פ.צ. קלן',
  'Hamburger SV': 'המבורג',
  'Hamburg': 'המבורג',
  'Schalke 04': 'שאלקה',
  'FC Schalke 04': 'שאלקה',
  'SC Paderborn': 'פאדרבורן',
  'Paderborn': 'פאדרבורן',
  'SC Paderborn 07': 'פאדרבורן',
  'SV Elversberg': 'אלברסברג',
  'Elversberg': 'אלברסברג',


  // ── Regulars in the European competitions ────────────────────────
  'Ajax': 'איאקס',
  'Anderlecht': 'אנדרלכט',
  // 'Bayer Leverkusen': 'באייר לברקוזן',
  // 'Bayern Munich': 'באיירן מינכן',
  'Benfica': 'בנפיקה',
  'Besiktas': 'בשיקטאש',
  // 'Borussia Dortmund': 'בורוסיה דורטמונד',
  'Borussia Monchengladbach': 'בורוסיה מנשנגלדבאך',
  'Celtic': 'סלטיק',
  'Club Brugge KV': 'קלוב ברוז׳',
  'Copenhagen': 'קופנהגן',
  'Dinamo Zagreb': 'דינמו זאגרב',
  // 'Eintracht Frankfurt': 'אינטראכט פרנקפורט',
  'Fenerbahce': 'פנרבחצ׳ה',
  'Ferencvarosi TC': 'פרנצוארוש',
  // 'Freiburg': 'פרייבורג',
  'Galatasaray': 'גלאטסראיי',
  'Legia Warszawa': 'לגיה ורשה',
  'Olympiakos Piraeus': 'אולימפיאקוס',
  'PAOK': 'פאוק סלוניקי',
  'PSV Eindhoven': 'פ.ס.וו. איינדהובן',
  'Panathinaikos': 'פנאתינייקוס',
  'Porto': 'פורטו',
  'Qarabag': 'קרבאח',
  // 'RB Leipzig': 'לייפציג',
  'Rangers': 'ריינג׳רס',
  'Red Bull Salzburg': 'זלצבורג',
  'Red Star Belgrade': 'הכוכב האדום בלגרד',
  'Feyenoord': 'פיינורד',
  'Shakhtar Donetsk': 'שחטאר דונייצק',
  'Slavia Praha': 'סלביה פראג',
  'Sparta Praha': 'ספרטה פראג',
  'Sporting CP': 'ספורטינג ליסבון',
  // 'Stuttgart': 'שטוטגרט',
  // 'Union Berlin': 'אוניון ברלין',
  // 'VfL Wolfsburg': 'וולפסבורג',
  // 'Werder Bremen': 'ורדר ברמן',
  'Young Boys': 'יאנג בויז',
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

/// Diacritic-insensitive index built once from [kTeamNamesHe] + [kClubNamesHe].
final Map<String, String> _foldedIndex = {
  for (final e in kTeamNamesHe.entries) _foldKey(e.key): e.value,
  for (final e in kClubNamesHe.entries) _foldKey(e.key): e.value,
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
  final trimmed = englishName.trim();
  return kTeamNamesHe[trimmed] ??
      kClubNamesHe[trimmed] ??
      _foldedIndex[_foldKey(englishName)] ??
      englishName;
}
