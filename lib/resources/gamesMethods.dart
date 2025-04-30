import 'package:football/models/games.dart';
import 'package:football/utils/config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';

    String _baseUrl = backendUrl;
class GamesMethods {
  Future<List<Game>> fetchAllGames(leagueId,  bool onlyThisLeague, 
  {bool onlyTodayGames = false,
    DateTime? selectedDate,
  } ) async {
   
    List<int> leagueIds = onlyThisLeague? [leagueId]: [2, 3, 383, 140 ,39 ,78] ;


    List<Game> allGames = [];

    for (int leagueId in leagueIds) {
      final games = await _fetchGamesForLeague(leagueId, onlyTodayGames: onlyTodayGames,
         selectedDate: selectedDate,
      );
      allGames.addAll(games);
    }

    allGames.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return allGames;
  }

  Future<List<Game>> fetchGamesForLeague(int leagueId, {bool onlyTodayGames = false,
   DateTime? selectedDate,
  }) async {
    return await _fetchGamesForLeague(leagueId,onlyTodayGames: onlyTodayGames,
      selectedDate: selectedDate,
    );
  }

  Future<List<Game>> _fetchGamesForLeague(int leagueId ,{bool onlyTodayGames = false,
   DateTime? selectedDate,
  }) async {
    final url = Uri.parse('$_baseUrl/api/realApiData');
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
           bool isNotPostponedOrTBD =
              game.status.short != 'PST' && game.status.short != 'TBD';



          bool isSelectedDate = true;
          if (selectedDate != null) {
            final gameDate =
                DateTime(game.date.year, game.date.month, game.date.day);
            isSelectedDate = gameDate.isAtSameMomentAs(selectedDate);
          } else if (onlyTodayGames) {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final gameDate =
                DateTime(game.date.year, game.date.month, game.date.day);
            isSelectedDate = gameDate.isAtSameMomentAs(today);
          }


      bool isToday = false;
          if (onlyTodayGames) {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final gameDate = DateTime(game.date.year, game.date.month, game.date.day);
            isToday = gameDate.isAtSameMomentAs(today);
          }




          // Additional filter logic for specific league IDs
     if (leagueId == 2 || leagueId == 848 || leagueId == 3) {
            return isNotPostponedOrTBD &&
                ((hasOdds &&
                        !game.league.round.contains("Qualifying")
                        && game.league.round != "Play-offs"
                        &&
                        // (!onlyTodayGames || isToday)) ||
                        (    isSelectedDate)) ||
                    (isFinished &&
                        !game.league.round.contains("Qualifying") 
                        && game.league.round != "Play-offs"
                        &&
                        // (!onlyTodayGames || isToday)));
                        (    isSelectedDate)));
          }
          // return hasOdds || isFinished;
      return isNotPostponedOrTBD &&
              (hasOdds || isFinished) &&
              // (!onlyTodayGames || isToday);
                  isSelectedDate;
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
