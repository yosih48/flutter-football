import 'package:football/models/games.dart';
import 'package:football/utils/config.dart';
import 'package:football/utils/game_cache_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';

String _baseUrl = backendUrl;

class GamesMethods {
  final GameCacheService _cacheService = GameCacheService();

  Future<List<Game>> fetchAllGames(
    leagueId,
    bool onlyThisLeague, {
    bool onlyTodayGames = false,
    DateTime? selectedDate,
  }) async {
    List<int> leagueIds =
        onlyThisLeague ? [leagueId] : [2, 3, 383, 140, 39, 848];
    List<Game> allGames = [];

    // First check for any cached data for these leagues
    bool hasLiveGames = false;

    // Try to get games from cache for each league
    for (int id in leagueIds) {
      final cachedGames = await _cacheService.getCachedGames(id, selectedDate);
      if (cachedGames != null) {
        // If we have cached games, check if any are live
        if (_cacheService.hasLiveGames(cachedGames)) {
          print(
              '⚡ Found live games in league $id - will fetch fresh data for all leagues');
          hasLiveGames = true;
          break; // If any league has live games, we'll fetch fresh data for all
        }
        allGames.addAll(cachedGames);
      } else {
        // If we don't have cache for any league, we need to fetch fresh data
        print('🔍 No cache available for league $id - will fetch fresh data');
        hasLiveGames = true;
        break;
      }
    }

    // If we have complete cached data and no live games, use it
    if (!hasLiveGames &&
        allGames.isNotEmpty &&
        allGames.length >= leagueIds.length) {
      print('📦 Using cached data for all leagues - no live games detected');
      allGames.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      return allGames;
    }

    // Otherwise fetch fresh data
    print('🔄 Fetching fresh data for all leagues');
    allGames.clear();
    for (int id in leagueIds) {
      final games = await _fetchGamesForLeague(
        id,
        onlyTodayGames: onlyTodayGames,
        selectedDate: selectedDate,
      );

      // Cache the fetched games
      await _cacheService.cacheGames(games, id, selectedDate);

      allGames.addAll(games);
    }

    allGames.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return allGames;
  }

  Future<List<Game>> fetchGamesForLeague(
    int leagueId, {
    bool onlyTodayGames = false,
    DateTime? selectedDate,
  }) async {
    // Try to get games from cache first
    final cachedGames =
        await _cacheService.getCachedGames(leagueId, selectedDate);

    // If we have cached games and none are live, use the cache
    if (cachedGames != null && !_cacheService.hasLiveGames(cachedGames)) {
      print('📦 Using cached data for league $leagueId');
      return cachedGames;
    }

    // Otherwise fetch fresh data
    print('🔄 Fetching fresh data for league $leagueId');
    final games = await _fetchGamesForLeague(
      leagueId,
      onlyTodayGames: onlyTodayGames,
      selectedDate: selectedDate,
    );

    // Cache the fetched games
    await _cacheService.cacheGames(games, leagueId, selectedDate);

    return games;
  }

  Future<List<Game>> _fetchGamesForLeague(
    int leagueId, {
    bool onlyTodayGames = false,
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
            final gameDate =
                DateTime(game.date.year, game.date.month, game.date.day);
            isToday = gameDate.isAtSameMomentAs(today);
          }

          // Additional filter logic for specific league IDs
          if (leagueId == 2 || leagueId == 848 || leagueId == 3) {
            return isNotPostponedOrTBD &&
                ((hasOdds &&
                        !game.league.round.contains("Qualifying") &&
                        game.league.round != "Play-offs" &&
                        // (!onlyTodayGames || isToday)) ||
                        (isSelectedDate)) ||
                    (isFinished &&
                        !game.league.round.contains("Qualifying") &&
                        game.league.round != "Play-offs" &&
                        // (!onlyTodayGames || isToday)));
                        (isSelectedDate)));
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

  // Method to force refresh data - useful for manual refresh
  Future<List<Game>> forceRefreshGames(int leagueId,
      {bool onlyTodayGames = false, DateTime? selectedDate}) async {
    print('🔄 Force refreshing data for league $leagueId');
    final games = await _fetchGamesForLeague(leagueId,
        onlyTodayGames: onlyTodayGames, selectedDate: selectedDate);

    // Update cache with fresh data
    await _cacheService.cacheGames(games, leagueId, selectedDate);

    return games;
  }

  // Helper method to check if any games are currently live
  Future<bool> hasLiveGames(int leagueId, {DateTime? selectedDate}) async {
    final games =
        await fetchGamesForLeague(leagueId, selectedDate: selectedDate);
    return _cacheService.hasLiveGames(games);
  }
}
