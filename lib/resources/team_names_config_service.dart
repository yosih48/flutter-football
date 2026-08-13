import 'dart:convert';

import 'package:football/utils/config.dart';
import 'package:football/utils/localized_team_name.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Source of truth for Hebrew team-name display strings is the backend
// (GET /api/config/teamNames, backed by src/utils/teamNamesHe.js — the same
// map the server uses for push-notification copy). The app caches the map and
// applies it as DISPLAY-ONLY overrides on top of the compiled baseline in
// lib/utils/localized_team_name.dart, so a name can be added or corrected
// without shipping an app update, and both sides never drift from a hand-copied
// list. The raw English name still flows through navigation/links/matching —
// this only changes what a `Text(...)` renders in Hebrew.
class TeamNamesConfigService {
  static final TeamNamesConfigService _instance =
      TeamNamesConfigService._internal();
  factory TeamNamesConfigService() => _instance;
  TeamNamesConfigService._internal();

  static const String _prefsNamesKey = 'team_names_he_cache_v1';
  static const String _prefsVersionKey = 'team_names_he_version_v1';

  Future<void> initialize() async {
    // 1. Apply last-known-good cache first so an offline launch localizes with
    //    the most recent names rather than only the compiled baseline.
    String? cachedVersion;
    try {
      final prefs = await SharedPreferences.getInstance();
      cachedVersion = prefs.getString(_prefsVersionKey);
      final cached = prefs.getString(_prefsNamesKey);
      if (cached != null) {
        final map = _asStringMap(jsonDecode(cached));
        if (map.isNotEmpty) applyRemoteTeamNames(map);
      }
    } catch (e) {
      print('⚠️ TeamNames: cache read failed: $e');
    }

    // 2. Refresh from backend. Any failure keeps the cached/baseline state.
    try {
      final res = await http
          .get(Uri.parse('$backendUrl/api/config/teamNames'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        print('⚠️ TeamNames: HTTP ${res.statusCode}, keeping current names');
        return;
      }
      final body = jsonDecode(res.body);
      final version = body['version']?.toString();
      // Version unchanged → cache already applied above, skip re-parsing/writing.
      if (version != null && version == cachedVersion) return;

      final map = _asStringMap(body['teamNames']);
      if (map.isEmpty) {
        print('⚠️ TeamNames: empty/invalid payload, keeping current names');
        return;
      }
      applyRemoteTeamNames(map);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsNamesKey, jsonEncode(map));
      if (version != null) {
        await prefs.setString(_prefsVersionKey, version);
      } else {
        await prefs.remove(_prefsVersionKey);
      }
      print('🏳️ TeamNames updated: ${map.length} entries (v$version)');
    } catch (e) {
      print('⚠️ TeamNames: fetch failed, keeping current names: $e');
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
