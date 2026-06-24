import 'package:flutter/material.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:football/models/games.dart';
import 'package:football/models/recent_form.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:football/utils/localized_team_name.dart';
import 'package:intl/intl.dart';

/// Recent-form block for the team screen: a W/D/L pill strip over a list of the
/// team's last matches. Each match is a dated card showing its competition and
/// result, mirroring the Matches tab. Stateless — the parent fetches the data
/// and supplies [onMatchTap].
class RecentFormBlock extends StatelessWidget {
  final int teamId;
  final RecentForm data;
  final void Function(Game game) onMatchTap;

  /// Header label. Defaults to the localized "Recent Form"; pass a team name
  /// when showing several blocks side by side (e.g. both teams in a match).
  final String? title;

  /// When false, the title + form-pill header is omitted and only the match
  /// cards are rendered (e.g. inside an accordion that already shows the pills).
  final bool showHeader;

  const RecentFormBlock({
    super.key,
    required this.teamId,
    required this.data,
    required this.onMatchTap,
    this.title,
    this.showHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final l = AppLocalizations.of(context)!;

    if (data.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
        child: Center(
          child: Text(
            l.recentFormEmpty.toUpperCase(),
            style: EType.label(color: c.inkDim, size: 11, letterSpacing: 2),
          ),
        ),
      );
    }

    final cards = <Widget>[];
    for (var i = 0; i < data.matches.length; i++) {
      cards.add(_matchCard(context, data.matches[i]));
      if (i < data.matches.length - 1) cards.add(const SizedBox(height: 10));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Row(
              children: [
                Container(width: 18, height: 1, color: c.live),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    (title ?? l.recentFormTitle).toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: EType.label(color: c.inkDim, size: 11, letterSpacing: 2.2),
                  ),
                ),
                const SizedBox(width: 8),
                ...data.form.map((r) => _pill(c, r)),
              ],
            ),
          ),
        ...cards,
      ],
    );
  }

  Color _resultColor(EditorialColors c, String r) {
    switch (r) {
      case 'W':
        return c.live;
      case 'L':
        return c.flag;
      case 'D':
        return c.inkMute;
      default:
        return c.inkDim;
    }
  }

  Widget _pill(EditorialColors c, String r) {
    final color = _resultColor(c, r);
    return Container(
      margin: const EdgeInsets.only(left: 4),
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        r,
        style: EType.label(color: color, size: 10, letterSpacing: 0.5),
      ),
    );
  }

  // A single dated match card: date header (with competition) over a result row.
  Widget _matchCard(BuildContext context, Game game) {
    final c = context.col;
    final localDate = game.date.toLocal();

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: c.hairline, width: 1),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Text(
                  DateFormat('EEE  d MMM yyyy').format(localDate).toUpperCase(),
                  style: EType.label(color: c.ink, size: 11, letterSpacing: 1.6),
                ),
                const Spacer(),
                if (game.league.name.isNotEmpty)
                  Flexible(
                    child: Text(
                      game.league.name.toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: EType.label(
                        color: c.inkDim,
                        size: 10,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(height: 1, color: c.hairline),
          _matchRow(context, game),
        ],
      ),
    );
  }

  Widget _matchRow(BuildContext context, Game game) {
    final c = context.col;
    final h = game.goals.home;
    final a = game.goals.away;
    final isHome = game.home.id == teamId;
    final scored = isHome ? h : a;
    final conceded = isHome ? a : h;

    String badge = 'D';
    Color badgeColor = c.inkMute;
    if (scored != null && conceded != null) {
      if (scored > conceded) {
        badge = 'W';
        badgeColor = c.live;
      } else if (scored < conceded) {
        badge = 'L';
        badgeColor = c.flag;
      }
    }

    return InkWell(
      onTap: () => onMatchTap(game),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Status / league column (mirrors the Matches tab).
            SizedBox(
              width: 56,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.status.short,
                    style: EType.label(color: c.inkMute, size: 11, letterSpacing: 1.4),
                  ),
                  const SizedBox(height: 6),
                  if (game.league.logo != null && game.league.logo!.isNotEmpty)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: Image.network(
                        game.league.logo!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.emoji_events_outlined,
                          size: 12,
                          color: c.inkDim,
                        ),
                      ),
                    )
                  else
                    Icon(Icons.emoji_events_outlined, size: 12, color: c.inkDim),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                children: [
                  _teamLine(context, game.home, h, isHome),
                  const SizedBox(height: 6),
                  _teamLine(context, game.away, a, !isHome),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: badgeColor, width: 1),
              ),
              child: Text(
                badge,
                style: EType.label(color: badgeColor, size: 11, letterSpacing: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamLine(BuildContext context, Team team, int? score, bool isViewer) {
    final c = context.col;
    return Row(
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: Image.network(
            team.logo,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.shield_outlined, size: 14, color: c.inkDim),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            localizedTeamName(context, team.name),
            overflow: TextOverflow.ellipsis,
            style: EType.body(
              color: c.ink,
              size: 13,
              weight: isViewer ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          score?.toString() ?? '-',
          style: EType.numeric(color: c.ink, size: 14, weight: FontWeight.w700),
        ),
      ],
    );
  }
}
