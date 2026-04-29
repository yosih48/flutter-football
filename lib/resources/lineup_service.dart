import 'package:football/models/lineup.dart';
import 'package:football/utils/config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

String _baseUrl = backendUrl;

class LineupService {
  Future<LineupResponse?> getFixtureLineups(int fixtureId, {DateTime? matchDate}) async {
    try {
      String url = '$_baseUrl/fixtures/$fixtureId/lineups';
      if (matchDate != null) {
        url += '?matchDate=${matchDate.toIso8601String()}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return LineupResponse.fromJson(data);
      } else {
        print('Failed to load lineups: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching lineups: $e');
      return null;
    }
  }
}
