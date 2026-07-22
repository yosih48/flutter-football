import 'package:flutter/material.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:football/models/games.dart';
import 'package:football/models/squad_player.dart';
import 'package:football/resources/team_squad_service.dart';
import 'package:football/resources/team_statistics_service.dart';
import 'package:football/screens/gameDetails.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:football/utils/he_player_name.dart';
import 'package:football/utils/localized_team_name.dart';
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
  int _selectedTab = 0; // 0=Matches, 1=Squad, 2=Table, 3=Stats

  // Squad fetch, cached per resolved team id so switching tabs doesn't refetch.
  int? _squadTeamId;
  Future<List<SquadPlayer>>? _squadFuture;

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
          localizedTeamName(context, widget.team.name).toUpperCase(),
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
            localizedTeamName(context, widget.team.name).toUpperCase(),
            textAlign: TextAlign.center,
            style: EType.teamNameDisplay(
              size: 24,
              color: c.ink,
              letterSpacing: 1.2,
              height: 1.1,
              hebrew: localizedTeamName(context, widget.team.name) !=
                  widget.team.name,
            ),
          ),
          const SizedBox(height: 12),
          _buildLeaguePill(c),
          const SizedBox(height: 16),
          _buildFormRow(c),
          const SizedBox(height: 14),
          _buildStatsTiles(c),
        ],
      ),
    );
  }

  // Recent W/D/L form (last up to 5 finished games), oldest → newest.
  Widget _buildFormRow(EditorialColors c) {
    final l = AppLocalizations.of(context)!;
    final teamId = _resolveFixtureTeamId();
    final finished = widget.allLeagueGames
        .where((g) =>
            (g.home.id == teamId || g.away.id == teamId) &&
            (g.status.short == 'FT' || g.status.short == 'AET') &&
            g.goals.home != null &&
            g.goals.away != null)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final last5 = finished.take(5).toList().reversed.toList();
    if (last5.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(l.formLabel,
            style: EType.label(color: c.inkDim, size: 10, letterSpacing: 1.4)),
        const SizedBox(width: 10),
        ...last5.map((g) {
          final isHome = g.home.id == teamId;
          final scored = isHome ? g.goals.home! : g.goals.away!;
          final conceded = isHome ? g.goals.away! : g.goals.home!;
          final res = scored > conceded ? 'W' : (scored < conceded ? 'L' : 'D');
          final col = res == 'W' ? c.live : (res == 'L' ? c.flag : c.inkMute);
          return Padding(
            padding: const EdgeInsets.only(left: 5),
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: col, shape: BoxShape.circle),
              child: Text(res,
                  style: EType.label(
                      color: Colors.white, size: 11, letterSpacing: 0)),
            ),
          );
        }),
      ],
    );
  }

  // Horizontal summary card: games · wins · draws · losses · goals.
  Widget _buildStatsTiles(EditorialColors c) {
    final l = AppLocalizations.of(context)!;
    final teamId = _resolveFixtureTeamId();
    final s = TeamStatisticsService.compute(widget.allLeagueGames, teamId);
    if (s.played == 0) return const SizedBox.shrink();

    Widget tile(String value, String label, Color color) => Expanded(
          child: Column(
            children: [
              Text(value,
                  style: EType.numeric(
                      color: color, size: 18, weight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EType.label(
                      color: c.inkDim, size: 10, letterSpacing: 0.2)),
            ],
          ),
        );
    Widget divider() => Container(width: 1, height: 30, color: c.hairline);

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.hairline, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
      child: Row(
        children: [
          tile('${s.played}', l.teamStatPlayed, c.ink),
          divider(),
          tile('${s.won}', l.teamStatWon, c.live),
          divider(),
          tile('${s.drawn}', l.teamStatDrawn, blue),
          divider(),
          tile('${s.lost}', l.teamStatLost, c.flag),
          divider(),
          tile('${s.goalsFor}:${s.goalsAgainst}', l.notifAllGoals, c.ink),
        ],
      ),
    );
  }

  // Localized short match date, e.g. "19 יולי" / "19 Jul" (no intl locale
  // init needed — Hebrew month names are mapped directly).
  String _matchDateLabel(DateTime d) {
    final local = d.toLocal();
    if (Localizations.localeOf(context).languageCode == 'he') {
      const months = [
        'ינואר', 'פברואר', 'מרץ', 'אפריל', 'מאי', 'יוני',
        'יולי', 'אוגוסט', 'ספטמבר', 'אוקטובר', 'נובמבר', 'דצמבר'
      ];
      return '${local.day} ${months[local.month - 1]}';
    }
    return DateFormat('d MMM').format(local);
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
    final tabs = [
      l.matchesTab.toUpperCase(),
      l.squadTab.toUpperCase(),
      l.tableTab.toUpperCase(),
    ];
    return Column(
      children: [
        Container(height: 1, color: c.hairline),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
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
        Container(height: 1, color: c.hairline),
      ],
    );
  }

  Widget _buildTabBody() {
    if (_selectedTab == 0) return _buildMatchesTab();
    if (_selectedTab == 1) return _buildSquadTab();
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
            _matchesCard(upcoming, teamId),
            const SizedBox(height: 16),
          ],
          if (past.isNotEmpty) ...[
            _sectionHeader(l.recentResults.toUpperCase()),
            const SizedBox(height: 8),
            _matchesCard(past, teamId),
          ],
        ],
      ),
    );
  }

  // A single rounded card holding all match rows for a section.
  Widget _matchesCard(List<Game> games, int teamId) {
    final c = context.col;
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.hairline, width: 1),
      ),
      child: Column(
        children: [
          for (var i = 0; i < games.length; i++)
            _matchRow(games[i], teamId, isLast: i == games.length - 1),
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

  // Opponent-centric row: opponent crest + name + "venue • date", a score pill,
  // and a W/D/L badge (from the viewed team's perspective).
  Widget _matchRow(Game game, int teamId, {required bool isLast}) {
    final c = context.col;
    final l = AppLocalizations.of(context)!;
    final isFinished =
        game.status.short == 'FT' || game.status.short == 'AET';
    final isHome = game.home.id == teamId;
    final opponent = isHome ? game.away : game.home;
    final h = game.goals.home;
    final a = game.goals.away;

    String? badgeText;
    Color badgeColor = c.inkMute;
    if (isFinished && h != null && a != null) {
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

    final subtitle =
        '${isHome ? l.venueHome : l.venueAway} • ${_matchDateLabel(game.date)}';
    final scoreStr = (isFinished && h != null && a != null)
        ? '$h : $a'
        : (game.status.short == 'NS'
            ? DateFormat('HH:mm').format(game.date.toLocal())
            : game.status.short);

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
            SizedBox(
              width: 28,
              height: 28,
              child: Image.network(
                opponent.logo,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.shield_outlined, size: 18, color: c.inkDim),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizedTeamName(context, opponent.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EType.body(
                        color: c.ink, size: 14, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: EType.body(color: c.inkMute, size: 11)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Score / kickoff pill.
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: c.cardHi,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.hairline, width: 1),
              ),
              child: Text(scoreStr,
                  style: EType.numeric(
                      color: c.ink, size: 13, weight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            // W/D/L badge.
            if (badgeText != null)
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration:
                    BoxDecoration(color: badgeColor, shape: BoxShape.circle),
                child: Text(badgeText,
                    style: EType.label(
                        color: Colors.white, size: 11, letterSpacing: 0)),
              )
            else
              const SizedBox(width: 26),
          ],
        ),
      ),
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

  // ── Squad tab ────────────────────────────────────────────────────────────
  // Reads the squad cached server-side (prewarmSquads.js). Grouped by position,
  // each row shows the player's photo, number and (localized) name.
  Widget _buildSquadTab() {
    final c = context.col;
    final l = AppLocalizations.of(context)!;

    final teamId = _resolveFixtureTeamId();
    if (_squadFuture == null || _squadTeamId != teamId) {
      _squadTeamId = teamId;
      _squadFuture = TeamSquadService().getSquad(teamId);
    }

    return FutureBuilder<List<SquadPlayer>>(
      future: _squadFuture,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation(c.live),
                ),
              ),
            ),
          );
        }
        final players = snap.data ?? const <SquadPlayer>[];
        if (players.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            child: Center(
              child: Text(
                l.squadNotAvailable.toUpperCase(),
                style: EType.label(color: c.inkDim, size: 11, letterSpacing: 2),
              ),
            ),
          );
        }
        return _buildSquadGroups(players, l);
      },
    );
  }

  Widget _buildSquadGroups(List<SquadPlayer> players, AppLocalizations l) {
    List<SquadPlayer> byPos(String pos) =>
        players.where((p) => p.position == pos).toList();
    // Any unexpected/blank positions fall into a trailing "other" bucket.
    final known = {'Goalkeeper', 'Defender', 'Midfielder', 'Attacker'};
    final other = players.where((p) => !known.contains(p.position)).toList();

    final groups = <(String, List<SquadPlayer>)>[
      (l.goalkeepers, byPos('Goalkeeper')),
      (l.defenders, byPos('Defender')),
      (l.midfielders, byPos('Midfielder')),
      (l.forwards, byPos('Attacker')),
      if (other.isNotEmpty) ('—', other),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final g in groups)
            if (g.$2.isNotEmpty) ...[
              _sectionHeader(g.$1.toUpperCase()),
              const SizedBox(height: 8),
              _squadCard(g.$2),
              const SizedBox(height: 16),
            ],
        ],
      ),
    );
  }

  Widget _squadCard(List<SquadPlayer> players) {
    final c = context.col;
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.hairline, width: 1),
      ),
      child: Column(
        children: [
          for (var i = 0; i < players.length; i++)
            _squadRow(players[i], isLast: i == players.length - 1),
        ],
      ),
    );
  }

  Widget _squadRow(SquadPlayer p, {required bool isLast}) {
    final c = context.col;
    return Container(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: c.hairline, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          // Shirt number
          SizedBox(
            width: 26,
            child: Text(
              p.number?.toString() ?? '',
              textAlign: TextAlign.center,
              style: EType.numeric(color: c.inkMute, size: 13, weight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          // Photo
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: c.cardHi,
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: (p.photo != null && p.photo!.isNotEmpty)
                ? Image.network(
                    p.photo!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Icon(Icons.person, size: 18, color: c.inkDim),
                  )
                : Icon(Icons.person, size: 18, color: c.inkDim),
          ),
          const SizedBox(width: 12),
          // Name
          Expanded(
            child: Text(
              localizedPlayerName(context, p.name),
              overflow: TextOverflow.ellipsis,
              style: EType.body(color: c.ink, size: 14),
            ),
          ),
          // Age (end of row)
          if (p.age != null) ...[
            const SizedBox(width: 10),
            Text(
              '${p.age}',
              style: EType.numeric(color: c.inkDim, size: 13, weight: FontWeight.w500),
            ),
          ],
        ],
      ),
    );
  }

  // ── Table tab ────────────────────────────────────────────────────────────
  Widget _buildTableTab() {
    final c = context.col;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
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
