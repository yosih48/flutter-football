import 'package:football/models/FixtureEvent.dart';
import 'package:football/utils/config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

String _baseUrl = backendUrl;
class FixtureEventsService {




  Future<FixtureEventsResponse?> getFixtureEvents(int fixtureId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/fixtures/$fixtureId/events'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
              print('response.statusCode == 200');
        final Map<String, dynamic> data = json.decode(response.body);
        print(data);
        return FixtureEventsResponse.fromJson(data);
      } else {
        print('Failed to load fixture events: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching fixture events: $e');
      return null;
    }
  }
}
