import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:football/utils/config.dart';

String _baseUrl = backendUrl;

class PlayersMethods {
  // Returns the raw per-player records from /getTopScorersList so callers can
  // pick the localized name/team themselves. Each entry has keys: `name`,
  // `name_english`, `team`, `team_english` (Hebrew variants may be empty).
  Future<List<Map<String, String>>> fetchPlayersListRaw(
      dynamic dataToSend) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/getTopScorersList'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'data': dataToSend}),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        return [];
      }
      final body = jsonDecode(response.body);
      final players = body['data']?['players'] as List<dynamic>?;
      if (players == null) return [];
      return players
          .whereType<Map>()
          .map<Map<String, String>>((p) => {
                'name': p['name']?.toString() ?? '',
                'name_english': p['name_english']?.toString() ?? '',
                'team': p['team']?.toString() ?? '',
                'team_english': p['team_english']?.toString() ?? '',
              })
          .toList();
    } catch (e) {
      print('Error fetching players: $e');
      return [];
    }
  }

  Future<List<String>> fetchPlayersList(dynamic dataToSend) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/getTopScorersList'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'data': dataToSend}),
      );

      if (response.statusCode == 200  || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        final players = responseData['data']?['players'] as List<dynamic>?;

        if (players != null) {
          // Combine name and team
          final formattedList = players.map<String>((player) {
            final nameEnglish = player['name_english'] ?? '';
            final teamEnglish = player['team_english'] ?? '';
            return '$nameEnglish ($teamEnglish)';
          }).toList();

          print('Fetched ${formattedList.length} players');
          return formattedList;
        } else {
          print('No players found in response');
          return [];
        }
      } else {
        print('Failed to fetch players: ${response.statusCode}');
        print('Response body: ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error fetching players: $e');
      return [];
    }
  }
}
