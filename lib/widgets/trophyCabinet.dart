import 'package:flutter/material.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:football/models/season_record.dart';
import 'package:football/resources/league_config_service.dart';
import 'package:football/resources/trophyMethods.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:football/utils/localized_team_name.dart';
import 'package:football/utils/he_player_name.dart';
import 'package:skeletonizer/skeletonizer.dart';

// Trophy cabinet: the user's archived past-season records, grouped by season.
// Mounted below the predictions on the profile once the user record loads.
class TrophyCabinetTab extends StatefulWidget {
  const TrophyCabinetTab({
    super.key,
    required this.userId,
    required this.allowedIds,
    this.methods = const TrophyMethods(),
  });

  final String userId;
  // Supported ∩ opted-in league ids (string), same set the profile uses.
  final Set<String> allowedIds;
  final TrophyMethods methods;

  @override
  State<TrophyCabinetTab> createState() => _TrophyCabinetTabState();
}

class _TrophyCabinetTabState extends State<TrophyCabinetTab> {
  List<SeasonRecord> _history = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final history = await widget.methods.fetchHistory(widget.userId);
      if (!mounted) return;
      setState(() {
        _history = _filter(history);
        _loading = false;
      });
    } catch (_) {
      // A failed fetch falls through to the empty state; the user can reopen
      // the tab to retry (initState re-runs on remount).
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<SeasonRecord> _filter(List<SeasonRecord> src) =>
      src.where((r) => widget.allowedIds.contains(r.leagueId.toString())).toList();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    if (_loading) {
      // Shimmer skeleton: a season header + a couple of placeholder cards,
      // shaped like the real content so the load feels seamless.
      const placeholder = SeasonRecord(
        leagueId: 0,
        season: 2026,
        current: false,
        points: 120,
        rank: 3,
        totalPlayers: 24,
        winnerPick: 'Portugal',
        championName: 'Portugal',
        championCorrect: false,
        championPoints: 0,
        topScorerPick: 'Harry Kane',
        topScorerPoints: 12,
        bracketPoints: 0,
      );
      return Skeletonizer(
        enabled: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(label: '${l.trophySeason} 2026'),
            const _TrophyCard(record: placeholder),
            const _TrophyCard(record: placeholder),
          ],
        ),
      );
    }

    if (_history.isEmpty) {
      return _CabinetEmpty(title: l.noTrophiesYet, subtitle: l.noTrophiesHint);
    }

    // Group archived history by season, newest first.
    final seasons = <int>{for (final r in _history) r.season}.toList()
      ..sort((a, b) => b.compareTo(a));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in seasons) ...[
          _SectionHeader(label: '${l.trophySeason} $s'),
          ..._history.where((r) => r.season == s).map((r) => _TrophyCard(record: r)),
        ],
      ],
    );
  }
}

String _leagueName(BuildContext context, int leagueId) {
  final remote = LeagueConfigService()
      .nameFor(leagueId, Localizations.localeOf(context).languageCode);
  return remote ?? leagueId.toString();
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Text(
        label.toUpperCase(),
        style: EType.label(color: c.inkDim, size: 11, letterSpacing: 1.5),
      ),
    );
  }
}

class _TrophyCard extends StatelessWidget {
  const _TrophyCard({required this.record});
  final SeasonRecord record;

  Color _rankColor(EditorialColors c) {
    switch (record.rank) {
      case 1:
        return const Color(0xFFD4AF37); // gold
      case 2:
        return const Color(0xFFAAB2BD); // silver
      case 3:
        return const Color(0xFFCD7F32); // bronze
      default:
        return c.inkDim;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final l = AppLocalizations.of(context)!;
    final rankColor = _rankColor(c);
    final hasChampionPick = record.winnerPick != null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: dark trophy badge + title/subtitle + rank pill
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c.ink,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.emoji_events,
                      size: 22, color: Color(0xFFD4AF37)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _leagueName(context, record.leagueId),
                        style: EType.display(
                            size: 16, color: c.ink, letterSpacing: 0.2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (hasChampionPick) ...[
                        const SizedBox(height: 3),
                        // The champion pick (team name, in Hebrew).
                        Text(
                          localizedTeamName(context, record.winnerPick!),
                          style: EType.display(
                              size: 13, color: c.ink, letterSpacing: 0.2),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          record.championCorrect ? l.championHit : l.championMiss,
                          style: EType.body(
                            color: record.championCorrect ? c.live : c.inkMute,
                            size: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (record.rank != null) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      border: Border.all(color: rankColor, width: 1.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '#${record.rank} ${l.trophyOf} ${record.totalPlayers}',
                      style: EType.numeric(
                          color: rankColor, size: 11, weight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: c.hairline),
          // Bottom: top scorer (leading) + big points (trailing)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Row(
              children: [
                if (record.topScorerPick != null)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.trophyTopScorerLabel,
                          style: EType.label(
                              color: c.inkDim, size: 10, letterSpacing: 1),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          localizedPlayerName(context, record.topScorerPick!),
                          style: EType.display(
                              size: 15, color: c.ink, letterSpacing: 0.2),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${record.topScorerPoints} ${l.pst}',
                          style: EType.body(color: c.inkDim, size: 11),
                        ),
                      ],
                    ),
                  )
                else
                  const Spacer(),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${record.points}',
                      style: EType.display(size: 28, color: c.ink),
                    ),
                    Text(
                      l.statisticsPoints,
                      style: EType.label(
                          color: c.inkDim, size: 10, letterSpacing: 1),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CabinetEmpty extends StatelessWidget {
  const _CabinetEmpty({required this.title, required this.subtitle});
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
            child: Icon(Icons.emoji_events_outlined, size: 26, color: c.inkDim),
          ),
          const SizedBox(height: 18),
          Text(
            title.toUpperCase(),
            style: EType.display(size: 22, color: c.ink, letterSpacing: 1.2),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: EType.body(color: c.inkMute, size: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}
