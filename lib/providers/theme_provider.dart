import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  ThemeData _themeData = ThemeData.light();
  
  ThemeData get themeData => _themeData;
  
  bool get isDarkMode => _themeData.brightness == Brightness.dark;
  
  // Define your custom themes
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.blue,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
    ),
    cardTheme: const CardTheme(
      color: Colors.white,
      elevation: 4,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.black87),
      bodyMedium: TextStyle(color: Colors.black87),
    ),
    // Add more custom properties as needed
    colorScheme: const ColorScheme.light(
      primary: Colors.blue,
      secondary: Colors.blueAccent,
      surface: Colors.white,
      background: Colors.grey,
    ),
  );
  
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.blue,
    scaffoldBackgroundColor: Colors.grey[900],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.grey[800],
      foregroundColor: Colors.white,
    ),
    cardTheme: CardTheme(
      color: Colors.grey[800],
      elevation: 4,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white),
    ),
    colorScheme: ColorScheme.dark(
      primary: Colors.blue,
      secondary: Colors.blueAccent,
      surface: Colors.grey[800]!,
      background: Colors.grey[900]!,
    ),
  );
  
  ThemeProvider() {
    _loadTheme();
  }
  
  void toggleTheme() {
    _themeData = isDarkMode ? lightTheme : darkTheme;
    _saveTheme();
    notifyListeners();
  }
  
  void setTheme(ThemeData theme) {
    _themeData = theme;
    _saveTheme();
    notifyListeners();
  }
  
  void _loadTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isDark = prefs.getBool('isDarkMode') ?? false;
    _themeData = isDark ? darkTheme : lightTheme;
    notifyListeners();
  }
  
  void _saveTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('isDarkMode', isDarkMode);
  }
}