import 'package:flutter/widgets.dart';

/// Hebrew display labels for fixture-statistic types, keyed by the English
/// `type` string the backend sends. Stats come from AllSportsAPI (Sofascore):
/// the backend flattens Sofascore's grouped `statisticsItems[].name` into a flat
/// list (see worldBackend `transformStats`), so each key below is one Sofascore
/// stat name. The api-football names (`Shots on Goal`, `shots insidebox`…) are
/// also kept as a fallback for the legacy/manual API-FOOTBALL path.
///
/// DISPLAY-ONLY. These strings may only be substituted inside `Text(...)`
/// widgets. The raw English `stat.type` must keep flowing through any matching,
/// keying, or data construction unchanged — otherwise stat rows break.
///
/// Keys are matched case-insensitively (see [_foldKey]); any unmapped type
/// falls back to its original English label so new stats still render.
const Map<String, String> kStatLabelsHe = {
  // ── Possession ───────────────────────────────────────────────────
  'ball possession': 'החזקת כדור',
  'expected goals': 'שערים צפויים',
  'expected_goals': 'שערים צפויים',
  'expected assists': 'בישולים צפויים',
  'goals prevented': 'שערים שנמנעו',
  'goals_prevented': 'שערים שנמנעו',

  // ── Shots ────────────────────────────────────────────────────────
  'total shots': 'בעיטות לשער',
  'shots on target': 'בעיטות למסגרת',
  'shots off target': 'בעיטות מחוץ למסגרת',
  'hit woodwork': 'קורה',
  'blocked shots': 'בעיטות שנעצרו',
  'shots inside box': 'בעיטות בתוך הרחבה',
  'shots outside box': 'בעיטות מחוץ לרחבה',
  'big chances': 'מצבים מסוכנים',
  'big chances scored': 'מצבים מסוכנים שנוצלו',
  'big chances missed': 'מצבים מסוכנים שהוחמצו',
  // api-football legacy shot names
  'shots on goal': 'בעיטות למסגרת',
  'shots off goal': 'בעיטות מחוץ למסגרת',
  'shots insidebox': 'בעיטות בתוך הרחבה',
  'shots outsidebox': 'בעיטות מחוץ לרחבה',

  // ── Attacking ────────────────────────────────────────────────────
  'touches in penalty area': 'נגיעות ברחבה',
  'fouled in final third': 'עבירות שספג בשליש ההתקפי',
  'offsides': 'נבדלים',

  // ── Passing ──────────────────────────────────────────────────────
  'passes': 'מסירות',
  'accurate passes': 'מסירות מדויקות',
  'throw-ins': 'זריקות חוץ',
  'final third entries': 'כניסות לשליש האחרון',
  'final third phase': 'משחק בשליש האחרון',
  'long balls': 'מסירות ארוכות',
  'crosses': 'כדורי רוחב',
  'through balls': 'מסירות עומק',
  // api-football legacy pass names
  'total passes': 'סך המסירות',
  'passes accurate': 'מסירות מדויקות',
  'passes %': 'אחוז מסירות',

  // ── Duels ────────────────────────────────────────────────────────
  'duels': 'מאבקים',
  'dispossessed': 'איבודי כדור',
  'ground duels': 'מאבקי קרקע',
  'aerial duels': 'מאבקי אוויר',
  'dribbles': 'דריבלים',

  // ── Defending ────────────────────────────────────────────────────
  'tackles': 'חטיפות',
  'tackles won': 'תיקולים מוצלחים',
  'total tackles': 'סך התיקולים',
  'interceptions': 'יירוטים',
  'recoveries': 'השבת כדורים',
  'clearances': 'הרחקות כדור',
  'errors lead to a shot': 'טעויות שהובילו לבעיטה',
  'errors lead to a goal': 'טעויות שהובילו לשער',

  // ── Goalkeeping ──────────────────────────────────────────────────
  'goalkeeper saves': 'הצלות שוער',
  'total saves': 'סך ההצלות',
  'big saves': 'הצלות גדולות',
  'punches': 'הרחקות באגרוף',
  'high claims': 'קליטות גבוהות',
  'goal kicks': 'בעיטות שער',

  // ── Set pieces / discipline ──────────────────────────────────────
  'corner kicks': 'קרנות',
  'free kicks': 'בעיטות חופשיות',
  'fouls': 'עבירות',
  'yellow cards': 'כרטיסים צהובים',
  'red cards': 'כרטיסים אדומים',
};

/// Lowercase + trim → a canonical, case-insensitive lookup key.
String _foldKey(String s) => s.trim().toLowerCase();

/// Case-insensitive index built once from [kStatLabelsHe].
final Map<String, String> _foldedIndex = {
  for (final e in kStatLabelsHe.entries) _foldKey(e.key): e.value,
};

/// Remote overrides fetched from the backend (GET /api/config/statLabels) and
/// applied via [applyRemoteStatLabels]. These WIN over the compiled
/// [kStatLabelsHe] map above, which stays the offline/first-launch baseline, so
/// a label can be added or corrected without an app release. Same DISPLAY-ONLY
/// contract — consulted only by the lookup below.
Map<String, String> _remoteFolded = const {};

/// Replace the remote English→Hebrew stat-label overrides. Pass the raw map from
/// the backend config endpoint; an empty map clears overrides to the baseline.
void applyRemoteStatLabels(Map<String, String> labels) {
  final folded = <String, String>{};
  labels.forEach((type, he) {
    final k = _foldKey(type);
    final v = he.trim();
    if (k.isEmpty || v.isEmpty) return;
    folded[k] = v;
  });
  _remoteFolded = folded;
}

/// Hebrew display label for a statistic [type] when the app locale is Hebrew
/// and a translation exists; otherwise the original [type].
///
/// Use ONLY inside `Text(...)` widgets — never for matching or keying stat rows
/// (the raw English `type` must keep flowing everywhere else).
String localizedStatLabel(BuildContext context, String type) {
  if (Localizations.localeOf(context).languageCode != 'he') return type;
  final k = _foldKey(type);
  return _remoteFolded[k] ?? _foldedIndex[k] ?? type;
}

/// Locale-agnostic variant for callers that already know the language code.
String localizedStatLabelFor(String languageCode, String type) {
  if (languageCode != 'he') return type;
  final k = _foldKey(type);
  return _remoteFolded[k] ?? _foldedIndex[k] ?? type;
}
