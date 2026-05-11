import 'package:flutter/material.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:football/models/games.dart';
import 'package:football/screens/gameDetails.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:football/widgets/StandingsTableWidget.dart';
import 'package:intl/intl.dart';

/// Team home screen — opened by tapping a team's crest in any games list or
/// match-detail screen. Two tabs: the team's recent + upcoming matches and the
/// league standings.
///
/// `allLeagueGames` is the full season's games list passed from the parent
/// screen — no API call is made here. Filtering in-memory for the team's
/// fixtures keeps this lightweight.
class TeamDetailsScreen extends StatefulWidget {
  final Team team;
  final League league;
  final List<Game> allLeagueGames;
  final String? userId;

  const TeamDetailsScreen({
    super.key,
    required this.team,
    required this.league,
    required this.allLeagueGames,
    this.userId,
  });

  @override
  State<TeamDetailsScreen> createState() => _TeamDetailsScreenState();
}

class _TeamDetailsScreenState extends State<TeamDetailsScreen> {
  int _selectedTab = 0; // 0=Matches, 1=Table

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Scaffold(
      backgroundColor: c.pitch,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: c.pitch,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: c.ink, size: 20),
        title: Text(
          widget.team.name.toUpperCase(),
          style: EType.label(color: c.ink, size: 12, letterSpacing: 2),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              _buildHero(c),
              const SizedBox(height: 12),
              _buildTabs(c),
              const SizedBox(height: 8),
              _buildTabBody(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Hero block: large logo + team name + league pill ─────────────────────
  Widget _buildHero(EditorialColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Container(
            width: 110,
            height: 110,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.cardHi,
              shape: BoxShape.circle,
            ),
            child: Image.network(
              widget.team.logo,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.shield_outlined, size: 56, color: c.inkDim),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            widget.team.name.toUpperCase(),
            textAlign: TextAlign.center,
            style: EType.display(
              size: 24,
              color: c.ink,
              letterSpacing: 1.2,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          _buildLeaguePill(c),
        ],
      ),
    );
  }

  Widget _buildLeaguePill(EditorialColors c) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.league.logo != null && widget.league.logo!.isNotEmpty) ...[
          SizedBox(
            width: 18,
            height: 18,
            child: Image.network(
              widget.league.logo!,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.emoji_events_outlined, size: 16, color: c.inkDim),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Text(
          widget.league.name,
          style: EType.body(color: c.inkMute, size: 14),
        ),
      ],
    );
  }

  // ── Tab bar ──────────────────────────────────────────────────────────────
  Widget _buildTabs(EditorialColors c) {
    final l = AppLocalizations.of(context)!;
    final tabs = [l.matchesTab.toUpperCase(), l.tableTab.toUpperCase()];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: c.hairline, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: Row(
          children: List.generate(tabs.length, (i) {
            final isActive = i == _selectedTab;
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _selectedTab = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isActive ? c.live : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    tabs[i],
                    textAlign: TextAlign.center,
                    style: EType.label(
                      color: isActive ? c.live : c.inkMute,
                      size: 11,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildTabBody() {
    if (_selectedTab == 0) return _buildMatchesTab();
    return _buildTableTab();
  }

  // ── Matches tab ──────────────────────────────────────────────────────────
  Widget _buildMatchesTab() {
    final c = context.col;
    final l = AppLocalizations.of(context)!;

    // The standings endpoint and the fixtures endpoint of API-Football don't
    // always agree on team IDs (or even exact names — "FC Barcelona" vs
    // "Barcelona", "Atlético" vs "Atletico", etc.). So we resolve the
    // fixture-side team id once by picking the unique team in the league's
    // fixtures whose name best overlaps with widget.team.name.
    final teamId = _resolveFixtureTeamId();
    final teamGames = widget.allLeagueGames
        .where((g) => g.home.id == teamId || g.away.id == teamId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    if (teamGames.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Center(
          child: Text(
            l.noMatchesForTeam.toUpperCase(),
            style: EType.label(color: c.inkDim, size: 11, letterSpacing: 2),
          ),
        ),
      );
    }

    final now = DateTime.now();
    final past = teamGames.where((g) => g.date.isBefore(now)).toList();
    final upcoming =
        teamGames.where((g) => !g.date.isBefore(now)).toList().reversed.toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (upcoming.isNotEmpty) ...[
            _sectionHeader(l.upcomingMatches.toUpperCase()),
            const SizedBox(height: 8),
            ..._buildPerDateGroups(upcoming, teamId),
            const SizedBox(height: 16),
          ],
          if (past.isNotEmpty) ...[
            _sectionHeader(l.recentResults.toUpperCase()),
            const SizedBox(height: 8),
            ..._buildPerDateGroups(past, teamId),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildPerDateGroups(List<Game> games, int teamId) {
    final byDate = <DateTime, List<Game>>{};
    for (final g in games) {
      final local = g.date.toLocal();
      final key = DateTime(local.year, local.month, local.day);
      byDate.putIfAbsent(key, () => []).add(g);
    }
    final keys = byDate.keys.toList()..sort((a, b) => b.compareTo(a));
    final widgets = <Widget>[];
    for (var i = 0; i < keys.length; i++) {
      final dateGames = byDate[keys[i]]!
        ..sort((a, b) => a.date.compareTo(b.date));
      widgets.add(_dateGroup(keys[i], dateGames, teamId));
      if (i < keys.length - 1) widgets.add(const SizedBox(height: 10));
    }
    return widgets;
  }

  Widget _dateGroup(DateTime date, List<Game> games, int teamId) {
    final c = context.col;
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: c.hairline, width: 1),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Text(
                  DateFormat('EEE  d MMM yyyy').format(date).toUpperCase(),
                  style: EType.label(
                    color: c.ink,
                    size: 11,
                    letterSpacing: 1.6,
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: c.hairline),
          ...games.asMap().entries.map((e) {
            final isLast = e.key == games.length - 1;
            return _matchRow(e.value, teamId, isLast: isLast);
          }),
        ],
      ),
    );
  }

  Widget _sectionHeader(String label) {
    final c = context.col;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(width: 18, height: 1, color: c.live),
          const SizedBox(width: 10),
          Text(
            label,
            style: EType.label(color: c.inkDim, size: 11, letterSpacing: 2.2),
          ),
        ],
      ),
    );
  }

  Widget _matchRow(Game game, int teamId, {required bool isLast}) {
    final c = context.col;
    final isFinished =
        game.status.short == 'FT' || game.status.short == 'AET';
    final h = game.goals.home;
    final a = game.goals.away;

    // W/D/L from this team's perspective.
    String? badgeText;
    Color badgeColor = c.inkDim;
    if (isFinished && h != null && a != null) {
      final isHome = game.home.id == teamId;
      final scored = isHome ? h : a;
      final conceded = isHome ? a : h;
      if (scored > conceded) {
        badgeText = 'W';
        badgeColor = c.live;
      } else if (scored < conceded) {
        badgeText = 'L';
        badgeColor = c.flag;
      } else {
        badgeText = 'D';
        badgeColor = c.inkMute;
      }
    }

    return InkWell(
      onTap: () => _openGameDetails(game),
      child: Container(
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: c.hairline, width: 1)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Status / league column
            SizedBox(
              width: 56,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isFinished
                        ? 'FT'
                        : (game.status.short == 'NS'
                            ? DateFormat('HH:mm').format(game.date.toLocal())
                            : game.status.short),
                    style: EType.label(
                      color: c.inkMute,
                      size: 11,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (game.league.logo != null &&
                      game.league.logo!.isNotEmpty)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: Image.network(
                        game.league.logo!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.emoji_events_outlined,
                          size: 12,
                          color: c.inkDim,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            // Teams + scores stacked
            Expanded(
              child: Column(
                children: [
                  _teamScoreLine(game.home, h, teamId, c),
                  const SizedBox(height: 6),
                  _teamScoreLine(game.away, a, teamId, c),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // W/D/L badge
            if (badgeText != null)
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: badgeColor, width: 1),
                ),
                child: Text(
                  badgeText,
                  style: EType.label(
                    color: badgeColor,
                    size: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              )
            else
              const SizedBox(width: 26),
          ],
        ),
      ),
    );
  }

  Widget _teamScoreLine(Team team, int? score, int viewerTeamId, EditorialColors c) {
    final isViewer = team.id == viewerTeamId;
    return Row(
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: Image.network(
            team.logo,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.shield_outlined, size: 14, color: c.inkDim),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            team.name,
            overflow: TextOverflow.ellipsis,
            style: EType.body(
              color: c.ink,
              size: 13,
              weight: isViewer ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          score?.toString() ?? '-',
          style: EType.numeric(
            color: c.ink,
            size: 14,
            weight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  void _openGameDetails(Game game) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameDetails(
          gameOriginalId: game.fixtureId,
          game: game,
          games: widget.allLeagueGames,
          initialIndex: widget.allLeagueGames.indexOf(game),
          userId: widget.userId,
        ),
      ),
    );
  }

  // Common club abbreviations / qualifiers that vary between API endpoints.
  static const Set<String> _stopWords = {
    'fc', 'cf', 'afc', 'sc', 'ac', 'rc', 'cd', 'ud', 'sd', 'club', 'de',
    'the',
  };

  // Lowercase, strip diacritics and punctuation, drop stop-words.
  static const String _accented =
      'àáâãäåāăąèéêëēĕėęěìíîïĩīĭįòóôõöōŏőùúûüũūŭůűñçßýÿźżž';
  static const String _plain =
      'aaaaaaaaaeeeeeeeeeiiiiiiiiooooooooouuuuuuuuuncbyyzzz';

  static List<String> _tokens(String s) {
    final buf = StringBuffer();
    final lower = s.toLowerCase();
    for (final ch in lower.runes) {
      final c = String.fromCharCode(ch);
      final i = _accented.indexOf(c);
      if (i >= 0) {
        buf.write(_plain[i]);
      } else if (RegExp(r'[a-z0-9]').hasMatch(c)) {
        buf.write(c);
      } else {
        buf.write(' ');
      }
    }
    return buf
        .toString()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty && !_stopWords.contains(t))
        .toList();
  }

  // Score how similar two team names are by token overlap, weighting longer
  // shared tokens higher (so "madrid" alone is weaker than "real madrid").
  static int _nameScore(List<String> a, List<String> b) {
    final bSet = b.toSet();
    int score = 0;
    for (final t in a) {
      if (bSet.contains(t)) score += t.length;
    }
    return score;
  }

  int _resolveFixtureTeamId() {
    // Direct id match wins immediately.
    for (final g in widget.allLeagueGames) {
      if (g.home.id == widget.team.id || g.away.id == widget.team.id) {
        return widget.team.id;
      }
    }
    final wanted = _tokens(widget.team.name);
    if (wanted.isEmpty) return widget.team.id;

    final seen = <int, List<String>>{};
    for (final g in widget.allLeagueGames) {
      seen.putIfAbsent(g.home.id, () => _tokens(g.home.name));
      seen.putIfAbsent(g.away.id, () => _tokens(g.away.name));
    }

    int bestId = widget.team.id;
    int bestScore = 0;
    seen.forEach((id, toks) {
      final s = _nameScore(wanted, toks);
      if (s > bestScore) {
        bestScore = s;
        bestId = id;
      }
    });
    return bestScore > 0 ? bestId : widget.team.id;
  }

  // ── Table tab ────────────────────────────────────────────────────────────
  Widget _buildTableTab() {
    final c = context.col;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: c.hairline, width: 1),
      ),
      child: StandingsTableWidget(
        leagueId: widget.league.id,
        highlightHomeId: widget.team.id,
        logoSourceGames: widget.allLeagueGames,
        onTeamTap: (id, name, logo) {
          if (id == widget.team.id) return;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TeamDetailsScreen(
                team: Team(id: id, name: name, logo: logo),
                league: widget.league,
                allLeagueGames: widget.allLeagueGames,
                userId: widget.userId,
              ),
            ),
          );
        },
      ),
    );
  }
}
