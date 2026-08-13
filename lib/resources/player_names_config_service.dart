import 'dart:convert';

import 'package:football/utils/config.dart';
import 'package:football/utils/player_names_he.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Source of truth for Hebrew player-name display strings is the backend
// (GET /api/config/playerNames, backed by src/utils/playerNamesHe.js — the same
// map the server uses for push-notification copy). The app caches the map and
// applies it as overrides on top of the bundled assets/player_names_he.json
// baseline, so a name can be added or corrected without an app update and both
// sides never drift from a hand-copied file.
//
// The map is large (~3k entries, ~140KB), so we cache a `version` and send it
// as `?v=` on refresh: an unchanged launch gets a tiny {unchanged:true} reply
// instead of re-downloading the whole map.
class PlayerNamesConfigService {
  static final PlayerNamesConfigService _instance =
      PlayerNamesConfigService._internal();
  factory PlayerNamesConfigService() => _instance;
  PlayerNamesConfigService._internal();

  static const String _prefsNamesKey = 'player_names_he_cache_v1';
  static const String _prefsVersionKey = 'player_names_he_version_v1';

  Future<void> initialize() async {
    // 1. Apply last-known-good cache first so an offline launch resolves with
    //    the most recent names rather than only the bundled asset.
    String? cachedVersion;
    try {
      final prefs = await SharedPreferences.getInstance();
      cachedVersion = prefs.getString(_prefsVersionKey);
      final cached = prefs.getString(_prefsNamesKey);
      if (cached != null) {
        final map = _asStringMap(jsonDecode(cached));
        if (map.isNotEmpty) PlayerNamesHe.applyRemote(map);
      }
    } catch (e) {
      print('⚠️ PlayerNames: cache read failed: $e');
    }

    // 2. Refresh from backend, sending the cached version so an unchanged map
    //    isn't re-downloaded. Any failure keeps the cached/bundled state.
    try {
      final uri = Uri.parse('$backendUrl/api/config/playerNames').replace(
        queryParameters:
            cachedVersion != null ? {'v': cachedVersion} : null,
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        print('⚠️ PlayerNames: HTTP ${res.statusCode}, keeping current names');
        return;
      }
      final body = jsonDecode(res.body);
      // Server confirms our cached version is current — nothing to do.
      if (body['unchanged'] == true) return;

      final version = body['version']?.toString();
      final map = _asStringMap(body['playerNames']);
      if (map.isEmpty) {
        print('⚠️ PlayerNames: empty/invalid payload, keeping current names');
        return;
      }
      PlayerNamesHe.applyRemote(map);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsNamesKey, jsonEncode(map));
      if (version != null) {
        await prefs.setString(_prefsVersionKey, version);
      } else {
        await prefs.remove(_prefsVersionKey);
      }
      print('🧑 PlayerNames updated: ${map.length} entries (v$version)');
    } catch (e) {
      print('⚠️ PlayerNames: fetch failed, keeping current names: $e');
    }
  }

  // Coerce a decoded JSON object into a clean <String, String> map, dropping any
  // non-string values rather than throwing on a malformed payload.
  Map<String, String> _asStringMap(dynamic raw) {
    if (raw is! Map) return const {};
    final out = <String, String>{};
    raw.forEach((k, v) {
      if (v is String) out['$k'] = v;
    });
    return out;
  }
}
