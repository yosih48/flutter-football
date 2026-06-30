import 'package:flutter/material.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:football/resources/stats_service.dart';
import 'package:football/utils/localized_stat_label.dart';
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
    const playedOrLive = {'FT', 'AET', 'PEN', '1H', '2H', 'HT', 'ET', 'P', 'LIVE'};
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

  Widget _teamHeader(String homeLogo, String awayLogo) {
    return Row(
      children: [
        _logo(homeLogo),
        const Spacer(),
        _logo(awayLogo),
      ],
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
        .firstWhere((s) => s.type == type, orElse: () => StatItem(type: type, value: null))
        .value;
    final aVal = away.statistics
        .firstWhere((s) => s.type == type, orElse: () => StatItem(type: type, value: null))
        .value;

    final hPct = _percentFraction(hVal);
    final aPct = _percentFraction(aVal);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatValue(hVal),
                  textAlign: TextAlign.start,
                  style: EType.numeric(color: c.ink, size: 13, weight: FontWeight.w600),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  localizedStatLabel(context, type).toUpperCase(),
                  textAlign: TextAlign.center,
                  style: EType.label(color: c.inkDim, size: 10, letterSpacing: 1.4),
                ),
              ),
              Expanded(
                child: Text(
                  _formatValue(aVal),
                  textAlign: TextAlign.end,
                  style: EType.numeric(color: c.ink, size: 13, weight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (hPct != null || aPct != null) ...[
            const SizedBox(height: 6),
            _bar(hPct ?? 0, aPct ?? 0),
          ] else ...[
            const SizedBox(height: 4),
            _bar(_normalize(hVal, aVal).$1, _normalize(hVal, aVal).$2),
          ],
        ],
      ),
    );
  }

  Widget _bar(double homeFrac, double awayFrac) {
    final c = context.col;
    final total = homeFrac + awayFrac;
    final h = total == 0 ? 0.5 : homeFrac / total;
    return SizedBox(
      height: 3,
      child: Row(
        children: [
          Expanded(
            flex: (h * 1000).round().clamp(1, 999),
            child: Container(color: c.live),
          ),
          Expanded(
            flex: ((1 - h) * 1000).round().clamp(1, 999),
            child: Container(color: c.amber),
          ),
        ],
      ),
    );
  }

  (double, double) _normalize(dynamic a, dynamic b) {
    final av = _toDouble(a);
    final bv = _toDouble(b);
    return (av, bv);
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
