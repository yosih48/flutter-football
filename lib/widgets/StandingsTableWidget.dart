import 'package:flutter/material.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:football/models/games.dart';
import 'package:football/resources/standings_service.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';

class StandingsTableWidget extends StatefulWidget {
  final int leagueId;
  final int? highlightHomeId;
  final int? highlightAwayId;
  final void Function(int teamId, String teamName, String teamLogo)? onTeamTap;

  /// Optional games used to recover working team logos when the standings
  /// endpoint returns a logo URL the backend can't proxy (e.g. UEFA cup
  /// tournament-scoped team IDs that 404 on Sofascore). We grab the API-
  /// Football logos from these games by matching on team name.
  final List<Game>? logoSourceGames;

  const StandingsTableWidget({
    super.key,
    required this.leagueId,
    this.highlightHomeId,
    this.highlightAwayId,
    this.onTeamTap,
    this.logoSourceGames,
  });

  @override
  State<StandingsTableWidget> createState() => _StandingsTableWidgetState();
}

class _StandingsTableWidgetState extends State<StandingsTableWidget> {
  final StandingsService _service = StandingsService();
  List<StandingRow>? _rows;
  bool _loading = true;

  static const Set<String> _stopWords = {
    'fc', 'cf', 'afc', 'sc', 'ac', 'rc', 'cd', 'ud', 'sd', 'club', 'de',
    'the',
  };
  static const String _accented =
      'àáâãäåāăąèéêëēĕėęěìíîïĩīĭįòóôõöōŏőùúûüũūŭůűñçßýÿźżž';
  static const String _plain =
      'aaaaaaaaaeeeeeeeeeiiiiiiiiooooooooouuuuuuuuuncbyyzzz';

  static List<String> _tokens(String s) {
    final buf = StringBuffer();
    for (final ch in s.toLowerCase().runes) {
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

  // Token-overlap score weighted by token length. "real madrid" vs "real madrid"
  // beats "real madrid" vs "atletico madrid" because the first shares both
  // tokens (10 chars) vs only "madrid" (6 chars).
  static int _score(List<String> a, Set<String> b) {
    int s = 0;
    for (final t in a) {
      if (b.contains(t)) s += t.length;
    }
    return s;
  }

  // Per-(games list) caches so we tokenize each fixture team once, not per row.
  List<Game>? _cachedGames;
  late List<({Team team, Set<String> tokens})> _candidates;

  void _rebuildCandidatesIfNeeded() {
    final games = widget.logoSourceGames;
    if (identical(games, _cachedGames)) return;
    _cachedGames = games;
    final byId = <int, ({Team team, Set<String> tokens})>{};
    if (games != null) {
      for (final g in games) {
        byId.putIfAbsent(
            g.home.id, () => (team: g.home, tokens: _tokens(g.home.name).toSet()));
        byId.putIfAbsent(
            g.away.id, () => (team: g.away, tokens: _tokens(g.away.name).toSet()));
      }
    }
    _candidates = byId.values.toList();
  }

  // Returns the matching fixture-side Team for this standings row, or null
  // if no fixture team shares any meaningful token with the row's name.
  Team? _fixtureTeamFor(StandingRow row) {
    _rebuildCandidatesIfNeeded();
    if (_candidates.isEmpty) return null;
    final wanted = _tokens(row.teamName);
    if (wanted.isEmpty) return null;

    Team? best;
    int bestScore = 0;
    for (final cand in _candidates) {
      final s = _score(wanted, cand.tokens);
      if (s > bestScore) {
        bestScore = s;
        best = cand.team;
      }
    }
    // Require at least a 3-letter token match to avoid spurious 1-2 letter
    // collisions (e.g. a stray "u" or "a" lingering after stop-word removal).
    return bestScore >= 3 ? best : null;
  }

  String _logoFor(StandingRow row) {
    final t = _fixtureTeamFor(row);
    if (t != null && t.logo.isNotEmpty) return t.logo;
    return row.teamLogo;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(StandingsTableWidget old) {
    super.didUpdateWidget(old);
    if (old.leagueId != widget.leagueId) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final r = await _service.getLeagueStandings(widget.leagueId);
    if (!mounted) return;
    setState(() {
      _rows = r;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final l = AppLocalizations.of(context)!;

    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation(c.live),
            ),
          ),
        ),
      );
    }

    if (_rows == null || _rows!.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        child: Center(
          child: Text(
            l.standingsNotAvailable.toUpperCase(),
            style: EType.label(color: c.inkDim, size: 11, letterSpacing: 2),
          ),
        ),
      );
    }

    final groups = <String, List<StandingRow>>{};
    for (final row in _rows!) {
      final key = row.group ?? '';
      groups.putIfAbsent(key, () => []).add(row);
    }
    final showGroupHeaders = groups.length > 1;

    final children = <Widget>[
      _headerRow(l),
      Container(height: 1, color: c.hairline),
    ];
    groups.forEach((groupName, rows) {
      if (showGroupHeaders && groupName.isNotEmpty) {
        children.add(_groupHeader(_localizedGroupName(groupName, l)));
      }
      children.addAll(rows.map(_bodyRow));
    });

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      child: Column(children: children),
    );
  }

  // Maps known playoff-round suffixes from the API (English) to localized
  // labels. Unknown groups (e.g. Champions League "Group A 25/26") fall through
  // to the raw API string.
  String _localizedGroupName(String raw, AppLocalizations l) {
    final lower = raw.toLowerCase();
    if (lower.contains('championship round')) return l.championshipRound;
    if (lower.contains('relegation round')) return l.relegationRound;
    return raw;
  }

  Widget _groupHeader(String name) {
    final c = context.col;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.hairline, width: 1)),
      ),
      child: Text(
        name,
        style: EType.label(color: c.ink, size: 11, letterSpacing: 1.2),
      ),
    );
  }

  Widget _headerRow(AppLocalizations l) {
    final c = context.col;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 22, child: _hdr('#')),
          const SizedBox(width: 6),
          Expanded(child: _hdr('')),
          SizedBox(width: 22, child: _hdr(l.colPlayed, center: true)),
          SizedBox(width: 22, child: _hdr(l.colWon, center: true)),
          SizedBox(width: 22, child: _hdr(l.colDrawn, center: true)),
          SizedBox(width: 22, child: _hdr(l.colLost, center: true)),
          SizedBox(width: 28, child: _hdr(l.colGoalDiff, center: true)),
          SizedBox(width: 28, child: _hdr(l.colPoints, center: true)),
        ],
      ),
    );
  }

  Widget _hdr(String s, {bool center = false}) {
    final c = context.col;
    return Text(
      s,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: EType.label(color: c.inkDim, size: 9, letterSpacing: 1.4),
    );
  }

  Widget _bodyRow(StandingRow row) {
    final c = context.col;
    final isMatch =
        row.teamId == widget.highlightHomeId || row.teamId == widget.highlightAwayId;

    final content = Container(
      decoration: BoxDecoration(
        color: isMatch ? c.liveSoft : Colors.transparent,
        border: Border(bottom: BorderSide(color: c.hairline, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '${row.rank}',
              style: EType.numeric(
                color: isMatch ? c.live : c.inkDim,
                size: 11,
                weight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  padding: const EdgeInsets.all(1),
                  decoration: BoxDecoration(color: c.cardHi, shape: BoxShape.circle),
                  child: Builder(builder: (_) {
                    var logo = _logoFor(row);
                    if (logo.isEmpty) {
                      return Icon(Icons.shield_outlined, size: 10, color: c.inkDim);
                    }
                    // Cache-bust ONLY proxy URLs that previously 404'd — leaves
                    // the API-Football CDN URLs untouched so they stay cached.
                    if (logo.contains('/api/team-image/')) {
                      logo += logo.contains('?') ? '&v=2' : '?v=2';
                    }
                    return Image.network(
                      logo,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          Icon(Icons.shield_outlined, size: 10, color: c.inkDim),
                    );
                  }),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    row.teamName,
                    overflow: TextOverflow.ellipsis,
                    style: EType.body(
                      color: c.ink,
                      size: 12,
                      weight: isMatch ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 22, child: _cell('${row.played}')),
          SizedBox(width: 22, child: _cell('${row.won}')),
          SizedBox(width: 22, child: _cell('${row.drawn}')),
          SizedBox(width: 22, child: _cell('${row.lost}')),
          SizedBox(
            width: 28,
            child: _cell(
              row.goalsDiff > 0 ? '+${row.goalsDiff}' : '${row.goalsDiff}',
            ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '${row.points}',
              textAlign: TextAlign.center,
              style: EType.numeric(
                color: c.ink,
                size: 12,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (widget.onTeamTap == null) return content;
    return InkWell(
      onTap: () {
        // Prefer the fixture-side team (canonical API-Football id, clean name,
        // working CDN logo). Falls back to the standings row when we can't
        // match by name.
        final t = _fixtureTeamFor(row);
        widget.onTeamTap!(
          t?.id ?? row.teamId,
          t?.name ?? row.teamName,
          (t?.logo.isNotEmpty ?? false) ? t!.logo : row.teamLogo,
        );
      },
      child: content,
    );
  }

  Widget _cell(String s) {
    final c = context.col;
    return Text(
      s,
      textAlign: TextAlign.center,
      style: EType.numeric(color: c.inkMute, size: 11),
    );
  }
}
