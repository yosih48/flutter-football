import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:football/utils/lineup_event_marks.dart' show playerMatchKey;

/// Curated Latin → Hebrew player-name map, loaded once from the bundled asset
/// `assets/player_names_he.json` (`{ "Franck Kessié": "פראנק קסייה", ... }`).
///
/// Keyed by initial+surname (via [playerMatchKey]) so a single entry matches
/// both the full lineup name ("Franck Kessié") and the abbreviated event name
/// ("F. Kessie"). Lookup is the curated layer in front of transliteration.
class PlayerNamesHe {
  static const _assetPath = 'assets/player_names_he.json';
  static final Map<String, String> _byKey = {};
  // Remote overrides from the backend (GET /api/config/playerNames), applied via
  // [applyRemote]. These WIN over the bundled asset, which stays the offline /
  // first-launch baseline — so a name can be added or fixed without an app
  // release. Keyed the same way (initial+surname via [playerMatchKey]).
  static final Map<String, String> _remoteByKey = {};
  static bool _loaded = false;

  static bool get isLoaded => _loaded;

  /// Merge a remote Latin→Hebrew map (raw, keyed by full name) on top of the
  /// bundled asset. Same Hebrew-only validation as the asset, so a malformed or
  /// blank entry is skipped rather than shadowing a good bundled one.
  static void applyRemote(Map<String, String> raw) {
    _remoteByKey.clear();
    raw.forEach((k, v) {
      final he = v.trim();
      if (he.isEmpty || !_looksHebrew(he)) return;
      final key = playerMatchKey(k);
      if (key.isNotEmpty) _remoteByKey[key] = he;
    });
  }

  /// Load and index the asset. Safe to call more than once (no-op after first).
  /// Call from main() before runApp so names resolve on first frame.
  static Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final decoded = json.decode(raw);
      if (decoded is Map) {
        decoded.forEach((k, v) {
          if (k is! String) return;
          if (v is! String) return;
          final he = v.trim();
          if (he.isEmpty || !_looksHebrew(he)) return; // skip blanks / garbled
          final key = playerMatchKey(k);
          if (key.isNotEmpty) _byKey[key] = he;
        });
      }
    } catch (_) {
      // Missing/corrupt asset → transliteration fallback still works.
    }
    _loaded = true;
  }

  /// Curated Hebrew name for [latinName], or null if not in the map. Remote
  /// overrides win over the bundled asset.
  static String? lookup(String latinName) {
    if (_byKey.isEmpty && _remoteByKey.isEmpty) return null;
    final key = playerMatchKey(latinName);
    return _remoteByKey[key] ?? _byKey[key];
  }

  // A valid entry must contain Hebrew letters and no Latin/CJK, which filters
  // out the occasional corrupt translation in the source file.
  static bool _looksHebrew(String s) {
    final hasHebrew = RegExp(r'[֐-׿]').hasMatch(s);
    final hasForeign = RegExp(r'[A-Za-z一-鿿]').hasMatch(s);
    return hasHebrew && !hasForeign;
  }
}
