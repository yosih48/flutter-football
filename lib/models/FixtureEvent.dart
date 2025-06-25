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
    return FixtureEvent(
      type: json['type'] ?? '',
      time: json['time']['elapsed'] ?? 0,
      team: json['team']['name'] ?? '',
      player: json['player']['name'] ?? '',
      assist: json['assist']?['name'],
      detail: json['detail'],
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
    var eventsList = json['events'] as List? ?? [];
    List<FixtureEvent> events = eventsList
        .map((eventJson) => FixtureEvent.fromJson(eventJson))
        .toList();

    return FixtureEventsResponse(
      success: json['success'] ?? false,
      fixtureId: json['fixtureId'] ?? '',
      events: events,
      count: json['count'] ?? 0,
    );
  }
}
