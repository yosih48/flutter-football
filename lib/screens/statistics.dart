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
        directionGuesses =
            filtered.where((g) => g.direction == 1).toList();
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
                style: EType.label(
                    color: c.inkDim, size: 10, letterSpacing: 3)),
            const SizedBox(height: 2),
            Text(l.statistics.toUpperCase(),
                style: EType.display(
                    size: 28, color: c.ink, letterSpacing: 1.4)),
          ],
        ),
      ),
      body: Skeletonizer(
        enabled: isLoading,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Section label ───────────────────────────────────────
              _sectionLabel(l.statisticsOverview.toUpperCase(), c),
              const SizedBox(height: 16),

              // ── Big number trio ─────────────────────────────────────
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _MetricBlock(
                        value: isLoading ? '—' : total.toString(),
                        label: l.totalGuesses,
                        accent: c.ink,
                        isLarge: true,
                        onTap: isLoading || total == 0
                            ? null
                            : () => _showGuessesSheet(
                                l.totalGuesses, userGuesses, c.ink),
                      ),
                    ),
                    Container(
                        width: 1, color: c.hairline, margin: const EdgeInsets.symmetric(vertical: 4)),
                    Expanded(
                      child: _MetricBlock(
                        value: isLoading ? '—' : direct.toString(),
                        label: l.directGuesses,
                        accent: c.live,
                        isLarge: false,
                        onTap: isLoading || direct == 0
                            ? null
                            : () => _showGuessesSheet(
                                l.directGuesses, directGuesses, c.live),
                      ),
                    ),
                    Container(
                        width: 1, color: c.hairline, margin: const EdgeInsets.symmetric(vertical: 4)),
                    Expanded(
                      child: _MetricBlock(
                        value: isLoading ? '—' : direction.toString(),
                        label: l.directionGuesses,
                        accent: c.amber,
                        isLarge: false,
                        onTap: isLoading || direction == 0
                            ? null
                            : () => _showGuessesSheet(
                                l.directionGuesses, directionGuesses, c.amber),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              Container(height: 1, color: c.hairline),
              const SizedBox(height: 24),

              // ── Accuracy section ────────────────────────────────────
              _sectionLabel(l.statisticsAccuracy.toUpperCase(), c),
              const SizedBox(height: 20),

              _AccuracyBar(
                label: l.directGuesses,
                count: direct,
                total: total,
                ratio: directPct,
                color: c.live,
                isLoading: isLoading,
              ),
              const SizedBox(height: 18),
              _AccuracyBar(
                label: l.directionGuesses,
                count: direction,
                total: total,
                ratio: directionPct,
                color: c.amber,
                isLoading: isLoading,
              ),

              const SizedBox(height: 24),
              Container(height: 1, color: c.hairline),
              const SizedBox(height: 24),

              // ── Points breakdown ─────────────────────────────────────
              _sectionLabel(l.statisticsPoints.toUpperCase(), c),
              const SizedBox(height: 16),
              _buildPointsBreakdown(context, l, c),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPointsBreakdown(BuildContext context, AppLocalizations l, EditorialColors c) {
    final totalPts = userGuesses.fold<double>(
        0.0, (sum, g) => sum + g.sumPoints);
    final directPts = directGuesses.fold<double>(
        0.0, (sum, g) => sum + g.sumPoints);
    final directionPts = directionGuesses.fold<double>(
        0.0, (sum, g) => sum + g.sumPoints);

    String fmt(double v) =>
        v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.hairline, width: 1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Column(
        children: [
          _PointsRow(
            label: l.totalGuesses,
            value: isLoading ? '—' : fmt(totalPts),
            accent: c.ink,
            isTotal: true,
          ),
          Container(height: 1, color: c.hairline),
          _PointsRow(
            label: l.directGuesses,
            value: isLoading ? '—' : fmt(directPts),
            accent: c.live,
          ),
          Container(height: 1, color: c.hairline),
          _PointsRow(
            label: l.directionGuesses,
            value: isLoading ? '—' : fmt(directionPts),
            accent: c.amber,
          ),
          Container(height: 1, color: c.hairline),
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
          Container(height: 1, color: c.hairline),
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
        ],
      ),
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

  Widget _sectionLabel(String text, EditorialColors c) {
    return Row(
      children: [
        Container(width: 18, height: 1, color: c.live),
        const SizedBox(width: 10),
        Text(text,
            style: EType.label(
                color: c.ink, size: 11, letterSpacing: 2.4)),
      ],
    );
  }
}

// ── Metric block (big number) ───────────────────────────────────────────
class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
    required this.value,
    required this.label,
    required this.accent,
    required this.isLarge,
    this.onTap,
  });
  final String value;
  final String label;
  final Color accent;
  final bool isLarge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final tappable = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              value,
              style: EType.scoreboard(
                size: isLarge ? 64 : 48,
                color: accent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              style: EType.label(
                color: c.inkDim,
                size: 9,
                letterSpacing: 1.6,
              ),
            ),
            // Subtle affordance that the number opens the underlying list.
            if (tappable) ...[
              const SizedBox(height: 6),
              Icon(Icons.expand_more, size: 14, color: accent),
            ],
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label.toUpperCase(),
                style: EType.label(
                    color: c.inkMute, size: 10, letterSpacing: 1.6)),
            Row(
              children: [
                Text(
                  isLoading ? '—' : '$count / $total',
                  style: EType.numeric(
                      color: c.inkDim, size: 11),
                ),
                const SizedBox(width: 10),
                Text(
                  isLoading ? '—%' : '$pct%',
                  style: EType.numeric(
                    color: color,
                    size: 13,
                    weight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Track
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(2),
          ),
          child: LayoutBuilder(
            builder: (_, constraints) => Stack(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  width: isLoading
                      ? 0
                      : constraints.maxWidth * ratio.clamp(0.0, 1.0),
                  height: 4,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
    this.isTotal = false,
    this.pickName,
    this.pickLogo,
    this.pickFallbackIcon,
  });
  final String label;
  final String value;
  final Color accent;
  final bool isTotal;
  final String? pickName;
  final String? pickLogo;
  final IconData? pickFallbackIcon;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isTotal ? c.terrace : Colors.transparent,
        border: Border(
          left: BorderSide(color: accent, width: 3),
        ),
      ),
      child: Row(
        children: [
          // Min width so short labels (e.g. אלופה) pad out to the same start as
          // longer ones (מלך שערים), keeping the pick names in a straight
          // vertical line across rows. Longer labels grow past it freely.
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 116),
            child: Text(
              label.toUpperCase(),
              style: EType.label(
                color: isTotal ? c.ink : c.inkMute,
                size: 11,
                letterSpacing: 1.8,
              ),
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
                            style: EType.label(
                              color: c.ink,
                              size: 12,
                              letterSpacing: 0.4,
                            ),
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
              size: isTotal ? 20 : 16,
              weight: FontWeight.w700,
            ),
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

    final guessScore = '${guess.homeTeamGoals}-${guess.awayTeamGoals}';
    final hasResult =
        game != null && game!.goals.home != null && game!.goals.away != null;
    // The actual result sits inline between the team names (e.g. "teamA 3-2
    // teamB"); a dash stands in until the score is posted.
    final resultScore =
        hasResult ? '${game!.goals.home}-${game!.goals.away}' : '–';

    String fmtPts(double v) =>
        v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);

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
                        child: Text(
                          resultScore,
                          style: EType.numeric(
                              color: c.ink,
                              size: 14,
                              weight: FontWeight.w700),
                        ),
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
                  score: guessScore,
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

// A small captioned score pill: caption on top, "h - a" beneath it.
class _ScoreChip extends StatelessWidget {
  const _ScoreChip({
    required this.caption,
    required this.score,
    required this.color,
  });
  final String caption;
  final String score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          caption.toUpperCase(),
          style: EType.label(color: c.inkMute, size: 8, letterSpacing: 1.2),
        ),
        const SizedBox(height: 2),
        Text(
          score,
          style: EType.numeric(color: color, size: 14, weight: FontWeight.w700),
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
        errorBuilder: (_, __, ___) =>
            Icon(fallback, size: 12, color: c.inkDim),
      ),
    );
  }
}
