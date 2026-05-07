import 'dart:convert';
import 'package:http/http.dart' as http;

// Data Models
class FixtureEvent {
  final String type;
  final int time;
  final String team;
  final String player;
  final String? assist;
  final String? detail;

  FixtureEvent({
    required this.type,
    required this.time,
    required this.team,
    required this.player,
    this.assist,
    this.detail,
  });

  factory FixtureEvent.fromJson(Map<String, dynamic> json) {
    // Tolerate missing/null nested objects — some upstream events omit them.
    final time = json['time'];
    final team = json['team'];
    final player = json['player'];
    final assist = json['assist'];
    return FixtureEvent(
      type: json['type']?.toString() ?? '',
      time: (time is Map ? time['elapsed'] : null) is int
          ? (time as Map)['elapsed'] as int
          : 0,
      team: (team is Map ? team['name']?.toString() : null) ?? '',
      player: (player is Map ? player['name']?.toString() : null) ?? '',
      assist: assist is Map ? assist['name']?.toString() : null,
      detail: json['detail']?.toString(),
    );
  }
}

class FixtureEventsResponse {
  final bool success;
  final String fixtureId;
  final List<FixtureEvent> events;
  final int count;

  FixtureEventsResponse({
    required this.success,
    required this.fixtureId,
    required this.events,
    required this.count,
  });

  factory FixtureEventsResponse.fromJson(Map<String, dynamic> json) {
    // Defensive: legacy/corrupt cached files on the backend can shape `events`
    // as a Map instead of a List. Treat any non-List as empty so the screen
    // renders cleanly instead of crashing.
    final raw = json['events'];
    final eventsList = raw is List ? raw : const [];
    final events = eventsList
        .whereType<Map>()
        .map((e) => FixtureEvent.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return FixtureEventsResponse(
      success: json['success'] ?? false,
      fixtureId: json['fixtureId']?.toString() ?? '',
      events: events,
      count: json['count'] is int ? json['count'] as int : events.length,
    );
  }
}
