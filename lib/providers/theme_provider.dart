import 'package:flutter/material.dart';
import 'package:football/theme/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  ThemeData _themeData = ThemeData.light();

  ThemeData get themeData => _themeData;

  bool get isDarkMode => _themeData.brightness == Brightness.dark;

  // Your custom dark theme (from GameApp)
  static final ThemeData darkTheme = ThemeData(
      scaffoldBackgroundColor: background,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: Colors.blue, // Cursor (blinking line)
      selectionColor: Colors.blue.shade100, // Text selection background
      selectionHandleColor: Colors.blue, // ← The "pin"/handle color
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: cards, // Set background color
      contentTextStyle: TextStyle(color: Colors.white), // Optional: text color
      actionTextColor: Colors.blue, // Optional: action button color
    ),
    primarySwatch: Colors.blue, // Sets the primary color to blue
    brightness: Brightness.dark, // Set dark theme
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor:
          Colors.white, // This sets the back button and text color to white
      iconTheme:
          IconThemeData(color: Colors.white), // Ensures all icons are white
      elevation: 0,
    ),
    textTheme: TextTheme(
        // bodyText1: TextStyle(color: Colors.blue), // Default text color
        // bodyText2: TextStyle(color: Colors.blue), // Another text style
        ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: Colors.blue, // Default color for CircularProgressIndicator
    ),
  );

  // Your custom light theme (from GameApp)
  static final ThemeData lightTheme = ThemeData(
       scaffoldBackgroundColor: white,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: Colors.blue, // Cursor (blinking line)
      selectionColor: Colors.blue.shade100, // Text selection background
      selectionHandleColor: Colors.blue, // ← The "pin"/handle color
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Colors.grey[800], // Set background color for light theme
      contentTextStyle: TextStyle(color: Colors.white), // Optional: text color
      actionTextColor: Colors.blue, // Optional: action button color
    ),
    primarySwatch: Colors.blue, // Sets the primary color to blue
    brightness: Brightness.light, // Set light theme
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors
          .black, // This sets the back button and text color to black for light theme
      iconTheme: IconThemeData(
          color: Colors.black), // Ensures all icons are black for light theme
      elevation: 0,
    ),
    textTheme: TextTheme(
        // bodyText1: TextStyle(color: Colors.black), // Default text color for light theme
        // bodyText2: TextStyle(color: Colors.black), // Another text style for light theme
        ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: Colors.blue, // Default color for CircularProgressIndicator
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

  void setDarkMode(bool isDark) {
    _themeData = isDark ? darkTheme : lightTheme;
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
    bool isDark = prefs.getBool('isDarkMode') ??
        true; // Default to dark since your original was dark
    _themeData = isDark ? darkTheme : lightTheme;
    notifyListeners();
  }

  void _saveTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('isDarkMode', isDarkMode);
  }
}
