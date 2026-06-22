import 'dart:convert';
import 'package:football/models/head_to_head.dart';
import 'package:football/utils/config.dart';
import 'package:http/http.dart' as http;

class HeadToHeadService {
  /// Returns head-to-head history for a fixture, or null if the backend has no
  /// cached data for it (yet) or on error. The backend derives this from
  /// already-cached fixtures — no external API call is made.
  Future<HeadToHead?> getHeadToHead(int fixtureId) async {
    try {
      final url = '$backendUrl/fixtures/$fixtureId/h2h';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode != 200) {
        print('Failed to load h2h: ${response.statusCode}');
        return null;
      }

      final Map<String, dynamic> data = json.decode(response.body);
      final raw = data['h2h'] as Map<String, dynamic>?;
      if (raw == null) return null;

      return HeadToHead.fromJson(raw);
    } catch (e) {
      print('Error fetching h2h: $e');
      return null;
    }
  }
}
