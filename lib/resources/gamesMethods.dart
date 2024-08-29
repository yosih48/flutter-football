import 'package:football/models/games.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';

class GamesMethods {
  Future<List<Game>> fetchAllGames() async {
    List<int> leagueIds = [2, 3, 383, 140];
    List<Game> allGames = [];

    for (int leagueId in leagueIds) {
      final games = await _fetchGamesForLeague(leagueId);
      allGames.addAll(games);
    }

    allGames.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return allGames;
  }

  Future<List<Game>> fetchGamesForLeague(int leagueId) async {
    return await _fetchGamesForLeague(leagueId);
  }

  Future<List<Game>> _fetchGamesForLeague(int leagueId) async {
    final url = Uri.parse('https://leagues.onrender.com/api/realApiData');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'data': leagueId}),
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      final gamesData = responseData['games'];
      if (gamesData != null && gamesData is List) {
        final List<Game> games =
            gamesData.map((item) => Game.fromJson(item)).toList();

        // Filter games
        final filteredGames = games.where((game) {
          bool hasOdds = game.odds.home != 10 ||
              game.odds.draw != 10 ||
              game.odds.away != 10;
          bool isFinished = game.status.long == "Match Finished";
          // Additional filter logic for specific league IDs
    
          if (leagueId == 2 || leagueId == 848 || leagueId == 3) {
            return hasOdds 
            &&
                    !game.league.round.contains("Qualifying") &&
                    !game.league.round.contains("Play-offs")
            ||
                isFinished &&
                    !game.league.round.contains("Qualifying") &&
                    !game.league.round.contains("Play-offs");
          }

          return hasOdds || isFinished;
        }).toList();

        // Sort the filtered games by timestamp
        filteredGames.sort((a, b) => a.timestamp.compareTo(b.timestamp));

        return filteredGames;
      } else {
        throw Exception('Games data is null or not a list');
      }
    } else {
      throw Exception('Failed to fetch games');
    }
  }
}
