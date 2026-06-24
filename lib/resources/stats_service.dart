import 'dart:convert';
import 'package:football/utils/config.dart';
import 'package:http/http.dart' as http;

class TeamStats {
  final int teamId;
  final String teamName;
  final String teamLogo;
  final List<StatItem> statistics;

  TeamStats({
    required this.teamId,
    required this.teamName,
    required this.teamLogo,
    required this.statistics,
  });

  factory TeamStats.fromJson(Map<String, dynamic> json) {
    final team = json['team'] as Map<String, dynamic>? ?? {};
    final rawStats = (json['statistics'] as List?) ?? [];
    return TeamStats(
      teamId: (team['id'] as num?)?.toInt() ?? 0,
      teamName: team['name']?.toString() ?? '',
      teamLogo: team['logo']?.toString() ?? '',
      statistics: rawStats
          .whereType<Map<String, dynamic>>()
          .map((s) => StatItem.fromJson(s))
          .toList(),
    );
  }
}

class StatItem {
  final String type;
  final dynamic value;

  StatItem({required this.type, required this.value});

  factory StatItem.fromJson(Map<String, dynamic> json) {
    return StatItem(
      type: json['type']?.toString() ?? '',
      value: json['value'],
    );
  }
}

class StatsService {
  Future<List<TeamStats>?> getFixtureStats(int fixtureId, {bool fetch = false}) async {
    try {
      final url = '$backendUrl/fixtures/$fixtureId/stats${fetch ? '?fetch=1' : ''}';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        print('Failed to load stats: ${response.statusCode}');
        return null;
      }

      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic>? raw = data['stats'] as List<dynamic>?;
      if (raw == null) return null;

      return raw
          .whereType<Map<String, dynamic>>()
          .map((e) => TeamStats.fromJson(e))
          .toList();
    } catch (e) {
      print('Error fetching stats: $e');
      return null;
    }
  }
}
