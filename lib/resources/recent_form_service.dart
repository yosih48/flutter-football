import 'dart:convert';
import 'package:football/models/recent_form.dart';
import 'package:football/utils/config.dart';
import 'package:http/http.dart' as http;

class RecentFormService {
  /// Fetches a team's last [limit] matches. [teamName] enables the backend's
  /// AllSport fallback when nothing is cached for the team.
  Future<RecentForm?> getLastMatches(
    int teamId,
    String teamName, {
    int limit = 5,
  }) async {
    try {
      final url =
          '$backendUrl/teams/$teamId/last-matches?name=${Uri.encodeQueryComponent(teamName)}&limit=$limit';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode != 200) {
        print('Failed to load recent form: ${response.statusCode}');
        return null;
      }
      final Map<String, dynamic> data = json.decode(response.body);
      if (data['success'] != true) return null;
      return RecentForm.fromJson(data);
    } catch (e) {
      print('Error fetching recent form: $e');
      return null;
    }
  }
}
