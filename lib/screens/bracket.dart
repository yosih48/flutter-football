import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:football/models/bracket.dart';
import 'package:football/resources/bracketMethods.dart';
import 'package:football/resources/league_config_service.dart';
import 'package:football/resources/standings_service.dart';
import 'package:football/screens/bracketLeague.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:football/utils/bracket_template.dart';
import 'package:football/utils/utils.dart';
import 'package:football/widgets/bracketLeaderboard.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skeletonizer/skeletonizer.dart';

// World Cup bracket-prediction screen. Layered on top of the per-game guessing
// game: users predict group qualifiers (1st/2nd per group) and who advances
// each knockout round up to the final. Bracket points live in their own
// leaderboard, kept separate from the matchday `points` ranking.
class BracketScreen extends StatefulWidget {
  const BracketScreen({
    super.key,
    required this.leagueId,
    required this.userId,
    required this.email,
    required this.userName,
  });

  final int leagueId;
  final String userId;
  final String email;
  final String userName;

  @override
  State<BracketScreen> createState() => _BracketScreenState();
}

class _BracketScreenState extends State<BracketScreen> {
  final _api = BracketMethods();
  final _standingsApi = StandingsService();

  static const String _kHelpSeenKey = 'bracketHelpSeen';

  bool _loading = true;
  bool _showRanking = false;

  BracketStructure? _structure;
  UserBracket? _bracket;

  // group letter -> ordered roster of team names (from standings).
  final Map<String, List<String>> _groupRosters = {};
  // team name -> crest url, for chip logos.
  final Map<String, String> _logos = {};

  List<BracketStanding> _ranking = [];

  // Ranking sub-view: private leagues (default, like the reference design) vs
  // the global board.
  bool _showLeagues = true;
  List<BracketLeagueInfo> _myLeagues = [];
  bool _leaguesBusy = false;

  // Local editable selections (seeded from _bracket on load).
  final Map<String, List<String>> _groupSel = {};
  // Knockout match tree: matchId -> winning team the user tapped.
  final Map<String, String> _winSel = {};
  // Predicted best third-placed qualifiers (≤ 8 teams, ≤ 1 per group).
  final List<String> _thirdQual = [];
  // Derived: which qualified third fills each R32 third slot (matchId -> team).
  Map<String, String> _thirdAssign = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final season = _seasonGuess();
    final results = await Future.wait([
      _api.fetchStructure(widget.leagueId),
      _api.fetchUserBracket(widget.userId, widget.leagueId, season: season),
      _standingsApi.getLeagueStandings(widget.leagueId),
      _api.fetchLeaderboard(widget.leagueId),
      _api.fetchMyLeagues(widget.userId, widget.leagueId),
    ]);
    if (!mounted) return;

    _structure = results[0] as BracketStructure?;
    _bracket = results[1] as UserBracket?;
    final standings = results[2] as List<StandingRow>?;
    _ranking = results[3] as List<BracketStanding>;
    _myLeagues = results[4] as List<BracketLeagueInfo>;

    _ingestStandings(standings);
    _seedSelections();

    setState(() => _loading = false);
    _maybeShowFirstTimeHelp();
  }

  // First open ever → surface the how-it-works sheet once, then remember.
  Future<void> _maybeShowFirstTimeHelp() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kHelpSeenKey) == true) return;
    if (!mounted) return;
    await _showHelpSheet();
    await prefs.setBool(_kHelpSeenKey, true);
  }

  int _seasonGuess() => _structure?.season ?? 2026;

  // Group standings → per-group rosters + a name→logo map. The API labels rows
  // "Group A" etc.; we key by the trailing letter to match structure.groupIds.
  void _ingestStandings(List<StandingRow>? rows) {
    _groupRosters.clear();
    _logos.clear();
    for (final r in rows ?? []) {
      if (r.teamName.isEmpty) continue;
      if (r.teamLogo.isNotEmpty) _logos[r.teamName] = r.teamLogo;
      final letter = _groupLetter(r.group);
      if (letter != null) {
        (_groupRosters[letter] ??= []).add(r.teamName);
      }
    }
  }

  String? _groupLetter(String? group) {
    if (group == null || group.isEmpty) return null;
    final tok = group.trim().split(RegExp(r'\s+')).last.toUpperCase();
    return tok.isEmpty ? null : tok;
  }

  void _seedSelections() {
    final gp = _bracket?.groupPicks ?? const {};
    // The 'thirds' key is the predicted best-third qualifiers, stored alongside
    // the real group picks (A–L) — the backend ignores it during scoring.
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
    _recomputeThirds();
    _seedTree();
  }

  // Rebuild the knockout match tree from saved advancePicks. Saved data is a
  // per-stage SET of winner names; we map each winner back onto its match in
  // bracket order so the tree shows the user's prior state. Stages are walked
  // top-down so each round's resolved winners feed the next round's slots.
  // Third-place slots are already resolved via _thirdAssign before this runs.
  void _seedTree() {
    _winSel.clear();
    final ap = _bracket?.advancePicks ?? const {};
    for (final stage in const ['R32', 'R16', 'QF', 'SF', 'F']) {
      final winners = {...(ap[stage] ?? const [])};
      for (final m in _matchesFor(stage)) {
        final a = _matchParticipant(m, true);
        final b = _matchParticipant(m, false);
        if (a != null && winners.contains(a)) {
          _winSel[m.id] = a;
        } else if (b != null && winners.contains(b)) {
          _winSel[m.id] = b;
        }
      }
    }
  }

  String _langCode(BuildContext context) =>
      Localizations.localeOf(context).languageCode;

  String? _logoFor(String team) => _logos[team];

  // ── Save handlers ────────────────────────────────────────────────────────

  Future<void> _save(String stage, Object picks) async {
    final err = await _api.saveStage(
      userId: widget.userId,
      email: widget.email,
      leagueId: widget.leagueId,
      season: _seasonGuess(),
      stage: stage,
      picks: picks,
    );
    if (!mounted) return;
    final l = AppLocalizations.of(context)!;
    if (err == null) {
      // Refresh from server so points/locks reflect the saved state.
      final fresh = await _api.fetchUserBracket(widget.userId, widget.leagueId,
          season: _seasonGuess());
      if (!mounted) return;
      if (fresh != null) {
        setState(() {
          _bracket = fresh;
          _seedSelections();
        });
      }
      _toast(l.bracketSaved, context.col.live);
    } else {
      _toast('${l.bracketSaveFailed}: $err', context.col.flag);
    }
  }

  void _toast(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: EType.body(color: Colors.white, size: 13)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Scaffold(
      backgroundColor: c.pitch,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: c.pitch,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: c.ink),
        actions: [
          IconButton(
            tooltip: AppLocalizations.of(context)!.bracketHelpTitle,
            icon: Icon(Icons.help_outline,
                color: c.ink, textDirection: TextDirection.ltr),
            onPressed: _showHelpSheet,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildHero(c),
            _buildTabStrip(c),
            Expanded(
              child: Skeletonizer(
                enabled: _loading,
                child: _showRanking
                    ? _buildRanking(c)
                    : _buildMyBracket(c),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(EditorialColors c) {
    final l = AppLocalizations.of(context)!;
    final lang = _langCode(context);
    final name = LeagueConfigService().nameFor(widget.leagueId, lang) ??
        l.bracketTitle;
    final total = _bracket?.totalPoints ?? 0;
    return Container(
      color: c.pitch,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.bracketTitle.toUpperCase(),
              style: EType.label(color: c.inkDim, size: 10, letterSpacing: 3)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(name.toUpperCase(),
                    style: EType.display(size: 30, color: c.ink, letterSpacing: 1.2),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$total',
                      style: EType.numeric(
                          color: c.live, size: 26, weight: FontWeight.w700)),
                  Text(l.bracketPointsLabel.toUpperCase(),
                      style: EType.label(
                          color: c.inkDim, size: 9, letterSpacing: 1.6)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabStrip(EditorialColors c) {
    final l = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: c.pitch,
        border: Border(bottom: BorderSide(color: c.hairline, width: 1)),
      ),
      child: Row(
        children: [
          _Tab(
            label: l.bracketMyBracketTab,
            icon: Icons.account_tree_outlined,
            active: !_showRanking,
            onTap: () => setState(() => _showRanking = false),
          ),
          _Tab(
            label: l.bracketRankingTab,
            icon: Icons.leaderboard_outlined,
            active: _showRanking,
            onTap: () => setState(() => _showRanking = true),
          ),
        ],
      ),
    );
  }

  // ── My Bracket ────────────────────────────────────────────────────────

  Widget _buildMyBracket(EditorialColors c) {
    final structure = _structure;
    if (!_loading && structure == null) {
      return _Empty(
        icon: Icons.account_tree_outlined,
        title: AppLocalizations.of(context)!.bracketNoTeamsTitle,
        subtitle: AppLocalizations.of(context)!.bracketNoTeamsHint,
      );
    }
    final s = structure ??
        BracketStructure(
          leagueId: widget.leagueId,
          season: 2026,
          groupCount: 0,
          groupIds: const [],
          qualifiersPerGroup: 2,
          bestThirds: 0,
          stages: const [],
        );
    final now = DateTime.now().toUtc();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGroupSection(c, s, now),
          _buildThirdsSection(c, s, now),
          for (final stage in s.knockoutStages)
            _buildKnockoutSection(c, s, stage, now),
        ],
      ),
    );
  }

  // ── Group stage ─────────────────────────────────────────────────────────

  Widget _buildGroupSection(
      EditorialColors c, BracketStructure s, DateTime now) {
    final l = AppLocalizations.of(context)!;
    final groupStage = s.stage('groups');
    final locked = groupStage?.isLocked(now) ?? false;
    final hasRosters = _groupRosters.isNotEmpty;

    return _Section(
      title: groupStage?.label(_langCode(context)) ?? l.bracketGroupStage,
      hint: locked ? l.bracketLockedLabel : l.bracketGroupHint,
      points: groupStage?.points,
      locked: locked,
      child: !hasRosters
          ? _InlineNote(text: l.bracketNoTeamsHint)
          : Column(
              children: [
                for (final letter in _orderedGroupLetters(s))
                  _buildGroupCard(c, letter, locked),
                const SizedBox(height: 12),
                if (!locked)
                  _SaveButton(
                    label: l.bracketSave,
                    onTap: () => _save('groups', _groupSel),
                  ),
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

  Widget _buildGroupCard(EditorialColors c, String letter, bool locked) {
    final l = AppLocalizations.of(context)!;
    final roster = _groupRosters[letter] ?? const [];
    final sel = _groupSel[letter] ?? const [];

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
          for (final team in roster)
            _GroupTeamRow(
              team: team,
              logo: _logoFor(team),
              order: _orderOf(sel, team),
              locked: locked,
              onTap: locked ? null : () => _toggleGroup(letter, team),
            ),
        ],
      ),
    );
  }

  // Returns 1 if team is predicted 1st, 2 if 2nd, 0 if unpicked.
  int _orderOf(List<String> sel, String team) {
    final i = sel.indexOf(team);
    return i < 0 ? 0 : i + 1;
  }

  void _toggleGroup(String letter, String team) {
    final sel = List<String>.from(_groupSel[letter] ?? const []);
    if (sel.contains(team)) {
      sel.remove(team);
    } else if (sel.length < 2) {
      sel.add(team);
    } else {
      // Replace the 2nd pick with the new one.
      sel[1] = team;
    }
    setState(() {
      _groupSel[letter] = sel;
      _revalidateChain();
    });
  }

  // ── Third-place qualifiers ───────────────────────────────────────────────
  //
  // The 8 best third-placed teams join the R32 between the group stage and the
  // bracket. The user marks, per group, the team they think finishes 3rd AND
  // survives the best-thirds cut (≤ 8 total). Those picks feed the R32 third
  // slots via the FIFA candidate-group template.

  Widget _buildThirdsSection(
      EditorialColors c, BracketStructure s, DateTime now) {
    final l = AppLocalizations.of(context)!;
    // Stored under the groups stage, so it locks with the group picks.
    final locked = s.stage('groups')?.isLocked(now) ?? false;
    final hasRosters = _groupRosters.isNotEmpty;

    return _Section(
      title: l.bracketThirdsTitle,
      hint: locked
          ? l.bracketLockedLabel
          : '${l.bracketThirdsHint} ֲ· ${_thirdQual.length}/8',
      locked: locked,
      initiallyExpanded: false,
      child: !hasRosters
          ? _InlineNote(text: l.bracketNoTeamsHint)
          : Column(
              children: [
                for (final letter in _orderedGroupLetters(s))
                  _buildThirdGroupCard(c, letter, locked),
                const SizedBox(height: 12),
                if (!locked)
                  _SaveButton(label: l.bracketSave, onTap: _saveThirds),
              ],
            ),
    );
  }

  Widget _buildThirdGroupCard(EditorialColors c, String letter, bool locked) {
    final l = AppLocalizations.of(context)!;
    final roster = _groupRosters[letter] ?? const [];
    final picks = _groupSel[letter] ?? const [];
    // Only the teams not already predicted to finish 1st/2nd can be a third.
    final leftovers = roster.where((t) => !picks.contains(t)).toList();
    if (leftovers.isEmpty) return const SizedBox.shrink();

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
          for (final team in leftovers)
            InkWell(
              onTap: locked ? null : () => _toggleThird(letter, team),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    _ThirdBadge(selected: _thirdQual.contains(team)),
                    const SizedBox(width: 10),
                    _Crest(url: _logoFor(team), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(team,
                          style: EType.body(
                              color: _thirdQual.contains(team)
                                  ? c.ink
                                  : c.inkMute,
                              size: 14,
                              weight: _thirdQual.contains(team)
                                  ? FontWeight.w600
                                  : FontWeight.w400),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _toggleThird(String group, String team) {
    final l = AppLocalizations.of(context)!;
    if (!_thirdQual.contains(team)) {
      final sameGroup =
          _thirdQual.where((t) => _groupOf(t) == group).length;
      // A new pick in a fresh group would exceed the 8 best-third cap.
      if (sameGroup == 0 && _thirdQual.length >= 8) {
        _toast(l.bracketThirdsFull, context.col.amber);
        return;
      }
    }
    setState(() {
      if (_thirdQual.contains(team)) {
        _thirdQual.remove(team);
      } else {
        // At most one third per group.
        _thirdQual.removeWhere((t) => _groupOf(t) == group);
        _thirdQual.add(team);
      }
      _revalidateChain();
    });
  }

  Future<void> _saveThirds() => _save('groups', {'thirds': _thirdQual});

  // ── Knockout rounds (FIFA slot-template match tree) ─────────────────────

  Widget _buildKnockoutSection(
      EditorialColors c, BracketStructure s, BracketStage stage, DateTime now) {
    final l = AppLocalizations.of(context)!;
    final matches = _matchesFor(stage.key);
    final winners = _winnersForStage(stage.key);
    final cap = stage.advancers ?? matches.length;
    final locked = stage.isLocked(now);
    // The round is ready once at least one match has a known participant
    // (group picks made, or the feeding round resolved).
    final anyReady = matches.any((m) =>
        _matchParticipant(m, true) != null ||
        _matchParticipant(m, false) != null);

    return _Section(
      title: stage.label(_langCode(context)),
      hint: locked
          ? l.bracketLockedLabel
          : anyReady
              ? '${l.bracketAdvanceLabel}  ${winners.length}/$cap'
              : l.bracketPickPrevious,
      points: stage.points,
      locked: locked || !anyReady,
      initiallyExpanded: false,
      child: !anyReady
          ? _InlineNote(text: l.bracketPickPrevious)
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Column(
                children: [
                  for (final m in matches) _buildMatchCard(c, m, locked),
                  const SizedBox(height: 12),
                  if (!locked)
                    _SaveButton(
                      label: l.bracketSave,
                      onTap: () =>
                          _save(stage.key, _winnersForStage(stage.key)),
                    ),
                ],
              ),
            ),
    );
  }

  List<BracketMatch> _matchesFor(String stage) => matchesForStage(stage);

  // Winners the user has tapped for a stage = the advance set the backend
  // scores (set-based scoring is unchanged by the match-tree UI).
  List<String> _winnersForStage(String stage) => _matchesFor(stage)
      .map((m) => _winSel[m.id])
      .whereType<String>()
      .toList();

  String? _groupOf(String team) {
    for (final e in _groupRosters.entries) {
      if (e.value.contains(team)) return e.key;
    }
    return null;
  }

  // Resolve the concrete team filling one side of a match, or null if still
  // undetermined (group not picked, third not chosen, feeding match open).
  String? _matchParticipant(BracketMatch m, bool sideA) => resolveParticipant(
        m,
        sideA,
        groupSel: _groupSel,
        thirdAssign: _thirdAssign,
        winSel: _winSel,
      );

  // Assign the user's qualified thirds onto the R32 third slots via the shared
  // FIFA Annex-C lookup (or bipartite fallback for a partial selection).
  void _recomputeThirds() {
    _thirdAssign = assignThirds(_thirdQual, _groupRosters);
  }

  void _tapSide(BracketMatch m, bool sideA) {
    final team = _matchParticipant(m, sideA);
    if (team == null) return; // participant not resolved yet
    setState(() => _setWinner(m, team));
  }

  // Toggle the winner of a match, then re-validate downstream rounds so any
  // pick that referenced a now-changed winner is dropped.
  void _setWinner(BracketMatch m, String team) {
    if (_winSel[m.id] == team) {
      _winSel.remove(m.id);
    } else {
      _winSel[m.id] = team;
    }
    _revalidateChain();
  }

  // Drop selections that are no longer consistent: a qualified third that got
  // promoted to a group pick, then re-derive the slot assignment, then any
  // match winner that is no longer one of the (re-resolved) participants. Walks
  // stages top-down so each round sees the corrected winners feeding it.
  void _revalidateChain() {
    _thirdQual.removeWhere((t) => _groupSel.values.any((p) => p.contains(t)));
    _recomputeThirds();
    for (final stage in const ['R32', 'R16', 'QF', 'SF', 'F']) {
      for (final m in _matchesFor(stage)) {
        final w = _winSel[m.id];
        if (w == null) continue;
        final a = _matchParticipant(m, true);
        final b = _matchParticipant(m, false);
        if (w != a && w != b) _winSel.remove(m.id);
      }
    }
  }

  Widget _buildMatchCard(EditorialColors c, BracketMatch m, bool locked) {
    final aTeam = _matchParticipant(m, true);
    final bTeam = _matchParticipant(m, false);
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
          _buildMatchRow(
              c, m, true, aTeam, win != null && win == aTeam, locked),
          Divider(height: 1, color: c.hairline),
          _buildMatchRow(
              c, m, false, bTeam, win != null && win == bTeam, locked),
        ],
      ),
    );
  }

  Widget _buildMatchRow(EditorialColors c, BracketMatch m, bool sideA, String? team,
      bool isWinner, bool locked) {
    final slot = sideA ? m.a : m.b;
    final resolved = team != null;
    final tappable = !locked && resolved;
    return InkWell(
      onTap: tappable ? () => _tapSide(m, sideA) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: isWinner ? c.liveSoft : null),
        child: Row(
          children: [
            _Crest(url: resolved ? _logoFor(team) : null, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                resolved ? team : _slotLabel(slot),
                style: EType.body(
                  color: isWinner
                      ? c.live
                      : (resolved ? c.ink : c.inkDim),
                  size: 14,
                  weight: isWinner
                      ? FontWeight.w700
                      : (resolved ? FontWeight.w500 : FontWeight.w400),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isWinner)
              Icon(Icons.check_circle, size: 18, color: c.live)
            else if (resolved && !locked)
              Icon(Icons.radio_button_unchecked, size: 16, color: c.hairlineHi),
          ],
        ),
      ),
    );
  }

  String _slotLabel(BracketSlot s) {
    final l = AppLocalizations.of(context)!;
    switch (s.kind) {
      case 'gw':
        return '1${s.group}';
      case 'ru':
        return '2${s.group}';
      case 'third':
        return '${l.bracketThirdPlace} ֲ· ${s.thirdGroups.join('/')}';
      case 'win':
        return l.bracketTBD;
      default:
        return '';
    }
  }

  // ── Ranking ──────────────────────────────────────────────────────────

  Widget _buildRanking(EditorialColors c) {
    return Column(
      children: [
        _buildRankSubTabs(c),
        Expanded(
          child: _showLeagues ? _buildLeaguesList(c) : _buildGlobalBoard(c),
        ),
      ],
    );
  }

  // Leagues | Global board sub-toggle inside the Ranking tab.
  Widget _buildRankSubTabs(EditorialColors c) {
    final l = AppLocalizations.of(context)!;
    Widget chip(String label, bool active, VoidCallback onTap) => Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              margin: const EdgeInsets.all(3),
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: active ? c.card : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                label.toUpperCase(),
                textAlign: TextAlign.center,
                style: EType.label(
                    color: active ? c.ink : c.inkDim,
                    size: 11,
                    letterSpacing: 1.2),
              ),
            ),
          ),
        );
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      decoration: BoxDecoration(
        color: c.terrace,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: c.hairline),
      ),
      child: Row(
        children: [
          chip(l.bracketLeaguesTab, _showLeagues,
              () => setState(() => _showLeagues = true)),
          chip(l.bracketGlobalTab, !_showLeagues,
              () => setState(() => _showLeagues = false)),
        ],
      ),
    );
  }

  // ── Global board ───────────────────────────────────────────────────────

  Widget _buildGlobalBoard(EditorialColors c) {
    final l = AppLocalizations.of(context)!;
    if (!_loading && _ranking.isEmpty) {
      return _Empty(
        icon: Icons.leaderboard_outlined,
        title: l.bracketRankingEmptyTitle,
        subtitle: l.bracketRankingEmptyHint,
      );
    }
    return BracketLeaderboardList(
      rows: _ranking,
      structure: _structure,
      highlightName: widget.userName,
      loading: _loading,
    );
  }

  // ── Private leagues ──────────────────────────────────────────────────────

  Widget _buildLeaguesList(EditorialColors c) {
    final l = AppLocalizations.of(context)!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: _LeagueActionBtn(
                  icon: Icons.add,
                  label: l.bracketLeagueCreate,
                  filled: true,
                  onTap: _leaguesBusy ? null : _showCreateDialog,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LeagueActionBtn(
                  icon: Icons.login,
                  label: l.bracketLeagueJoin,
                  filled: false,
                  onTap: _leaguesBusy ? null : _showJoinDialog,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: (!_loading && _myLeagues.isEmpty)
              ? _Empty(
                  icon: Icons.groups_outlined,
                  title: l.bracketLeaguesEmptyTitle,
                  subtitle: l.bracketLeaguesEmptyHint,
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  itemCount: _myLeagues.length,
                  itemBuilder: (ctx, i) => _leagueCard(c, l, _myLeagues[i]),
                ),
        ),
      ],
    );
  }

  Widget _leagueCard(EditorialColors c, AppLocalizations l, BracketLeagueInfo lg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.hairline),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openLeague(lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(lg.name.toUpperCase(),
                              style: EType.display(
                                  size: 18, color: c.ink, letterSpacing: 0.6),
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (lg.isOwner) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.star, size: 14, color: c.live),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.group_outlined, size: 14, color: c.inkDim),
                        const SizedBox(width: 5),
                        Text('${lg.memberCount} ${l.bracketLeagueMembers}',
                            style: EType.body(color: c.inkDim, size: 12)),
                        const SizedBox(width: 12),
                        Icon(Icons.tag, size: 14, color: c.inkDim),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(lg.code,
                              style: EType.numeric(color: c.inkMute, size: 12),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: c.inkDim),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openLeague(BracketLeagueInfo lg) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BracketLeagueScreen(
          league: lg,
          userId: widget.userId,
          userName: widget.userName,
          structure: _structure,
        ),
      ),
    );
    if (changed == true) _reloadLeagues();
  }

  Future<void> _reloadLeagues() async {
    final leagues = await _api.fetchMyLeagues(widget.userId, widget.leagueId);
    if (mounted) setState(() => _myLeagues = leagues);
  }

  // ── How-it-works help sheet ─────────────────────────────────────────────
  Future<void> _showHelpSheet() {
    final c = context.col;
    final l = AppLocalizations.of(context)!;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.pitch,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (ctx, scroll) => Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.hairlineHi,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Container(width: 18, height: 1, color: c.live),
                    const SizedBox(width: 10),
                    Text(l.bracketHelpTitle.toUpperCase(),
                        style: EType.label(
                            color: c.ink, size: 12, letterSpacing: 2.4)),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    Text(l.bracketHelpIntro,
                        style: EType.body(color: c.inkMute, size: 14)),
                    const SizedBox(height: 8),
                    _helpEntry(c, Icons.grid_view_outlined,
                        l.bracketHelpGroupsTitle, l.bracketHelpGroupsBody),
                    _helpEntry(c, Icons.looks_3_outlined,
                        l.bracketHelpThirdsTitle, l.bracketHelpThirdsBody),
                    _helpEntry(c, Icons.account_tree_outlined,
                        l.bracketHelpKnockoutTitle, l.bracketHelpKnockoutBody),
                    _helpEntry(c, Icons.star_outline,
                        l.bracketHelpPointsTitle, l.bracketHelpPointsBody),
                    _helpEntry(c, Icons.lock_clock_outlined,
                        l.bracketHelpLockTitle, l.bracketHelpLockBody),
                    _helpEntry(c, Icons.groups_outlined,
                        l.bracketHelpLeaguesTitle, l.bracketHelpLeaguesBody),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: Material(
                      color: c.live,
                      borderRadius: BorderRadius.circular(2),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(2),
                        onTap: () => Navigator.of(ctx).pop(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            l.bracketHelpGotIt.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: EType.label(
                                color: c.pitch, size: 12, letterSpacing: 1.8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _helpEntry(
      EditorialColors c, IconData icon, String title, String body) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: c.live),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.toUpperCase(),
                    style: EType.label(
                        color: c.ink, size: 11, letterSpacing: 1.6)),
                const SizedBox(height: 6),
                Text(body,
                    style: EType.body(color: c.inkMute, size: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Editorial dialog scaffolding (matches lib/screens/table.dart) ────────
  Widget _editorialDialog({
    required String title,
    required Widget body,
    required List<Widget> actions,
  }) {
    final c = context.col;
    return Dialog(
      backgroundColor: c.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(2),
        side: BorderSide(color: c.hairline, width: 1),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 18, height: 1, color: c.live),
                const SizedBox(width: 10),
                Text(title.toUpperCase(),
                    style: EType.label(
                        color: c.ink, size: 11, letterSpacing: 2.4)),
              ],
            ),
            const SizedBox(height: 18),
            body,
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: actions,
            ),
          ],
        ),
      ),
    );
  }

  Widget _editorialField({
    required TextEditingController controller,
    required String label,
    int? maxLength,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final c = context.col;
    return TextField(
      controller: controller,
      autofocus: true,
      cursorColor: c.live,
      cursorWidth: 1.5,
      maxLength: maxLength,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      style: EType.body(color: c.ink, size: 14),
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        labelStyle:
            EType.label(color: c.inkDim, size: 11, letterSpacing: 1.6),
        floatingLabelStyle:
            EType.label(color: c.live, size: 11, letterSpacing: 1.6),
        filled: true,
        fillColor: c.terrace,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: BorderSide(color: c.hairline, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: BorderSide(color: c.hairline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: BorderSide(color: c.live, width: 1),
        ),
      ),
    );
  }

  Widget _ghostBtn(String label, VoidCallback onPressed, {Color? color}) {
    final c = context.col;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      ),
      child: Text(
        label.toUpperCase(),
        style: EType.label(
            color: color ?? c.inkMute, size: 11, letterSpacing: 1.8),
      ),
    );
  }

  Widget _solidBtn(String label, VoidCallback onPressed) {
    final c = context.col;
    return Material(
      color: c.live,
      borderRadius: BorderRadius.circular(2),
      child: InkWell(
        borderRadius: BorderRadius.circular(2),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Text(
            label.toUpperCase(),
            style: EType.label(color: c.pitch, size: 11, letterSpacing: 1.8),
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateDialog() async {
    final l = AppLocalizations.of(context)!;
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => _editorialDialog(
        title: l.bracketLeagueCreateTitle,
        body: _editorialField(
          controller: ctrl,
          label: l.bracketLeagueNameHint,
          maxLength: 40,
        ),
        actions: [
          _ghostBtn(l.cancel, () => Navigator.pop(ctx)),
          const SizedBox(width: 8),
          _solidBtn(l.bracketLeagueCreate,
              () => Navigator.pop(ctx, ctrl.text.trim())),
        ],
      ),
    );
    if (name == null || name.length < 2) return;
    setState(() => _leaguesBusy = true);
    final res = await _api.createLeague(
        name: name, leagueId: widget.leagueId, ownerUserId: widget.userId);
    if (!mounted) return;
    setState(() => _leaguesBusy = false);
    if (res.league != null) {
      setState(() => _myLeagues = [..._myLeagues, res.league!]);
      showSnackBar(context, l.bracketLeagueCreated, tone: SnackTone.success);
    } else {
      showSnackBar(context, res.error ?? l.bracketLeagueActionFailed,
          tone: SnackTone.error);
    }
  }

  Future<void> _showJoinDialog() async {
    final l = AppLocalizations.of(context)!;
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => _editorialDialog(
        title: l.bracketLeagueJoinTitle,
        body: _editorialField(
          controller: ctrl,
          label: l.bracketLeagueCodeHint,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
          ],
        ),
        actions: [
          _ghostBtn(l.cancel, () => Navigator.pop(ctx)),
          const SizedBox(width: 8),
          _solidBtn(l.bracketLeagueJoin,
              () => Navigator.pop(ctx, ctrl.text.trim())),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;
    setState(() => _leaguesBusy = true);
    final res = await _api.joinLeague(userId: widget.userId, code: code);
    if (!mounted) return;
    setState(() => _leaguesBusy = false);
    if (res.league != null) {
      if (res.alreadyMember) {
        showSnackBar(context, l.bracketLeagueAlreadyMember,
            tone: SnackTone.warning);
      } else {
        showSnackBar(context, l.bracketLeagueJoined, tone: SnackTone.success);
      }
      _reloadLeagues();
    } else {
      showSnackBar(context, res.error ?? l.bracketLeagueActionFailed,
          tone: SnackTone.error);
    }
  }

}

// ── Reusable pieces ─────────────────────────────────────────────────────

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 16, color: active ? c.ink : c.inkDim),
                  const SizedBox(width: 8),
                  Text(label.toUpperCase(),
                      style: EType.label(
                          color: active ? c.ink : c.inkDim,
                          size: 11,
                          letterSpacing: 1.6)),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 2,
              width: active ? 60.0 : 0.0,
              color: c.live,
            ),
          ],
        ),
      ),
    );
  }
}

// Create / Join buttons atop the private-leagues list.
class _LeagueActionBtn extends StatelessWidget {
  const _LeagueActionBtn({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final fg = filled ? Colors.black : c.ink;
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: filled ? c.live : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: filled ? null : Border.all(color: c.hairline),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 8),
              Text(label.toUpperCase(),
                  style: EType.label(color: fg, size: 11, letterSpacing: 1.2)),
            ],
          ),
        ),
      ),
    );
  }
}

// Collapsible section. The header is tappable to hide/show its content so the
// long list of stages (groups + thirds + 5 knockout rounds) doesn't force a
// lot of scrolling to reach the next one.
class _Section extends StatefulWidget {
  const _Section({
    required this.title,
    required this.hint,
    required this.child,
    this.locked = false,
    this.initiallyExpanded = true,
    this.points,
  });
  final String title;
  final String hint;
  final Widget child;
  final bool locked;
  final bool initiallyExpanded;
  // Points awarded per correct pick in this stage; rendered as a +N badge.
  final int? points;

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
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
                  Container(
                      width: 18,
                      height: 1,
                      color: widget.locked ? c.inkDim : c.live),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(widget.title.toUpperCase(),
                                  style: EType.label(
                                      color: c.ink,
                                      size: 12,
                                      letterSpacing: 2),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            if (widget.points != null && widget.points! > 0) ...[
                              const SizedBox(width: 8),
                              _PointsBadge(points: widget.points!, locked: widget.locked),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(widget.hint.toUpperCase(),
                            style: EType.label(
                                color: widget.locked ? c.inkDim : c.inkMute,
                                size: 9,
                                letterSpacing: 1.4),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  if (widget.locked)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(Icons.lock_outline, size: 14, color: c.inkDim),
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

// "+N" points badge shown beside a section title.
class _PointsBadge extends StatelessWidget {
  const _PointsBadge({required this.points, this.locked = false});
  final int points;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final color = locked ? c.inkDim : c.live;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text('+$points',
          style: EType.numeric(
              color: color, size: 10, weight: FontWeight.w700)),
    );
  }
}

class _GroupTeamRow extends StatelessWidget {
  const _GroupTeamRow({
    required this.team,
    required this.logo,
    required this.order,
    required this.locked,
    required this.onTap,
  });
  final String team;
  final String? logo;
  final int order; // 0 unpicked, 1 first, 2 second
  final bool locked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final picked = order > 0;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            _OrderBadge(order: order),
            const SizedBox(width: 10),
            _Crest(url: logo, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(team,
                  style: EType.body(
                      color: picked ? c.ink : c.inkMute,
                      size: 14,
                      weight: picked ? FontWeight.w600 : FontWeight.w400),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderBadge extends StatelessWidget {
  const _OrderBadge({required this.order});
  final int order;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final picked = order > 0;
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: picked ? c.live : Colors.transparent,
        border: Border.all(color: picked ? c.live : c.hairlineHi, width: 1.5),
      ),
      child: picked
          ? Text('$order',
              style: EType.numeric(
                  color: c.pitch, size: 11, weight: FontWeight.w700))
          : null,
    );
  }
}

class _ThirdBadge extends StatelessWidget {
  const _ThirdBadge({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? c.live : Colors.transparent,
        border:
            Border.all(color: selected ? c.live : c.hairlineHi, width: 1.5),
      ),
      child: selected ? Icon(Icons.check, size: 13, color: c.pitch) : null,
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
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.shield_outlined, size: size * 0.6, color: c.inkDim)),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.live,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(label.toUpperCase(),
              style: EType.label(
                  color: c.pitch, size: 12, letterSpacing: 2.4)),
        ),
      ),
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
      child: Text(text,
          style: EType.body(color: c.inkDim, size: 13, height: 1.4)),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
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
    return Padding(
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
              style: EType.display(size: 22, color: c.ink, letterSpacing: 1.2),
              textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: EType.body(color: c.inkMute, size: 13, height: 1.5)),
        ],
      ),
    );
  }
}
