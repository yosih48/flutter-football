import 'package:flutter/material.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:football/models/games.dart';
import 'package:football/models/recent_form.dart';
import 'package:football/resources/recent_form_service.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:football/utils/localized_team_name.dart';
import 'package:football/widgets/RecentFormBlock.dart';

/// Both teams' recent form for a single match. Loads each team's last matches
/// (cache-first via the backend; AllSport fallback). [onMatchTap] receives the
/// tapped game plus the list it belongs to, so the parent can navigate.
///
/// Two layouts:
///  - [collapsible] = false (default): a home/away tab selector over the
///    selected team's full match list. Used in the FORM tab of started games.
///  - [collapsible] = true: a compact per-team accordion — each team shows its
///    W/D/L pills, tap to expand the full 5-match list. Used inline pre-match so
///    it stays short and doesn't push the predictions below the fold.
class MatchFormSection extends StatefulWidget {
  final Team home;
  final Team away;
  final void Function(Game game, List<Game> contextMatches) onMatchTap;
  final bool collapsible;

  const MatchFormSection({
    super.key,
    required this.home,
    required this.away,
    required this.onMatchTap,
    this.collapsible = false,
  });

  @override
  State<MatchFormSection> createState() => _MatchFormSectionState();
}

class _MatchFormSectionState extends State<MatchFormSection> {
  late Future<List<RecentForm?>> _future;
  int _selected = 0; // tabbed mode: 0 = home, 1 = away
  final Set<int> _expanded = {}; // accordion mode: which teams are open

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<RecentForm?>> _load() {
    final svc = RecentFormService();
    return Future.wait([
      svc.getLastMatches(widget.home.id, widget.home.name),
      svc.getLastMatches(widget.away.id, widget.away.name),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final l = AppLocalizations.of(context)!;

    return FutureBuilder<List<RecentForm?>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final home = snap.data != null ? snap.data![0] : null;
        final away = snap.data != null ? snap.data![1] : null;

        if ((home == null || home.isEmpty) && (away == null || away.isEmpty)) {
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

        if (widget.collapsible) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _accordion(0, widget.home, home),
              const SizedBox(height: 10),
              _accordion(1, widget.away, away),
            ],
          );
        }

        final selectedTeam = _selected == 0 ? widget.home : widget.away;
        final selectedForm = _selected == 0 ? home : away;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _tabBar(c),
            const SizedBox(height: 14),
            _teamBlock(selectedTeam, selectedForm),
          ],
        );
      },
    );
  }

  // ── Accordion (collapsible) layout ──────────────────────────────────────

  Widget _accordion(int index, Team team, RecentForm? form) {
    final c = context.col;
    final isOpen = _expanded.contains(index);
    final hasMatches = form != null && !form.isEmpty;

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: c.hairline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: hasMatches
                ? () => setState(() {
                      if (isOpen) {
                        _expanded.remove(index);
                      } else {
                        _expanded.add(index);
                      }
                    })
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
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
                      localizedTeamName(context, team.name).toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: EType.label(color: c.ink, size: 12, letterSpacing: 1.2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (hasMatches) ...[
                    ...form.form.map((r) => _pill(c, r)),
                    const SizedBox(width: 6),
                    Icon(
                      isOpen ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: c.inkMute,
                    ),
                  ] else
                    Text(
                      AppLocalizations.of(context)!.recentFormEmpty.toUpperCase(),
                      style: EType.label(color: c.inkDim, size: 10, letterSpacing: 1),
                    ),
                ],
              ),
            ),
          ),
          if (isOpen && hasMatches) ...[
            Container(height: 1, color: c.hairline),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: RecentFormBlock(
                teamId: form.perspectiveTeamId ?? team.id,
                data: form,
                showHeader: false,
                onMatchTap: (g) => widget.onMatchTap(g, form.matches),
              ),
            ),
          ],
        ],
      ),
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

  // ── Tabbed layout ───────────────────────────────────────────────────────

  Widget _tabBar(EditorialColors c) {
    return Row(
      children: [
        _tab(c, 0, widget.home),
        _tab(c, 1, widget.away),
      ],
    );
  }

  Widget _tab(EditorialColors c, int index, Team team) {
    final active = _selected == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _selected = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? c.live : c.hairline,
                width: active ? 2 : 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: Image.network(
                  team.logo,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      Icon(Icons.shield_outlined, size: 14, color: c.inkDim),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  localizedTeamName(context, team.name).toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: EType.label(
                    color: active ? c.live : c.inkMute,
                    size: 11,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _teamBlock(Team team, RecentForm? form) {
    final c = context.col;
    final l = AppLocalizations.of(context)!;

    if (form == null || form.isEmpty) {
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

    return RecentFormBlock(
      teamId: form.perspectiveTeamId ?? team.id,
      data: form,
      onMatchTap: (g) => widget.onMatchTap(g, form.matches),
    );
  }
}
