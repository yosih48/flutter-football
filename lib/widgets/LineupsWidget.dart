import 'dart:math';
import 'package:flutter/material.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:football/models/lineup.dart';
import 'package:football/resources/lineup_service.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';

// ── Fixed pitch colours — independent of light/dark theme ─────────────────
const Color _kHome  = Color(0xFF4B7BF5); // vivid blue  (home XI)
const Color _kAway  = Color(0xFF28A96C); // vivid green (away XI)
const Color _kPitchDark  = Color(0xFF1A5C38);
const Color _kPitchLight = Color(0xFF1E6842);
const Color _kLine  = Color(0x52FFFFFF); // white @ 32%

// ── Player dot geometry ───────────────────────────────────────────────────
const double _kDia      = 32.0; // circle diameter
const double _kLabelW   = 62.0; // total width incl. name

class LineupsWidget extends StatefulWidget {
  final int fixtureId;
  final DateTime matchDate;
  final String homeTeamName;
  final String awayTeamName;

  const LineupsWidget({
    super.key,
    required this.fixtureId,
    required this.matchDate,
    required this.homeTeamName,
    required this.awayTeamName,
  });

  @override
  State<LineupsWidget> createState() => _LineupsWidgetState();
}

class _LineupsWidgetState extends State<LineupsWidget> {
  final LineupService _lineupService = LineupService();
  LineupResponse? _lineupResponse;
  bool _isLoading = true;
  bool _hasError   = false;

  @override
  void initState() {
    super.initState();
    _fetchLineups();
  }

  @override
  void didUpdateWidget(LineupsWidget old) {
    super.didUpdateWidget(old);
    if (old.fixtureId != widget.fixtureId) _fetchLineups();
  }

  Future<void> _fetchLineups() async {
    setState(() { _isLoading = true; _hasError = false; });

    final response = await _lineupService.getFixtureLineups(
      widget.fixtureId,
      matchDate: widget.matchDate,
    );

    if (!mounted) return;
    setState(() {
      _lineupResponse = response;
      _isLoading = false;
      _hasError   = response == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final l = AppLocalizations.of(context)!;

    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation(c.live),
            ),
          ),
        ),
      );
    }

    if (_hasError) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: GestureDetector(
            onTap: _fetchLineups,
            child: Text(
              l.failedToLoadEvents.toUpperCase(),
              style: EType.label(color: c.inkDim, size: 11, letterSpacing: 2),
            ),
          ),
        ),
      );
    }

    if (_lineupResponse == null ||
        !_lineupResponse!.available ||
        (_lineupResponse!.lineups?.isEmpty ?? true)) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: Text(
            l.lineupsNotAvailable.toUpperCase(),
            style: EType.label(color: c.inkDim, size: 11, letterSpacing: 2),
          ),
        ),
      );
    }

    final lineups = _lineupResponse!.lineups!;
    final home    = lineups[0];
    final away    = lineups.length > 1 ? lineups[1] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Tactical pitch ─────────────────────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: _TacticalPitch(home: home, away: away),
        ),

        // ── Substitutes ────────────────────────────────────────────
        if (home.substitutes.isNotEmpty || (away?.substitutes.isNotEmpty ?? false)) ...[
          const SizedBox(height: 20),
          _SubstitutesSection(home: home, away: away, l: l),
        ],
      ],
    );
  }
}

// ── Tactical pitch ─────────────────────────────────────────────────────────

class _TacticalPitch extends StatelessWidget {
  final TeamLineup  home;
  final TeamLineup? away;
  const _TacticalPitch({required this.home, this.away});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.62, // portrait pitch — height ≈ 1.6 × width
      child: LayoutBuilder(
        builder: (_, constraints) {
          final w     = constraints.maxWidth;
          final h     = constraints.maxHeight;
          final halfH = h / 2;

          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // ── Pitch background ──────────────────────────────
              Positioned.fill(
                child: CustomPaint(painter: _PitchPainter()),
              ),

              // ── Formation chips near centre line ──────────────
              if (home.formation.isNotEmpty)
                Positioned(
                  left: 10,
                  top: halfH - 16,
                  child: _FormationChip(home.formation),
                ),
              if (away != null && away!.formation.isNotEmpty)
                Positioned(
                  left: 10,
                  top: halfH + 4,
                  child: _FormationChip(away!.formation),
                ),

              // ── Home XI — top half, GK at top ─────────────────
              ..._buildTeam(
                home.startXI, w, halfH,
                yOffset: 0, isHome: true,
              ),

              // ── Away XI — bottom half, GK at bottom ───────────
              if (away != null)
                ..._buildTeam(
                  away!.startXI, w, halfH,
                  yOffset: halfH, isHome: false,
                ),
            ],
          );
        },
      ),
    );
  }

  // ── Position calculation ─────────────────────────────────────────────────
  List<Widget> _buildTeam(
    List<LineupPlayer> players,
    double w,
    double halfH, {
    required double yOffset,
    required bool   isHome,
  }) {
    // Group players by formation row (from grid field, fallback to pos).
    final Map<int, List<LineupPlayer>> byRow = {};
    for (final p in players) {
      final row = _gridRow(p.grid) ?? _posToRow(p.pos);
      byRow.putIfAbsent(row, () => []).add(p);
    }
    if (byRow.isEmpty) return [];

    final sortedRows = byRow.keys.toList()..sort();
    final n = sortedRows.length;

    // Leave 10% at pitch edge, 8% at centre line → 82% usable span.
    const edgePad  = 0.10;
    const centPad  = 0.08;
    const usable   = 1.0 - edgePad - centPad;

    final List<Widget> out = [];

    for (int ri = 0; ri < n; ri++) {
      final rowPlayers = List<LineupPlayer>.from(byRow[sortedRows[ri]]!)
        ..sort((a, b) =>
            (_gridCol(a.grid) ?? 1).compareTo(_gridCol(b.grid) ?? 1));

      // Fraction of halfH from the edge (0 = edge, ~0.92 = centre line)
      final frac = n == 1 ? 0.5 : edgePad + ri * usable / (n - 1);

      // For home: row 0 (GK) sits near the top, last row near centre.
      // For away: mirrored — row 0 (GK) sits near the bottom.
      final y = isHome
          ? yOffset + halfH * frac
          : yOffset + halfH * (1.0 - frac);

      final np = rowPlayers.length;
      for (int ci = 0; ci < np; ci++) {
        out.add(_PlayerDot(
          player: rowPlayers[ci],
          x: w * (ci + 1) / (np + 1),
          y: y,
          color: isHome ? _kHome : _kAway,
        ));
      }
    }
    return out;
  }

  // ── Grid helpers ──────────────────────────────────────────────────────────
  static int? _gridRow(String? g) {
    if (g == null || g.isEmpty) return null;
    final p = g.split(':');
    return p.length == 2 ? int.tryParse(p[0]) : null;
  }

  static int? _gridCol(String? g) {
    if (g == null || g.isEmpty) return null;
    final p = g.split(':');
    return p.length == 2 ? int.tryParse(p[1]) : null;
  }

  static int _posToRow(String? pos) {
    switch (pos) {
      case 'G': return 1;
      case 'D': return 2;
      case 'M': return 3;
      case 'F': return 4;
      default:  return 3;
    }
  }
}

// ── Pitch CustomPainter ────────────────────────────────────────────────────

class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Alternating vertical stripes ──────────────────────────────
    const stripes = 8;
    final sw = w / stripes;
    for (int i = 0; i < stripes; i++) {
      canvas.drawRect(
        Rect.fromLTWH(i * sw, 0, sw, h),
        Paint()..color = i.isEven ? _kPitchDark : _kPitchLight,
      );
    }

    final lp = Paint()
      ..color = _kLine
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final fp = Paint()
      ..color = _kLine
      ..style = PaintingStyle.fill;

    // ── Pitch border ──────────────────────────────────────────────
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), lp);

    // ── Centre line ───────────────────────────────────────────────
    canvas.drawLine(Offset(0, h * 0.5), Offset(w, h * 0.5), lp);

    // ── Centre circle (radius = 9.15/68 of pitch width ≈ 13.5%) ──
    final cr = w * 0.135;
    canvas.drawCircle(Offset(w / 2, h / 2), cr, lp);
    canvas.drawCircle(Offset(w / 2, h / 2), 2.5, fp);

    // ── Penalty boxes (40.32m wide × 16.5m deep on 105×68 pitch) ─
    // Width  = 40.32/68  ≈ 59.3%
    // Height = 16.5/52.5 ≈ 15.7% of half-pitch = 7.86% of full h
    final pbW = w * 0.593;
    final pbH = h * 0.157 * 0.5; // scaled to full-pitch height
    final pbX = (w - pbW) / 2;
    canvas.drawRect(Rect.fromLTWH(pbX, 0,       pbW, pbH), lp);
    canvas.drawRect(Rect.fromLTWH(pbX, h - pbH, pbW, pbH), lp);

    // ── Goal boxes (18.32m wide × 5.5m deep) ─────────────────────
    final gbW = w * 0.269;
    final gbH = h * 0.052 * 0.5;
    final gbX = (w - gbW) / 2;
    canvas.drawRect(Rect.fromLTWH(gbX, 0,       gbW, gbH), lp);
    canvas.drawRect(Rect.fromLTWH(gbX, h - gbH, gbW, gbH), lp);

    // ── Penalty spots (11m from goal line ≈ 10.5% of half-height) ─
    final psY = h * 0.105 * 0.5;
    canvas.drawCircle(Offset(w / 2, psY),     2.5, fp);
    canvas.drawCircle(Offset(w / 2, h - psY), 2.5, fp);

    // ── Penalty arcs (same radius as centre circle, clipped
    //    to outside the penalty box) ─────────────────────────────
    final paR = w * 0.135;
    // Top arc
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, pbH, w, h - pbH));
    canvas.drawCircle(Offset(w / 2, psY), paR, lp);
    canvas.restore();
    // Bottom arc
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, w, h - pbH));
    canvas.drawCircle(Offset(w / 2, h - psY), paR, lp);
    canvas.restore();

    // ── Corner arcs ───────────────────────────────────────────────
    final cR = w * 0.033;
    canvas.drawArc(Rect.fromLTWH(-cR,     -cR,     cR * 2, cR * 2), 0,         pi / 2, false, lp);
    canvas.drawArc(Rect.fromLTWH(w - cR,  -cR,     cR * 2, cR * 2), pi / 2,    pi / 2, false, lp);
    canvas.drawArc(Rect.fromLTWH(-cR,     h - cR,  cR * 2, cR * 2), -pi / 2,   pi / 2, false, lp);
    canvas.drawArc(Rect.fromLTWH(w - cR,  h - cR,  cR * 2, cR * 2), pi,        pi / 2, false, lp);
  }

  @override
  bool shouldRepaint(covariant _PitchPainter _) => false;
}

// ── Formation chip overlay ─────────────────────────────────────────────────

class _FormationChip extends StatelessWidget {
  final String text;
  const _FormationChip(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withOpacity(0.42),
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

// ── Player dot ─────────────────────────────────────────────────────────────

class _PlayerDot extends StatelessWidget {
  final LineupPlayer player;
  final double x;
  final double y;
  final Color  color;

  const _PlayerDot({
    required this.player,
    required this.x,
    required this.y,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      // Centre the label column horizontally on x, circle top at y - r.
      left: x - _kLabelW / 2,
      top:  y - _kDia   / 2,
      child: SizedBox(
        width: _kLabelW,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Jersey circle ─────────────────────────────────
            Container(
              width:  _kDia,
              height: _kDia,
              margin: EdgeInsets.symmetric(
                horizontal: (_kLabelW - _kDia) / 2,
              ),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.88),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.40),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '${player.number}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 3),

            // ── Name tag ──────────────────────────────────────
            Text(
              _abbrev(player.name),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 9.0,
                fontWeight: FontWeight.w600,
                shadows: const [
                  Shadow(
                    color: Color(0xBB000000),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _abbrev(String name) {
    final parts = name.trim().split(' ');
    if (parts.length <= 1) return name;
    return '${parts.first[0]}. ${parts.sublist(1).join(' ')}';
  }
}

// ── Substitutes section ────────────────────────────────────────────────────

class _SubstitutesSection extends StatelessWidget {
  final TeamLineup  home;
  final TeamLineup? away;
  final AppLocalizations l;

  const _SubstitutesSection({
    required this.home,
    this.away,
    required this.l,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.col;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section label
        Row(
          children: [
            Container(width: 12, height: 1, color: c.hairlineHi),
            const SizedBox(width: 8),
            Text(
              l.substitutes.toUpperCase(),
              style: EType.label(color: c.inkDim, size: 10, letterSpacing: 2),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Two-column list
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _SubList(lineup: home, color: _kHome, c: c, mirror: false),
              ),
              Container(width: 1, color: c.hairline),
              Expanded(
                child: _SubList(lineup: away, color: _kAway, c: c, mirror: true),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubList extends StatelessWidget {
  final TeamLineup? lineup;
  final Color       color;
  final EditorialColors c;
  final bool        mirror; // true = away side (right-aligned)

  const _SubList({
    required this.lineup,
    required this.color,
    required this.c,
    required this.mirror,
  });

  @override
  Widget build(BuildContext context) {
    if (lineup == null || lineup!.substitutes.isEmpty) {
      return const SizedBox.shrink();
    }
    final subs = lineup!.substitutes;
    final pa   = EdgeInsets.only(left: mirror ? 10 : 0, right: mirror ? 0 : 10);

    return Padding(
      padding: pa,
      child: Column(
        crossAxisAlignment:
            mirror ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // ── Team badge + name ──────────────────────────────
          Row(
            mainAxisAlignment:
                mirror ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: mirror
                ? [
                    Flexible(
                      child: Text(
                        lineup!.team.name.toUpperCase(),
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: EType.label(
                            color: c.inkMute, size: 9, letterSpacing: 1.4),
                      ),
                    ),
                    const SizedBox(width: 5),
                    _Dot(color: color),
                  ]
                : [
                    _Dot(color: color),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        lineup!.team.name.toUpperCase(),
                        overflow: TextOverflow.ellipsis,
                        style: EType.label(
                            color: c.inkMute, size: 9, letterSpacing: 1.4),
                      ),
                    ),
                  ],
          ),
          const SizedBox(height: 8),

          // ── Player rows ───────────────────────────────────
          ...subs.map((p) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3.5),
                child: Row(
                  mainAxisAlignment:
                      mirror ? MainAxisAlignment.end : MainAxisAlignment.start,
                  children: mirror
                      ? [
                          Flexible(
                            child: Text(
                              p.name,
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                              style: EType.body(color: c.ink, size: 12),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _NumChip(number: p.number, color: color),
                        ]
                      : [
                          _NumChip(number: p.number, color: color),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              p.name,
                              overflow: TextOverflow.ellipsis,
                              style: EType.body(color: c.ink, size: 12),
                            ),
                          ),
                        ],
                ),
              )),
        ],
      ),
    );
  }
}

// ── Tiny helpers ──────────────────────────────────────────────────────────

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 8, height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _NumChip extends StatelessWidget {
  final int   number;
  final Color color;
  const _NumChip({required this.number, required this.color});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 20,
        child: Text(
          '$number',
          style: EType.numeric(color: color, size: 11, weight: FontWeight.w700),
        ),
      );
}
