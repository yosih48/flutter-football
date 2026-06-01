import 'package:flutter/material.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:football/models/bracket.dart';
import 'package:football/resources/bracketMethods.dart';
import 'package:football/resources/league_config_service.dart';
import 'package:football/resources/standings_service.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:skeletonizer/skeletonizer.dart';

// World Cup bracket-prediction screen. Layered on top of the per-game guessing
// game: users predict group qualifiers (1st/2nd per group), who advances each
// knockout round, and the tournament champion. Bracket points live in their
// own leaderboard, kept separate from the matchday `points` ranking.
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

  bool _loading = true;
  bool _showRanking = false;

  BracketStructure? _structure;
  UserBracket? _bracket;

  // group letter -> ordered roster of team names (from standings).
  final Map<String, List<String>> _groupRosters = {};
  // team name -> crest url, for chip logos.
  final Map<String, String> _logos = {};
  List<String> _allTeams = [];

  List<BracketStanding> _ranking = [];

  // Local editable selections (seeded from _bracket on load).
  final Map<String, List<String>> _groupSel = {};
  // Knockout match tree: matchId -> winning team the user tapped.
  final Map<String, String> _winSel = {};
  // Third-place R32 slots the user filled: matchId -> chosen team name.
  final Map<String, String> _thirdSel = {};
  String? _championSel;

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
    ]);
    if (!mounted) return;

    _structure = results[0] as BracketStructure?;
    _bracket = results[1] as UserBracket?;
    final standings = results[2] as List<StandingRow>?;
    _ranking = results[3] as List<BracketStanding>;

    _ingestStandings(standings);
    _seedSelections();

    setState(() => _loading = false);
  }

  int _seasonGuess() => _structure?.season ?? 2026;

  // Group standings → per-group rosters + a name→logo map. The API labels rows
  // "Group A" etc.; we key by the trailing letter to match structure.groupIds.
  void _ingestStandings(List<StandingRow>? rows) {
    _groupRosters.clear();
    _logos.clear();
    final all = <String>[];
    for (final r in rows ?? []) {
      if (r.teamName.isEmpty) continue;
      if (r.teamLogo.isNotEmpty) _logos[r.teamName] = r.teamLogo;
      if (!all.contains(r.teamName)) all.add(r.teamName);
      final letter = _groupLetter(r.group);
      if (letter != null) {
        (_groupRosters[letter] ??= []).add(r.teamName);
      }
    }
    _allTeams = all;
  }

  String? _groupLetter(String? group) {
    if (group == null || group.isEmpty) return null;
    final tok = group.trim().split(RegExp(r'\s+')).last.toUpperCase();
    return tok.isEmpty ? null : tok;
  }

  void _seedSelections() {
    _groupSel
      ..clear()
      ..addAll(_bracket?.groupPicks.map((k, v) => MapEntry(k, [...v])) ?? {});
    _championSel = _bracket?.champion;
    _seedTree();
  }

  // Rebuild the knockout match tree from saved advancePicks. Saved data is a
  // per-stage SET of winner names; we map each winner back onto its match in
  // bracket order so the tree shows the user's prior state. Stages are walked
  // top-down so each round's resolved winners feed the next round's slots.
  void _seedTree() {
    _winSel.clear();
    _thirdSel.clear();
    final ap = _bracket?.advancePicks ?? const {};

    // R32: 24 of the 32 slots resolve from group picks; the other 8 are
    // third-placed teams the user can't pick directly, so we recover them by
    // matching any saved winner whose group is an eligible third for that slot.
    final pool = List<String>.from(ap['R32'] ?? const []);
    for (final m in _matchesFor('R32')) {
      final a = _matchParticipant(m, true);
      final b = _matchParticipant(m, false);
      String? winner;
      if (a != null && pool.contains(a)) {
        winner = a;
      } else if (b != null && pool.contains(b)) {
        winner = b;
      }
      if (winner != null) {
        _winSel[m.id] = winner;
        pool.remove(winner);
        continue;
      }
      final thirdGroups = _isThird(m.a)
          ? m.a.thirdGroups
          : (_isThird(m.b) ? m.b.thirdGroups : const <String>[]);
      if (thirdGroups.isNotEmpty) {
        for (final t in pool) {
          final g = _groupOf(t);
          if (g != null && thirdGroups.contains(g)) {
            _thirdSel[m.id] = t;
            _winSel[m.id] = t;
            pool.remove(t);
            break;
          }
        }
      }
    }

    for (final stage in const ['R16', 'QF', 'SF', 'F']) {
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
          _buildChampionSection(c, s, now),
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

  // ── Champion ──────────────────────────────────────────────────────────

  Widget _buildChampionSection(
      EditorialColors c, BracketStructure s, DateTime now) {
    final l = AppLocalizations.of(context)!;
    final stage = s.stage('champion');
    final locked = stage?.isLocked(now) ?? false;
    final pts = stage?.points ?? 0;

    return _Section(
      title: stage?.label(_langCode(context)) ?? l.bracketChampionLabel,
      hint: locked ? l.bracketLockedLabel : '${l.bracketChampionHint} · +$pts ${l.pst}',
      locked: locked,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: GestureDetector(
          onTap: (locked || _allTeams.isEmpty) ? null : _openChampionPicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _championSel != null ? c.live : c.hairline,
                width: _championSel != null ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.emoji_events_outlined,
                    size: 20, color: _championSel != null ? c.live : c.inkDim),
                const SizedBox(width: 12),
                if (_championSel != null) ...[
                  _Crest(url: _logoFor(_championSel!), size: 24),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    (_championSel ?? l.bracketSelectTeamTitle).toUpperCase(),
                    style: EType.display(
                        size: 18,
                        color: _championSel != null ? c.ink : c.inkDim,
                        letterSpacing: 0.6),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!locked)
                  Icon(Icons.chevron_right, size: 20, color: c.inkDim),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openChampionPicker() async {
    final picked = await _showTeamPicker(_allTeams, _championSel);
    if (picked == null) return;
    setState(() => _championSel = picked);
    await _save('champion', picked);
  }

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
              ? '${l.bracketAdvanceLabel}  ${winners.length}/$cap · +${stage.points} ${l.pst}'
              : l.bracketPickPrevious,
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

  List<_Match> _matchesFor(String stage) =>
      _kBracketTemplate.where((m) => m.stage == stage).toList();

  // Winners the user has tapped for a stage = the advance set the backend
  // scores (set-based scoring is unchanged by the match-tree UI).
  List<String> _winnersForStage(String stage) => _matchesFor(stage)
      .map((m) => _winSel[m.id])
      .whereType<String>()
      .toList();

  bool _isThird(_Slot s) => s.kind == 'third';

  String? _groupOf(String team) {
    for (final e in _groupRosters.entries) {
      if (e.value.contains(team)) return e.key;
    }
    return null;
  }

  // Resolve the concrete team filling one side of a match, or null if still
  // undetermined (group not picked, third not chosen, feeding match open).
  String? _matchParticipant(_Match m, bool sideA) {
    final s = sideA ? m.a : m.b;
    switch (s.kind) {
      case 'gw':
        final p = _groupSel[s.group] ?? const [];
        return p.isNotEmpty ? p[0] : null;
      case 'ru':
        final p = _groupSel[s.group] ?? const [];
        return p.length > 1 ? p[1] : null;
      case 'third':
        return _thirdSel[m.id];
      case 'win':
        return _winSel[s.src];
      default:
        return null;
    }
  }

  // Teams eligible to fill a third-place slot: roster members of the slot's
  // candidate groups that the user did NOT pick 1st/2nd, minus thirds already
  // assigned to other matches.
  List<String> _eligibleThirds(_Match m) {
    final slot = _isThird(m.a) ? m.a : m.b;
    final usedElsewhere = {
      for (final e in _thirdSel.entries)
        if (e.key != m.id) e.value
    };
    final out = <String>[];
    for (final g in slot.thirdGroups) {
      final roster = _groupRosters[g] ?? const [];
      final picks = _groupSel[g] ?? const [];
      for (final t in roster) {
        if (!picks.contains(t) &&
            !usedElsewhere.contains(t) &&
            !out.contains(t)) {
          out.add(t);
        }
      }
    }
    return out;
  }

  Future<void> _tapSide(_Match m, bool sideA) async {
    final slot = sideA ? m.a : m.b;
    if (_isThird(slot)) {
      final current = _thirdSel[m.id];
      if (current == null) {
        final picked = await _showTeamPicker(
          _eligibleThirds(m),
          null,
          title: AppLocalizations.of(context)!.bracketPickThird,
        );
        if (picked == null || !mounted) return;
        setState(() {
          _thirdSel[m.id] = picked;
          _setWinner(m, picked);
        });
        return;
      }
      setState(() => _setWinner(m, current));
      return;
    }
    final team = _matchParticipant(m, sideA);
    if (team == null) return; // opponent/participant not resolved yet
    setState(() => _setWinner(m, team));
  }

  // Toggle the winner of a match, then re-validate downstream rounds so any
  // pick that referenced a now-changed winner is dropped.
  void _setWinner(_Match m, String team) {
    if (_winSel[m.id] == team) {
      _winSel.remove(m.id);
    } else {
      _winSel[m.id] = team;
    }
    _revalidateChain();
  }

  // Drop selections that are no longer consistent: a third no longer eligible
  // (got promoted to a group pick), or a match winner that is no longer one of
  // the (re-resolved) participants. Walks stages top-down so each round sees
  // the corrected winners feeding it.
  void _revalidateChain() {
    for (final m in _matchesFor('R32')) {
      final t = _thirdSel[m.id];
      if (t != null && _groupSel.values.any((p) => p.contains(t))) {
        _thirdSel.remove(m.id);
        if (_winSel[m.id] == t) _winSel.remove(m.id);
      }
    }
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

  Widget _buildMatchCard(EditorialColors c, _Match m, bool locked) {
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

  Widget _buildMatchRow(EditorialColors c, _Match m, bool sideA, String? team,
      bool isWinner, bool locked) {
    final slot = sideA ? m.a : m.b;
    final isThird = _isThird(slot);
    final resolved = team != null;
    final tappable = !locked && (resolved || isThird);
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
            if (isThird && !resolved && !locked)
              Icon(Icons.add_circle_outline, size: 18, color: c.inkDim)
            else if (isWinner)
              Icon(Icons.check_circle, size: 18, color: c.live)
            else if (resolved && !locked)
              Icon(Icons.radio_button_unchecked, size: 16, color: c.hairlineHi),
          ],
        ),
      ),
    );
  }

  String _slotLabel(_Slot s) {
    final l = AppLocalizations.of(context)!;
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

  // ── Ranking ──────────────────────────────────────────────────────────

  Widget _buildRanking(EditorialColors c) {
    final l = AppLocalizations.of(context)!;
    if (!_loading && _ranking.isEmpty) {
      return _Empty(
        icon: Icons.leaderboard_outlined,
        title: l.bracketRankingEmptyTitle,
        subtitle: l.bracketRankingEmptyHint,
      );
    }
    final rows = _loading
        ? List.generate(
            6, (i) => BracketStanding(name: 'Loading', points: 0))
        : _ranking;
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: rows.length,
      itemBuilder: (ctx, i) {
        final r = rows[i];
        final isMe = r.name == widget.userName;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: isMe ? c.liveSoft : null,
            border: Border(bottom: BorderSide(color: c.hairline, width: 1)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text('${i + 1}',
                    style: EType.numeric(
                        color: i < 3 ? c.live : c.inkDim,
                        size: 14,
                        weight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(r.name.toUpperCase(),
                    style: EType.display(
                        size: 17,
                        color: isMe ? c.live : c.ink,
                        letterSpacing: 0.6),
                    overflow: TextOverflow.ellipsis),
              ),
              Text('${r.points}',
                  style: EType.numeric(
                      color: c.ink, size: 15, weight: FontWeight.w600)),
              const SizedBox(width: 6),
              Text(l.pst,
                  style: EType.label(color: c.inkDim, size: 9, letterSpacing: 1)),
            ],
          ),
        );
      },
    );
  }

  // ── Team picker dialog ──────────────────────────────────────────────────

  Future<String?> _showTeamPicker(List<String> teams, String? current,
      {String? title}) {
    final c = context.col;
    final l = AppLocalizations.of(context)!;
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: c.terrace,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.9,
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
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text((title ?? l.bracketSelectTeamTitle).toUpperCase(),
                      style: EType.label(
                          color: c.ink, size: 12, letterSpacing: 2)),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scroll,
                  itemCount: teams.length,
                  itemBuilder: (ctx, i) {
                    final team = teams[i];
                    final selected = team == current;
                    return InkWell(
                      onTap: () => Navigator.of(ctx).pop(team),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border(
                              bottom:
                                  BorderSide(color: c.hairline, width: 1)),
                        ),
                        child: Row(
                          children: [
                            _Crest(url: _logoFor(team), size: 26),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(team,
                                  style: EType.body(
                                      color: selected ? c.live : c.ink,
                                      size: 14,
                                      weight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w400)),
                            ),
                            if (selected)
                              Icon(Icons.check, size: 18, color: c.live),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
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

// Collapsible section. The header is tappable to hide/show its content so the
// long list of stages (groups + champion + 5 knockout rounds) doesn't force a
// lot of scrolling to reach the next one.
class _Section extends StatefulWidget {
  const _Section({
    required this.title,
    required this.hint,
    required this.child,
    this.locked = false,
    this.initiallyExpanded = true,
  });
  final String title;
  final String hint;
  final Widget child;
  final bool locked;
  final bool initiallyExpanded;

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
                        Text(widget.title.toUpperCase(),
                            style: EType.label(
                                color: c.ink, size: 12, letterSpacing: 2)),
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

// ── FIFA 2026 knockout bracket template ──────────────────────────────────
//
// One side of a match. Resolves to a concrete team via the user's picks:
//   gw/ru   → 1st / 2nd of a group (from groupPicks)
//   third   → one of the listed groups' 3rd-placed teams (user-chosen)
//   win     → the winner the user tapped in the referenced match
class _Slot {
  final String kind; // 'gw' | 'ru' | 'third' | 'win'
  final String? group;
  final List<String> thirdGroups;
  final String? src; // referenced match id, for 'win'
  const _Slot._(this.kind, this.group, this.thirdGroups, this.src);
  const _Slot.gw(String g) : this._('gw', g, const [], null);
  const _Slot.ru(String g) : this._('ru', g, const [], null);
  const _Slot.third(List<String> g) : this._('third', null, g, null);
  const _Slot.win(String s) : this._('win', null, const [], s);
}

class _Match {
  final String id;
  final String stage;
  final _Slot a;
  final _Slot b;
  const _Match(this.id, this.stage, this.a, this.b);
}

// Fixed FIFA 2026 bracket (match numbers 73–104). R32 slots come from the
// published position template; later rounds chain on the winners of two
// feeding matches. Match order within a stage is bracket (top-to-bottom) order.
const List<_Match> _kBracketTemplate = [
  // Round of 32
  _Match('m73', 'R32', _Slot.ru('A'), _Slot.ru('B')),
  _Match('m74', 'R32', _Slot.gw('E'), _Slot.third(['A', 'B', 'C', 'D', 'F'])),
  _Match('m75', 'R32', _Slot.gw('F'), _Slot.ru('C')),
  _Match('m76', 'R32', _Slot.gw('C'), _Slot.ru('F')),
  _Match('m77', 'R32', _Slot.gw('I'), _Slot.third(['C', 'D', 'F', 'G', 'H'])),
  _Match('m78', 'R32', _Slot.ru('E'), _Slot.ru('I')),
  _Match('m79', 'R32', _Slot.gw('A'), _Slot.third(['C', 'E', 'F', 'H', 'I'])),
  _Match('m80', 'R32', _Slot.gw('L'), _Slot.third(['E', 'H', 'I', 'J', 'K'])),
  _Match('m81', 'R32', _Slot.gw('D'), _Slot.third(['B', 'E', 'F', 'I', 'J'])),
  _Match('m82', 'R32', _Slot.gw('G'), _Slot.third(['A', 'E', 'H', 'I', 'J'])),
  _Match('m83', 'R32', _Slot.ru('K'), _Slot.ru('L')),
  _Match('m84', 'R32', _Slot.gw('H'), _Slot.ru('J')),
  _Match('m85', 'R32', _Slot.gw('B'), _Slot.third(['E', 'F', 'G', 'I', 'J'])),
  _Match('m86', 'R32', _Slot.gw('J'), _Slot.ru('H')),
  _Match('m87', 'R32', _Slot.gw('K'), _Slot.third(['D', 'E', 'I', 'J', 'L'])),
  _Match('m88', 'R32', _Slot.ru('D'), _Slot.ru('G')),
  // Round of 16
  _Match('m89', 'R16', _Slot.win('m74'), _Slot.win('m77')),
  _Match('m90', 'R16', _Slot.win('m73'), _Slot.win('m75')),
  _Match('m91', 'R16', _Slot.win('m76'), _Slot.win('m78')),
  _Match('m92', 'R16', _Slot.win('m79'), _Slot.win('m80')),
  _Match('m93', 'R16', _Slot.win('m83'), _Slot.win('m84')),
  _Match('m94', 'R16', _Slot.win('m81'), _Slot.win('m82')),
  _Match('m95', 'R16', _Slot.win('m86'), _Slot.win('m88')),
  _Match('m96', 'R16', _Slot.win('m85'), _Slot.win('m87')),
  // Quarter-finals
  _Match('m97', 'QF', _Slot.win('m89'), _Slot.win('m90')),
  _Match('m98', 'QF', _Slot.win('m93'), _Slot.win('m94')),
  _Match('m99', 'QF', _Slot.win('m91'), _Slot.win('m92')),
  _Match('m100', 'QF', _Slot.win('m95'), _Slot.win('m96')),
  // Semi-finals
  _Match('m101', 'SF', _Slot.win('m97'), _Slot.win('m98')),
  _Match('m102', 'SF', _Slot.win('m99'), _Slot.win('m100')),
  // Final
  _Match('m104', 'F', _Slot.win('m101'), _Slot.win('m102')),
];
