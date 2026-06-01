import 'dart:async';
import 'dart:convert';

import 'package:football/utils/config.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Source of truth for which leagues the app fetches/offers AND their display
// names. Both come from the backend (GET /api/config/leagues) so a new league
// can be added by season — id + EN/HE name — without shipping an app update.
// This intentionally does NOT touch the per-user chosenLeagues preference; it
// only decides the universe of leagues (and their labels) the filter runs on.
class LeagueConfigService {
  static final LeagueConfigService _instance =
      LeagueConfigService._internal();
  factory LeagueConfigService() => _instance;
  LeagueConfigService._internal();

  // Baked-in fallback used on a fresh install before the first successful
  // fetch, and any time network/cache is unavailable. Never empty. Names for
  // these known ids resolve via the app's existing localization fallback, so
  // only ids are needed here.
  static const List<int> _defaultLeagues = [2, 383, 140, 3, 39, 78, 848];

  static const String _prefsKey = 'supported_leagues_cache_v2';

  // Always non-empty. Order preserved as configured.
  List<int> supportedLeagues = List<int>.from(_defaultLeagues);

  // id -> { 'en': ..., 'he': ... }. Empty until cache/network populates it.
  final Map<int, Map<String, String>> _names = {};

  // Ids flagged hasBracket:true in the backend config — tournament leagues that
  // offer the bracket-prediction game on top of per-game guessing.
  final Set<int> _bracketLeagues = {};

  Future<void> initialize() async {
    // 1. Last-known-good cache first, so an offline launch still gets the most
    //    recent list/names instead of the (possibly stale) compiled defaults.
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_prefsKey);
      if (cached != null) _apply(jsonDecode(cached));
    } catch (e) {
      print('⚠️ LeagueConfig: cache read failed: $e');
    }

    // 2. Refresh from backend. Any failure keeps the cached/default state.
    try {
      final res = await http
          .get(Uri.parse('$backendUrl/api/config/leagues'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        print('⚠️ LeagueConfig: HTTP ${res.statusCode}, keeping current list');
        return;
      }
      final body = jsonDecode(res.body);
      final raw = body['leagues'];
      if (_apply(raw)) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_prefsKey, jsonEncode(raw));
        print('🏆 LeagueConfig updated: $supportedLeagues');
      } else {
        print('⚠️ LeagueConfig: empty/invalid payload, keeping current list');
      }
    } catch (e) {
      print('⚠️ LeagueConfig: fetch failed, keeping current list: $e');
    }
  }

  // Localized league name from the backend config, or null if this id has no
  // configured name (caller should fall back to its existing localization).
  // [langCode] is the active locale code, e.g. 'he' or 'en'.
  String? nameFor(int id, String langCode) {
    final n = _names[id];
    if (n == null) return null;
    final primary = langCode == 'he' ? n['he'] : n['en'];
    if (primary != null && primary.trim().isNotEmpty) return primary;
    // One language missing — fall back to whichever is present.
    final other = langCode == 'he' ? n['en'] : n['he'];
    if (other != null && other.trim().isNotEmpty) return other;
    return null;
  }

  // True if this league offers the tournament bracket game (hasBracket in the
  // backend config). False for ordinary leagues and before config loads.
  bool hasBracket(int id) => _bracketLeagues.contains(id);

  // Parses the server shape [{id,nameEn,nameHe}, ...] or a bare [2,383,...]
  // list (older cache form). Order preserved, dupes/invalid entries dropped.
  // Returns false if nothing usable was found (caller keeps current state).
  bool _apply(dynamic raw) {
    if (raw is! List) return false;
    final ids = <int>[];
    final names = <int, Map<String, String>>{};
    final brackets = <int>{};
    for (final item in raw) {
      int? id;
      String? en;
      String? he;
      bool bracket = false;
      if (item is int) {
        id = item;
      } else if (item is Map) {
        id = item['id'] is int ? item['id'] as int : int.tryParse('${item['id']}');
        final e = item['nameEn'];
        final h = item['nameHe'];
        if (e is String && e.trim().isNotEmpty) en = e.trim();
        if (h is String && h.trim().isNotEmpty) he = h.trim();
        bracket = item['hasBracket'] == true;
      }
      if (id == null || ids.contains(id)) continue;
      ids.add(id);
      if (bracket) brackets.add(id);
      if (en != null || he != null) {
        names[id] = {
          if (en != null) 'en': en,
          if (he != null) 'he': he,
        };
      }
    }
    if (ids.isEmpty) return false;
    supportedLeagues = ids;
    _names
      ..clear()
      ..addAll(names);
    _bracketLeagues
      ..clear()
      ..addAll(brackets);
    return true;
  }
}
