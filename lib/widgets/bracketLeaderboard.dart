import 'package:flutter/material.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:football/models/bracket.dart';
import 'package:football/resources/bracketMethods.dart';
import 'package:football/screens/bracketViewer.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';

/// Ranked, expandable bracket leaderboard list. Shared by the global Ranking
/// tab and each private league's standings screen so the row + per-stage
/// breakdown look identical everywhere.
class BracketLeaderboardList extends StatefulWidget {
  const BracketLeaderboardList({
    super.key,
    required this.rows,
    required this.structure,
    this.highlightName,
    this.highlightUserId,
    this.loading = false,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
  });

  final List<BracketStanding> rows;
  final BracketStructure? structure;
  final String? highlightName;
  final String? highlightUserId;
  final bool loading;
  final EdgeInsets padding;

  @override
  State<BracketLeaderboardList> createState() => _BracketLeaderboardListState();
}

class _BracketLeaderboardListState extends State<BracketLeaderboardList> {
  final Set<int> _expanded = {};

  String _lang(BuildContext context) =>
      Localizations.localeOf(context).languageCode;

  bool _isMe(BracketStanding r) {
    if (widget.highlightUserId != null &&
        r.userID != null &&
        r.userID == widget.highlightUserId) {
      return true;
    }
    return widget.highlightName != null && r.name == widget.highlightName;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final l = AppLocalizations.of(context)!;
    final rows = widget.loading
        ? List.generate(6, (i) => BracketStanding(name: 'Loading', points: 0))
        : widget.rows;

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: widget.padding,
      itemCount: rows.length,
      itemBuilder: (ctx, i) {
        final r = rows[i];
        final isMe = !widget.loading && _isMe(r);
        // Expandable when there's a per-stage breakdown to show, OR the player
        // has a viewable bracket (so the "View full bracket" action is reachable
        // even for players with 0 points / no scored stages).
        final canView = widget.structure != null && r.userID != null;
        final hasBreakdown =
            !widget.loading && (r.stages.isNotEmpty || canView);
        final expanded = _expanded.contains(i);
        return Container(
          decoration: BoxDecoration(
            color: isMe ? c.liveSoft : null,
            border: Border(bottom: BorderSide(color: c.hairline, width: 1)),
          ),
          child: Column(
            children: [
              InkWell(
                onTap: hasBreakdown
                    ? () => setState(
                        () => expanded ? _expanded.remove(i) : _expanded.add(i))
                    : null,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text('${i + 1}',
                            style: EType.numeric(
                                color: i < 3 ? c.live : c.inkDim,
                                size: 14,
                                weight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(r.name.toUpperCase(),
                                  style: EType.body(
                                      size: 15,
                                      color: isMe ? c.live : c.ink,
                                      weight: FontWeight.w700,
                                      hebrew: Localizations.localeOf(context)
                                              .languageCode ==
                                          'he'),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            if (r.isOwner) ...[
                              const SizedBox(width: 6),
                              Icon(Icons.star, size: 13, color: c.live),
                            ],
                          ],
                        ),
                      ),
                      Text('${r.points}',
                          style: EType.numeric(
                              color: c.ink, size: 15, weight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      Text(l.pst,
                          style: EType.label(
                              color: c.inkDim, size: 9, letterSpacing: 1)),
                      if (hasBreakdown) ...[
                        const SizedBox(width: 6),
                        Icon(
                          expanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 18,
                          color: c.inkDim,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (expanded) _breakdown(c, r),
            ],
          ),
        );
      },
    );
  }

  // Per-stage points chips, in the structure's canonical stage order.
  Widget _breakdown(EditorialColors c, BracketStanding r) {
    final lang = _lang(context);
    // Show every tournament stage (from the structure) so the breakdown looks
    // identical for all players — even ones the backend hasn't scored yet,
    // whose stages map is empty. Missing stages default to 0 below.
    final order = widget.structure?.stages.map((s) => s.key).toList() ??
        r.stages.keys.toList();
    final l = AppLocalizations.of(context)!;
    final canView = widget.structure != null && r.userID != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final k in order)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: c.hairline, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        (widget.structure?.stage(k)?.label(lang) ?? k)
                            .toUpperCase(),
                        style: EType.label(
                            color: c.inkDim, size: 9, letterSpacing: 1),
                      ),
                      const SizedBox(width: 6),
                      Text('${r.stages[k] ?? 0}',
                          style: EType.numeric(
                              color: c.ink, size: 12, weight: FontWeight.w700)),
                    ],
                  ),
                ),
            ],
          ),
          if (canView) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BracketViewerScreen(
                    leagueId: widget.structure!.leagueId,
                    userId: r.userID!,
                    displayName: r.name,
                    structure: widget.structure,
                    season: widget.structure!.season,
                    stagePoints: r.stages,
                  ),
                ),
              ),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: c.hairlineHi, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.account_tree_outlined, size: 14, color: c.live),
                    const SizedBox(width: 8),
                    Text(l.bracketViewFull.toUpperCase(),
                        style: EType.label(
                            color: c.ink, size: 10, letterSpacing: 1)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
