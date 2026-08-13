import 'dart:convert';

import 'package:football/utils/config.dart';
import 'package:football/utils/localized_stat_label.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Source of truth for Hebrew fixture-stat labels is the backend
// (GET /api/config/statLabels, backed by src/utils/statLabelsHe.js). The app
// caches the map and applies it as DISPLAY-ONLY overrides on top of the compiled
// baseline in lib/utils/localized_stat_label.dart, so a label can be added or
// corrected without shipping an app update. The raw English `stat.type` still
// flows through matching/keying — this only changes what a `Text(...)` renders.
class StatLabelsConfigService {
  static final StatLabelsConfigService _instance =
      StatLabelsConfigService._internal();
  factory StatLabelsConfigService() => _instance;
  StatLabelsConfigService._internal();

  static const String _prefsLabelsKey = 'stat_labels_he_cache_v1';
  static const String _prefsVersionKey = 'stat_labels_he_version_v1';

  Future<void> initialize() async {
    // 1. Apply last-known-good cache first so an offline launch localizes with
    //    the most recent labels rather than only the compiled baseline.
    String? cachedVersion;
    try {
      final prefs = await SharedPreferences.getInstance();
      cachedVersion = prefs.getString(_prefsVersionKey);
      final cached = prefs.getString(_prefsLabelsKey);
      if (cached != null) {
        final map = _asStringMap(jsonDecode(cached));
        if (map.isNotEmpty) applyRemoteStatLabels(map);
      }
    } catch (e) {
      print('⚠️ StatLabels: cache read failed: $e');
    }

    // 2. Refresh from backend. Any failure keeps the cached/baseline state.
    try {
      final res = await http
          .get(Uri.parse('$backendUrl/api/config/statLabels'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        print('⚠️ StatLabels: HTTP ${res.statusCode}, keeping current labels');
        return;
      }
      final body = jsonDecode(res.body);
      final version = body['version']?.toString();
      // Version unchanged → cache already applied above, skip re-parsing/writing.
      if (version != null && version == cachedVersion) return;

      final map = _asStringMap(body['statLabels']);
      if (map.isEmpty) {
        print('⚠️ StatLabels: empty/invalid payload, keeping current labels');
        return;
      }
      applyRemoteStatLabels(map);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsLabelsKey, jsonEncode(map));
      if (version != null) {
        await prefs.setString(_prefsVersionKey, version);
      } else {
        await prefs.remove(_prefsVersionKey);
      }
      print('📊 StatLabels updated: ${map.length} entries (v$version)');
    } catch (e) {
      print('⚠️ StatLabels: fetch failed, keeping current labels: $e');
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
