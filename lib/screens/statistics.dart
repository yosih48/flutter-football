import 'package:flutter/material.dart';
import 'package:football/models/games.dart';
import 'package:football/models/guesses.dart';
import 'package:football/resources/gamesMethods.dart';
import 'package:football/resources/guessesMethods.dart';
import 'package:football/resources/usersMethods.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:football/utils/localized_team_name.dart';
import 'package:football/utils/he_player_name.dart';
import 'package:football/widgets/seasonPickers.dart';
import 'package:skeletonizer/skeletonizer.dart';

class Statistics extends StatefulWidget {
  final userId;
  final leagueId;
  const Statistics({super.key, this.userId, this.leagueId});

  @override
  State<Statistics> createState() => _StatisticsState();
}

class _StatisticsState extends State<Statistics> {
  List<Guess> userGuesses = [];
  List<Guess> directGuesses = [];
  List<Guess> directionGuesses = [];
  // fixtureId → Game for the current league, so a tapped metric can list each
  // guess alongside its team names and the actual result. Built from the games
  // already fetched below — no extra network round-trip.
  final Map<int, Game> _gamesById = {};
  int _topScorerPoints = 0;
  int _championPoints = 0;
  // This player's pre-season predictions for the current league. Revealed to
  // everyone only once the league has kicked off (see _leagueStarted) so picks
  // can't be copied before the season begins.
  String _winnerPick = '';
  String _topScorerPick = '';
  // Crest URLs, re-derived from the league lists once picks are known. Logos pop
  // in asynchronously; the Hebrew names render immediately without them.
  String? _winnerLogo;
  String? _topScorerLogo;
  bool _leagueStarted = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserGuesses();
  }

  Future<void> _fetchUserGuesses() async {
    try {
      final leagueID = widget.leagueId as int;

      // Guesses + user-doc + league games are independent — fire in parallel so
      // we pay one round-trip latency instead of three.
      final results = await Future.wait([
        GuessesMethods().fetchThisUserGuesses(widget.userId),
        UsersMethods().fetchUserById(widget.userId).catchError((e) {
          print('Error fetching user points: $e');
          return <String, dynamic>{};
        }),
        GamesMethods().fetchGamesForLeague(leagueID).catchError((e) {
          print('Error fetching league games: $e');
          return <Game>[];
        }),
      ]);
      final guesses = results[0] as List<Guess>;
      final userData = results[1] as Map<String, dynamic>;
      final games = results[2] as List<Game>;

      final leagueKey = '$leagueID';

      // Only games whose kickoff has already passed count toward stats — so the
      // accuracy percentage reflects only games that have actually started/played,
      // not pending guesses for upcoming fixtures. `timestamp` is epoch seconds.
      final nowSecs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final startedFixtureIds = games
          .where((g) => g.timestamp <= nowSecs)
          .map((g) => g.fixtureId)
          .toSet();

      final filtered = guesses
          .where((g) =>
              g.leagueId == leagueID &&
              startedFixtureIds.contains(g.gameOriginalId))
          .toList();

      int leaguePoints(dynamic field) {
        if (field is Map && field[leagueKey] != null) {
          return (field[leagueKey] as num).toInt();
        }
        return 0;
      }

      final topScorerPts = leaguePoints(userData['topScorerPoints']);
      final championPts = leaguePoints(userData['championPoints']);

      // Winner/topScorer picks are stored as plain name strings keyed by league.
      String leaguePick(dynamic field) {
        if (field is Map && field[leagueKey] != null) {
          return field[leagueKey].toString();
        }
        return '';
      }

      final winnerPick = leaguePick(userData['winner']);
      final topScorerPick = leaguePick(userData['topScorer']);

      setState(() {
        _gamesById
          ..clear()
          ..addEntries(games.map((g) => MapEntry(g.fixtureId, g)));
        userGuesses = filtered;
        directGuesses = filtered.where((g) => g.direct == 1).toList();
        directionGuesses = filtered.where((g) => g.direction == 1).toList();
        _topScorerPoints = topScorerPts;
        _championPoints = championPts;
        _winnerPick = winnerPick;
        _topScorerPick = topScorerPick;
        _leagueStarted = startedFixtureIds.isNotEmpty;
        isLoading = false;
      });

      // Only fetch crests when the section will actually render (league started
      // and a pick exists), so we don't hit the team/player lists needlessly.
      if (_leagueStarted) _resolvePickLogos(leagueID);
    } catch (e) {
      print('Error fetching user guesses: $e');
      setState(() => isLoading = false);
    }
  }

  // Resolve the winner/top-scorer crests in the background and fold them in when
  // ready. Fails soft: a missing logo just leaves the generic fallback icon.
  Future<void> _resolvePickLogos(int leagueId) async {
    final winnerLogo = _winnerPick.isEmpty
        ? null
        : await resolveWinnerLogo(leagueId, _winnerPick);
    final topScorerLogo = _topScorerPick.isEmpty
        ? null
        : await resolveTopScorerLogo(leagueId, _topScorerPick);
    if (!mounted) return;
    setState(() {
      _winnerLogo = winnerLogo;
      _topScorerLogo = topScorerLogo;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final l = AppLocalizations.of(context)!;
    final total = userGuesses.length;
    final direct = directGuesses.length;
    final direction = directionGuesses.length;

    // Accuracy ratios (guard div-by-zero)
    final directPct = total > 0 ? direct / total : 0.0;
    final directionPct = total > 0 ? direction / total : 0.0;

    return Scaffold(
      backgroundColor: c.pitch,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: c.pitch,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: c.ink, size: 20),
        toolbarHeight: 72,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.playerLabel.toUpperCase(),
                style:
                    EType.label(color: c.inkDim, size: 10, letterSpacing: 3)),
            const SizedBox(height: 2),
            Text(
              l.statistics.toUpperCase(),
              style: EType.screenTitle(
                size: 26,
                color: c.ink,
                hebrew: Localizations.localeOf(context).languageCode == 'he',
              ),
            ),
          ],
        ),
      ),
      body: Skeletonizer(
        enabled: isLoading,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Overview: headline + split bar, on the page surface ──
              _SectionHeader(label: l.statisticsOverview),
              const SizedBox(height: 14),
              _buildOverview(context, l, c, total, direct, direction),
              const SizedBox(height: 28),

              // ── Accuracy ────────────────────────────────────────────
              _SectionHeader(label: l.statisticsAccuracy),
              const SizedBox(height: 12),
              _Card(
                child: Column(
                  children: [
                    _AccuracyBar(
                      label: l.directGuesses,
                      count: direct,
                      total: total,
                      ratio: directPct,
                      color: c.live,
                      isLoading: isLoading,
                    ),
                    _AccuracyBar(
                      label: l.directionGuesses,
                      count: direction,
                      total: total,
                      ratio: directionPct,
                      color: c.amber,
                      isLoading: isLoading,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Points ──────────────────────────────────────────────
              _SectionHeader(label: l.statisticsPoints),
              const SizedBox(height: 12),
              _Card(child: _buildPointsBreakdown(context, l, c)),
            ],
          ),
        ),
      ),
    );
  }

  // Headline total + segmented split + legend. Same three numbers as before
  // (total / exact / direction) plus the derived miss count, which is what the
  // segmented bar needs to add up to 100%.
  Widget _buildOverview(
    BuildContext context,
    AppLocalizations l,
    EditorialColors c,
    int total,
    int direct,
    int direction,
  ) {
    // Derived for display only — clamped so an overlapping direct/direction
    // classification can never render a negative segment.
    final misses = (total - direct - direction).clamp(0, total);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Headline: big value pinned to the start edge (right in RTL), the
        // label sitting alongside it on the same baseline.
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              isLoading ? '—' : total.toString(),
              key: const Key('stats-total'),
              style: EType.scoreboard(size: 40, color: c.ink),
            ),
            const SizedBox(width: 12),
            // Fills the rest so the label sits immediately alongside the
            // number (start-aligned = hugging it in both RTL and LTR).
            Expanded(
              child: Text(
                l.totalGuesses,
                style: EType.body(color: c.inkMute, size: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // The split bar and its legend are a chart, not prose: they read
        // worst→best (grey, amber, green) left-to-right in the design, so both
        // are pinned LTR. The Hebrew labels inside still shape themselves RTL.
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatsSegmentedBar(
                segments: [
                  StatsSegment(misses, c.inkFaint),
                  StatsSegment(direction, c.amber),
                  StatsSegment(direct, c.live),
                ],
                track: c.hairline,
                isLoading: isLoading,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _LegendItem(
                    value: misses,
                    label: l.statisticsMisses,
                    color: c.inkFaint,
                    isLoading: isLoading,
                  ),
                  _LegendItem(
                    value: direction,
                    label: l.directionGuesses,
                    color: c.amber,
                    isLoading: isLoading,
                    onTap: isLoading || direction == 0
                        ? null
                        : () => _showGuessesSheet(
                            l.directionGuesses, directionGuesses, c.amber),
                  ),
                  _LegendItem(
                    value: direct,
                    label: l.directGuesses,
                    color: c.live,
                    isLoading: isLoading,
                    onTap: isLoading || direct == 0
                        ? null
                        : () => _showGuessesSheet(
                            l.directGuesses, directGuesses, c.live),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPointsBreakdown(
      BuildContext context, AppLocalizations l, EditorialColors c) {
    final matchPts =
        userGuesses.fold<double>(0.0, (sum, g) => sum + g.sumPoints);
    final directPts =
        directGuesses.fold<double>(0.0, (sum, g) => sum + g.sumPoints);
    final directionPts =
        directionGuesses.fold<double>(0.0, (sum, g) => sum + g.sumPoints);

    // Grand total = every match guess PLUS the tournament bonuses, so the
    // figure in the dark bar is the sum of every row shown above it.
    final totalPts = matchPts + _topScorerPoints + _championPoints;

    String fmt(double v) =>
        v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Match guesses ────────────────────────────────────────────
        _PointsGroupHeader(label: l.statisticsMatchGuesses),
        _PointsRow(
          label: l.directGuesses,
          value: isLoading ? '—' : fmt(directPts),
          accent: c.live,
        ),
        _PointsRow(
          label: l.directionGuesses,
          value: isLoading ? '—' : fmt(directionPts),
          accent: c.amber,
        ),

        // ── Tournament bonus ─────────────────────────────────────────
        _PointsGroupHeader(label: l.statisticsTournamentBonus),
        _PointsRow(
          label: l.topScorerPointsLabel,
          value: isLoading ? '—' : _topScorerPoints.toString(),
          accent: c.live,
          // Reveal the actual pick (Hebrew name + crest) once the league has
          // started — before that it stays hidden so picks can't be copied.
          pickName: _showPicks && _topScorerPick.isNotEmpty
              ? localizedPlayerName(context, _topScorerPick)
              : null,
          pickLogo: _topScorerLogo,
          pickFallbackIcon: Icons.sports_soccer_outlined,
        ),
        _PointsRow(
          label: l.championPointsLabel,
          value: isLoading ? '—' : _championPoints.toString(),
          accent: c.flag,
          pickName: _showPicks && _winnerPick.isNotEmpty
              ? localizedTeamName(context, _winnerPick)
              : null,
          pickLogo: _winnerLogo,
          pickFallbackIcon: Icons.emoji_events_outlined,
        ),

        // ── Total ────────────────────────────────────────────────────
        // Unchanged figure: the sum over every counted guess (misses included
        // at 0), which is exactly what the old "total" row showed.
        _TotalPointsRow(
          label: l.statisticsTotalPoints,
          value: isLoading ? '—' : fmt(totalPts),
        ),
      ],
    );
  }

  // Picks are revealed to everyone only after the league kicks off, so they
  // can't be copied pre-season.
  bool get _showPicks => !isLoading && _leagueStarted;

  // Reveal the individual guesses behind a tapped metric. Everything is already
  // in memory (guesses + games), so this opens instantly with no extra fetch.
  void _showGuessesSheet(String title, List<Guess> guesses, Color accent) {
    final c = context.col;
    final l = AppLocalizations.of(context)!;
    // Most recent first — mirrors how players think about their latest games.
    final sorted = [...guesses]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    showModalBottomSheet(
      context: context,
      backgroundColor: c.pitch,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final maxHeight = MediaQuery.of(ctx).size.height * 0.8;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              // Grab handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(width: 18, height: 1, color: accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${title.toUpperCase()}  ·  ${sorted.length}',
                        style: EType.label(
                            color: c.ink, size: 12, letterSpacing: 2),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: sorted.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(l.noGuesses,
                            style: EType.label(color: c.inkMute, size: 12)),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                        physics: const BouncingScrollPhysics(),
                        itemCount: sorted.length,
                        separatorBuilder: (_, __) =>
                            Container(height: 1, color: c.hairline),
                        itemBuilder: (_, i) => _GuessRow(
                          guess: sorted[i],
                          game: _gamesById[sorted[i].gameOriginalId],
                          accent: accent,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Card shell ──────────────────────────────────────────────────────────
// Section label that sits ON the page surface, above its card — a short green
// dash plus a quiet caption, as in the design.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4),
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
            label,
            style: EType.body(color: c.inkMute, size: 12),
          ),
        ],
      ),
    );
  }
}

// Plain white rounded surface. Contents are clipped so the group bands and the
// dark total bar sit flush against the rounded corners.
class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.hairline, width: 1),
      ),
      child: child,
    );
  }
}

// ── Segmented split bar ─────────────────────────────────────────────────
@visibleForTesting
class StatsSegment {
  const StatsSegment(this.value, this.color);
  final int value;
  final Color color;
}

@visibleForTesting
class StatsSegmentedBar extends StatelessWidget {
  const StatsSegmentedBar({
    super.key,
    required this.segments,
    required this.track,
    required this.isLoading,
  });
  final List<StatsSegment> segments;
  final Color track;
  final bool isLoading;

  static const double height = 10.0;

  @override
  Widget build(BuildContext context) {
    final sum = segments.fold<int>(0, (a, s) => a + s.value);

    if (isLoading || sum == 0) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: track,
          borderRadius: BorderRadius.circular(height / 2),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Row(
          // MUST stretch: a childless ColoredBox takes its size from its
          // constraints, and a Row's default centre alignment passes LOOSE
          // vertical constraints — which collapsed every segment to zero
          // height and made the whole bar invisible whenever there was data.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final s in segments)
              if (s.value > 0)
                Expanded(flex: s.value, child: ColoredBox(color: s.color)),
          ],
        ),
      ),
    );
  }
}

// ── Legend entry under the segmented bar ────────────────────────────────
class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.value,
    required this.label,
    required this.color,
    required this.isLoading,
    this.onTap,
  });
  final int value;
  final String label;
  final Color color;
  final bool isLoading;
  final VoidCallback? onTap;

  /// Misses are the "inactive" series in the design — grey dot, muted figure —
  /// while the two scoring series keep a full-contrast number.
  bool get _muted => onTap == null;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Padding(
      // Grouped from the leading edge with an even gap rather than spread
      // across the full width — matches the design.
      padding: const EdgeInsets.only(right: 28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  isLoading ? '—' : value.toString(),
                  style: EType.numeric(
                      color: _muted ? c.inkDim : c.ink,
                      size: 17,
                      weight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              style: EType.body(color: c.inkDim, size: 11),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Accuracy bar ────────────────────────────────────────────────────────
class _AccuracyBar extends StatelessWidget {
  const _AccuracyBar({
    required this.label,
    required this.count,
    required this.total,
    required this.ratio,
    required this.color,
    required this.isLoading,
  });
  final String label;
  final int count;
  final int total;
  final double ratio;
  final Color color;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final pct = (ratio * 100).round();

    const barHeight = 6.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EType.body(
                      color: c.ink, size: 13, weight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 10),
              // Split into separate widgets rather than one "$count / $total"
              // string: a numeric string is a bidi island that always renders
              // LTR, so the two figures would sit the wrong way round in Hebrew.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(isLoading ? '—' : '$count',
                      style: EType.numeric(color: c.inkDim, size: 11)),
                  Text(' / ', style: EType.numeric(color: c.inkDim, size: 11)),
                  Text(isLoading ? '—' : '$total',
                      style: EType.numeric(color: c.inkDim, size: 11)),
                ],
              ),
              const SizedBox(width: 10),
              // Fixed-width so the percentages line up in a straight column
              // regardless of whether they're 1, 2 or 3 digits.
              SizedBox(
                width: 40,
                child: Text(
                  isLoading ? '—%' : '$pct%',
                  textAlign: TextAlign.end,
                  style: EType.numeric(
                    color: color,
                    size: 14,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Track. The fill is start-aligned, so it grows from the right in
          // Hebrew and from the left in English.
          Container(
            height: barHeight,
            decoration: BoxDecoration(
              color: c.hairline,
              borderRadius: BorderRadius.circular(barHeight / 2),
            ),
            child: LayoutBuilder(
              builder: (_, constraints) => Align(
                alignment: AlignmentDirectional.centerStart,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  width: isLoading
                      ? 0
                      : constraints.maxWidth * ratio.clamp(0.0, 1.0),
                  height: barHeight,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(barHeight / 2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Points breakdown row ────────────────────────────────────────────────
// For the top-scorer / champion rows, [pickName] (+ optional [pickLogo]) reveals
// who the player predicted, rendered as a crest + Hebrew name between the label
// and the points so the points are tied to the actual prediction.
class _PointsRow extends StatelessWidget {
  const _PointsRow({
    required this.label,
    required this.value,
    required this.accent,
    this.pickName,
    this.pickLogo,
    this.pickFallbackIcon,
  });
  final String label;
  final String value;
  final Color accent;
  final String? pickName;
  final String? pickLogo;
  final IconData? pickFallbackIcon;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Min width so short labels (e.g. אלופה) pad out to the same start as
          // longer ones (מלך שערים), keeping the pick names in a straight
          // vertical line across rows. Longer labels grow past it freely.
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 116),
            child: Text(
              label,
              style: EType.body(color: c.ink, size: 13),
            ),
          ),
          // Pick reveal fills the middle so the label stays at the start and the
          // points stay at the end; empty when there's no pick to show.
          Expanded(
            child: pickName == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsetsDirectional.only(start: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Crest(
                            logoUrl: pickLogo,
                            fallback: pickFallbackIcon ??
                                Icons.sports_soccer_outlined),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            pickName!,
                            overflow: TextOverflow.ellipsis,
                            style: EType.body(color: c.inkMute, size: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: EType.numeric(
              color: accent,
              size: 17,
              weight: FontWeight.w700,
            ),
          ),
          // Colour indicator, preserved from the old left-border accent.
          const SizedBox(width: 12),
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Points sub-group band ───────────────────────────────────────────────
class _PointsGroupHeader extends StatelessWidget {
  const _PointsGroupHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Container(
      width: double.infinity,
      color: c.cardHi,
      padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
      child: Text(
        label,
        style: EType.body(color: c.inkDim, size: 11),
      ),
    );
  }
}

// ── Dark total bar closing the points card ──────────────────────────────
class _TotalPointsRow extends StatelessWidget {
  const _TotalPointsRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    // Flush to the card's edges — the parent _Card clips it to the rounded
    // bottom corners, so no margin or radius of its own.
    return Container(
      width: double.infinity,
      color: c.ink,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style:
                  EType.body(color: c.card, size: 13, weight: FontWeight.w600),
            ),
          ),
          Text(
            value,
            style:
                EType.numeric(color: c.card, size: 20, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ── One guess row inside the metric sheet ───────────────────────────────
// Shows the fixture (localized team names), the player's predicted score, the
// actual result when known, and the points that guess earned.
class _GuessRow extends StatelessWidget {
  const _GuessRow({
    required this.guess,
    required this.game,
    required this.accent,
  });
  final Guess guess;
  final Game? game;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final l = AppLocalizations.of(context)!;

    final homeName =
        game != null ? localizedTeamName(context, game!.home.name) : '';
    final awayName =
        game != null ? localizedTeamName(context, game!.away.name) : '';

    final hasResult =
        game != null && game!.goals.home != null && game!.goals.away != null;

    String fmtPts(double v) =>
        v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);

    final scoreStyle =
        EType.numeric(color: c.ink, size: 14, weight: FontWeight.w700);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (game != null)
                  // Score is split into per-team goal widgets (home, dash, away)
                  // rather than one "1-2" string. A single numeric string is a
                  // bidi "island" that always renders LTR, so in Hebrew (RTL) the
                  // digits would sit next to the wrong team. Separate widgets let
                  // the row's direction place each goal beside its own team.
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          homeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: EType.label(
                              color: c.ink, size: 13, letterSpacing: 0.3),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: hasResult
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('${game!.goals.home}',
                                      style: scoreStyle),
                                  Text('-', style: scoreStyle),
                                  Text('${game!.goals.away}',
                                      style: scoreStyle),
                                ],
                              )
                            : Text('–', style: scoreStyle),
                      ),
                      Flexible(
                        child: Text(
                          awayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: EType.label(
                              color: c.ink, size: 13, letterSpacing: 0.3),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 6),
                _ScoreChip(
                  caption: l.guess,
                  homeGoals: guess.homeTeamGoals,
                  awayGoals: guess.awayTeamGoals,
                  color: accent,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                fmtPts(guess.sumPoints),
                style: EType.numeric(
                    color: accent, size: 18, weight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                l.points.toUpperCase(),
                style:
                    EType.label(color: c.inkMute, size: 8, letterSpacing: 1.4),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// A small captioned score pill: caption on top, home/away goals beneath it.
// The goals are split into separate widgets (home, dash, away) so they line up
// with their teams in both LTR and RTL — a single "h-a" string is a bidi island
// that renders LTR everywhere and would read backwards in Hebrew.
class _ScoreChip extends StatelessWidget {
  const _ScoreChip({
    required this.caption,
    required this.homeGoals,
    required this.awayGoals,
    required this.color,
  });
  final String caption;
  final String homeGoals;
  final String awayGoals;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final scoreStyle =
        EType.numeric(color: color, size: 14, weight: FontWeight.w700);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          caption.toUpperCase(),
          style: EType.label(color: c.inkMute, size: 8, letterSpacing: 1.2),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(homeGoals, style: scoreStyle),
            Text('-', style: scoreStyle),
            Text(awayGoals, style: scoreStyle),
          ],
        ),
      ],
    );
  }
}

// Circular crest frame matching the season-picker dropdown rows. Falls back to
// a generic icon while the logo is still resolving or when none is available.
class _Crest extends StatelessWidget {
  const _Crest({required this.logoUrl, required this.fallback});
  final String? logoUrl;
  final IconData fallback;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    if (logoUrl == null || logoUrl!.isEmpty) {
      return Icon(fallback, size: 16, color: c.inkMute);
    }
    return Container(
      width: 22,
      height: 22,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: c.cardHi,
        shape: BoxShape.circle,
        border: Border.all(color: c.hairline, width: 1),
      ),
      child: Image.network(
        logoUrl!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(fallback, size: 12, color: c.inkDim),
      ),
    );
  }
}
