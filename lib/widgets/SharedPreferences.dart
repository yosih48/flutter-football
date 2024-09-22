import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesUtil {
  static const String _keySelectedGroupName = 'selectedGroupName';

  static Future<String?> getSelectedGroupName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySelectedGroupName);
  }

  static Future<void> setSelectedGroupName(String groupName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySelectedGroupName, groupName);
  }
}
