import 'dart:convert';
import 'package:football/models/games.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GameCacheService {
  static const String _cacheKeyPrefix = 'games_cache_';
  static const String _cacheTimestampPrefix = 'games_timestamp_';

  // Cache expiration durations in milliseconds
  static const int _finishedGamesCacheDuration =
      24 * 60 * 60 * 1000; // 24 hours
  static const int _upcomingGamesCacheDuration = 30 * 60 * 1000; // 30 minutes

  // Store games in cache by league and date
  Future<void> cacheGames(
      List<Game> games, int leagueId, DateTime? date) async {
    if (games.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _generateCacheKey(leagueId, date);

    // Convert games to JSON
    final gamesJson = jsonEncode(games.map((game) => game.toJson()).toList());

    // Store games and timestamp
    await prefs.setString(cacheKey, gamesJson);
    await prefs.setInt('$_cacheTimestampPrefix$cacheKey',
        DateTime.now().millisecondsSinceEpoch);

    print(
        '💾 Cached ${games.length} games for league $leagueId${date != null ? " on ${date.day}/${date.month}" : ""}');
  }

  // Get cached games if available and valid
  Future<List<Game>?> getCachedGames(int leagueId, DateTime? date) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _generateCacheKey(leagueId, date);

    final cachedData = prefs.getString(cacheKey);
    if (cachedData == null) {
      print(
          '🔍 No cache found for league $leagueId${date != null ? " on ${date.day}/${date.month}" : ""}');
      return null;
    }

    final timestamp = prefs.getInt('$_cacheTimestampPrefix$cacheKey');
    if (timestamp == null) {
      print('⚠️ Cache timestamp missing for league $leagueId');
      return null;
    }

    // Parse the cached games
    final List<dynamic> gamesJson = jsonDecode(cachedData);
    final games = gamesJson.map((json) => Game.fromJson(json)).toList();

    // Check if cache is valid based on game status
    if (!_isCacheValid(games, timestamp)) {
      print('⌛ Cache expired or invalid for league $leagueId');
      return null;
    }

    final age = DateTime.now().millisecondsSinceEpoch - timestamp;
    print(
        '📦 Found valid cache for league $leagueId with ${games.length} games (${(age / 60000).toStringAsFixed(1)} min old)');
    return games;
  }

  // Check if there are any live games in the list
  bool hasLiveGames(List<Game> games) {
    final hasLive = games.any((game) =>
        game.status.short == '1H' ||
        game.status.short == '2H' ||
        game.status.short == 'HT' ||
        game.status.short == 'ET' ||
        game.status.short == 'BT' ||
        game.status.short == 'P' ||
        game.status.short == 'INT');

    if (hasLive) {
      final liveGames = games
          .where((game) =>
              game.status.short == '1H' ||
              game.status.short == '2H' ||
              game.status.short == 'HT' ||
              game.status.short == 'ET' ||
              game.status.short == 'BT' ||
              game.status.short == 'P' ||
              game.status.short == 'INT')
          .toList();

      print('⚽ Found ${liveGames.length} live games');
      for (final game in liveGames) {
        print(
            '   🎮 ${game.home.name} vs ${game.away.name} - ${game.status.short} ${game.status.elapsed ?? 0}\'');
      }
    }

    return hasLive;
  }

  // Check if cache is still valid based on game status and timestamp
  bool _isCacheValid(List<Game> games, int timestamp) {
    final now = DateTime.now().millisecondsSinceEpoch;

    // If any game is live, cache is invalid
    if (hasLiveGames(games)) return false;

    // If all games are finished, use longer cache duration
    if (games.every((game) => game.status.long == "Match Finished")) {
      final isValid = now - timestamp < _finishedGamesCacheDuration;
      if (!isValid) {
        print(
            '⌛ Cache for finished games expired (${((now - timestamp) / 60000).toStringAsFixed(1)} min old)');
      }
      return isValid;
    }

    // For upcoming games, use shorter cache duration
    final isValid = now - timestamp < _upcomingGamesCacheDuration;
    if (!isValid) {
      print(
          '⌛ Cache for upcoming games expired (${((now - timestamp) / 60000).toStringAsFixed(1)} min old)');
    }
    return isValid;
  }

  // Generate a unique cache key based on league and date
  String _generateCacheKey(int leagueId, DateTime? date) {
    if (date == null) {
      return '$_cacheKeyPrefix${leagueId}_all';
    }
    return '$_cacheKeyPrefix${leagueId}_${date.year}_${date.month}_${date.day}';
  }

  // Clear all cached games
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    for (final key in keys) {
      if (key.startsWith(_cacheKeyPrefix) ||
          key.startsWith(_cacheTimestampPrefix)) {
        await prefs.remove(key);
      }
    }
  }
}
