import 'package:football/models/games.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';

class GamesMethods {
  Future<List<Game>> fetchGames(int leagueId) async {
    print('leagueId ${leagueId}');
    final url = Uri.parse('https://leagues.onrender.com/api/realApiData');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'data': leagueId}),
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      // print(responseData);
      final gamesData = responseData['games'];
      print('gamesData ${gamesData}');
      if (gamesData != null && gamesData is List) {
        final games =
            (gamesData as List).map((item) => Game.fromJson(item)).toList();
        return games;
      } else {
        throw Exception('Games data is null or not a list');
      }
    } else {
      throw Exception('Failed to fetch games');
    }
  }


}
