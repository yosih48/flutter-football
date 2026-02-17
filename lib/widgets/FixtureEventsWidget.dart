import 'package:flutter/material.dart';
import 'package:football/models/FixtureEvent.dart';
import 'package:football/resources/FixtureEventsService.dart';
import 'package:football/theme/colors.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class FixtureEventsWidget extends StatefulWidget {
  final int fixtureId;
  final String homeTeamName;
  final String awayTeamName;
  final bool isCompact;

  const FixtureEventsWidget({
    Key? key,
    required this.fixtureId,
    required this.homeTeamName,
    required this.awayTeamName,
    this.isCompact = false,
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
    return Container(
      // Padding adjusted for nesting inside the game card
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                _expanded = !_expanded;
              });
            },
            child: _buildHeader(),
          ),
          if (_expanded) ...[
            SizedBox(height: 12),
             // Add a divider to separate header/score from events if needed, 
             // or keep it clean. Let's keep it clean but maybe add a top border key?
             // For now, just spacing.
            if (_isLoading)
              _buildLoadingWidget()
            else if (_error != null)
              _buildErrorWidget()
            else if (_eventsResponse != null &&
                _eventsResponse!.events.isNotEmpty)
              _buildTimeline(_eventsResponse!.events)
            else
              _buildEmptyWidget(),
          ]
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1), // Fixed Blue Background
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.sports_soccer, color: Colors.blue, size: 20), // Fixed Blue Icon
            ),
            SizedBox(width: 12),
            Text(
              AppLocalizations.of(context)!.matchEvents,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        Row(
          children: [
            if (!_isLoading)
              IconButton(
                icon: Icon(Icons.refresh, color: Colors.grey[400]),
                onPressed: _loadFixtureEvents,
                iconSize: 20,
                tooltip: 'Refresh Events',
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            SizedBox(width: 12),
            Icon(
              _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: Colors.grey[400],
              size: 24,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeline(List<FixtureEvent> events) {
    // Sort events by time descending so the latest events appear on top.
    final sortedEvents = List<FixtureEvent>.from(events)
      ..sort((a, b) => b.time.compareTo(a.time));
    
    return ListView.builder(
      physics: NeverScrollableScrollPhysics(),
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
              // Home Side
              Expanded(
                child: isHome
                    ? _buildEventContent(event, isHome: true)
                    : SizedBox.shrink(),
              ),

              // Timeline Line
              Container(
                width: 40,
                child: Column(
                  children: [
                     // Top Line
                    Expanded(
                      child: Container(
                        width: 1, // Thinner line
                        color: index == 0 ? Colors.transparent : Colors.grey[800],
                      ),
                    ),
                    
                    // Time Bubble
                    Container(
                      width: 26, // Slightly smaller
                      height: 26,
                      decoration: BoxDecoration(
                        color: cards, // Background matching the card
                        border: Border.all(color: Colors.grey[700]!, width: 1.5),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          "${event.time}'",
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 9, // Smaller font
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    
                    // Bottom Line
                    Expanded(
                      child: Container(
                        width: 1, // Thinner line
                        color: isLast ? Colors.transparent : Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ),

              // Away Side
              Expanded(
                child: !isHome
                    ? _buildEventContent(event, isHome: false)
                    : SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEventContent(FixtureEvent event, {required bool isHome}) {
    final eventInfo = _getEventInfo(event);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
      child: Row(
        mainAxisAlignment:
            isHome ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isHome) ...[
            _buildEventIcon(eventInfo),
            SizedBox(width: 10),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isHome ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  event.player,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  textAlign: isHome ? TextAlign.right : TextAlign.left,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (event.detail != null && event.detail!.isNotEmpty)
                  Text(
                    event.detail!,
                     style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 11,
                    ),
                    textAlign: isHome ? TextAlign.right : TextAlign.left,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (event.assist != null && event.assist!.isNotEmpty)
                  Text(
                    "Asst: ${event.assist}",
                     style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 10,
                      fontStyle: FontStyle.italic
                    ),
                    textAlign: isHome ? TextAlign.right : TextAlign.left,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (isHome) ...[
            SizedBox(width: 10),
            _buildEventIcon(eventInfo),
          ],
        ],
      ),
    );
  }

  Widget _buildEventIcon(Map<String, dynamic> info) {
    if (info['type'] == 'text') {
       return Container(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
         decoration: BoxDecoration(
          color: info['color'].withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: info['color'].withOpacity(0.5)),
        ),
        child: Text(
          info['text'],
          style: TextStyle(
            color: info['color'],
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
       );
    }
    
    // For Goal icons, we make them pop a bit more if it's a goal
    if (info['isGoal'] == true) {
        return Container(
          // padding: EdgeInsets.all(4),
          // decoration: BoxDecoration(
          //   shape: BoxShape.circle,
          //   border: Border.all(color: info['color'].withOpacity(0.3), width: 1),
          //   // color: info['color'].withOpacity(0.1),
          // ),
          child: Icon(
            info['icon'],
            color: info['color'],
            size: 18,
          ),
        );
    }

    return Icon(
      info['icon'],
      color: info['color'],
      size: 18,
    );
  }

  Map<String, dynamic> _getEventInfo(FixtureEvent event) {
    String type = event.type.toLowerCase();
    String detail = event.detail?.toLowerCase() ?? '';

    if (type == 'goal') {
      if (detail.contains('missed')) {
         return {
          'icon': Icons.sports_soccer,
          'color': Colors.red,
          'type': 'icon',
          'isGoal': true,
        };
      }
      return {
        'icon': Icons.sports_soccer, // Material icon is cleaner
        'color': Colors.blue, // Requested blue color
        'type': 'icon',
        'isGoal': true,
      };
    } else if (type == 'card') {
      if (detail.contains('yellow')) {
        return {
          'icon': Icons.style, 
          'color': Colors.yellow,
          'type': 'icon',
        };
      } else {
        return {
          'icon': Icons.style,
          'color': Colors.red,
          'type': 'icon',
        };
      }
    } else if (type == 'subst') {
      return {
        'icon': Icons.import_export, 
        'color': Colors.green,
        'type': 'icon',
      };
    } else if (type == 'var') {
       return {
          'text': 'VAR',
          'color': Colors.purpleAccent,
          'type': 'text',
        };
    }

    return {
      'icon': Icons.info_outline,
      'color': Colors.grey,
      'type': 'icon',
    };
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(primary),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              _error ?? AppLocalizations.of(context)!.failedToLoadEvents,
              style: TextStyle(color: Colors.redAccent, fontSize: 13),
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.redAccent),
            onPressed: _loadFixtureEvents,
            iconSize: 20,
          )
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Icon(Icons.event_busy, color: Colors.grey[600], size: 40),
          SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)!.noGoals, 
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }
}
