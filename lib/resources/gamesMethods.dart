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
    // If only fetching a specific league, use the regular method
    if (onlyThisLeague) {
      print('🔍 Fetching games for single league $leagueId only');
      return await fetchGamesForLeague(leagueId,
          onlyTodayGames: onlyTodayGames, selectedDate: selectedDate);
    }

    List<int> allLeagueIds = [2, 3, 383, 140, 39, 848];
    List<Game> allGames = [];
    List<int> leaguesToFetch = [];

    // If a date is specified, try to use the master cache to know which leagues have games
    if (selectedDate != null) {
      // Try to get the list of leagues that have games on this date from master cache
      List<int> leaguesWithGames =
          await _cacheService.getLeaguesWithGames(selectedDate);

      if (leaguesWithGames.isNotEmpty) {
        // We have information about which leagues have games
        print(
            '📋 Using master cache - only checking leagues with games: ${leaguesWithGames.join(', ')}');

        // Only check these leagues
        List<int> leaguesToCheck =
            leaguesWithGames.where((id) => allLeagueIds.contains(id)).toList();

        // Parallelize cache checks
        print('🔍 Searching cache for leagues: ${leaguesToCheck.join(', ')}');
        final cacheResults = await Future.wait(leaguesToCheck.map((id) async {
          final cachedGames =
              await _cacheService.getCachedGames(id, selectedDate);
          return MapEntry(id, cachedGames);
        }));

        for (var entry in cacheResults) {
          final id = entry.key;
          final cachedGames = entry.value;

          if (cachedGames != null) {
            // If we have cached games, check if any are live
            if (_cacheService.hasLiveGames(cachedGames)) {
              print(
                  '⚡ Found live games in league $id - will fetch fresh data for this league');
              leaguesToFetch.add(id);
            } else {
              // Use the cached games if they're valid and not live
              print('✅ Using cached games for league $id');
              allGames.addAll(cachedGames);
            }
          } else {
            // If we don't have cache for this specific league, add it to leagues to fetch
            print(
                '🔍 No cache available for league $id - will fetch fresh data for this league only');
            leaguesToFetch.add(id);
          }
        }
      } else {
        // No master cache, so we don't know which leagues have games
        // We'll do a full check on the first league, then use its results to update master cache
        print(
            '🔍 No master cache available - checking first league to build master cache');

        // Try the first league
        final firstLeagueGames = await _fetchGamesForLeague(allLeagueIds[0],
            onlyTodayGames: onlyTodayGames, selectedDate: selectedDate);

        // Cache the results
        await _cacheService.cacheGames(
            firstLeagueGames, allLeagueIds[0], selectedDate);
        allGames.addAll(firstLeagueGames);

        // Now check the rest of the leagues normally
        leaguesToFetch = allLeagueIds.sublist(1);
      }
    } else {
      // No date specified, can't use master cache optimization
      // Instead of a single flag, track which leagues need fresh data
      print('📅 No date filter specified - checking all leagues individually');

      // Parallelize cache checks for all leagues
      print('🔍 Searching cache for all leagues');
      final cacheResults = await Future.wait(allLeagueIds.map((id) async {
        final cachedGames =
            await _cacheService.getCachedGames(id, selectedDate);
        return MapEntry(id, cachedGames);
      }));

      for (var entry in cacheResults) {
        final id = entry.key;
        final cachedGames = entry.value;

        if (cachedGames != null) {
          // If we have cached games, check if any are live
          if (_cacheService.hasLiveGames(cachedGames)) {
            print(
                '⚡ Found live games in league $id - will fetch fresh data for this league');
            leaguesToFetch.add(id);
          } else {
            // Use the cached games if they're valid and not live
            print('✅ Using cached games for league $id');
            allGames.addAll(cachedGames);
          }
        } else {
          // If we don't have cache for this specific league, add it to leagues to fetch
          print(
              '🔍 No cache available for league $id - will fetch fresh data for this league only');
          leaguesToFetch.add(id);
        }
      }
    }

    // Fetch fresh data only for leagues that need it
    if (leaguesToFetch.isNotEmpty) {
      print('🔄 Fetching fresh data for leagues: ${leaguesToFetch.join(', ')}');
      
      // Parallelize fetching fresh data
      final fetchedGamesList = await Future.wait(leaguesToFetch.map((id) async {
        final games = await _fetchGamesForLeague(
          id,
          onlyTodayGames: onlyTodayGames,
          selectedDate: selectedDate,
        );
        
        // Cache the fetched games
        await _cacheService.cacheGames(games, id, selectedDate);
        
        return games;
      }));

      for (var games in fetchedGamesList) {
        allGames.addAll(games);
      }
    }

    // Sort all games by timestamp regardless of source
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
if(leagueId == -1){
      print('⚠️ Invalid league ID: $leagueId');
      return [];

}

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
