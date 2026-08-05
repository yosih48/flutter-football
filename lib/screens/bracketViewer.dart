import 'package:flutter/material.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:football/models/bracket.dart';
import 'package:football/models/games.dart';
import 'package:football/resources/bracketMethods.dart';
import 'package:football/resources/gamesMethods.dart';
import 'package:football/resources/standings_service.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:football/utils/bracket_template.dart';
import 'package:football/utils/localized_team_name.dart';
import 'package:skeletonizer/skeletonizer.dart';

// Read-only view of another player's World Cup bracket. Renders the same
// group/third/knockout layout as the editable screen (lib/screens/bracket.dart)
// using the shared FIFA template, but nothing is tappable. Self-contained: it
// fetches the structure, the group rosters (from standings) and the target
// user's saved picks given just the ids.
class BracketViewerScreen extends StatefulWidget {
  const BracketViewerScreen({
    super.key,
    required this.leagueId,
    required this.userId,
    required this.displayName,
    this.structure,
    this.season,
    this.stagePoints,
  });

  final int leagueId;
  final String userId;
  final String displayName;
  final BracketStructure? structure;
  final int? season;
  // Optional per-stage earned points (from the leaderboard row) — shown as
  // badges so the viewer doubles as a scoring breakdown.
  final Map<String, int>? stagePoints;

  @override
  State<BracketViewerScreen> createState() => _BracketViewerScreenState();
}

class _BracketViewerScreenState extends State<BracketViewerScreen> {
  final _api = BracketMethods();
  final _standingsApi = StandingsService();

  bool _loading = true;
  BracketStructure? _structure;
  UserBracket? _bracket;

  final Map<String, List<String>> _groupRosters = {};
  // group letter -> actual qualifiers in final rank order [1st, 2nd], from the
  // settled standings. Used to mark each pick correct/wrong + award points.
  final Map<String, List<String>> _groupActualTop2 = {};
  // Actual 8 best third-placed teams (ranked), from the settled standings.
  final List<String> _bestThirdsActual = [];
  // stage key -> set of normalized team names that actually advanced, from
  // finished knockout fixtures. Used to mark advancer picks correct/wrong.
  final Map<String, Set<String>> _knockoutWinners = {};
  final Map<String, String> _logos = {};

  // Derived read-only selections.
  final Map<String, List<String>> _groupSel = {};
  final List<String> _thirdQual = [];
  Map<String, String> _thirdAssign = {};
  Map<String, String> _winSel = {};

  @override
  void initState() {
    super.initState();
    _structure = widget.structure;
    _load();
  }

  int _season() => widget.season ?? _structure?.season ?? 2026;

  Future<void> _load() async {
    final results = await Future.wait([
      _structure == null
          ? _api.fetchStructure(widget.leagueId)
          : Future.value(_structure),
      _api.fetchUserBracket(widget.userId, widget.leagueId, season: _season()),
      _standingsApi.getLeagueStandings(widget.leagueId),
      GamesMethods().fetchGamesForLeague(widget.leagueId),
    ]);
    if (!mounted) return;

    _structure = results[0] as BracketStructure? ?? _structure;
    _bracket = results[1] as UserBracket?;
    _ingestStandings(results[2] as List<StandingRow>?);
    _computeKnockoutWinners(results[3] as List<Game>?);
    _deriveSelections();

    setState(() => _loading = false);
  }

  void _ingestStandings(List<StandingRow>? rows) {
    _groupRosters.clear();
    _groupActualTop2.clear();
    _bestThirdsActual.clear();
    _logos.clear();
    final byGroup = <String, List<StandingRow>>{};
    for (final r in rows ?? <StandingRow>[]) {
      if (r.teamName.isEmpty) continue;
      if (r.teamLogo.isNotEmpty) _logos[r.teamName] = r.teamLogo;
      final letter = _groupLetter(r.group);
      if (letter == null) continue;
      (byGroup[letter] ??= []).add(r);
    }
    final thirds = <StandingRow>[];
    byGroup.forEach((letter, list) {
      // Sort by final rank so index 0 = group winner, 1 = runner-up.
      list.sort((a, b) => a.rank.compareTo(b.rank));
      _groupRosters[letter] = list.map((r) => r.teamName).toList();
      _groupActualTop2[letter] = list.take(2).map((r) => r.teamName).toList();
      if (list.length > 2) thirds.add(list[2]);
    });
    // FIFA best-thirds ranking: points → goal difference → goals for.
    thirds.sort((a, b) => b.points != a.points
        ? b.points - a.points
        : b.goalsDiff != a.goalsDiff
            ? b.goalsDiff - a.goalsDiff
            : b.goalsFor - a.goalsFor);
    final n = _structure?.bestThirds ?? 0;
    _bestThirdsActual.addAll(thirds.take(n).map((r) => r.teamName));
  }

  String? _groupLetter(String? group) {
    if (group == null || group.isEmpty) return null;
    final tok = group.trim().split(RegExp(r'\s+')).last.toUpperCase();
    return tok.isEmpty ? null : tok;
  }

  // Rebuild the read-only tree from the saved picks, mirroring the editor's
  // seeding but as pure derivation (no editable state).
  void _deriveSelections() {
    final gp = _bracket?.groupPicks ?? const {};
    _groupSel
      ..clear()
      ..addAll({
        for (final e in gp.entries)
          if (e.key != 'thirds') e.key: List<String>.from(e.value)
      });
    _thirdQual
      ..clear()
      ..addAll([
        for (final t in (gp['thirds'] ?? const <String>[]))
          if (!_thirdQual.contains(t)) t
      ]);
    _thirdAssign = assignThirds(_thirdQual, _groupRosters);
    _winSel = seedWinnersFromPicks(
      _bracket?.advancePicks ?? const {},
      groupSel: _groupSel,
      thirdAssign: _thirdAssign,
    );
  }

  String _lang(BuildContext context) =>
      Localizations.localeOf(context).languageCode;

  String? _logoFor(String team) => _logos[team];

  List<BracketMatch> _matchesFor(String stage) => matchesForStage(stage);

  String? _participant(BracketMatch m, bool sideA) => resolveParticipant(
        m,
        sideA,
        groupSel: _groupSel,
        thirdAssign: _thirdAssign,
        winSel: _winSel,
      );

  bool get _hasAnyPicks =>
      _groupSel.values.any((v) => v.isNotEmpty) ||
      _thirdQual.isNotEmpty ||
      _winSel.isNotEmpty;

  int? _stageEarned(String key) => widget.stagePoints?[key];

  // The group stage shows per-pick correct/wrong + points only once it's been
  // settled (the backend stamped stagePoints.groups) and we have final
  // standings to compare against.
  bool get _groupsSettled =>
      (widget.stagePoints?['groups'] ?? _bracket?.stagePoints['groups']) !=
          null &&
      _groupActualTop2.isNotEmpty;

  bool _sameTeam(String a, String b) =>
      a.trim().toLowerCase() == b.trim().toLowerCase();

  bool _isQualifier(String letter, String team) =>
      (_groupActualTop2[letter] ?? const []).any((t) => _sameTeam(t, team));

  // Points for one group pick: qualifier points if the team finished top-2,
  // plus the order bonus if it landed in the exact predicted position.
  // Mirrors the backend scoreGroups logic.
  int _scoreGroupPick(String letter, String team, int predictedIndex) {
    final gs = _structure?.stage('groups');
    if (gs == null) return 0;
    final actual = _groupActualTop2[letter] ?? const [];
    final inTop2 = actual.any((t) => _sameTeam(t, team));
    final exact = predictedIndex < actual.length &&
        _sameTeam(actual[predictedIndex], team);
    return (inTop2 ? gs.qualifierPoints : 0) + (exact ? gs.orderBonus : 0);
  }

  // Thirds are settled with the group stage; show results once that's stamped
  // and we've computed the actual best-thirds.
  bool get _thirdsSettled =>
      (widget.stagePoints?['groups'] ?? _bracket?.stagePoints['groups']) !=
          null &&
      _bestThirdsActual.isNotEmpty;

  bool _isBestThird(String team) =>
      _bestThirdsActual.any((t) => _sameTeam(t, team));

  int _scoreThirdPick(String team) => _isBestThird(team)
      ? (_structure?.stage('groups')?.thirdQualifierPoints ?? 0)
      : 0;

  // ── Knockout results (mirrors backend computeKnockoutWinners) ──────────────
  static const Set<String> _finishedStatuses = {'FT', 'AET', 'PEN'};

  void _computeKnockoutWinners(List<Game>? games) {
    _knockoutWinners.clear();
    for (final g in games ?? const <Game>[]) {
      final stage = _stageForRound(g.league.round);
      if (stage == null) continue;
      if (!_finishedStatuses.contains(g.status.short)) continue;
      final winner = g.home.winner == true
          ? g.home.name
          : (g.away.winner == true ? g.away.name : null);
      if (winner == null || winner.isEmpty) continue;
      (_knockoutWinners[stage] ??= {}).add(winner.trim().toLowerCase());
    }
  }

  String? _stageForRound(String round) {
    final r = round.toLowerCase();
    if (r.contains('round of 32')) return 'R32';
    if (r.contains('round of 16')) return 'R16';
    if (r.contains('quarter')) return 'QF';
    if (r.contains('semi')) return 'SF';
    if (r.contains('final') &&
        !RegExp(r'semi|quarter|3rd|third|play').hasMatch(r)) return 'F';
    return null;
  }

  bool _knockoutSettled(String stageKey) =>
      (widget.stagePoints?[stageKey] ?? _bracket?.stagePoints[stageKey]) !=
          null &&
      (_knockoutWinners[stageKey]?.isNotEmpty ?? false);

  bool _isAdvancer(String stageKey, String team) =>
      _knockoutWinners[stageKey]?.contains(team.trim().toLowerCase()) ?? false;

  int get _total =>
      widget.stagePoints?.values.fold<int>(0, (a, b) => a + b) ??
      (_bracket?.totalPoints ?? 0);

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: c.pitch,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: c.pitch,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: c.ink),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.bracketViewerTitle.toUpperCase(),
                style: EType.label(color: c.inkDim, size: 9, letterSpacing: 2)),
            Text(widget.displayName.toUpperCase(),
                style: EType.body(
                    size: 18,
                    color: c.ink,
                    weight: FontWeight.w700,
                    hebrew:
                        Localizations.localeOf(context).languageCode == 'he'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Skeletonizer(
          enabled: _loading,
          child: _buildBody(c, l),
        ),
      ),
    );
  }

  Widget _buildBody(EditorialColors c, AppLocalizations l) {
    final s = _structure;
    if (!_loading && s == null) {
      return _ViewerEmpty(
        icon: Icons.account_tree_outlined,
        title: l.bracketNoTeamsTitle,
        subtitle: l.bracketNoTeamsHint,
      );
    }
    if (!_loading && !_hasAnyPicks) {
      return _ViewerEmpty(
        icon: Icons.edit_off_outlined,
        title: l.bracketViewerEmptyTitle,
        subtitle: l.bracketViewerEmptyHint,
      );
    }

    final struct = s ??
        BracketStructure(
          leagueId: widget.leagueId,
          season: _season(),
          groupCount: 0,
          groupIds: const [],
          qualifiersPerGroup: 2,
          bestThirds: 0,
          stages: const [],
        );

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHero(c, l),
          _buildGroupSection(c, struct, l),
          _buildThirdsSection(c, struct, l),
          for (final stage in struct.knockoutStages)
            _buildKnockoutSection(c, stage, l),
        ],
      ),
    );
  }

  Widget _buildHero(EditorialColors c, AppLocalizations l) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(
        children: [
          Container(width: 18, height: 1, color: c.live),
          const SizedBox(width: 10),
          Text('$_total',
              style: EType.numeric(
                  color: c.live, size: 22, weight: FontWeight.w700)),
          const SizedBox(width: 6),
          Text(l.bracketPointsLabel.toUpperCase(),
              style: EType.label(color: c.inkDim, size: 9, letterSpacing: 1.6)),
        ],
      ),
    );
  }

  // ── Group stage ────────────────────────────────────────────────────────

  Widget _buildGroupSection(
      EditorialColors c, BracketStructure s, AppLocalizations l) {
    final groupStage = s.stage('groups');
    final hasRosters = _groupRosters.isNotEmpty;
    return _ViewerSection(
      title: groupStage?.label(_lang(context)) ?? l.bracketGroupStage,
      points: _stageEarned('groups') ?? groupStage?.points,
      child: !hasRosters
          ? _InlineNote(text: l.bracketNoTeamsHint)
          : Column(
              children: [
                for (final letter in _orderedGroupLetters(s))
                  _buildGroupCard(c, letter, l),
              ],
            ),
    );
  }

  List<String> _orderedGroupLetters(BracketStructure s) {
    final letters = s.groupIds.isNotEmpty
        ? s.groupIds
        : (_groupRosters.keys.toList()..sort());
    return letters.where((g) => _groupRosters.containsKey(g)).toList();
  }

  Widget _buildGroupCard(EditorialColors c, String letter, AppLocalizations l) {
    final roster = _groupRosters[letter] ?? const [];
    final sel = _groupSel[letter] ?? const [];
    // Only show teams the user actually ranked, in pick order, so the card
    // reads as "their prediction" rather than the full table.
    final ranked = [
      for (final t in sel)
        if (roster.contains(t)) t
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${l.bracketGroupWord} $letter'.toUpperCase(),
              style: EType.label(color: c.inkMute, size: 11, letterSpacing: 2)),
          const SizedBox(height: 10),
          if (ranked.isEmpty)
            Text('—', style: EType.body(color: c.inkDim, size: 14))
          else
            for (var i = 0; i < ranked.length; i++)
              _TeamRow(
                team: ranked[i],
                logo: _logoFor(ranked[i]),
                order: i + 1,
                // Once settled: mark each pick correct/wrong + its points.
                correct:
                    _groupsSettled ? _isQualifier(letter, ranked[i]) : null,
                points: _groupsSettled
                    ? _scoreGroupPick(letter, ranked[i], i)
                    : null,
              ),
        ],
      ),
    );
  }

  // ── Third-place qualifiers ───────────────────────────────────────────────

  Widget _buildThirdsSection(
      EditorialColors c, BracketStructure s, AppLocalizations l) {
    if (_thirdQual.isEmpty) return const SizedBox.shrink();
    return _ViewerSection(
      title: l.bracketThirdsTitle,
      initiallyExpanded: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final t in _thirdQual)
              Builder(builder: (context) {
                final settled = _thirdsSettled;
                final correct = settled ? _isBestThird(t) : null;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      _Crest(url: _logoFor(t), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(localizedTeamName(context, t),
                            style: EType.body(
                                color: correct == false ? c.inkMute : c.ink,
                                size: 14,
                                weight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (correct != null)
                        _ResultBadge(
                            correct: correct, points: _scoreThirdPick(t))
                      else
                        Text(l.bracketThirdPlace.toUpperCase(),
                            style: EType.label(
                                color: c.inkDim, size: 9, letterSpacing: 1)),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // ── Knockout rounds ──────────────────────────────────────────────────────

  Widget _buildKnockoutSection(
      EditorialColors c, BracketStage stage, AppLocalizations l) {
    final matches = _matchesFor(stage.key);
    final anyReady = matches.any(
        (m) => _participant(m, true) != null || _participant(m, false) != null);
    return _ViewerSection(
      title: stage.label(_lang(context)),
      points: _stageEarned(stage.key) ?? stage.points,
      initiallyExpanded: false,
      child: !anyReady
          ? _InlineNote(text: l.bracketPickPrevious)
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Column(
                children: [
                  for (final m in matches) _buildMatchCard(c, m, stage, l),
                ],
              ),
            ),
    );
  }

  Widget _buildMatchCard(EditorialColors c, BracketMatch m, BracketStage stage,
      AppLocalizations l) {
    final aTeam = _participant(m, true);
    final bTeam = _participant(m, false);
    final win = _winSel[m.id];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.hairline),
      ),
      child: Column(
        children: [
          _matchRow(c, m, stage, true, aTeam, win != null && win == aTeam, l),
          Divider(height: 1, color: c.hairline),
          _matchRow(c, m, stage, false, bTeam, win != null && win == bTeam, l),
        ],
      ),
    );
  }

  Widget _matchRow(EditorialColors c, BracketMatch m, BracketStage stage,
      bool sideA, String? team, bool isWinner, AppLocalizations l) {
    final slot = sideA ? m.a : m.b;
    final resolved = team != null;
    // Once the round is settled, show a result chip on the user's predicted
    // advancer: green +points if they actually advanced, red 0 otherwise.
    final showResult = isWinner && resolved && _knockoutSettled(stage.key);
    final advanced = showResult ? _isAdvancer(stage.key, team) : false;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: isWinner ? c.liveSoft : null),
      child: Row(
        children: [
          _Crest(url: resolved ? _logoFor(team) : null, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              resolved ? localizedTeamName(context, team) : _slotLabel(slot, l),
              style: EType.body(
                color: showResult && !advanced
                    ? c.inkMute
                    : (isWinner ? c.live : (resolved ? c.ink : c.inkDim)),
                size: 14,
                weight: isWinner
                    ? FontWeight.w700
                    : (resolved ? FontWeight.w500 : FontWeight.w400),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (showResult)
            _ResultBadge(correct: advanced, points: stage.points)
          else if (isWinner)
            Icon(Icons.check_circle, size: 18, color: c.live),
        ],
      ),
    );
  }

  String _slotLabel(BracketSlot s, AppLocalizations l) {
    switch (s.kind) {
      case 'gw':
        return '1${s.group}';
      case 'ru':
        return '2${s.group}';
      case 'third':
        return '${l.bracketThirdPlace} · ${s.thirdGroups.join('/')}';
      case 'win':
        return l.bracketTBD;
      default:
        return '';
    }
  }
}

// ── Reusable read-only pieces (mirror the editor's visual style) ────────────

class _ViewerSection extends StatefulWidget {
  const _ViewerSection({
    required this.title,
    required this.child,
    this.points,
    this.initiallyExpanded = true,
  });
  final String title;
  final Widget child;
  final int? points;
  final bool initiallyExpanded;

  @override
  State<_ViewerSection> createState() => _ViewerSectionState();
}

class _ViewerSectionState extends State<_ViewerSection> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: [
                  Container(width: 18, height: 1, color: c.live),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(widget.title.toUpperCase(),
                              style: EType.label(
                                  color: c.ink, size: 12, letterSpacing: 2),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (widget.points != null && widget.points! > 0) ...[
                          const SizedBox(width: 8),
                          _PointsBadge(points: widget.points!),
                        ],
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(Icons.keyboard_arrow_down,
                        size: 20, color: c.inkDim),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child: _expanded
                ? widget.child
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _PointsBadge extends StatelessWidget {
  const _PointsBadge({required this.points});
  final int points;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: c.live.withValues(alpha: 0.12),
        border: Border.all(color: c.live, width: 1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text('+$points',
          style:
              EType.numeric(color: c.live, size: 10, weight: FontWeight.w700)),
    );
  }
}

class _TeamRow extends StatelessWidget {
  const _TeamRow({
    required this.team,
    required this.logo,
    required this.order,
    this.correct,
    this.points,
  });
  final String team;
  final String? logo;
  final int order;
  // null = stage not settled yet (no result shown). Otherwise true/false marks
  // whether this pick qualified, with [points] earned for it.
  final bool? correct;
  final int? points;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: correct == false ? c.flag : c.live,
              border: Border.all(
                  color: correct == false ? c.flag : c.live, width: 1.5),
            ),
            child: Text('$order',
                style: EType.numeric(
                    color: c.pitch, size: 11, weight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          _Crest(url: logo, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(localizedTeamName(context, team),
                style: EType.body(
                    color: correct == false ? c.inkMute : c.ink,
                    size: 14,
                    weight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
          if (correct != null) ...[
            const SizedBox(width: 8),
            _ResultBadge(correct: correct!, points: points ?? 0),
          ],
        ],
      ),
    );
  }
}

// Correct/wrong + points chip shown on a settled pick. Green check "+N" when
// the pick qualified, red ✕ "0" when it didn't.
class _ResultBadge extends StatelessWidget {
  const _ResultBadge({required this.correct, required this.points});
  final bool correct;
  final int points;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final color = correct ? c.live : c.flag;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(correct ? Icons.check : Icons.close, size: 11, color: color),
          const SizedBox(width: 3),
          Text(correct ? '+$points' : '0',
              style: EType.numeric(
                  color: color, size: 10, weight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _Crest extends StatelessWidget {
  const _Crest({required this.url, this.size = 22});
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.12),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: (url == null || url!.isEmpty)
          ? Icon(Icons.shield_outlined, size: size * 0.6, color: c.inkDim)
          : Image.network(url!,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(Icons.shield_outlined,
                  size: size * 0.6, color: c.inkDim)),
    );
  }
}

class _InlineNote extends StatelessWidget {
  const _InlineNote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child:
          Text(text, style: EType.body(color: c.inkDim, size: 13, height: 1.4)),
    );
  }
}

class _ViewerEmpty extends StatelessWidget {
  const _ViewerEmpty({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: c.hairline, width: 1),
              ),
              child: Icon(icon, size: 26, color: c.inkDim),
            ),
            const SizedBox(height: 18),
            Text(title.toUpperCase(),
                style: EType.body(
                    size: 20,
                    color: c.ink,
                    weight: FontWeight.w700,
                    hebrew:
                        Localizations.localeOf(context).languageCode == 'he'),
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: EType.body(color: c.inkMute, size: 13, height: 1.5)),
          ],
        ),
      ),
    );
  }
}
