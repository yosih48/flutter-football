import 'package:flutter/material.dart';
import 'package:football/models/FixtureEvent.dart';
import 'package:football/resources/FixtureEventsService.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:football/utils/he_player_name.dart';
import 'package:football/utils/localized_team_name.dart';

class FixtureEventsWidget extends StatefulWidget {
  final int fixtureId;
  final String homeTeamName;
  final String awayTeamName;
  final bool isCompact;

  /// Set to false when the parent already provides a section header
  /// (e.g. the collapsible block in GameDetails). Defaults to true.
  final bool showHeader;

  /// Crests for the two-team strip above the timeline. Optional — the strip
  /// falls back to a shield icon when a logo is missing or fails to load.
  final String? homeTeamLogo;
  final String? awayTeamLogo;

  const FixtureEventsWidget({
    Key? key,
    required this.fixtureId,
    required this.homeTeamName,
    required this.awayTeamName,
    this.isCompact = false,
    this.showHeader = true,
    this.homeTeamLogo,
    this.awayTeamLogo,
  }) : super(key: key);

  @override
  _FixtureEventsWidgetState createState() => _FixtureEventsWidgetState();
}

class _FixtureEventsWidgetState extends State<FixtureEventsWidget> {
  FixtureEventsResponse? _eventsResponse;
  bool _isLoading = false;
  String? _error;
  bool _expanded = true;
  bool _majorOnly = false;

  // Hebrew copy is set in Rubik rather than Sora — see EType.body. Trialling
  // this on the events tab only; the rest of the app still uses the default.
  bool get _he => Localizations.localeOf(context).languageCode == 'he';

  bool _isMajor(FixtureEvent e) {
    final type = e.type.toLowerCase();
    final detail = e.detail?.toLowerCase() ?? '';
    if (type == 'goal') return true;
    if (detail.contains('penalty')) return true;
    if (e.assist != null && e.assist!.isNotEmpty && type != 'subst') {
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _loadFixtureEvents();
  }

  Future<void> _loadFixtureEvents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response =
          await FixtureEventsService().getFixtureEvents(widget.fixtureId);

      setState(() {
        _eventsResponse = response;
        _isLoading = false;
      });

      if (response == null) {
        setState(() {
          _error = 'Failed to load fixture events';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showHeader) ...[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _expanded = !_expanded),
              child: _buildHeader(c),
            ),
            if (_expanded) ...[
              const SizedBox(height: 12),
              _buildContent(c),
            ],
          ] else
            _buildContent(c),
        ],
      ),
    );
  }

  Widget _buildContent(EditorialColors c) {
    if (_isLoading) return _buildLoadingWidget(c);
    if (_error != null) return _buildErrorWidget(c);
    if (_eventsResponse != null && _eventsResponse!.events.isNotEmpty) {
      final all = _eventsResponse!.events;
      final filtered = _majorOnly ? all.where(_isMajor).toList() : all;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTeamStrip(c),
          const SizedBox(height: 14),
          _buildFilterToggle(c),
          const SizedBox(height: 6),
          if (filtered.isEmpty)
            _buildEmptyWidget(c)
          else
            _buildTimeline(filtered, c),
        ],
      );
    }
    return _buildEmptyWidget(c);
  }

  // Two-team strip: home leads (right in RTL), away trails, each a crest plus
  // the localized team name.
  Widget _buildTeamStrip(EditorialColors c) {
    return Row(
      children: [
        Expanded(
          child: _teamChip(widget.homeTeamName, widget.homeTeamLogo, c,
              alignEnd: false),
        ),
        Expanded(
          child: _teamChip(widget.awayTeamName, widget.awayTeamLogo, c,
              alignEnd: true),
        ),
      ],
    );
  }

  Widget _teamChip(String name, String? logo, EditorialColors c,
      {required bool alignEnd}) {
    final crest = SizedBox(
      width: 20,
      height: 20,
      child: (logo == null || logo.isEmpty)
          ? Icon(Icons.shield_outlined, size: 16, color: c.inkDim)
          : Image.network(
              logo,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.shield_outlined, size: 16, color: c.inkDim),
            ),
    );
    final label = Flexible(
      child: Text(
        localizedTeamName(context, name),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: EType.body(
            color: c.ink, size: 13, weight: FontWeight.w700, hebrew: _he),
      ),
    );

    return Row(
      mainAxisAlignment:
          alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: alignEnd
          ? [label, const SizedBox(width: 8), crest]
          : [crest, const SizedBox(width: 8), label],
    );
  }

  // Segmented filter: the active half is a solid green pill, the other is the
  // plain card surface — both inside one rounded, hairlined track.
  Widget _buildFilterToggle(EditorialColors c) {
    final l = AppLocalizations.of(context)!;
    return Center(
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: c.cardHi,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.hairline, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _filterPill(l.majorEvents, _majorOnly,
                () => setState(() => _majorOnly = true), c),
            _filterPill(l.allEvents, !_majorOnly,
                () => setState(() => _majorOnly = false), c),
          ],
        ),
      ),
    );
  }

  Widget _filterPill(
      String label, bool active, VoidCallback onTap, EditorialColors c) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        decoration: BoxDecoration(
          color: active ? c.live : c.card,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: EType.body(
            color: active ? Colors.white : c.inkMute,
            size: 13,
            weight: FontWeight.w600,
            hebrew: _he,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(EditorialColors c) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: c.liveSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.sports_soccer, color: c.live, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              AppLocalizations.of(context)!.matchEvents,
              style: EType.body(
                size: 16,
                color: c.ink,
                weight: FontWeight.w700,
                hebrew: Localizations.localeOf(context).languageCode == 'he',
              ),
            ),
          ],
        ),
        Row(
          children: [
            if (!_isLoading)
              IconButton(
                icon: Icon(Icons.refresh, color: c.inkMute),
                onPressed: _loadFixtureEvents,
                iconSize: 18,
                tooltip: 'Refresh Events',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            const SizedBox(width: 12),
            Icon(
              _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: c.inkMute,
              size: 22,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeline(List<FixtureEvent> events, EditorialColors c) {
    final sortedEvents = List<FixtureEvent>.from(events)
      ..sort((a, b) => b.time.compareTo(a.time));

    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: sortedEvents.length,
      itemBuilder: (context, index) {
        final event = sortedEvents[index];
        final isHome = event.team == widget.homeTeamName;
        final bool isLast = index == sortedEvents.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Home side
              Expanded(
                child: isHome
                    ? _buildEventContent(event, isHome: true, c: c)
                    : const SizedBox.shrink(),
              ),

              // Timeline spine: continuous rule, an icon node marking the
              // event type, and the minute tucked alongside it.
              _buildSpine(event, c, isFirst: index == 0, isLast: isLast),

              // Away side
              Expanded(
                child: !isHome
                    ? _buildEventContent(event, isHome: false, c: c)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }

  static const double _nodeSize = 30;
  // Gap + text box under the node. Fixed so the rule's gap can be computed
  // without measuring text.
  static const double _minuteGap = 3;
  static const double _minuteHeight = 13;

  Widget _buildSpine(
    FixtureEvent event,
    EditorialColors c, {
    required bool isFirst,
    required bool isLast,
  }) {
    // A "Missed Penalty" has type "Goal" but is NOT a goal — keep it off the
    // solid green goal node and the ⚽ icon.
    final detail = event.detail?.toLowerCase() ?? '';
    final isGoal =
        event.type.toLowerCase() == 'goal' && !detail.contains('missed');

    return SizedBox(
      width: 46,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The rule, with a gap sized to the node PLUS the minute beneath it
          // so neither is struck through.
          Positioned.fill(
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: 1.5,
                    color: isFirst ? Colors.transparent : c.hairline,
                  ),
                ),
                const SizedBox(height: _nodeSize + _minuteGap + _minuteHeight),
                Expanded(
                  child: Container(
                    width: 1.5,
                    color: isLast ? Colors.transparent : c.hairline,
                  ),
                ),
              ],
            ),
          ),
          // Node above, minute centred directly beneath it. Both centre on the
          // spine, so the group lines up with the gap in the rule.
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Goals are a solid green disc, everything else a quiet outlined
              // circle, so scoring reads at a glance down the column.
              Container(
                width: _nodeSize,
                height: _nodeSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isGoal ? c.live : c.card,
                  shape: BoxShape.circle,
                  border:
                      isGoal ? null : Border.all(color: c.hairline, width: 1.5),
                ),
                child: _nodeIcon(event, c, isGoal: isGoal),
              ),
              const SizedBox(height: _minuteGap),
              SizedBox(
                height: _minuteHeight,
                child: Text(
                  "${event.time}'",
                  // The box is as wide as the node, so centre explicitly —
                  // otherwise the text hugs the start edge and looks offset.
                  textAlign: TextAlign.center,
                  style: EType.numeric(
                      color: c.inkDim, size: 10, weight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _nodeIcon(FixtureEvent event, EditorialColors c,
      {required bool isGoal}) {
    if (isGoal) {
      return const Icon(Icons.sports_soccer, size: 17, color: Colors.white);
    }
    final type = event.type.toLowerCase();
    final detail = event.detail?.toLowerCase() ?? '';
    // Missed penalty (type "Goal", detail "Missed Penalty"): a struck-through
    // ball so it reads as an attempt that didn't score, distinct from a goal.
    if (type == 'goal' && detail.contains('missed')) {
      return Icon(Icons.block, size: 14, color: c.inkMute);
    }
    if (type == 'subst') {
      return Icon(Icons.swap_vert, size: 15, color: c.inkDim);
    }
    if (type == 'card') {
      final detail = event.detail?.toLowerCase() ?? '';
      final red = detail.contains('red');
      return Icon(Icons.square_rounded,
          size: 13, color: red ? c.flag : const Color(0xFFFACC15));
    }
    if (type == 'var') {
      return Icon(Icons.videocam_outlined, size: 14, color: c.inkDim);
    }
    return Icon(Icons.circle, size: 8, color: c.inkDim);
  }

  Widget _buildEventContent(
    FixtureEvent event, {
    required bool isHome,
    required EditorialColors c,
  }) {
    // No side icon: the node on the spine already carries the event type, so
    // the full width goes to the player name (long names were truncating).
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
      child: Row(
        mainAxisAlignment:
            isHome ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: _buildEventBody(event, isHome: isHome, c: c),
          ),
        ],
      ),
    );
  }

  Widget _buildEventBody(
    FixtureEvent event, {
    required bool isHome,
    required EditorialColors c,
  }) {
    final l = AppLocalizations.of(context)!;
    final type = event.type.toLowerCase();
    final align = isHome ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final textAlign = isHome ? TextAlign.right : TextAlign.left;

    if (type == 'subst') {
      // For subs API-Sports puts the player going OFF in `player` and the
      // player coming ON in `assist`.
      return Column(
        crossAxisAlignment: align,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (event.assist != null && event.assist!.isNotEmpty)
            _subRow(
              icon: Icons.arrow_upward,
              color: c.live,
              label: l.playerIn,
              name: event.assist!,
              isHome: isHome,
              c: c,
            ),
          if (event.assist != null && event.assist!.isNotEmpty)
            const SizedBox(height: 2),
          _subRow(
            icon: Icons.arrow_downward,
            color: c.flag,
            label: l.playerOut,
            name: event.player,
            isHome: isHome,
            c: c,
          ),
        ],
      );
    }

    // Name + a small type badge on one line, assist underneath. No frame —
    // the node on the spine already carries the colour coding.
    final badge = _typeBadge(event, c);
    final nameRow = <Widget>[
      Flexible(
        child: Text(
          localizedPlayerName(context, event.player),
          style: EType.body(
              color: c.ink, size: 13, weight: FontWeight.w700, hebrew: _he),
          textAlign: textAlign,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      if (badge != null) ...[const SizedBox(width: 8), badge],
    ];

    return Column(
      crossAxisAlignment: align,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment:
              isHome ? MainAxisAlignment.start : MainAxisAlignment.end,
          children: isHome ? nameRow : nameRow.reversed.toList(),
        ),
        if (event.assist != null && event.assist!.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            "${l.assist} ${localizedPlayerName(context, event.assist!)}",
            style:
                EType.body(color: c.inkDim, size: 11, height: 1.3, hebrew: _he),
            textAlign: textAlign,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  // Small pill naming the event kind — "goal", "penalty", "own goal", a card.
  // Returns null for plain events that need no label.
  Widget? _typeBadge(FixtureEvent event, EditorialColors c) {
    final l = AppLocalizations.of(context)!;
    final type = event.type.toLowerCase();
    final detail = event.detail?.toLowerCase() ?? '';

    String text;
    Color color;
    if (type == 'goal') {
      if (detail.contains('missed')) {
        // Missed penalty: muted, not the amber scored-penalty badge.
        text = l.missedPenaltyLabel;
        color = c.inkMute;
      } else if (detail.contains('penalty')) {
        text = l.penaltyLabel;
        color = c.amber;
      } else if (detail.contains('own')) {
        text = l.ownGoalLabel;
        color = c.flag;
      } else {
        text = l.goalLabel;
        color = c.live;
      }
    } else if (type == 'card') {
      final red = detail.contains('red');
      text = red ? l.redCardLabel : l.yellowCardLabel;
      color = red ? c.flag : const Color(0xFFB45309);
    } else if (type == 'var') {
      text = 'VAR';
      color = c.inkMute;
    } else {
      return null;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: EType.body(
            color: color, size: 10, weight: FontWeight.w700, hebrew: _he),
      ),
    );
  }

  Widget _subRow({
    required IconData icon,
    required Color color,
    required String label,
    required String name,
    required bool isHome,
    required EditorialColors c,
  }) {
    final children = <Widget>[
      Icon(icon, color: color, size: 14),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          localizedPlayerName(context, name),
          // The arrow already encodes direction; colouring the name to match
          // makes on/off readable without reading the icon.
          style: EType.body(
              color: color, size: 12.5, weight: FontWeight.w600, hebrew: _he),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: isHome ? TextAlign.right : TextAlign.left,
        ),
      ),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment:
          isHome ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: isHome ? children.reversed.toList() : children,
    );
  }

  Widget _buildLoadingWidget(EditorialColors c) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation<Color>(c.live),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(EditorialColors c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: Colors.red.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error ?? AppLocalizations.of(context)!.failedToLoadEvents,
              style: EType.body(color: Colors.redAccent, size: 13),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.redAccent),
            onPressed: _loadFixtureEvents,
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget(EditorialColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Column(
        children: [
          Icon(Icons.event_busy, color: c.inkDim, size: 36),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)!.noEvents,
            style: EType.label(
                color: c.inkMute, size: 12, letterSpacing: 1.4, hebrew: _he),
          ),
        ],
      ),
    );
  }
}
