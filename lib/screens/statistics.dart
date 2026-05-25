import 'package:flutter/material.dart';
import 'package:football/models/guesses.dart';
import 'package:football/resources/guessesMethods.dart';
import 'package:football/resources/usersMethods.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:football/l10n/app_localizations.dart';
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
  int _topScorerPoints = 0;
  int _championPoints = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserGuesses();
  }

  Future<void> _fetchUserGuesses() async {
    try {
      // Guesses + user-doc are independent — fire in parallel so we pay one
      // round-trip latency instead of two.
      final results = await Future.wait([
        GuessesMethods().fetchThisUserGuesses(widget.userId),
        UsersMethods().fetchUserById(widget.userId).catchError((e) {
          print('Error fetching user points: $e');
          return <String, dynamic>{};
        }),
      ]);
      final guesses = results[0] as List<Guess>;
      final userData = results[1] as Map<String, dynamic>;

      final leagueID = widget.leagueId as int;
      final leagueKey = '$leagueID';
      final filtered =
          guesses.where((g) => g.leagueId == leagueID).toList();

      int leaguePoints(dynamic field) {
        if (field is Map && field[leagueKey] != null) {
          return (field[leagueKey] as num).toInt();
        }
        return 0;
      }

      final topScorerPts = leaguePoints(userData['topScorerPoints']);
      final championPts = leaguePoints(userData['championPoints']);

      setState(() {
        userGuesses = filtered;
        directGuesses = filtered.where((g) => g.direct == 1).toList();
        directionGuesses =
            filtered.where((g) => g.direction == 1).toList();
        _topScorerPoints = topScorerPts;
        _championPoints = championPts;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching user guesses: $e');
      setState(() => isLoading = false);
    }
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
            Text('PLAYER',
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
              _sectionLabel('OVERVIEW', c),
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
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              Container(height: 1, color: c.hairline),
              const SizedBox(height: 24),

              // ── Accuracy section ────────────────────────────────────
              _sectionLabel('ACCURACY', c),
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
              _sectionLabel('POINTS', c),
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
          ),
          Container(height: 1, color: c.hairline),
          _PointsRow(
            label: l.championPointsLabel,
            value: isLoading ? '—' : _championPoints.toString(),
            accent: c.flag,
          ),
        ],
      ),
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
  });
  final String value;
  final String label;
  final Color accent;
  final bool isLarge;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Container(
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
        ],
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
class _PointsRow extends StatelessWidget {
  const _PointsRow({
    required this.label,
    required this.value,
    required this.accent,
    this.isTotal = false,
  });
  final String label;
  final String value;
  final Color accent;
  final bool isTotal;

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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label.toUpperCase(),
            style: EType.label(
              color: isTotal ? c.ink : c.inkMute,
              size: 11,
              letterSpacing: 1.8,
            ),
          ),
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
