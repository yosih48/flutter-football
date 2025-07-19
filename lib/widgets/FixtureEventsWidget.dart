import 'package:flutter/material.dart';
import 'package:football/models/FixtureEvent.dart';
import 'package:football/resources/FixtureEventsService.dart';
import 'package:football/theme/colors.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class FixtureEventsWidget extends StatefulWidget {
  final int fixtureId;

  final bool isCompact;

  const FixtureEventsWidget({
    Key? key,
    required this.fixtureId,
    this.isCompact = false,
  }) : super(key: key);

  @override
  _FixtureEventsWidgetState createState() => _FixtureEventsWidgetState();
}

class _FixtureEventsWidgetState extends State<FixtureEventsWidget> {
  FixtureEventsResponse? _eventsResponse;
  bool _isLoading = false;
  String? _error;
  bool _expanded = false;
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
      color: cards,
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _expanded = !_expanded;
              });
            },
            child: _buildHeader(),
          ),
          if (_expanded) ...[
            SizedBox(height: 16),
            if (_isLoading)
              _buildLoadingWidget()
            else if (_error != null)
              _buildErrorWidget()
            else if (_eventsResponse != null &&
                _eventsResponse!.events.isNotEmpty)
              _buildEventsWidget()
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
            Icon(Icons.sports_soccer, color: Colors.blue, size: 20),
            SizedBox(width: 8),
            Text(
              AppLocalizations.of(context)!.matchEvents,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
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
              ),
            Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.white,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
              ),
            ),
            SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.loadingEvents,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
          ],
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
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error, color: Colors.red, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.failedToLoadEvents,
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Colors.red.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: _loadFixtureEvents,
            child: Text(
              AppLocalizations.of(context)!.retry,
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.sports_soccer_outlined,
              size: 48,
              color: Colors.grey[500],
            ),
            SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.noGoals,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.eventsAppear,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsWidget() {
    final events = _eventsResponse!.events;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // if (!widget.isCompact)
        //   Padding(
        //     padding: const EdgeInsets.only(bottom: 16),
        //     child: Text(
        //       '${_eventsResponse!.count} ${AppLocalizations.of(context)!.goals}',
        //       style: TextStyle(
        //         color: Colors.green,
        //         fontSize: 14,
        //         fontWeight: FontWeight.bold,
        //       ),
        //     ),
        //   ),
        ListView.separated(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: events.length,
          separatorBuilder: (context, index) => Divider(
            color: Colors.grey[700],
            height: 1,
          ),
          itemBuilder: (context, index) {
            final event = events[index];
            return _buildEventItem(event);
          },
        ),
      ],
    );
  }

  Widget _buildEventItem(FixtureEvent event) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // Time indicator
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.withOpacity(0.5)),
            ),
            child: Center(
              child: Text(
                '${event.time}\'',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                  fontSize: 12,
                ),
              ),
            ),
          ),

          SizedBox(width: 16),

          // Event details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Player name
                Text(
                  event.player,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),

                SizedBox(height: 4),

                // Team name
                Text(
                  event.team,
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontSize: 14,
                  ),
                ),

                // Assist (if available)
                // if (event.assist != null) ...[
                //   SizedBox(height: 2),
                //   Text(
                //     '${AppLocalizations.of(context)!.assist} ${event.assist}',
                //     style: TextStyle(
                //       fontSize: 12,
                //       color: Colors.grey[400],
                //       fontStyle: FontStyle.italic,
                //     ),
                //   ),
                // ],

                // Detail (if available)
                // if (event.detail != null) ...[
                //   SizedBox(height: 2),
                //   Text(
                //     event.detail!,
                //     style: TextStyle(
                //       fontSize: 12,
                //       color: Colors.grey[400],
                //     ),
                //   ),
                // ],
              ],
            ),
          ),

          // Goal icon
          Container(
            padding: const EdgeInsets.all(8),
            // decoration: BoxDecoration(
            //   color: Colors.orange.withOpacity(0.2),
            //   borderRadius: BorderRadius.circular(8),
            // ),
            child: Icon(
              FontAwesomeIcons.futbol,
              color: Colors.blue,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}
