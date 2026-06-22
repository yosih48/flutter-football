import 'package:flutter/material.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:football/models/head_to_head.dart';
import 'package:football/resources/head_to_head_service.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:football/utils/localized_team_name.dart';
import 'package:intl/intl.dart' show DateFormat;

/// Head-to-head tab content for the match-detail screen. Shows an aggregate
/// summary (home W–D–L away + goal totals) and a list of the last meetings.
/// Data comes from the backend's cached fixtures — no external API call.
class HeadToHeadWidget extends StatefulWidget {
  final int fixtureId;
  final String homeTeamName;
  final String homeTeamLogo;
  final int homeTeamId;
  final String awayTeamName;
  final String awayTeamLogo;

  const HeadToHeadWidget({
    super.key,
    required this.fixtureId,
    required this.homeTeamName,
    required this.homeTeamLogo,
    required this.homeTeamId,
    required this.awayTeamName,
    required this.awayTeamLogo,
  });

  @override
  State<HeadToHeadWidget> createState() => _HeadToHeadWidgetState();
}

class _HeadToHeadWidgetState extends State<HeadToHeadWidget> {
  final HeadToHeadService _service = HeadToHeadService();
  HeadToHead? _h2h;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(HeadToHeadWidget old) {
    super.didUpdateWidget(old);
    if (old.fixtureId != widget.fixtureId) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await _service.getHeadToHead(widget.fixtureId);
    if (!mounted) return;
    setState(() {
      _h2h = result;
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

    final h2h = _h2h;
    if (h2h == null || h2h.meetings.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        child: Center(
          child: Text(
            l.h2hNoData.toUpperCase(),
            style: EType.label(color: c.inkDim, size: 11, letterSpacing: 2),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _summary(c, l, h2h.summary),
          const SizedBox(height: 18),
          ...h2h.meetings.map((m) => _meetingRow(c, m)),
        ],
      ),
    );
  }

  // ── Summary header: home crest | W-D-L | away crest, goal totals below ──────
  Widget _summary(EditorialColors c, AppLocalizations l, H2HSummary s) {
    // summary is normalized so team A == current fixture's home team.
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _summaryTeam(c, widget.homeTeamLogo, widget.homeTeamName, isHome: true)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  Text(
                    '${s.aWins}-${s.draws}-${s.bWins}',
                    style: EType.numeric(color: c.ink, size: 20, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'W-D-L',
                    style: EType.label(color: c.inkDim, size: 9, letterSpacing: 1.4),
                  ),
                ],
              ),
            ),
            Expanded(child: _summaryTeam(c, widget.awayTeamLogo, widget.awayTeamName, isHome: false)),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '${l.h2hGoals.toUpperCase()}   ${s.aGoals} – ${s.bGoals}',
          style: EType.label(color: c.inkMute, size: 10, letterSpacing: 1.4),
        ),
      ],
    );
  }

  Widget _summaryTeam(EditorialColors c, String logo, String name, {required bool isHome}) {
    return Column(
      crossAxisAlignment: isHome ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        _logo(c, logo, 34),
        const SizedBox(height: 6),
        Text(
          localizedTeamName(context, name).toUpperCase(),
          textAlign: isHome ? TextAlign.start : TextAlign.end,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: EType.label(color: c.ink, size: 10, letterSpacing: 0.8),
        ),
      ],
    );
  }

  // ── Single meeting row: date · competition · score ─────────────────────────
  Widget _meetingRow(EditorialColors c, H2HMeeting m) {
    final dateStr = m.date != null ? DateFormat('dd MMM yyyy').format(m.date!.toLocal()) : '';
    final hg = m.homeGoals;
    final ag = m.awayGoals;
    final score = (hg != null && ag != null) ? '$hg – $ag' : '–';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.hairline, width: 1)),
      ),
      child: Row(
        children: [
          // Home side (this meeting's home, not necessarily current home team)
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    localizedTeamName(context, m.homeName),
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EType.body(color: c.ink, size: 12),
                  ),
                ),
                const SizedBox(width: 6),
                _logo(c, m.homeLogo, 18),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              children: [
                Text(
                  score,
                  style: EType.numeric(color: c.ink, size: 13, weight: FontWeight.w700),
                ),
                if (dateStr.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    dateStr,
                    style: EType.label(color: c.inkDim, size: 8, letterSpacing: 0.6),
                  ),
                ],
              ],
            ),
          ),
          // Away side
          Expanded(
            child: Row(
              children: [
                _logo(c, m.awayLogo, 18),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    localizedTeamName(context, m.awayName),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EType.body(color: c.ink, size: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _logo(EditorialColors c, String url, double size) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: c.cardHi, shape: BoxShape.circle),
      child: url.isNotEmpty
          ? Image.network(
              url,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.shield_outlined, size: size * 0.5, color: c.inkDim),
            )
          : Icon(Icons.shield_outlined, size: size * 0.5, color: c.inkDim),
    );
  }
}
