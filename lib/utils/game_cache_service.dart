import 'dart:convert';
import 'package:football/models/games.dart';
import 'package:football/resources/league_config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GameCacheService {
  static const String _cacheKeyPrefix = 'games_cache_';
  static const String _cacheTimestampPrefix = 'games_timestamp_';
  static const String _masterCacheKey = 'leagues_with_games_';
  static const String _lastDailyResetKey = 'games_last_daily_reset';

  // Short stable token derived from the current supported-leagues list. Baked
  // into every cache key so that adding/removing a league via the backend
  // config naturally invalidates the old keys — lookups miss with the new
  // fingerprint and a fresh fetch repopulates. The previous-fingerprint
  // entries linger in SharedPreferences until the daily noon reset clears
  // them, which is fine (bounded to one day of stale rows).
  String _leaguesFingerprint() {
    final ids = List<int>.from(LeagueConfigService().supportedLeagues)..sort();
    return ids.join('-').hashCode.toRadixString(36);
  }

  // Cache expiration durations in milliseconds
  static const int _finishedGamesCacheDuration =
      24 * 60 * 60 * 1000; // 24 hours
  static const int _upcomingGamesCacheDuration = 7 * 60 * 1000; // 15 minutes
  static const int _masterCacheDuration = 6 * 60 * 60 * 1000; // 6 hours

  // Store games in cache by league and date
  Future<void> cacheGames(
      List<Game> games, int leagueId, DateTime? date) async {
    await _performDailyResetIfNeeded(); // ✅ Daily reset check

    if (games.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _generateCacheKey(leagueId, date);

    // Convert games to JSON
    final gamesJson = jsonEncode(games.map((game) => game.toJson()).toList());

    // Store games and timestamp
    await prefs.setString(cacheKey, gamesJson);
    await prefs.setInt('$_cacheTimestampPrefix$cacheKey',
        DateTime.now().millisecondsSinceEpoch);

    // Update the master cache to indicate this league has games on this date
    await _updateMasterCache(leagueId, date, games.isNotEmpty);

    print(
        '💾 Cached ${games.length} games for league $leagueId${date != null ? " on ${date.day}/${date.month}" : ""}');
  }

  // Update master cache of leagues with games for a specific date
  Future<void> _updateMasterCache(
      int leagueId, DateTime? date, bool hasGames) async {
    if (date == null) return; // Only track by specific dates

    final prefs = await SharedPreferences.getInstance();
    final masterKey = _masterKey(date);

    // Get existing data
    final existingData = prefs.getString(masterKey);
    Map<String, dynamic> leaguesWithGames = {};

    if (existingData != null) {
      leaguesWithGames = Map<String, dynamic>.from(jsonDecode(existingData));
    }

    // Update the entry for this league
    leaguesWithGames[leagueId.toString()] = hasGames;

    // Save back to cache with timestamp
    await prefs.setString(masterKey, jsonEncode(leaguesWithGames));
    await prefs.setInt('${_cacheTimestampPrefix}$masterKey',
        DateTime.now().millisecondsSinceEpoch);
  }

  // Get a list of leagues that have games on a specific date
  Future<List<int>> getLeaguesWithGames(DateTime date) async {
    await _performDailyResetIfNeeded(); // ✅ Daily reset check

    final prefs = await SharedPreferences.getInstance();
    final masterKey = _masterKey(date);

    // Check if master cache exists and is valid
    final existingData = prefs.getString(masterKey);
    final timestamp = prefs.getInt('${_cacheTimestampPrefix}$masterKey');

    if (existingData == null || timestamp == null) {
      print('🔍 No master cache found for ${date.day}/${date.month}');
      return []; // No cache data
    }

    // Check if cache is still valid
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - timestamp > _masterCacheDuration) {
      print('⌛ Master cache expired for ${date.day}/${date.month}');
      return []; // Expired cache
    }

    // Parse and filter leagues that have games
    final Map<String, dynamic> leaguesData = jsonDecode(existingData);
    final List<int> leaguesWithGames = leaguesData.entries
        .where((entry) => entry.value == true)
        .map((entry) => int.parse(entry.key))
        .toList();

    print(
        '📋 Found ${leaguesWithGames.length} leagues with games on ${date.day}/${date.month}: ${leaguesWithGames.join(', ')}');
    return leaguesWithGames;
  }

  // Get cached games if available and valid
  Future<List<Game>?> getCachedGames(int leagueId, DateTime? date) async {
    await _performDailyResetIfNeeded(); // ✅ Daily reset check

    final prefs = await SharedPreferences.getInstance();
    final cacheKey = _generateCacheKey(leagueId, date);

    final cachedData = prefs.getString(cacheKey);
    if (cachedData == null) {
      print(
          '🔍 No cache found for league $leagueId${date != null ? " on ${date.day}/${date.month}" : ""}');
      return null;
    }

    print(
        '🔍 Cache found for league $leagueId${date != null ? " on ${date.day}/${date.month}" : ""}');

    final timestamp = prefs.getInt('$_cacheTimestampPrefix$cacheKey');
    if (timestamp == null) {
      print('⚠️ Cache timestamp missing for league $leagueId');
      return null;
    }

    // Parse the cached games
    try {
      print('📝 Parsing cached JSON for league $leagueId (${cachedData.length} bytes)...');
      final List<dynamic> gamesJson = jsonDecode(cachedData);
      print('📝 JSON parsed, converting ${gamesJson.length} items to Game objects...');
      final games = gamesJson.map((json) => Game.fromJson(json)).toList();
      print('✅ Cache parsed successfully: ${games.length} games');

      // Check if cache is valid based on game status
      if (!_isCacheValid(games, timestamp)) {
        print('⌛ Cache expired or invalid for league $leagueId');
        return null;
      }

      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      print(
          '📦 Found valid cache for league $leagueId with ${games.length} games (${(age / 60000).toStringAsFixed(1)} min old)');
      return games;
    } catch (e, stackTrace) {
      print('❌ Error parsing cached data for league $leagueId: $e');
      print('Stack: $stackTrace');
      return null;
    }
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

  // Generate a unique cache key based on league, date, and the current
  // supported-leagues fingerprint.
  String _generateCacheKey(int leagueId, DateTime? date) {
    final fp = _leaguesFingerprint();
    if (date == null) {
      return '$_cacheKeyPrefix${leagueId}_all_$fp';
    }
    return '$_cacheKeyPrefix${leagueId}_${date.year}_${date.month}_${date.day}_$fp';
  }

  String _masterKey(DateTime date) {
    final fp = _leaguesFingerprint();
    return '$_masterCacheKey${date.year}_${date.month}_${date.day}_$fp';
  }

  // Get cached games for a specific date across ALL leagues (ignores expiry)
  // Used when scrolling up to view past games from cache
  Future<List<Game>> getCachedGamesForDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final allLeagues = LeagueConfigService().supportedLeagues;
    List<Game> allGames = [];
    final existingIds = <int>{};

    for (final leagueId in allLeagues) {
      final cacheKey = _generateCacheKey(leagueId, date);
      final cachedData = prefs.getString(cacheKey);
      if (cachedData == null) continue;

      try {
        final List<dynamic> gamesJson = jsonDecode(cachedData);
        final games = gamesJson.map((json) => Game.fromJson(json)).toList();
        // Filter to only include games on the requested date
        final dateStart = DateTime(date.year, date.month, date.day);
        final dateEnd = dateStart.add(Duration(days: 1));
        final gamesForDate = games.where((g) =>
            !g.date.isBefore(dateStart) && g.date.isBefore(dateEnd)).toList();
        for (final g in gamesForDate) {
          if (!existingIds.contains(g.fixtureId)) {
            existingIds.add(g.fixtureId);
            allGames.add(g);
          }
        }
      } catch (e) {
        print('❌ Error reading cache for league $leagueId on ${date.day}/${date.month}: $e');
      }
    }

    // Also try the "all" cache key (no date) and filter
    for (final leagueId in allLeagues) {
      final cacheKey = _generateCacheKey(leagueId, null);
      final cachedData = prefs.getString(cacheKey);
      if (cachedData == null) continue;

      try {
        final List<dynamic> gamesJson = jsonDecode(cachedData);
        final games = gamesJson.map((json) => Game.fromJson(json)).toList();
        final dateStart = DateTime(date.year, date.month, date.day);
        final dateEnd = dateStart.add(Duration(days: 1));
        final gamesForDate = games.where((g) =>
            !g.date.isBefore(dateStart) && g.date.isBefore(dateEnd)).toList();
        for (final g in gamesForDate) {
          if (!existingIds.contains(g.fixtureId)) {
            existingIds.add(g.fixtureId);
            allGames.add(g);
          }
        }
      } catch (e) {
        // ignore
      }
    }

    allGames.sort((a, b) => a.date.compareTo(b.date));
    print('📦 getCachedGamesForDate: found ${allGames.length} games for ${date.day}/${date.month}');
    return allGames;
  }

  // Clear all cached games
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    for (final key in keys) {
      if (key.startsWith(_cacheKeyPrefix) ||
          key.startsWith(_cacheTimestampPrefix) ||
          key.startsWith(_masterCacheKey)) {
        await prefs.remove(key);
      }
    }
  }

  // ✅ Daily reset checker — clears cache once after 12:00 PM each day
  Future<void> _performDailyResetIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();

    final todayAtNoon = DateTime(now.year, now.month, now.day, 12, 0);

    final lastResetMillis = prefs.getInt(_lastDailyResetKey);
    final lastReset = lastResetMillis != null
        ? DateTime.fromMillisecondsSinceEpoch(lastResetMillis)
        : null;

    if (lastReset == null || lastReset.isBefore(todayAtNoon)) {
      print('🔁 Daily cache reset triggered');
      await clearCache();
      await prefs.setInt(_lastDailyResetKey, now.millisecondsSinceEpoch);
    }
  }
}
