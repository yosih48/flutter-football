import 'package:flutter/foundation.dart';
import 'package:football/utils/he_player_name.dart';
import 'package:football/utils/localized_team_name.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User choice — only meaningful while the app locale is Hebrew — of whether
/// team names and player names display in Hebrew or in their original name.
/// Two independent switches, each defaulting to Hebrew (the prior behavior).
///
/// The choice is mirrored into the display-lookup modules
/// ([setPreferHebrewTeamNames] / [setPreferHebrewPlayerNames]) so the
/// `localizedTeamName` / `localizedPlayerName` helpers pick it up, and
/// [notifyListeners] drives a rebuild of the `MaterialApp` subtree (this
/// provider sits alongside the locale one in `GameApp`) so visible names
/// refresh immediately on toggle.
class NamesLanguageProvider extends ChangeNotifier {
  static const _kTeam = 'team_names_in_hebrew';
  static const _kPlayer = 'player_names_in_hebrew';

  bool _teamNamesInHebrew = true;
  bool _playerNamesInHebrew = true;

  bool get teamNamesInHebrew => _teamNamesInHebrew;
  bool get playerNamesInHebrew => _playerNamesInHebrew;

  NamesLanguageProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _teamNamesInHebrew = prefs.getBool(_kTeam) ?? true;
      _playerNamesInHebrew = prefs.getBool(_kPlayer) ?? true;
    } catch (_) {
      // Keep the Hebrew defaults on any storage error.
    }
    setPreferHebrewTeamNames(_teamNamesInHebrew);
    setPreferHebrewPlayerNames(_playerNamesInHebrew);
    notifyListeners();
  }

  Future<void> setTeamNamesInHebrew(bool value) async {
    if (_teamNamesInHebrew == value) return;
    _teamNamesInHebrew = value;
    setPreferHebrewTeamNames(value);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kTeam, value);
    } catch (_) {}
  }

  Future<void> setPlayerNamesInHebrew(bool value) async {
    if (_playerNamesInHebrew == value) return;
    _playerNamesInHebrew = value;
    setPreferHebrewPlayerNames(value);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPlayer, value);
    } catch (_) {}
  }
}
