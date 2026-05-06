import 'package:flutter/material.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:football/resources/standings_service.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';

class StandingsTableWidget extends StatefulWidget {
  final int leagueId;
  final int? highlightHomeId;
  final int? highlightAwayId;
  final void Function(int teamId, String teamName, String teamLogo)? onTeamTap;

  const StandingsTableWidget({
    super.key,
    required this.leagueId,
    this.highlightHomeId,
    this.highlightAwayId,
    this.onTeamTap,
  });

  @override
  State<StandingsTableWidget> createState() => _StandingsTableWidgetState();
}

class _StandingsTableWidgetState extends State<StandingsTableWidget> {
  final StandingsService _service = StandingsService();
  List<StandingRow>? _rows;
  bool _loading = true;

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
                  child: row.teamLogo.isNotEmpty
                      ? Image.network(
                          row.teamLogo,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              Icon(Icons.shield_outlined, size: 10, color: c.inkDim),
                        )
                      : Icon(Icons.shield_outlined, size: 10, color: c.inkDim),
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
      onTap: () => widget.onTeamTap!(row.teamId, row.teamName, row.teamLogo),
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
