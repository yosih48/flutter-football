import 'package:flutter/material.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:football/resources/stats_service.dart';
import 'package:football/utils/localized_stat_label.dart';
import 'package:football/utils/localized_team_name.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';

class StatsWidget extends StatefulWidget {
  final int fixtureId;
  final String homeTeamName;
  final String awayTeamName;
  final int? matchElapsed;
  final String? matchStatusShort;

  const StatsWidget({
    super.key,
    required this.fixtureId,
    required this.homeTeamName,
    required this.awayTeamName,
    this.matchElapsed,
    this.matchStatusShort,
  });

  @override
  State<StatsWidget> createState() => _StatsWidgetState();
}

class _StatsWidgetState extends State<StatsWidget> {
  final StatsService _service = StatsService();
  List<TeamStats>? _stats;
  bool _loading = true;
  int? _statsAsOfMinute;
  String? _statsAsOfStatus;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(StatsWidget old) {
    super.didUpdateWidget(old);
    if (old.fixtureId != widget.fixtureId) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    const playedOrLive = {
      'FT',
      'AET',
      'PEN',
      '1H',
      '2H',
      'HT',
      'ET',
      'P',
      'LIVE'
    };
    final shouldFetch = playedOrLive.contains(widget.matchStatusShort);
    final result =
        await _service.getFixtureStats(widget.fixtureId, fetch: shouldFetch);
    if (!mounted) return;
    setState(() {
      _stats = result;
      _statsAsOfMinute = widget.matchElapsed;
      _statsAsOfStatus = widget.matchStatusShort;
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

    if (_stats == null || _stats!.length < 2) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        child: Center(
          child: Text(
            l.statsNotAvailable.toUpperCase(),
            style: EType.label(color: c.inkDim, size: 11, letterSpacing: 2),
          ),
        ),
      );
    }

    final home = _stats!.firstWhere(
      (s) => s.teamName == widget.homeTeamName,
      orElse: () => _stats![0],
    );
    final away = _stats!.firstWhere(
      (s) => s.teamName == widget.awayTeamName,
      orElse: () => _stats![1],
    );

    final allTypes = <String>{};
    for (final s in home.statistics) allTypes.add(s.type);
    for (final s in away.statistics) allTypes.add(s.type);

    // final asOf = _asOfLabel(l);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // if (asOf != null) ...[
          //   Center(
          //     child: Text(
          //       asOf.toUpperCase(),
          //       style: EType.label(color: c.inkDim, size: 9, letterSpacing: 1.6),
          //     ),
          //   ),
          //   const SizedBox(height: 10),
          // ],
          _teamHeader(home.teamLogo, away.teamLogo),
          const SizedBox(height: 14),
          ...allTypes.map((type) => _statRow(type, home, away)),
        ],
      ),
    );
  }

  // String? _asOfLabel(AppLocalizations l) {
  //   final status = _statsAsOfStatus;
  //   if (status == 'FT' || status == 'AET' || status == 'PEN') {
  //     return l.statsAsOfFullTime;
  //   }
  //   final minute = _statsAsOfMinute;
  //   if (minute == null || minute <= 0) return null;
  //   return l.statsAsOf(minute.toString());
  // }

  // Colour each side owns throughout the panel — dot, values and bar. Home is
  // amber, away green, so a row can be read without re-checking the header.
  Color get _homeColor => context.col.amber;
  Color get _awayColor => context.col.live;

  Widget _teamHeader(String homeLogo, String awayLogo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: _teamChip(widget.homeTeamName, homeLogo, _homeColor,
                alignEnd: false),
          ),
          Expanded(
            child: _teamChip(widget.awayTeamName, awayLogo, _awayColor,
                alignEnd: true),
          ),
        ],
      ),
    );
  }

  Widget _teamChip(String name, String logo, Color dot,
      {required bool alignEnd}) {
    final c = context.col;
    final isHe = Localizations.localeOf(context).languageCode == 'he';
    final parts = <Widget>[
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
      ),
      const SizedBox(width: 8),
      _logo(logo),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          localizedTeamName(context, name),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: EType.body(
              color: c.ink, size: 13, weight: FontWeight.w700, hebrew: isHe),
        ),
      ),
    ];
    return Row(
      mainAxisAlignment:
          alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: alignEnd ? parts.reversed.toList() : parts,
    );
  }

  Widget _logo(String url) {
    final c = context.col;
    return Container(
      width: 28,
      height: 28,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: c.cardHi, shape: BoxShape.circle),
      child: url.isNotEmpty
          ? Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.shield_outlined, size: 14, color: c.inkDim),
            )
          : Icon(Icons.shield_outlined, size: 14, color: c.inkDim),
    );
  }

  Widget _statRow(String type, TeamStats home, TeamStats away) {
    final c = context.col;
    final hVal = home.statistics
        .firstWhere((s) => s.type == type,
            orElse: () => StatItem(type: type, value: null))
        .value;
    final aVal = away.statistics
        .firstWhere((s) => s.type == type,
            orElse: () => StatItem(type: type, value: null))
        .value;

    final hPct = _percentFraction(hVal);
    final aPct = _percentFraction(aVal);

    // Raw magnitudes drive both the bars and which side is "winning" the stat.
    final hNum = hPct ?? _toDouble(hVal);
    final aNum = aPct ?? _toDouble(aVal);
    final isHe = Localizations.localeOf(context).languageCode == 'he';

    // Only one side is emphasised, and only when they actually differ — a tie
    // leaves both muted rather than bolding both.
    final homeLeads = hNum > aNum;
    final awayLeads = aNum > hNum;

    TextStyle valueStyle(bool leads) => EType.numeric(
          color: leads ? c.ink : c.inkDim,
          size: 15,
          weight: leads ? FontWeight.w700 : FontWeight.w500,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatValue(hVal),
                  textAlign: TextAlign.start,
                  style: valueStyle(homeLeads),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  localizedStatLabel(context, type),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EType.body(
                      color: c.ink,
                      size: 13,
                      weight: FontWeight.w500,
                      hebrew: isHe),
                ),
              ),
              Expanded(
                child: Text(
                  _formatValue(aVal),
                  textAlign: TextAlign.end,
                  style: valueStyle(awayLeads),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _bar(hNum, aNum),
        ],
      ),
    );
  }

  // One continuous bar split at the ratio: home grows from the start edge,
  // away from the end edge, and the two colours meet in the middle with no
  // track showing between them.
  Widget _bar(double homeVal, double awayVal) {
    final c = context.col;
    const h = 5.0;
    final total = homeVal + awayVal;

    // Nothing recorded for either side — a flat track, rather than an
    // arbitrary 50/50 split that would imply data we don't have.
    if (total <= 0) {
      return Container(
        height: h,
        decoration: BoxDecoration(
          color: c.cardHi,
          borderRadius: BorderRadius.circular(h / 2),
        ),
      );
    }

    // Scaled to 1000ths so small differences still shift the seam, and floored
    // at 1 so a zero side stays a hairline rather than vanishing.
    final hFlex = ((homeVal / total) * 1000).round().clamp(1, 999);

    return ClipRRect(
      borderRadius: BorderRadius.circular(h / 2),
      child: SizedBox(
        height: h,
        child: Row(
          // MUST stretch: a childless ColoredBox takes its height from its
          // constraints, and a Row's default centre alignment would collapse
          // both halves to zero height.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: hFlex, child: ColoredBox(color: _homeColor)),
            Expanded(flex: 1000 - hFlex, child: ColoredBox(color: _awayColor)),
          ],
        ),
      ),
    );
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    final s = v.toString().replaceAll('%', '').trim();
    return double.tryParse(s) ?? 0;
  }

  /// Returns the percent value as 0–1, or null if not a percent string.
  double? _percentFraction(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    if (!s.contains('%')) return null;
    final n = double.tryParse(s.replaceAll('%', '').trim());
    if (n == null) return null;
    return n / 100.0;
  }

  String _formatValue(dynamic v) {
    if (v == null) return '–';
    return v.toString();
  }
}
