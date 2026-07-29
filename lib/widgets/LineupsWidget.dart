import 'dart:math';
import 'package:flutter/material.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:football/models/FixtureEvent.dart';
import 'package:football/models/lineup.dart';
import 'package:football/resources/FixtureEventsService.dart';
import 'package:football/resources/lineup_service.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:football/utils/he_player_name.dart';
import 'package:football/utils/lineup_event_marks.dart';
import 'package:football/utils/localized_team_name.dart';

// ── Fixed pitch colours — independent of light/dark theme ─────────────────
const Color _kHome = Color(0xFF4B7BF5); // vivid blue  (home XI ring)
const Color _kAway = Color(0xFF2BC48A); // vivid green (away XI ring)
const Color _kPitchDark = Color(0xFF064D3B); // pitch base
const Color _kPitchLight = Color(0xFF075F47); // mown band
const Color _kLine = Color(0x42FFFFFF); // white @ ~26%

// ── Player dot geometry ───────────────────────────────────────────────────
const double _kDia = 40.0; // avatar diameter
const double _kLabelW = 70.0; // total width incl. name

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
  // false = home XI, true = away XI.
  bool _showAway = false;

  final LineupService _lineupService = LineupService();
  LineupResponse? _lineupResponse;
  List<FixtureEvent> _events = const [];
  bool _isLoading = true;
  bool _hasError = false;

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
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    // Lineups (AllSports) and events (API-Football) are independent endpoints —
    // fetch in parallel. Events power the goal/card/sub marks on the pitch.
    final results = await Future.wait([
      _lineupService.getFixtureLineups(
        widget.fixtureId,
        matchDate: widget.matchDate,
      ),
      FixtureEventsService().getFixtureEvents(widget.fixtureId),
    ]);

    if (!mounted) return;
    final response = results[0] as LineupResponse?;
    final eventsResp = results[1] as FixtureEventsResponse?;
    setState(() {
      _lineupResponse = response;
      _events = eventsResp?.events ?? const [];
      _isLoading = false;
      _hasError = response == null;
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
            width: 18,
            height: 18,
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
              l.failedToLoadLineUp.toUpperCase(),
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
    final home = lineups[0];
    final away = lineups.length > 1 ? lineups[1] : null;

    // Distil events into per-player marks, scoped to each side by team name so a
    // surname shared across both teams can't cross-match.
    final homeMarks = buildPlayerMarks(_events, home.team.name);
    final awayMarks = away != null
        ? buildPlayerMarks(_events, away.team.name)
        : <String, PlayerMarks>{};

    // Only one XI is on the pitch at a time now, so resolve the selected side
    // once and drive the header, pitch and substitutes from it.
    final showAway = _showAway && away != null;
    final team = showAway ? away : home;
    final teamMarks = showAway ? awayMarks : homeMarks;
    final teamColor = showAway ? _kAway : _kHome;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Predicted-lineup banner ────────────────────────────────
        if (_lineupResponse!.predicted) ...[
          _PredictedBanner(label: l.predictedLineup),
          const SizedBox(height: 10),
        ],

        // ── Team toggle ────────────────────────────────────────────
        if (away != null) ...[
          _TeamToggle(
            homeName: home.team.name,
            awayName: away.team.name,
            showAway: showAway,
            onChanged: (v) => setState(() => _showAway = v),
          ),
          const SizedBox(height: 12),
        ],

        // ── Selected team + its formation ──────────────────────────
        _PitchHeader(team: team),
        const SizedBox(height: 8),

        // ── Tactical pitch ─────────────────────────────────────────
        // Isolate the pitch as its own layer: it's a tall, static stack of
        // gradient avatars + shadows, so caching it lets the outer scroll just
        // composite it instead of re-rasterizing all the blurs every frame.
        RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _TacticalPitch(
              team: team,
              marks: teamMarks,
              color: teamColor,
            ),
          ),
        ),

        // ── Substitutes (selected team only) ───────────────────────
        if (team.substitutes.isNotEmpty) ...[
          const SizedBox(height: 20),
          _SubstitutesSection(
            home: team,
            away: null,
            homeMarks: teamMarks,
            awayMarks: const {},
            l: l,
          ),
        ],
      ],
    );
  }
}

// Segmented switch between the two XIs — active half filled, matching the
// events-tab filter.
class _TeamToggle extends StatelessWidget {
  const _TeamToggle({
    required this.homeName,
    required this.awayName,
    required this.showAway,
    required this.onChanged,
  });
  final String homeName;
  final String awayName;
  final bool showAway;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    // Centred: the parent Column aligns to start, so a shrink-wrapped toggle
    // would otherwise hug the edge.
    return Center(
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: c.cardHi,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.hairline, width: 1),
        ),
        child: Row(
          // Sized to its labels rather than stretched full-width.
          mainAxisSize: MainAxisSize.min,
          children: [
            _half(context, homeName, !showAway, () => onChanged(false)),
            _half(context, awayName, showAway, () => onChanged(true)),
          ],
        ),
      ),
    );
  }

  Widget _half(
      BuildContext context, String name, bool active, VoidCallback onTap) {
    final c = context.col;
    final isHe = Localizations.localeOf(context).languageCode == 'he';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        alignment: Alignment.center,
        // Long club names would otherwise stretch it across the screen.
        constraints: const BoxConstraints(maxWidth: 150),
        decoration: BoxDecoration(
          color: active ? c.live : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          localizedTeamName(context, name),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: EType.body(
            color: active ? Colors.white : c.inkMute,
            size: 13,
            weight: FontWeight.w600,
            hebrew: isHe,
          ),
        ),
      ),
    );
  }
}

// Crest + name at the start, formation pill at the end.
class _PitchHeader extends StatelessWidget {
  const _PitchHeader({required this.team});
  final TeamLineup team;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final isHe = Localizations.localeOf(context).languageCode == 'he';
    final logo = team.team.logo ?? '';
    return Row(
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: logo.isEmpty
              ? Icon(Icons.shield_outlined, size: 18, color: c.inkDim)
              : Image.network(
                  logo,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      Icon(Icons.shield_outlined, size: 18, color: c.inkDim),
                ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            localizedTeamName(context, team.team.name),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: EType.body(
                color: c.ink, size: 14, weight: FontWeight.w700, hebrew: isHe),
          ),
        ),
        if (team.formation.isNotEmpty) _FormationChip(team.formation),
      ],
    );
  }
}

// ── Predicted-lineup banner ─────────────────────────────────────────────────

class _PredictedBanner extends StatelessWidget {
  final String label;
  const _PredictedBanner({required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.liveSoft,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: c.live.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lightbulb_outline, color: c.live, size: 15),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label.toUpperCase(),
              style: EType.label(color: c.live, size: 10, letterSpacing: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tactical pitch ─────────────────────────────────────────────────────────

class _TacticalPitch extends StatelessWidget {
  final TeamLineup team;
  final Map<String, PlayerMarks> marks;
  final Color color;
  const _TacticalPitch({
    required this.team,
    required this.marks,
    required this.color,
  });

  // Each formation row gets its own fixed-height slot, so the pitch grows with
  // the line-up instead of squeezing 22 players into one screen. This is what
  // gives ScoreQuest its airy, uncrowded look — rows never collide at the
  // centre line and dense back-fours get room to breathe.
  static const double _kRowH = 84.0;
  // Vertical breathing room at the goal lines so the top/bottom rows' rating +
  // name (which sit BELOW the avatar) aren't clipped by the pitch edge.
  // Symmetric, so the painter's centre line (h/2) stays aligned with the
  // half-way split between the two teams.
  static const double _kVPad = 32.0;

  @override
  Widget build(BuildContext context) {
    final rows = _orderedRows(team.startXI);

    // One team now owns the whole pitch instead of a half, so each formation
    // row gets a full slot and the XI spreads goal-line to goal-line.
    final bodyH = (rows.isEmpty ? 1 : rows.length) * _kRowH;
    final h = bodyH + _kVPad * 2;

    return SizedBox(
      height: h,
      child: LayoutBuilder(
        builder: (_, constraints) {
          final w = constraints.maxWidth;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(painter: _PitchPainter()),
              ),
              ..._placeTeam(rows, w, bodyH, marks: marks),
            ],
          );
        },
      ),
    );
  }

  // Group a starting XI into formation rows (grid field, fallback to position),
  // ordered GK→forwards, each row left→right by grid column.
  List<List<LineupPlayer>> _orderedRows(List<LineupPlayer> players) {
    final Map<int, List<LineupPlayer>> byRow = {};
    for (final p in players) {
      final row = _gridRow(p.grid) ?? _posToRow(p.pos);
      byRow.putIfAbsent(row, () => []).add(p);
    }
    final keys = byRow.keys.toList()..sort();
    return keys.map((k) {
      return List<LineupPlayer>.from(byRow[k]!)
        ..sort(
            (a, b) => (_gridCol(a.grid) ?? 1).compareTo(_gridCol(b.grid) ?? 1));
    }).toList();
  }

  // ── Position calculation ─────────────────────────────────────────────────
  List<Widget> _placeTeam(
    List<List<LineupPlayer>> rows,
    double w,
    double bodyH, {
    required Map<String, PlayerMarks> marks,
  }) {
    final n = rows.length;
    if (n == 0) return const [];

    final List<Widget> out = [];
    for (int ri = 0; ri < n; ri++) {
      final rowPlayers = rows[ri];

      // Each row is centred in its own equal band down the full pitch, keeper
      // at the top through to the forwards at the bottom.
      final frac = (ri + 0.5) / n;
      final y = _kVPad + bodyH * frac;

      final np = rowPlayers.length;
      for (int ci = 0; ci < np; ci++) {
        out.add(_PlayerDot(
          player: rowPlayers[ci],
          x: w * (ci + 1) / (np + 1),
          y: y,
          color: color,
          marks: marks.forPlayer(rowPlayers[ci]),
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
      case 'G':
        return 1;
      case 'D':
        return 2;
      case 'M':
        return 3;
      case 'F':
        return 4;
      default:
        return 3;
    }
  }
}

// ── Pitch CustomPainter ────────────────────────────────────────────────────

class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Alternating horizontal bands (mow pattern) ─────────────────
    // Fixed band HEIGHT rather than a fixed count: the pitch grows with the
    // formation, so a fixed count would stretch or squash the stripes from one
    // line-up to the next. This keeps them a consistent thickness and just
    // draws more of them on a taller pitch.
    const bandH = 80.0;
    final bands = (h / bandH).ceil();
    for (int i = 0; i < bands; i++) {
      final top = i * bandH;
      canvas.drawRect(
        // Clamp the last band so it can't paint past the pitch.
        Rect.fromLTWH(0, top, w, min(bandH, h - top)),
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
    canvas.drawRect(Rect.fromLTWH(pbX, 0, pbW, pbH), lp);
    canvas.drawRect(Rect.fromLTWH(pbX, h - pbH, pbW, pbH), lp);

    // ── Goal boxes (18.32m wide × 5.5m deep) ─────────────────────
    final gbW = w * 0.269;
    final gbH = h * 0.052 * 0.5;
    final gbX = (w - gbW) / 2;
    canvas.drawRect(Rect.fromLTWH(gbX, 0, gbW, gbH), lp);
    canvas.drawRect(Rect.fromLTWH(gbX, h - gbH, gbW, gbH), lp);

    // ── Penalty spots (11m from goal line ≈ 10.5% of half-height) ─
    final psY = h * 0.105 * 0.5;
    canvas.drawCircle(Offset(w / 2, psY), 2.5, fp);
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
    canvas.drawArc(
        Rect.fromLTWH(-cR, -cR, cR * 2, cR * 2), 0, pi / 2, false, lp);
    canvas.drawArc(
        Rect.fromLTWH(w - cR, -cR, cR * 2, cR * 2), pi / 2, pi / 2, false, lp);
    canvas.drawArc(
        Rect.fromLTWH(-cR, h - cR, cR * 2, cR * 2), -pi / 2, pi / 2, false, lp);
    canvas.drawArc(
        Rect.fromLTWH(w - cR, h - cR, cR * 2, cR * 2), pi, pi / 2, false, lp);
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
  final Color color;
  final PlayerMarks? marks;

  const _PlayerDot({
    required this.player,
    required this.x,
    required this.y,
    required this.color,
    this.marks,
  });

  @override
  Widget build(BuildContext context) {
    final m = marks;
    final subOff = m?.subOffMin != null;
    return Positioned(
      // Centre the label column horizontally on x, avatar top at y - r.
      left: x - _kLabelW / 2,
      top: y - _kDia / 2,
      child: SizedBox(
        width: _kLabelW,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Avatar + event badges ─────────────────────────
            // Badges spill outside the avatar bounds, so don't clip.
            SizedBox(
              width: _kLabelW,
              height: _kDia + 4,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  // Dim a subbed-off player's avatar, like ScoreQuest.
                  Opacity(
                    opacity: subOff ? 0.55 : 1.0,
                    child: _PlayerAvatar(
                      number: player.number,
                      color: color,
                      // API-Football media CDN headshot (free, disk-warmed
                      // server-side); falls back to the number on load error.
                      photoUrl: player.photo,
                    ),
                  ),

                  // Goal(s) — top-left ball
                  if (m != null && (m.goals > 0 || m.ownGoals > 0))
                    Positioned(
                      left: (_kLabelW - _kDia) / 2 - 7,
                      top: -3,
                      child: _GoalBadge(
                        count: m.goals + m.ownGoals,
                        own: m.goals == 0 && m.ownGoals > 0,
                      ),
                    ),

                  // Card — top-right
                  if (m != null && (m.yellow > 0 || m.red > 0))
                    Positioned(
                      right: (_kLabelW - _kDia) / 2 - 5,
                      top: -3,
                      child: _CardBadge(red: m.red > 0),
                    ),

                  // Subbed off — bottom-right red down-arrow
                  if (subOff)
                    Positioned(
                      right: (_kLabelW - _kDia) / 2 - 6,
                      bottom: -1,
                      child: const _SubArrowBadge(off: true),
                    ),

                  // Captain armband — bottom-left "C"
                  if (player.captain)
                    Positioned(
                      left: (_kLabelW - _kDia) / 2 - 6,
                      bottom: -1,
                      child: const _CaptainBadge(),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // ── Rating pill (live/finished only) ──────────────
            if (player.rating != null) ...[
              _RatingPill(rating: player.rating!),
              const SizedBox(height: 2),
            ],

            // ── Name — with the number when a photo hides it in the circle ──
            Builder(builder: (_) {
              final hasPhoto = player.photo != null && player.photo!.isNotEmpty;
              final nameText = Text(
                localizedPlayerName(context, player.name, abbreviate: true),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9.5,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                ),
              );
              if (!hasPhoto) return nameText;
              return Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${player.number}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Flexible(child: nameText),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

// Circular player avatar with a team-coloured ring. Shows a real headshot when
// [photoUrl] is provided (falls back to the jersey number on load error), or
// the number placeholder when it's null — so photos drop in with no layout
// change once the image proxy is wired up.
class _PlayerAvatar extends StatelessWidget {
  final int number;
  final Color color;
  final String? photoUrl;

  const _PlayerAvatar({
    required this.number,
    required this.color,
    this.photoUrl,
  });

  Widget _numberFallback() => DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // Coloured circle background (home blue / away green).
          gradient: RadialGradient(
            center: const Alignment(-0.2, -0.3),
            radius: 0.95,
            colors: [
              Color.lerp(color, Colors.white, 0.18)!,
              color,
              Color.lerp(color, Colors.black, 0.18)!,
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
        child: Center(
          child: Text(
            '$number',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kDia,
      height: _kDia,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: ClipOval(
        child: (photoUrl != null && photoUrl!.isNotEmpty)
            ? Image.network(
                photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _numberFallback(),
              )
            : _numberFallback(),
      ),
    );
  }
}

// ── Event badges ────────────────────────────────────────────────────────────

Color _ratingColor(double r) {
  if (r >= 8.0) return const Color(0xFF1D9BF0); // blue — outstanding
  if (r >= 7.0) return const Color(0xFF12B886); // green — good
  if (r >= 6.0) return const Color(0xFFF59F00); // amber — average
  return const Color(0xFFE03131); // red — poor
}

class _RatingPill extends StatelessWidget {
  final double rating;
  const _RatingPill({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: _ratingColor(rating),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        rating.toStringAsFixed(1),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          height: 1.0,
        ),
      ),
    );
  }
}

class _GoalBadge extends StatelessWidget {
  final int count;
  final bool own;
  const _GoalBadge({required this.count, this.own = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 15,
      height: 15,
      decoration: BoxDecoration(
        color: own ? const Color(0xFFE03131) : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black26, width: 0.5),
      ),
      child: count > 1
          ? Center(
              child: Text(
                '$count',
                style: TextStyle(
                  color: own ? Colors.white : Colors.black,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : Icon(Icons.sports_soccer,
              size: 11, color: own ? Colors.white : Colors.black87),
    );
  }
}

class _CardBadge extends StatelessWidget {
  final bool red;
  const _CardBadge({required this.red});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 13,
      decoration: BoxDecoration(
        color: red ? const Color(0xFFE03131) : const Color(0xFFFACC15),
        borderRadius: BorderRadius.circular(1.5),
        border: Border.all(color: Colors.black26, width: 0.5),
      ),
    );
  }
}

class _SubArrowBadge extends StatelessWidget {
  final bool off;
  const _SubArrowBadge({required this.off});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: off ? const Color(0xFFE03131) : const Color(0xFF12B886),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Icon(
        off ? Icons.arrow_downward : Icons.arrow_upward,
        size: 9,
        color: Colors.white,
      ),
    );
  }
}

class _CaptainBadge extends StatelessWidget {
  const _CaptainBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 13,
      height: 13,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white70, width: 0.5),
      ),
      child: const Text(
        'C',
        style: TextStyle(
          color: Colors.amber,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          height: 1.0,
        ),
      ),
    );
  }
}

// Inline marks shown next to a substitute's name: came-on arrow, goals, cards,
// and rating. Returns [] when the bench player had no involvement.
List<Widget> _subMarkers(PlayerMarks? m) {
  if (m == null) return const [];
  final out = <Widget>[];
  if (m.subOnMin != null) {
    out.add(const _SubArrowBadge(off: false));
  }
  if (m.goals > 0 || m.ownGoals > 0) {
    out.add(const SizedBox(width: 3));
    out.add(_GoalBadge(
        count: m.goals + m.ownGoals, own: m.goals == 0 && m.ownGoals > 0));
  }
  if (m.yellow > 0 || m.red > 0) {
    out.add(const SizedBox(width: 3));
    out.add(_CardBadge(red: m.red > 0));
  }
  return out;
}

// ── Substitutes section ────────────────────────────────────────────────────

class _SubstitutesSection extends StatelessWidget {
  final TeamLineup home;
  final TeamLineup? away;
  final Map<String, PlayerMarks> homeMarks;
  final Map<String, PlayerMarks> awayMarks;
  final AppLocalizations l;

  const _SubstitutesSection({
    required this.home,
    this.away,
    required this.homeMarks,
    required this.awayMarks,
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
                child: _SubList(
                    lineup: home,
                    color: _kHome,
                    c: c,
                    mirror: false,
                    marks: homeMarks),
              ),
              Container(width: 1, color: c.hairline),
              Expanded(
                child: _SubList(
                    lineup: away,
                    color: _kAway,
                    c: c,
                    mirror: true,
                    marks: awayMarks),
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
  final Color color;
  final EditorialColors c;
  final bool mirror; // true = away side (right-aligned)
  final Map<String, PlayerMarks> marks;

  const _SubList({
    required this.lineup,
    required this.color,
    required this.c,
    required this.mirror,
    required this.marks,
  });

  @override
  Widget build(BuildContext context) {
    if (lineup == null || lineup!.substitutes.isEmpty) {
      return const SizedBox.shrink();
    }
    final subs = lineup!.substitutes;
    final pa = EdgeInsets.only(left: mirror ? 10 : 0, right: mirror ? 0 : 10);

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
                        localizedTeamName(context, lineup!.team.name)
                            .toUpperCase(),
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
                        localizedTeamName(context, lineup!.team.name)
                            .toUpperCase(),
                        overflow: TextOverflow.ellipsis,
                        style: EType.label(
                            color: c.inkMute, size: 9, letterSpacing: 1.4),
                      ),
                    ),
                  ],
          ),
          const SizedBox(height: 8),

          // ── Player rows ───────────────────────────────────
          ...subs.map((p) {
            final m = marks.forPlayer(p);
            final nameWidget = Flexible(
              child: Text(
                localizedPlayerName(context, p.name),
                textAlign: mirror ? TextAlign.right : TextAlign.left,
                overflow: TextOverflow.ellipsis,
                style: EType.body(color: c.ink, size: 12),
              ),
            );
            final markers = _subMarkers(m);
            final children = <Widget>[
              _NumChip(number: p.number, color: color),
              const SizedBox(width: 6),
              nameWidget,
              if (markers.isNotEmpty) ...[
                const SizedBox(width: 6),
                ...markers,
              ],
            ];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3.5),
              child: Row(
                mainAxisAlignment:
                    mirror ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: mirror ? children.reversed.toList() : children,
              ),
            );
          }),
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
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _NumChip extends StatelessWidget {
  final int number;
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
