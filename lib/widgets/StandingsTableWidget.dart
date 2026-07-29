import 'package:flutter/material.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:football/models/games.dart';
import 'package:football/resources/standings_service.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:football/utils/localized_team_name.dart';

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
    'fc',
    'cf',
    'afc',
    'sc',
    'ac',
    'rc',
    'cd',
    'ud',
    'sd',
    'club',
    'de',
    'the',
  };

  // Manual aliases for clubs that the standings endpoint and API-Football
  // disagree on past mere abbreviations — usually historical rebrands or
  // colloquial names. Key/value pre-normalization, lower-case. Add more as
  // we discover them.
  static const Map<String, String> _nameAliases = {
    'hapoel jerusalem': 'hapoel katamon',
    'olympique lyonnais': 'lyon',
  };

  static String _applyAliases(String s) {
    final key = s.toLowerCase().trim();
    return _nameAliases[key] ?? s;
  }

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

  static int _sharedTokenCount(List<String> a, Set<String> b) {
    int n = 0;
    for (final t in a) {
      if (b.contains(t)) n++;
    }
    return n;
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
        byId.putIfAbsent(g.home.id,
            () => (team: g.home, tokens: _tokens(g.home.name).toSet()));
        byId.putIfAbsent(g.away.id,
            () => (team: g.away, tokens: _tokens(g.away.name).toSet()));
      }
    }
    _candidates = byId.values.toList();
  }

  // Returns the matching fixture-side Team for this standings row, or null
  // if no fixture team shares enough tokens with the row's name to be
  // confident in the mapping.
  Team? _fixtureTeamFor(StandingRow row) {
    _rebuildCandidatesIfNeeded();
    if (_candidates.isEmpty) return null;
    final wanted = _tokens(_applyAliases(row.teamName));
    if (wanted.isEmpty) return null;

    Team? best;
    int bestScore = 0;
    int bestSharedTokens = 0;
    for (final cand in _candidates) {
      final s = _score(wanted, cand.tokens);
      if (s > bestScore) {
        bestScore = s;
        bestSharedTokens = _sharedTokenCount(wanted, cand.tokens);
        best = cand.team;
      }
    }
    if (best == null || bestScore < 3) return null;
    // When the standings name has 2+ tokens, require at least 2 to overlap.
    // Otherwise a single common token (e.g. "jerusalem") would let any
    // unrelated team in the same city claim the row.
    if (wanted.length >= 2 && bestSharedTokens < 2) return null;
    return best;
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
      children.addAll(rows.map((r) => _bodyRow(r, grouped: showGroupHeaders)));
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
    final isHe = Localizations.localeOf(context).languageCode == 'he';
    return Container(
      width: double.infinity,
      color: c.cardHi,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 2.5,
            decoration: BoxDecoration(
              color: c.live,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            name,
            style: EType.body(
                color: c.ink, size: 12, weight: FontWeight.w700, hebrew: isHe),
          ),
        ],
      ),
    );
  }

  Widget _headerRow(AppLocalizations l) {
    // Padding and the rank/gap widths mirror _bodyRow exactly, so the headings
    // sit directly above the columns they label.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 22, child: _hdr('#', center: true)),
          const SizedBox(width: 8),
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

  // Colour for a qualifying position, or null when the row isn't one.
  //
  // Only applied to multi-group tables (World Cup / CL group stage), where the
  // top two advance. A single-table league has no such cut-off at rank 2, and
  // the API rows carry no `description` field to derive one from — so those
  // tables get no qualification tint at all rather than a wrong one.
  Color? _qualifyColor(StandingRow row, bool grouped) {
    if (!grouped) return null;
    final c = context.col;
    if (row.rank == 1) return c.amber;
    if (row.rank == 2) return c.live;
    return null;
  }

  Widget _bodyRow(StandingRow row, {bool grouped = false}) {
    final c = context.col;
    final isMatch = row.teamId == widget.highlightHomeId ||
        row.teamId == widget.highlightAwayId;
    final qualify = _qualifyColor(row, grouped);

    final content = Container(
      decoration: BoxDecoration(
        color: (isMatch || qualify != null) ? c.liveSoft : Colors.transparent,
        border: Border(
          bottom: BorderSide(color: c.hairline, width: 1),
          // Accent bar marking a qualifying slot (rendered at the start edge,
          // so it sits on the right in Hebrew).
          left: BorderSide(
            color: qualify ?? Colors.transparent,
            width: 3,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Row(
        children: [
          _rankBadge(row.rank, qualify, isMatch),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  padding: const EdgeInsets.all(1),
                  decoration:
                      BoxDecoration(color: c.cardHi, shape: BoxShape.circle),
                  child: Builder(builder: (_) {
                    var logo = _logoFor(row);
                    if (logo.isEmpty) {
                      return Icon(Icons.shield_outlined,
                          size: 10, color: c.inkDim);
                    }
                    // Cache-bust ONLY proxy URLs that previously 404'd — leaves
                    // the API-Football CDN URLs untouched so they stay cached.
                    if (logo.contains('/api/team-image/')) {
                      logo += logo.contains('?') ? '&v=2' : '?v=2';
                    }
                    return Image.network(
                      logo,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(Icons.shield_outlined,
                          size: 10, color: c.inkDim),
                    );
                  }),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    localizedTeamName(context, row.teamName),
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

  // Qualifying ranks get an outlined badge in their accent colour; everything
  // else stays a plain muted numeral.
  Widget _rankBadge(int rank, Color? qualify, bool isMatch) {
    final c = context.col;
    if (qualify == null) {
      return SizedBox(
        width: 22,
        child: Text(
          '$rank',
          textAlign: TextAlign.center,
          style: EType.numeric(
            color: isMatch ? c.live : c.inkDim,
            size: 11,
            weight: FontWeight.w600,
          ),
        ),
      );
    }
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: qualify, width: 1.5),
      ),
      child: Text(
        '$rank',
        style: EType.numeric(color: qualify, size: 11, weight: FontWeight.w700),
      ),
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
