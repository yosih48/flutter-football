import 'dart:convert';
import 'package:football/utils/config.dart';
import 'package:http/http.dart' as http;

class StandingRow {
  final int rank;
  final int teamId;
  final String teamName;
  final String teamLogo;
  final int played;
  final int won;
  final int drawn;
  final int lost;
  final int goalsFor;
  final int goalsAgainst;
  final int goalsDiff;
  final int points;
  final String? form;
  final String? group;

  StandingRow({
    required this.rank,
    required this.teamId,
    required this.teamName,
    required this.teamLogo,
    required this.played,
    required this.won,
    required this.drawn,
    required this.lost,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalsDiff,
    required this.points,
    this.form,
    this.group,
  });

  factory StandingRow.fromJson(Map<String, dynamic> json) {
    final team = json['team'] as Map<String, dynamic>? ?? {};
    final all = json['all'] as Map<String, dynamic>? ?? {};
    final goals = all['goals'] as Map<String, dynamic>? ?? {};
    return StandingRow(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      teamId: (team['id'] as num?)?.toInt() ?? 0,
      teamName: team['name']?.toString() ?? '',
      teamLogo: team['logo']?.toString() ?? '',
      played: (all['played'] as num?)?.toInt() ?? 0,
      won: (all['win'] as num?)?.toInt() ?? 0,
      drawn: (all['draw'] as num?)?.toInt() ?? 0,
      lost: (all['lose'] as num?)?.toInt() ?? 0,
      goalsFor: (goals['for'] as num?)?.toInt() ?? 0,
      goalsAgainst: (goals['against'] as num?)?.toInt() ?? 0,
      goalsDiff: (json['goalsDiff'] as num?)?.toInt() ?? 0,
      points: (json['points'] as num?)?.toInt() ?? 0,
      form: json['form']?.toString(),
      group: json['group']?.toString(),
    );
  }
}

class StandingsService {
  /// Returns standings as a flat list of rows. API-FOOTBALL nests them as
  /// response[0].league.standings[group][row]; we flatten here.
  Future<List<StandingRow>?> getLeagueStandings(int leagueId) async {
    try {
      final url = '$backendUrl/leagues/$leagueId/standings';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        print('Failed to load standings: ${response.statusCode}');
        return null;
      }

      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic>? raw = data['standings'] as List<dynamic>?;
      if (raw == null || raw.isEmpty) return null;

      final first = raw.first as Map<String, dynamic>?;
      final league = first?['league'] as Map<String, dynamic>?;
      final groups = league?['standings'] as List<dynamic>? ?? [];

      final rows = <StandingRow>[];
      for (final group in groups) {
        if (group is! List) continue;
        for (final row in group) {
          if (row is Map<String, dynamic>) {
            rows.add(StandingRow.fromJson(row));
          }
        }
      }
      return rows;
    } catch (e) {
      print('Error fetching standings: $e');
      return null;
    }
  }
}
