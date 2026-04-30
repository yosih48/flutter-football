import 'package:flutter/material.dart';
import 'package:football/models/FixtureEvent.dart';
import 'package:football/resources/FixtureEventsService.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class FixtureEventsWidget extends StatefulWidget {
  final int fixtureId;
  final String homeTeamName;
  final String awayTeamName;
  final bool isCompact;
  /// Set to false when the parent already provides a section header
  /// (e.g. the collapsible block in GameDetails). Defaults to true.
  final bool showHeader;

  const FixtureEventsWidget({
    Key? key,
    required this.fixtureId,
    required this.homeTeamName,
    required this.awayTeamName,
    this.isCompact = false,
    this.showHeader = true,
  }) : super(key: key);

  @override
  _FixtureEventsWidgetState createState() => _FixtureEventsWidgetState();
}

class _FixtureEventsWidgetState extends State<FixtureEventsWidget> {
  FixtureEventsResponse? _eventsResponse;
  bool _isLoading = false;
  String? _error;
  bool _expanded = true;

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
      return _buildTimeline(_eventsResponse!.events, c);
    }
    return _buildEmptyWidget(c);
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
              style: EType.display(
                size: 16,
                color: c.ink,
                letterSpacing: 0.4,
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

              // Timeline spine
              SizedBox(
                width: 40,
                child: Column(
                  children: [
                    // Top line
                    Expanded(
                      child: Container(
                        width: 1,
                        color: index == 0
                            ? Colors.transparent
                            : c.hairline,
                      ),
                    ),
                    // Time bubble
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: c.card,
                        border:
                            Border.all(color: c.hairlineHi, width: 1.5),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          "${event.time}'",
                          style: EType.numeric(
                            color: c.inkDim,
                            size: 9,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    // Bottom line
                    Expanded(
                      child: Container(
                        width: 1,
                        color: isLast ? Colors.transparent : c.hairline,
                      ),
                    ),
                  ],
                ),
              ),

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

  Widget _buildEventContent(
    FixtureEvent event, {
    required bool isHome,
    required EditorialColors c,
  }) {
    final eventInfo = _getEventInfo(event);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
      child: Row(
        mainAxisAlignment:
            isHome ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isHome) ...[
            _buildEventIcon(eventInfo),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isHome ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  event.player,
                  style: EType.body(
                    color: c.ink,
                    size: 13,
                    weight: FontWeight.w600,
                  ),
                  textAlign: isHome ? TextAlign.right : TextAlign.left,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (event.detail != null && event.detail!.isNotEmpty)
                  Text(
                    event.detail!,
                    style: EType.label(
                      color: c.inkMute,
                      size: 11,
                    ),
                    textAlign: isHome ? TextAlign.right : TextAlign.left,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (event.assist != null && event.assist!.isNotEmpty)
                  Text(
                    "Asst: ${event.assist}",
                    style: EType.body(
                      color: c.inkDim,
                      size: 10,
                      height: 1.3,
                    ),
                    textAlign: isHome ? TextAlign.right : TextAlign.left,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (isHome) ...[
            const SizedBox(width: 10),
            _buildEventIcon(eventInfo),
          ],
        ],
      ),
    );
  }

  Widget _buildEventIcon(Map<String, dynamic> info) {
    if (info['type'] == 'text') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: (info['color'] as Color).withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
              color: (info['color'] as Color).withOpacity(0.5)),
        ),
        child: Text(
          info['text'] as String,
          style: TextStyle(
            color: info['color'] as Color,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Icon(
      info['icon'] as IconData,
      color: info['color'] as Color,
      size: 18,
    );
  }

  Map<String, dynamic> _getEventInfo(FixtureEvent event) {
    final type = event.type.toLowerCase();
    final detail = event.detail?.toLowerCase() ?? '';

    if (type == 'goal') {
      if (detail.contains('missed')) {
        return {'icon': Icons.sports_soccer, 'color': Colors.red, 'type': 'icon', 'isGoal': true};
      }
      return {'icon': Icons.sports_soccer, 'color': Colors.blue, 'type': 'icon', 'isGoal': true};
    } else if (type == 'card') {
      return {
        'icon': Icons.style,
        'color': detail.contains('yellow') ? Colors.yellow : Colors.red,
        'type': 'icon',
      };
    } else if (type == 'subst') {
      return {'icon': Icons.import_export, 'color': Colors.green, 'type': 'icon'};
    } else if (type == 'var') {
      return {'text': 'VAR', 'color': Colors.purpleAccent, 'type': 'text'};
    }

    return {'icon': Icons.info_outline, 'color': Colors.grey, 'type': 'icon'};
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
            AppLocalizations.of(context)!.noGoals,
            style: EType.label(color: c.inkMute, size: 12, letterSpacing: 1.4),
          ),
        ],
      ),
    );
  }
}
