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

// Trophy cabinet: the user's archived past-season records, grouped by season,
// under a career summary strip. Opened from the profile's cabinet entry card.
class TrophyCabinetTab extends StatefulWidget {
  const TrophyCabinetTab({
    super.key,
    required this.userId,
    this.methods = const TrophyMethods(),
  });

  final String userId;
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
      // Show the full archived history as returned by the backend — trophies
      // are permanent and must NOT be filtered by the user's currently-enabled
      // leagues. A league they played in a past season (but have since opted
      // out of) still belongs in their cabinet.
      final history = await widget.methods.fetchHistory(widget.userId);
      if (!mounted) return;
      setState(() {
        _history = history;
        _loading = false;
      });
    } catch (_) {
      // A failed fetch falls through to the empty state; the user can reopen
      // the tab to retry (initState re-runs on remount).
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    if (_loading) {
      // Shimmer skeleton shaped like the real content — summary strip, a
      // season rule, then a couple of cards — so the load feels seamless.
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SummaryBar(records: [placeholder, placeholder]),
            _SeasonHeader(label: '${l.trophySeason} 2026'),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryBar(records: _history),
        for (final s in seasons) ...[
          _SeasonHeader(label: '${l.trophySeason} $s'),
          ..._history
              .where((r) => r.season == s)
              .map((r) => _TrophyCard(record: r)),
        ],
        const SizedBox(height: 20),
      ],
    );
  }
}

String _leagueName(BuildContext context, int leagueId) {
  final remote = LeagueConfigService()
      .nameFor(leagueId, Localizations.localeOf(context).languageCode);
  return remote ?? leagueId.toString();
}

// Medal colours, shared by the rank badge and the card's edge accent.
const Color _kGold = Color(0xFFD4AF37);
const Color _kSilver = Color(0xFFAAB2BD);
const Color _kBronze = Color(0xFFCD7F32);

Color? _medalColor(int? rank) {
  switch (rank) {
    case 1:
      return _kGold;
    case 2:
      return _kSilver;
    case 3:
      return _kBronze;
    default:
      return null; // off the podium — caller falls back to a neutral tone
  }
}

// ── Career summary ──────────────────────────────────────────────────────────
// Three totals across every archived record: points, podium finishes, wins.
class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.records});
  final List<SeasonRecord> records;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final l = AppLocalizations.of(context)!;

    final total = records.fold<int>(0, (sum, r) => sum + r.points);
    final podiums = records.where((r) => r.rank != null && r.rank! <= 3).length;
    final firsts = records.where((r) => r.rank == 1).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.hairline),
      ),
      child: IntrinsicHeight(
        child: Row(
          // MUST stretch: the 1px dividers are childless and would collapse to
          // zero height under the Row's default centre alignment.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _SummaryStat(
                value: '$total',
                label: l.trophyTotalPoints,
                icon: Icons.bolt,
                iconColor: c.live,
              ),
            ),
            _divider(c),
            Expanded(
              child: _SummaryStat(
                value: '$podiums',
                label: l.trophyPodiums,
                icon: Icons.emoji_events_outlined,
                iconColor: c.inkMute,
              ),
            ),
            _divider(c),
            Expanded(
              child: _SummaryStat(
                value: '$firsts',
                label: l.trophyFirstPlaces,
                icon: Icons.emoji_events,
                iconColor: _kGold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(EditorialColors c) => Container(
      width: 1,
      color: c.hairline,
      margin: const EdgeInsets.symmetric(vertical: 2));
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.value,
    required this.label,
    required this.icon,
    required this.iconColor,
  });
  final String value;
  final String label;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final isHe = Localizations.localeOf(context).languageCode == 'he';
    return Column(
      mainAxisSize: MainAxisSize.min,
      // The parent Row stretches us to the tallest stat; stay centred in it.
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Icon first so it sits on the leading side of the numeral (right in
        // Hebrew), matching the reference layout.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: iconColor),
            const SizedBox(width: 6),
            Text(
              value,
              style: EType.numeric(
                  color: c.ink, size: 24, weight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: EType.body(color: c.inkDim, size: 11, hebrew: isHe),
        ),
      ],
    );
  }
}

// ── Season rule ─────────────────────────────────────────────────────────────
// "Season 2026" followed by a hairline that runs to the far edge.
class _SeasonHeader extends StatelessWidget {
  const _SeasonHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final isHe = Localizations.localeOf(context).languageCode == 'he';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Text(
            label,
            style: EType.body(color: c.inkDim, size: 12, hebrew: isHe),
          ),
          const SizedBox(width: 12),
          Expanded(child: Container(height: 1, color: c.hairline)),
        ],
      ),
    );
  }
}

class _TrophyCard extends StatelessWidget {
  const _TrophyCard({required this.record});
  final SeasonRecord record;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final medal = _medalColor(record.rank);
    final accent = medal ?? c.hairlineHi;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      // Clip so the accent stripe below takes on the card's rounded corners.
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.hairline),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context, c, medal),
              _topScorerStrip(context, c),
            ],
          ),
          // Physical-left edge accent, as in the reference. Positioned rather
          // than a Border side because Border forbids a non-uniform side when
          // a borderRadius is set.
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 5,
            child: ColoredBox(color: accent),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, EditorialColors c, Color? medal) {
    final l = AppLocalizations.of(context)!;
    final isHe = Localizations.localeOf(context).languageCode == 'he';

    return Padding(
      // Extra left inset clears the 5px accent stripe.
      padding: const EdgeInsets.only(left: 18, right: 14, top: 14, bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (record.rank != null) ...[
            _rankBadge(context, c, medal),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _leagueName(context, record.leagueId),
                  style: EType.body(
                      color: c.ink,
                      size: 16,
                      weight: FontWeight.w700,
                      hebrew: isHe),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (record.winnerPick != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    localizedTeamName(context, record.winnerPick!),
                    style: EType.body(
                        color: c.amber,
                        size: 13,
                        weight: FontWeight.w500,
                        hebrew: isHe),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 7),
                  _championChip(context, c, l, isHe),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${record.points}',
                style: EType.numeric(
                    color: c.ink, size: 28, weight: FontWeight.w700),
              ),
              const SizedBox(height: 1),
              Text(
                l.trophyYourPoints,
                style: EType.body(color: c.live, size: 10, hebrew: isHe),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Filled medallion for a podium finish, muted disc otherwise, with the field
  // size ("of 22") underneath.
  Widget _rankBadge(BuildContext context, EditorialColors c, Color? medal) {
    final l = AppLocalizations.of(context)!;
    final isHe = Localizations.localeOf(context).languageCode == 'he';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: medal ?? c.cardHi,
            shape: BoxShape.circle,
            border: Border.all(
              color: medal ?? c.hairline,
              width: 1.5,
            ),
          ),
          child: Text(
            '${record.rank}',
            style: EType.numeric(
              color: medal != null ? Colors.white : c.inkMute,
              size: 17,
              weight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${l.trophyOf} ${record.totalPlayers}',
          style: EType.body(color: c.inkDim, size: 10, hebrew: isHe),
        ),
      ],
    );
  }

  Widget _championChip(
      BuildContext context, EditorialColors c, AppLocalizations l, bool isHe) {
    final hit = record.championCorrect;
    final fg = hit ? c.live : c.inkDim;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: hit ? c.liveSoft : c.cardHi,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(hit ? Icons.check : Icons.close, size: 12, color: fg),
          const SizedBox(width: 4),
          // Flexible: the chip sizes to its content, but the label must give
          // way rather than push the chip past the card on narrow screens.
          Flexible(
            child: Text(
              hit ? l.championHit : l.championMiss,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: EType.body(color: fg, size: 11, hebrew: isHe),
            ),
          ),
        ],
      ),
    );
  }

  // Tinted footer: top-scorer pick and what it earned.
  Widget _topScorerStrip(BuildContext context, EditorialColors c) {
    final l = AppLocalizations.of(context)!;
    final isHe = Localizations.localeOf(context).languageCode == 'he';
    final pick = record.topScorerPick;

    return Container(
      color: c.liveSoft,
      padding: const EdgeInsets.only(left: 18, right: 14, top: 9, bottom: 9),
      // spaceBetween over two shrinkable groups: the slack collects in the
      // middle, so the trailing group stays flush to the end of the row however
      // short the player name is.
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.gps_fixed, size: 13, color: c.inkDim),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    l.trophyTopScorerLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EType.body(color: c.inkDim, size: 11, hebrew: isHe),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // A season with no top-scorer pick keeps the row rather than dropping
          // it, so cards stay the same shape whether or not one was made.
          if (pick == null)
            Text(
              l.trophyNoPick,
              style: EType.body(color: c.inkDim, size: 12, hebrew: isHe),
            )
          else
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${record.topScorerPoints} ${l.pst}',
                    style: EType.body(color: c.inkMute, size: 11, hebrew: isHe),
                  ),
                  const SizedBox(width: 8),
                  // Last child — lands at the end of the row (left in RTL).
                  Flexible(
                    child: Text(
                      localizedPlayerName(context, pick),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EType.body(
                          color: c.ink,
                          size: 12,
                          weight: FontWeight.w600,
                          hebrew: isHe),
                    ),
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
    // Center on BOTH axes. The parent gives this a min-height of the viewport
    // (see TrophyCabinetScreen), so Center has room to work vertically; the
    // full-width SizedBox stops the Column from shrink-wrapping and drifting
    // off-centre horizontally.
    return Center(
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: c.hairline, width: 1),
                ),
                child: Icon(Icons.emoji_events_outlined,
                    size: 26, color: c.inkDim),
              ),
              const SizedBox(height: 18),
              Text(
                title.toUpperCase(),
                style: EType.body(
                    size: 20,
                    color: c.ink,
                    weight: FontWeight.w700,
                    hebrew:
                        Localizations.localeOf(context).languageCode == 'he'),
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
        ),
      ),
    );
  }
}
