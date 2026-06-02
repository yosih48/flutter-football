// FIFA 2026 knockout bracket template + pure pick-resolution helpers, shared
// by the editable bracket screen (lib/screens/bracket.dart) and the read-only
// bracket viewer (lib/screens/bracketViewer.dart) so the slot template,
// Annex-C third allocation and bipartite fallback live in exactly one place.

// One side of a match. Resolves to a concrete team via a user's picks:
//   gw/ru   → 1st / 2nd of a group (from groupPicks)
//   third   → one of the listed groups' 3rd-placed teams (user-chosen)
//   win     → the winner the user tapped in the referenced match
class BracketSlot {
  final String kind; // 'gw' | 'ru' | 'third' | 'win'
  final String? group;
  final List<String> thirdGroups;
  final String? src; // referenced match id, for 'win'
  const BracketSlot._(this.kind, this.group, this.thirdGroups, this.src);
  const BracketSlot.gw(String g) : this._('gw', g, const [], null);
  const BracketSlot.ru(String g) : this._('ru', g, const [], null);
  const BracketSlot.third(List<String> g) : this._('third', null, g, null);
  const BracketSlot.win(String s) : this._('win', null, const [], s);
}

class BracketMatch {
  final String id;
  final String stage;
  final BracketSlot a;
  final BracketSlot b;
  const BracketMatch(this.id, this.stage, this.a, this.b);
}

// Matches belonging to one stage, in bracket (top-to-bottom) order.
List<BracketMatch> matchesForStage(String stage) =>
    kBracketTemplate.where((m) => m.stage == stage).toList();

bool slotIsThird(BracketSlot s) => s.kind == 'third';

// Which group a team belongs to, by scanning the per-group rosters.
String? groupOfTeam(String team, Map<String, List<String>> rosters) {
  for (final e in rosters.entries) {
    if (e.value.contains(team)) return e.key;
  }
  return null;
}

// Resolve the concrete team filling one side of a match, or null if still
// undetermined (group not picked, third not chosen, feeding match open).
String? resolveParticipant(
  BracketMatch m,
  bool sideA, {
  required Map<String, List<String>> groupSel,
  required Map<String, String> thirdAssign,
  required Map<String, String> winSel,
}) {
  final s = sideA ? m.a : m.b;
  switch (s.kind) {
    case 'gw':
      final p = groupSel[s.group] ?? const [];
      return p.isNotEmpty ? p[0] : null;
    case 'ru':
      final p = groupSel[s.group] ?? const [];
      return p.length > 1 ? p[1] : null;
    case 'third':
      return thirdAssign[m.id];
    case 'win':
      return winSel[s.src];
    default:
      return null;
  }
}

// Assign the user's qualified thirds onto the R32 third slots. Each slot
// accepts a third only from its FIFA candidate groups. With all eight thirds
// decided, the official Annex-C lookup applies; otherwise a bipartite (Kuhn)
// matching fills as many slots as possible so the bracket can preview early.
Map<String, String> assignThirds(
    List<String> thirdQual, Map<String, List<String>> rosters) {
  final assign = <String, String>{};
  final thirds = List<String>.from(thirdQual);
  if (thirds.isEmpty) return assign;

  // Group -> team for the picked thirds (≤1 per group is enforced on pick).
  final byGroup = <String, String>{};
  for (final t in thirds) {
    final g = groupOfTeam(t, rosters);
    if (g != null) byGroup[g] = t;
  }

  // Official FIFA 2026 Annex C: once all eight best thirds are decided, the
  // group→slot allocation is a fixed lookup keyed by the set of eight groups.
  if (byGroup.length == 8) {
    final key = (byGroup.keys.toList()..sort()).join();
    final row = kAnnexC[key];
    if (row != null) {
      // Column order in Annex C: 1A 1B 1D 1E 1G 1I 1K 1L.
      const slotMatch = ['m79', 'm85', 'm81', 'm74', 'm82', 'm77', 'm87', 'm80'];
      for (var i = 0; i < slotMatch.length; i++) {
        final team = byGroup[row[i]];
        if (team != null) assign[slotMatch[i]] = team;
      }
      return assign;
    }
  }

  // Partial selection (fewer than eight) — fall back to a valid bipartite
  // match so the bracket can preview as picks come in.
  final slots = matchesForStage('R32')
      .where((m) => slotIsThird(m.a) || slotIsThird(m.b))
      .toList();
  if (slots.isEmpty) return assign;

  final adj = <List<int>>[]; // slot index -> eligible third indices
  for (final m in slots) {
    final slot = slotIsThird(m.a) ? m.a : m.b;
    final list = <int>[];
    for (var j = 0; j < thirds.length; j++) {
      final g = groupOfTeam(thirds[j], rosters);
      if (g != null && slot.thirdGroups.contains(g)) list.add(j);
    }
    adj.add(list);
  }

  final thirdToSlot = List<int>.filled(thirds.length, -1);
  bool augment(int slot, List<bool> seen) {
    for (final j in adj[slot]) {
      if (seen[j]) continue;
      seen[j] = true;
      if (thirdToSlot[j] == -1 || augment(thirdToSlot[j], seen)) {
        thirdToSlot[j] = slot;
        return true;
      }
    }
    return false;
  }

  for (var s = 0; s < slots.length; s++) {
    augment(s, List<bool>.filled(thirds.length, false));
  }
  for (var j = 0; j < thirds.length; j++) {
    if (thirdToSlot[j] != -1) assign[slots[thirdToSlot[j]].id] = thirds[j];
  }
  return assign;
}

// Re-derive a stage-keyed winner map from saved advancePicks (a per-stage SET
// of winner names). Each winner is mapped back onto its match in bracket order,
// walking stages top-down so each round's resolved winners feed the next.
Map<String, String> seedWinnersFromPicks(
  Map<String, List<String>> advancePicks, {
  required Map<String, List<String>> groupSel,
  required Map<String, String> thirdAssign,
}) {
  final winSel = <String, String>{};
  for (final stage in const ['R32', 'R16', 'QF', 'SF', 'F']) {
    final winners = {...(advancePicks[stage] ?? const <String>[])};
    for (final m in matchesForStage(stage)) {
      final a = resolveParticipant(m, true,
          groupSel: groupSel, thirdAssign: thirdAssign, winSel: winSel);
      final b = resolveParticipant(m, false,
          groupSel: groupSel, thirdAssign: thirdAssign, winSel: winSel);
      if (a != null && winners.contains(a)) {
        winSel[m.id] = a;
      } else if (b != null && winners.contains(b)) {
        winSel[m.id] = b;
      }
    }
  }
  return winSel;
}

// Fixed FIFA 2026 bracket (match numbers 73–104). R32 slots come from the
// published position template; later rounds chain on the winners of two
// feeding matches. Match order within a stage is bracket (top-to-bottom) order.
const List<BracketMatch> kBracketTemplate = [
  // Round of 32
  BracketMatch('m73', 'R32', BracketSlot.ru('A'), BracketSlot.ru('B')),
  BracketMatch('m74', 'R32', BracketSlot.gw('E'), BracketSlot.third(['A', 'B', 'C', 'D', 'F'])),
  BracketMatch('m75', 'R32', BracketSlot.gw('F'), BracketSlot.ru('C')),
  BracketMatch('m76', 'R32', BracketSlot.gw('C'), BracketSlot.ru('F')),
  BracketMatch('m77', 'R32', BracketSlot.gw('I'), BracketSlot.third(['C', 'D', 'F', 'G', 'H'])),
  BracketMatch('m78', 'R32', BracketSlot.ru('E'), BracketSlot.ru('I')),
  BracketMatch('m79', 'R32', BracketSlot.gw('A'), BracketSlot.third(['C', 'E', 'F', 'H', 'I'])),
  BracketMatch('m80', 'R32', BracketSlot.gw('L'), BracketSlot.third(['E', 'H', 'I', 'J', 'K'])),
  BracketMatch('m81', 'R32', BracketSlot.gw('D'), BracketSlot.third(['B', 'E', 'F', 'I', 'J'])),
  BracketMatch('m82', 'R32', BracketSlot.gw('G'), BracketSlot.third(['A', 'E', 'H', 'I', 'J'])),
  BracketMatch('m83', 'R32', BracketSlot.ru('K'), BracketSlot.ru('L')),
  BracketMatch('m84', 'R32', BracketSlot.gw('H'), BracketSlot.ru('J')),
  BracketMatch('m85', 'R32', BracketSlot.gw('B'), BracketSlot.third(['E', 'F', 'G', 'I', 'J'])),
  BracketMatch('m86', 'R32', BracketSlot.gw('J'), BracketSlot.ru('H')),
  BracketMatch('m87', 'R32', BracketSlot.gw('K'), BracketSlot.third(['D', 'E', 'I', 'J', 'L'])),
  BracketMatch('m88', 'R32', BracketSlot.ru('D'), BracketSlot.ru('G')),
  // Round of 16
  BracketMatch('m89', 'R16', BracketSlot.win('m74'), BracketSlot.win('m77')),
  BracketMatch('m90', 'R16', BracketSlot.win('m73'), BracketSlot.win('m75')),
  BracketMatch('m91', 'R16', BracketSlot.win('m76'), BracketSlot.win('m78')),
  BracketMatch('m92', 'R16', BracketSlot.win('m79'), BracketSlot.win('m80')),
  BracketMatch('m93', 'R16', BracketSlot.win('m83'), BracketSlot.win('m84')),
  BracketMatch('m94', 'R16', BracketSlot.win('m81'), BracketSlot.win('m82')),
  BracketMatch('m95', 'R16', BracketSlot.win('m86'), BracketSlot.win('m88')),
  BracketMatch('m96', 'R16', BracketSlot.win('m85'), BracketSlot.win('m87')),
  // Quarter-finals
  BracketMatch('m97', 'QF', BracketSlot.win('m89'), BracketSlot.win('m90')),
  BracketMatch('m98', 'QF', BracketSlot.win('m93'), BracketSlot.win('m94')),
  BracketMatch('m99', 'QF', BracketSlot.win('m91'), BracketSlot.win('m92')),
  BracketMatch('m100', 'QF', BracketSlot.win('m95'), BracketSlot.win('m96')),
  // Semi-finals
  BracketMatch('m101', 'SF', BracketSlot.win('m97'), BracketSlot.win('m98')),
  BracketMatch('m102', 'SF', BracketSlot.win('m99'), BracketSlot.win('m100')),
  // Final
  BracketMatch('m104', 'F', BracketSlot.win('m101'), BracketSlot.win('m102')),
];

/// Official FIFA World Cup 2026 Annex C allocation of the eight best
/// third-placed teams. Key = the eight qualifying groups, sorted and joined
/// (e.g. "EFGHIJKL"). Value = the group assigned to each of the eight winner
/// slots in column order 1A 1B 1D 1E 1G 1I 1K 1L.
const Map<String, String> kAnnexC = {
  'EFGHIJKL': 'EJIFHGLK',
  'DFGHIJKL': 'HGIDJFLK',
  'DEGHIJKL': 'EJIDHGLK',
  'DEFHIJKL': 'EJIDHFLK',
  'DEFGIJKL': 'EGIDJFLK',
  'DEFGHJKL': 'EGJDHFLK',
  'DEFGHIKL': 'EGIDHFLK',
  'DEFGHIJL': 'EGJDHFLI',
  'DEFGHIJK': 'EGJDHFIK',
  'CFGHIJKL': 'HGICJFLK',
  'CEGHIJKL': 'EJICHGLK',
  'CEFHIJKL': 'EJICHFLK',
  'CEFGIJKL': 'EGICJFLK',
  'CEFGHJKL': 'EGJCHFLK',
  'CEFGHIKL': 'EGICHFLK',
  'CEFGHIJL': 'EGJCHFLI',
  'CEFGHIJK': 'EGJCHFIK',
  'CDGHIJKL': 'HGICJDLK',
  'CDFHIJKL': 'CJIDHFLK',
  'CDFGIJKL': 'CGIDJFLK',
  'CDFGHJKL': 'CGJDHFLK',
  'CDFGHIKL': 'CGIDHFLK',
  'CDFGHIJL': 'CGJDHFLI',
  'CDFGHIJK': 'CGJDHFIK',
  'CDEHIJKL': 'EJICHDLK',
  'CDEGIJKL': 'EGICJDLK',
  'CDEGHJKL': 'EGJCHDLK',
  'CDEGHIKL': 'EGICHDLK',
  'CDEGHIJL': 'EGJCHDLI',
  'CDEGHIJK': 'EGJCHDIK',
  'CDEFIJKL': 'CJEDIFLK',
  'CDEFHJKL': 'CJEDHFLK',
  'CDEFHIKL': 'CEIDHFLK',
  'CDEFHIJL': 'CJEDHFLI',
  'CDEFHIJK': 'CJEDHFIK',
  'CDEFGJKL': 'CGEDJFLK',
  'CDEFGIKL': 'CGEDIFLK',
  'CDEFGIJL': 'CGEDJFLI',
  'CDEFGIJK': 'CGEDJFIK',
  'CDEFGHKL': 'CGEDHFLK',
  'CDEFGHJL': 'CGJDHFLE',
  'CDEFGHJK': 'CGJDHFEK',
  'CDEFGHIL': 'CGEDHFLI',
  'CDEFGHIK': 'CGEDHFIK',
  'CDEFGHIJ': 'CGJDHFEI',
  'BFGHIJKL': 'HJBFIGLK',
  'BEGHIJKL': 'EJIBHGLK',
  'BEFHIJKL': 'EJBFIHLK',
  'BEFGIJKL': 'EJBFIGLK',
  'BEFGHJKL': 'EJBFHGLK',
  'BEFGHIKL': 'EGBFIHLK',
  'BEFGHIJL': 'EJBFHGLI',
  'BEFGHIJK': 'EJBFHGIK',
  'BDGHIJKL': 'HJBDIGLK',
  'BDFHIJKL': 'HJBDIFLK',
  'BDFGIJKL': 'IGBDJFLK',
  'BDFGHJKL': 'HGBDJFLK',
  'BDFGHIKL': 'HGBDIFLK',
  'BDFGHIJL': 'HGBDJFLI',
  'BDFGHIJK': 'HGBDJFIK',
  'BDEHIJKL': 'EJBDIHLK',
  'BDEGIJKL': 'EJBDIGLK',
  'BDEGHJKL': 'EJBDHGLK',
  'BDEGHIKL': 'EGBDIHLK',
  'BDEGHIJL': 'EJBDHGLI',
  'BDEGHIJK': 'EJBDHGIK',
  'BDEFIJKL': 'EJBDIFLK',
  'BDEFHJKL': 'EJBDHFLK',
  'BDEFHIKL': 'EIBDHFLK',
  'BDEFHIJL': 'EJBDHFLI',
  'BDEFHIJK': 'EJBDHFIK',
  'BDEFGJKL': 'EGBDJFLK',
  'BDEFGIKL': 'EGBDIFLK',
  'BDEFGIJL': 'EGBDJFLI',
  'BDEFGIJK': 'EGBDJFIK',
  'BDEFGHKL': 'EGBDHFLK',
  'BDEFGHJL': 'HGBDJFLE',
  'BDEFGHJK': 'HGBDJFEK',
  'BDEFGHIL': 'EGBDHFLI',
  'BDEFGHIK': 'EGBDHFIK',
  'BDEFGHIJ': 'HGBDJFEI',
  'BCGHIJKL': 'HJBCIGLK',
  'BCFHIJKL': 'HJBCIFLK',
  'BCFGIJKL': 'IGBCJFLK',
  'BCFGHJKL': 'HGBCJFLK',
  'BCFGHIKL': 'HGBCIFLK',
  'BCFGHIJL': 'HGBCJFLI',
  'BCFGHIJK': 'HGBCJFIK',
  'BCEHIJKL': 'EJBCIHLK',
  'BCEGIJKL': 'EJBCIGLK',
  'BCEGHJKL': 'EJBCHGLK',
  'BCEGHIKL': 'EGBCIHLK',
  'BCEGHIJL': 'EJBCHGLI',
  'BCEGHIJK': 'EJBCHGIK',
  'BCEFIJKL': 'EJBCIFLK',
  'BCEFHJKL': 'EJBCHFLK',
  'BCEFHIKL': 'EIBCHFLK',
  'BCEFHIJL': 'EJBCHFLI',
  'BCEFHIJK': 'EJBCHFIK',
  'BCEFGJKL': 'EGBCJFLK',
  'BCEFGIKL': 'EGBCIFLK',
  'BCEFGIJL': 'EGBCJFLI',
  'BCEFGIJK': 'EGBCJFIK',
  'BCEFGHKL': 'EGBCHFLK',
  'BCEFGHJL': 'HGBCJFLE',
  'BCEFGHJK': 'HGBCJFEK',
  'BCEFGHIL': 'EGBCHFLI',
  'BCEFGHIK': 'EGBCHFIK',
  'BCEFGHIJ': 'HGBCJFEI',
  'BCDHIJKL': 'HJBCIDLK',
  'BCDGIJKL': 'IGBCJDLK',
  'BCDGHJKL': 'HGBCJDLK',
  'BCDGHIKL': 'HGBCIDLK',
  'BCDGHIJL': 'HGBCJDLI',
  'BCDGHIJK': 'HGBCJDIK',
  'BCDFIJKL': 'CJBDIFLK',
  'BCDFHJKL': 'CJBDHFLK',
  'BCDFHIKL': 'CIBDHFLK',
  'BCDFHIJL': 'CJBDHFLI',
  'BCDFHIJK': 'CJBDHFIK',
  'BCDFGJKL': 'CGBDJFLK',
  'BCDFGIKL': 'CGBDIFLK',
  'BCDFGIJL': 'CGBDJFLI',
  'BCDFGIJK': 'CGBDJFIK',
  'BCDFGHKL': 'CGBDHFLK',
  'BCDFGHJL': 'CGBDHFLJ',
  'BCDFGHJK': 'HGBCJFDK',
  'BCDFGHIL': 'CGBDHFLI',
  'BCDFGHIK': 'CGBDHFIK',
  'BCDFGHIJ': 'HGBCJFDI',
  'BCDEIJKL': 'EJBCIDLK',
  'BCDEHJKL': 'EJBCHDLK',
  'BCDEHIKL': 'EIBCHDLK',
  'BCDEHIJL': 'EJBCHDLI',
  'BCDEHIJK': 'EJBCHDIK',
  'BCDEGJKL': 'EGBCJDLK',
  'BCDEGIKL': 'EGBCIDLK',
  'BCDEGIJL': 'EGBCJDLI',
  'BCDEGIJK': 'EGBCJDIK',
  'BCDEGHKL': 'EGBCHDLK',
  'BCDEGHJL': 'HGBCJDLE',
  'BCDEGHJK': 'HGBCJDEK',
  'BCDEGHIL': 'EGBCHDLI',
  'BCDEGHIK': 'EGBCHDIK',
  'BCDEGHIJ': 'HGBCJDEI',
  'BCDEFJKL': 'CJBDEFLK',
  'BCDEFIKL': 'CEBDIFLK',
  'BCDEFIJL': 'CJBDEFLI',
  'BCDEFIJK': 'CJBDEFIK',
  'BCDEFHKL': 'CEBDHFLK',
  'BCDEFHJL': 'CJBDHFLE',
  'BCDEFHJK': 'CJBDHFEK',
  'BCDEFHIL': 'CEBDHFLI',
  'BCDEFHIK': 'CEBDHFIK',
  'BCDEFHIJ': 'CJBDHFEI',
  'BCDEFGKL': 'CGBDEFLK',
  'BCDEFGJL': 'CGBDJFLE',
  'BCDEFGJK': 'CGBDJFEK',
  'BCDEFGIL': 'CGBDEFLI',
  'BCDEFGIK': 'CGBDEFIK',
  'BCDEFGIJ': 'CGBDJFEI',
  'BCDEFGHL': 'CGBDHFLE',
  'BCDEFGHK': 'CGBDHFEK',
  'BCDEFGHJ': 'HGBCJFDE',
  'BCDEFGHI': 'CGBDHFEI',
  'AFGHIJKL': 'HJIFAGLK',
  'AEGHIJKL': 'EJIAHGLK',
  'AEFHIJKL': 'EJIFAHLK',
  'AEFGIJKL': 'EJIFAGLK',
  'AEFGHJKL': 'EGJFAHLK',
  'AEFGHIKL': 'EGIFAHLK',
  'AEFGHIJL': 'EGJFAHLI',
  'AEFGHIJK': 'EGJFAHIK',
  'ADGHIJKL': 'HJIDAGLK',
  'ADFHIJKL': 'HJIDAFLK',
  'ADFGIJKL': 'IGJDAFLK',
  'ADFGHJKL': 'HGJDAFLK',
  'ADFGHIKL': 'HGIDAFLK',
  'ADFGHIJL': 'HGJDAFLI',
  'ADFGHIJK': 'HGJDAFIK',
  'ADEHIJKL': 'EJIDAHLK',
  'ADEGIJKL': 'EJIDAGLK',
  'ADEGHJKL': 'EGJDAHLK',
  'ADEGHIKL': 'EGIDAHLK',
  'ADEGHIJL': 'EGJDAHLI',
  'ADEGHIJK': 'EGJDAHIK',
  'ADEFIJKL': 'EJIDAFLK',
  'ADEFHJKL': 'HJEDAFLK',
  'ADEFHIKL': 'HEIDAFLK',
  'ADEFHIJL': 'HJEDAFLI',
  'ADEFHIJK': 'HJEDAFIK',
  'ADEFGJKL': 'EGJDAFLK',
  'ADEFGIKL': 'EGIDAFLK',
  'ADEFGIJL': 'EGJDAFLI',
  'ADEFGIJK': 'EGJDAFIK',
  'ADEFGHKL': 'HGEDAFLK',
  'ADEFGHJL': 'HGJDAFLE',
  'ADEFGHJK': 'HGJDAFEK',
  'ADEFGHIL': 'HGEDAFLI',
  'ADEFGHIK': 'HGEDAFIK',
  'ADEFGHIJ': 'HGJDAFEI',
  'ACGHIJKL': 'HJICAGLK',
  'ACFHIJKL': 'HJICAFLK',
  'ACFGIJKL': 'IGJCAFLK',
  'ACFGHJKL': 'HGJCAFLK',
  'ACFGHIKL': 'HGICAFLK',
  'ACFGHIJL': 'HGJCAFLI',
  'ACFGHIJK': 'HGJCAFIK',
  'ACEHIJKL': 'EJICAHLK',
  'ACEGIJKL': 'EJICAGLK',
  'ACEGHJKL': 'EGJCAHLK',
  'ACEGHIKL': 'EGICAHLK',
  'ACEGHIJL': 'EGJCAHLI',
  'ACEGHIJK': 'EGJCAHIK',
  'ACEFIJKL': 'EJICAFLK',
  'ACEFHJKL': 'HJECAFLK',
  'ACEFHIKL': 'HEICAFLK',
  'ACEFHIJL': 'HJECAFLI',
  'ACEFHIJK': 'HJECAFIK',
  'ACEFGJKL': 'EGJCAFLK',
  'ACEFGIKL': 'EGICAFLK',
  'ACEFGIJL': 'EGJCAFLI',
  'ACEFGIJK': 'EGJCAFIK',
  'ACEFGHKL': 'HGECAFLK',
  'ACEFGHJL': 'HGJCAFLE',
  'ACEFGHJK': 'HGJCAFEK',
  'ACEFGHIL': 'HGECAFLI',
  'ACEFGHIK': 'HGECAFIK',
  'ACEFGHIJ': 'HGJCAFEI',
  'ACDHIJKL': 'HJICADLK',
  'ACDGIJKL': 'IGJCADLK',
  'ACDGHJKL': 'HGJCADLK',
  'ACDGHIKL': 'HGICADLK',
  'ACDGHIJL': 'HGJCADLI',
  'ACDGHIJK': 'HGJCADIK',
  'ACDFIJKL': 'CJIDAFLK',
  'ACDFHJKL': 'HJFCADLK',
  'ACDFHIKL': 'HFICADLK',
  'ACDFHIJL': 'HJFCADLI',
  'ACDFHIJK': 'HJFCADIK',
  'ACDFGJKL': 'CGJDAFLK',
  'ACDFGIKL': 'CGIDAFLK',
  'ACDFGIJL': 'CGJDAFLI',
  'ACDFGIJK': 'CGJDAFIK',
  'ACDFGHKL': 'HGFCADLK',
  'ACDFGHJL': 'CGJDAFLH',
  'ACDFGHJK': 'HGJCAFDK',
  'ACDFGHIL': 'HGFCADLI',
  'ACDFGHIK': 'HGFCADIK',
  'ACDFGHIJ': 'HGJCAFDI',
  'ACDEIJKL': 'EJICADLK',
  'ACDEHJKL': 'HJECADLK',
  'ACDEHIKL': 'HEICADLK',
  'ACDEHIJL': 'HJECADLI',
  'ACDEHIJK': 'HJECADIK',
  'ACDEGJKL': 'EGJCADLK',
  'ACDEGIKL': 'EGICADLK',
  'ACDEGIJL': 'EGJCADLI',
  'ACDEGIJK': 'EGJCADIK',
  'ACDEGHKL': 'HGECADLK',
  'ACDEGHJL': 'HGJCADLE',
  'ACDEGHJK': 'HGJCADEK',
  'ACDEGHIL': 'HGECADLI',
  'ACDEGHIK': 'HGECADIK',
  'ACDEGHIJ': 'HGJCADEI',
  'ACDEFJKL': 'CJEDAFLK',
  'ACDEFIKL': 'CEIDAFLK',
  'ACDEFIJL': 'CJEDAFLI',
  'ACDEFIJK': 'CJEDAFIK',
  'ACDEFHKL': 'HEFCADLK',
  'ACDEFHJL': 'HJFCADLE',
  'ACDEFHJK': 'HJECAFDK',
  'ACDEFHIL': 'HEFCADLI',
  'ACDEFHIK': 'HEFCADIK',
  'ACDEFHIJ': 'HJECAFDI',
  'ACDEFGKL': 'CGEDAFLK',
  'ACDEFGJL': 'CGJDAFLE',
  'ACDEFGJK': 'CGJDAFEK',
  'ACDEFGIL': 'CGEDAFLI',
  'ACDEFGIK': 'CGEDAFIK',
  'ACDEFGIJ': 'CGJDAFEI',
  'ACDEFGHL': 'HGFCADLE',
  'ACDEFGHK': 'HGECAFDK',
  'ACDEFGHJ': 'HGJCAFDE',
  'ACDEFGHI': 'HGECAFDI',
  'ABGHIJKL': 'HJBAIGLK',
  'ABFHIJKL': 'HJBAIFLK',
  'ABFGIJKL': 'IJBFAGLK',
  'ABFGHJKL': 'HJBFAGLK',
  'ABFGHIKL': 'HGBAIFLK',
  'ABFGHIJL': 'HJBFAGLI',
  'ABFGHIJK': 'HJBFAGIK',
  'ABEHIJKL': 'EJBAIHLK',
  'ABEGIJKL': 'EJBAIGLK',
  'ABEGHJKL': 'EJBAHGLK',
  'ABEGHIKL': 'EGBAIHLK',
  'ABEGHIJL': 'EJBAHGLI',
  'ABEGHIJK': 'EJBAHGIK',
  'ABEFIJKL': 'EJBAIFLK',
  'ABEFHJKL': 'EJBFAHLK',
  'ABEFHIKL': 'EIBFAHLK',
  'ABEFHIJL': 'EJBFAHLI',
  'ABEFHIJK': 'EJBFAHIK',
  'ABEFGJKL': 'EJBFAGLK',
  'ABEFGIKL': 'EGBAIFLK',
  'ABEFGIJL': 'EJBFAGLI',
  'ABEFGIJK': 'EJBFAGIK',
  'ABEFGHKL': 'EGBFAHLK',
  'ABEFGHJL': 'HJBFAGLE',
  'ABEFGHJK': 'HJBFAGEK',
  'ABEFGHIL': 'EGBFAHLI',
  'ABEFGHIK': 'EGBFAHIK',
  'ABEFGHIJ': 'HJBFAGEI',
  'ABDHIJKL': 'IJBDAHLK',
  'ABDGIJKL': 'IJBDAGLK',
  'ABDGHJKL': 'HJBDAGLK',
  'ABDGHIKL': 'IGBDAHLK',
  'ABDGHIJL': 'HJBDAGLI',
  'ABDGHIJK': 'HJBDAGIK',
  'ABDFIJKL': 'IJBDAFLK',
  'ABDFHJKL': 'HJBDAFLK',
  'ABDFHIKL': 'HIBDAFLK',
  'ABDFHIJL': 'HJBDAFLI',
  'ABDFHIJK': 'HJBDAFIK',
  'ABDFGJKL': 'FJBDAGLK',
  'ABDFGIKL': 'IGBDAFLK',
  'ABDFGIJL': 'FJBDAGLI',
  'ABDFGIJK': 'FJBDAGIK',
  'ABDFGHKL': 'HGBDAFLK',
  'ABDFGHJL': 'HGBDAFLJ',
  'ABDFGHJK': 'HGBDAFJK',
  'ABDFGHIL': 'HGBDAFLI',
  'ABDFGHIK': 'HGBDAFIK',
  'ABDFGHIJ': 'HGBDAFIJ',
  'ABDEIJKL': 'EJBAIDLK',
  'ABDEHJKL': 'EJBDAHLK',
  'ABDEHIKL': 'EIBDAHLK',
  'ABDEHIJL': 'EJBDAHLI',
  'ABDEHIJK': 'EJBDAHIK',
  'ABDEGJKL': 'EJBDAGLK',
  'ABDEGIKL': 'EGBAIDLK',
  'ABDEGIJL': 'EJBDAGLI',
  'ABDEGIJK': 'EJBDAGIK',
  'ABDEGHKL': 'EGBDAHLK',
  'ABDEGHJL': 'HJBDAGLE',
  'ABDEGHJK': 'HJBDAGEK',
  'ABDEGHIL': 'EGBDAHLI',
  'ABDEGHIK': 'EGBDAHIK',
  'ABDEGHIJ': 'HJBDAGEI',
  'ABDEFJKL': 'EJBDAFLK',
  'ABDEFIKL': 'EIBDAFLK',
  'ABDEFIJL': 'EJBDAFLI',
  'ABDEFIJK': 'EJBDAFIK',
  'ABDEFHKL': 'HEBDAFLK',
  'ABDEFHJL': 'HJBDAFLE',
  'ABDEFHJK': 'HJBDAFEK',
  'ABDEFHIL': 'HEBDAFLI',
  'ABDEFHIK': 'HEBDAFIK',
  'ABDEFHIJ': 'HJBDAFEI',
  'ABDEFGKL': 'EGBDAFLK',
  'ABDEFGJL': 'EGBDAFLJ',
  'ABDEFGJK': 'EGBDAFJK',
  'ABDEFGIL': 'EGBDAFLI',
  'ABDEFGIK': 'EGBDAFIK',
  'ABDEFGIJ': 'EGBDAFIJ',
  'ABDEFGHL': 'HGBDAFLE',
  'ABDEFGHK': 'HGBDAFEK',
  'ABDEFGHJ': 'HGBDAFEJ',
  'ABDEFGHI': 'HGBDAFEI',
  'ABCHIJKL': 'IJBCAHLK',
  'ABCGIJKL': 'IJBCAGLK',
  'ABCGHJKL': 'HJBCAGLK',
  'ABCGHIKL': 'IGBCAHLK',
  'ABCGHIJL': 'HJBCAGLI',
  'ABCGHIJK': 'HJBCAGIK',
  'ABCFIJKL': 'IJBCAFLK',
  'ABCFHJKL': 'HJBCAFLK',
  'ABCFHIKL': 'HIBCAFLK',
  'ABCFHIJL': 'HJBCAFLI',
  'ABCFHIJK': 'HJBCAFIK',
  'ABCFGJKL': 'CJBFAGLK',
  'ABCFGIKL': 'IGBCAFLK',
  'ABCFGIJL': 'CJBFAGLI',
  'ABCFGIJK': 'CJBFAGIK',
  'ABCFGHKL': 'HGBCAFLK',
  'ABCFGHJL': 'HGBCAFLJ',
  'ABCFGHJK': 'HGBCAFJK',
  'ABCFGHIL': 'HGBCAFLI',
  'ABCFGHIK': 'HGBCAFIK',
  'ABCFGHIJ': 'HGBCAFIJ',
  'ABCEIJKL': 'EJBAICLK',
  'ABCEHJKL': 'EJBCAHLK',
  'ABCEHIKL': 'EIBCAHLK',
  'ABCEHIJL': 'EJBCAHLI',
  'ABCEHIJK': 'EJBCAHIK',
  'ABCEGJKL': 'EJBCAGLK',
  'ABCEGIKL': 'EGBAICLK',
  'ABCEGIJL': 'EJBCAGLI',
  'ABCEGIJK': 'EJBCAGIK',
  'ABCEGHKL': 'EGBCAHLK',
  'ABCEGHJL': 'HJBCAGLE',
  'ABCEGHJK': 'HJBCAGEK',
  'ABCEGHIL': 'EGBCAHLI',
  'ABCEGHIK': 'EGBCAHIK',
  'ABCEGHIJ': 'HJBCAGEI',
  'ABCEFJKL': 'EJBCAFLK',
  'ABCEFIKL': 'EIBCAFLK',
  'ABCEFIJL': 'EJBCAFLI',
  'ABCEFIJK': 'EJBCAFIK',
  'ABCEFHKL': 'HEBCAFLK',
  'ABCEFHJL': 'HJBCAFLE',
  'ABCEFHJK': 'HJBCAFEK',
  'ABCEFHIL': 'HEBCAFLI',
  'ABCEFHIK': 'HEBCAFIK',
  'ABCEFHIJ': 'HJBCAFEI',
  'ABCEFGKL': 'EGBCAFLK',
  'ABCEFGJL': 'EGBCAFLJ',
  'ABCEFGJK': 'EGBCAFJK',
  'ABCEFGIL': 'EGBCAFLI',
  'ABCEFGIK': 'EGBCAFIK',
  'ABCEFGIJ': 'EGBCAFIJ',
  'ABCEFGHL': 'HGBCAFLE',
  'ABCEFGHK': 'HGBCAFEK',
  'ABCEFGHJ': 'HGBCAFEJ',
  'ABCEFGHI': 'HGBCAFEI',
  'ABCDIJKL': 'IJBCADLK',
  'ABCDHJKL': 'HJBCADLK',
  'ABCDHIKL': 'HIBCADLK',
  'ABCDHIJL': 'HJBCADLI',
  'ABCDHIJK': 'HJBCADIK',
  'ABCDGJKL': 'CJBDAGLK',
  'ABCDGIKL': 'IGBCADLK',
  'ABCDGIJL': 'CJBDAGLI',
  'ABCDGIJK': 'CJBDAGIK',
  'ABCDGHKL': 'HGBCADLK',
  'ABCDGHJL': 'HGBCADLJ',
  'ABCDGHJK': 'HGBCADJK',
  'ABCDGHIL': 'HGBCADLI',
  'ABCDGHIK': 'HGBCADIK',
  'ABCDGHIJ': 'HGBCADIJ',
  'ABCDFJKL': 'CJBDAFLK',
  'ABCDFIKL': 'CIBDAFLK',
  'ABCDFIJL': 'CJBDAFLI',
  'ABCDFIJK': 'CJBDAFIK',
  'ABCDFHKL': 'HFBCADLK',
  'ABCDFHJL': 'CJBDAFLH',
  'ABCDFHJK': 'HJBCAFDK',
  'ABCDFHIL': 'HFBCADLI',
  'ABCDFHIK': 'HFBCADIK',
  'ABCDFHIJ': 'HJBCAFDI',
  'ABCDFGKL': 'CGBDAFLK',
  'ABCDFGJL': 'CGBDAFLJ',
  'ABCDFGJK': 'CGBDAFJK',
  'ABCDFGIL': 'CGBDAFLI',
  'ABCDFGIK': 'CGBDAFIK',
  'ABCDFGIJ': 'CGBDAFIJ',
  'ABCDFGHL': 'CGBDAFLH',
  'ABCDFGHK': 'HGBCAFDK',
  'ABCDFGHJ': 'HGBCAFDJ',
  'ABCDFGHI': 'HGBCAFDI',
  'ABCDEJKL': 'EJBCADLK',
  'ABCDEIKL': 'EIBCADLK',
  'ABCDEIJL': 'EJBCADLI',
  'ABCDEIJK': 'EJBCADIK',
  'ABCDEHKL': 'HEBCADLK',
  'ABCDEHJL': 'HJBCADLE',
  'ABCDEHJK': 'HJBCADEK',
  'ABCDEHIL': 'HEBCADLI',
  'ABCDEHIK': 'HEBCADIK',
  'ABCDEHIJ': 'HJBCADEI',
  'ABCDEGKL': 'EGBCADLK',
  'ABCDEGJL': 'EGBCADLJ',
  'ABCDEGJK': 'EGBCADJK',
  'ABCDEGIL': 'EGBCADLI',
  'ABCDEGIK': 'EGBCADIK',
  'ABCDEGIJ': 'EGBCADIJ',
  'ABCDEGHL': 'HGBCADLE',
  'ABCDEGHK': 'HGBCADEK',
  'ABCDEGHJ': 'HGBCADEJ',
  'ABCDEGHI': 'HGBCADEI',
  'ABCDEFKL': 'CEBDAFLK',
  'ABCDEFJL': 'CJBDAFLE',
  'ABCDEFJK': 'CJBDAFEK',
  'ABCDEFIL': 'CEBDAFLI',
  'ABCDEFIK': 'CEBDAFIK',
  'ABCDEFIJ': 'CJBDAFEI',
  'ABCDEFHL': 'HFBCADLE',
  'ABCDEFHK': 'HEBCAFDK',
  'ABCDEFHJ': 'HJBCAFDE',
  'ABCDEFHI': 'HEBCAFDI',
  'ABCDEFGL': 'CGBDAFLE',
  'ABCDEFGK': 'CGBDAFEK',
  'ABCDEFGJ': 'CGBDAFEJ',
  'ABCDEFGI': 'CGBDAFEI',
  'ABCDEFGH': 'HGBCAFDE',
};
