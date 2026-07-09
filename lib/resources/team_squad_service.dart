import 'dart:convert';
import 'package:football/models/squad_player.dart';
import 'package:football/utils/config.dart';
import 'package:http/http.dart' as http;

String _baseUrl = backendUrl;

class TeamSquadService {
  /// Fetches a team's squad from the backend disk cache (no external API).
  /// Returns an empty list when no squad has been pre-warmed for the team.
  Future<List<SquadPlayer>> getSquad(int teamId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/teams/$teamId/squad'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final list = data['players'];
        if (list is List) {
          return list
              .whereType<Map>()
              .map((e) => SquadPlayer.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
        return [];
      }
      print('Failed to load squad: ${response.statusCode}');
      return [];
    } catch (e) {
      print('Error fetching squad: $e');
      return [];
    }
  }
}
