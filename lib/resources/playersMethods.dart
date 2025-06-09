import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:football/utils/config.dart';

String _baseUrl = backendUrl;

class PlayersMethods {
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
