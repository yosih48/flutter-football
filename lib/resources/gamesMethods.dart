import 'package:football/models/games.dart';
import 'package:football/utils/config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

    String _baseUrl = backendUrl;
class GamesMethods {
  final Duration _cacheDuration = Duration(hours: 2);
  final Duration _liveCacheCheckDuration = Duration(minutes: 5);



  Future<List<Game>> fetchAllGames(
    leagueId,
    bool onlyThisLeague, {
    bool onlyTodayGames = false,
    DateTime? selectedDate,
  }) async {
    return _fetchAllGamesWithCache(leagueId, onlyThisLeague,
        onlyTodayGames: onlyTodayGames,
        selectedDate: selectedDate,
        forceRefresh: false);
  }

  // Internal implementation with caching
  Future<List<Game>> _fetchAllGamesWithCache(
    leagueId,
    bool onlyThisLeague, {
    bool onlyTodayGames = false,
    DateTime? selectedDate,
    bool forceRefresh = false,
  }) async {
    List<int> leagueIds = onlyThisLeague ? [leagueId] : [2, 3, 383, 140];
    List<Game> allGames = [];

    for (int leagueId in leagueIds) {
      final games = await _fetchGamesForLeagueWithCache(
        leagueId,
        onlyTodayGames: onlyTodayGames,
        selectedDate: selectedDate,
        forceRefresh: forceRefresh,
      );
      allGames.addAll(games);
    }

    allGames.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return allGames;
  }

  // Keep this method signature the same as your original code
  Future<List<Game>> fetchGamesForLeague(
    int leagueId, {
    bool onlyTodayGames = false,
    DateTime? selectedDate,
  }) async {
    return _fetchGamesForLeagueWithCache(
      leagueId,
      onlyTodayGames: onlyTodayGames,
      selectedDate: selectedDate,
      forceRefresh: false,
    );
  }

  // Internal implementation with caching
  Future<List<Game>> _fetchGamesForLeagueWithCache(
    int leagueId, {
    bool onlyTodayGames = false,
    DateTime? selectedDate,
    bool forceRefresh = false,
  }) async {
    // Create a cache key based on parameters
    final String cacheKey =
        'games_${leagueId}_${onlyTodayGames}_${selectedDate?.toIso8601String() ?? 'null'}';

    // First, check if we have fresh cache data
    final cachedData = forceRefresh ? null : await _getCachedData(cacheKey);

    // If we have cached data, check if any games are live using that cached data
    bool hasLiveGames = false;
    if (cachedData != null) {
      hasLiveGames = _checkForLiveGamesFromCache(cachedData);

      // If no live games are happening, we can safely use the cached data
      if (!hasLiveGames) {
        return cachedData;
      }
    }

    // If we don't have cached data or live games are detected, fetch fresh data
    final freshData =
        await _fetchFreshData(leagueId, onlyTodayGames, selectedDate);

    // Save the fresh data to cache
    await _saveDataToCache(cacheKey, freshData);

    return freshData;
  }

  // Original method implementation unchanged
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
                        isSelectedDate) ||
                    (isFinished &&
                        !game.league.round.contains("Qualifying") &&
                        game.league.round != "Play-offs" &&
                        isSelectedDate));
          }

          return isNotPostponedOrTBD &&
              (hasOdds || isFinished) &&
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

  bool _checkForLiveGamesFromCache(List<Game> games) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return games.any((game) {
      // Check if the game is today
      final gameDate = DateTime(game.date.year, game.date.month, game.date.day);
      bool isToday = gameDate.isAtSameMomentAs(today);

      // Check if the game is in progress based on status
      bool isLive = game.status.short == "1H" ||
          game.status.short == "2H" ||
          game.status.short == "HT" ||
          game.status.short == "ET" ||
          game.status.short == "P" ||
          game.status.short == "BT";

      return isToday && isLive;
    });
  }

  Future<List<Game>?> _getCachedData(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check if we have cache data and it's not expired
      final cacheTimestampKey = '${key}_timestamp';
      final cacheDataKey = key;

      final cacheTimestamp = prefs.getInt(cacheTimestampKey);
      final cacheData = prefs.getString(cacheDataKey);

      if (cacheTimestamp != null && cacheData != null) {
        final cachedTime = DateTime.fromMillisecondsSinceEpoch(cacheTimestamp);
        final now = DateTime.now();

        // If cache has not expired, return the cached data
        if (now.difference(cachedTime) < _cacheDuration) {
          final List<dynamic> decodedData = jsonDecode(cacheData);
          return decodedData.map((item) => Game.fromJson(item)).toList();
        }
      }
    } catch (e) {
      print('Error getting cached data: $e');
    }

    return null;
  }

  Future<void> _saveDataToCache(String key, List<Game> games) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save timestamp and data
      await prefs.setInt(
          '${key}_timestamp', DateTime.now().millisecondsSinceEpoch);

      // Convert games to json and save
      final gamesList = games.map((game) => game.toJson()).toList();
      await prefs.setString(key, jsonEncode(gamesList));
    } catch (e) {
      print('Error saving data to cache: $e');
    }
  }

  Future<List<Game>> _fetchFreshData(
      int leagueId, bool onlyTodayGames, DateTime? selectedDate) async {
    // This just calls your original implementation
    return _fetchGamesForLeague(leagueId,
        onlyTodayGames: onlyTodayGames, selectedDate: selectedDate);
  }

  // Public method to force refresh the data
  Future<List<Game>> forceRefreshGames(
    int leagueId,
    bool onlyThisLeague, {
    bool onlyTodayGames = false,
    DateTime? selectedDate,
  }) async {
    return _fetchAllGamesWithCache(leagueId, onlyThisLeague,
        onlyTodayGames: onlyTodayGames,
        selectedDate: selectedDate,
        forceRefresh: true);
  }

  // Public method to clear all cache
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys =
          prefs.getKeys().where((key) => key.startsWith('games_')).toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }
}
