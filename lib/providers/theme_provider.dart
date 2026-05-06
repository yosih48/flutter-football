import 'package:flutter/material.dart';
import 'package:football/theme/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  ThemeData _themeData = ThemeData.light();

  ThemeData get themeData => _themeData;

  bool get isDarkMode => _themeData.brightness == Brightness.dark;

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
  static const Color background = Color(0xFF121212);
  static const Color cards = Color(0xFF1E1E1E);
  static const Color white = Colors.white; // Add this if not defined elsewhere

  // Your custom dark theme (from GameApp)
  static final ThemeData darkTheme = ThemeData(
    scaffoldBackgroundColor: EditorialColors.dark.pitch,
    extensions: const <ThemeExtension<dynamic>>[EditorialColors.dark],
    cardTheme: const CardThemeData(
      color: cards,
      elevation: 4.0,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: Colors.blue,
      selectionColor: Colors.blue.shade100,
      selectionHandleColor: Colors.blue,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: EditorialColors.dark.cardHi,
      elevation: 0,
      contentTextStyle: TextStyle(
        color: EditorialColors.dark.ink,
        fontSize: 13,
        height: 1.35,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      actionTextColor: EditorialColors.dark.live,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: EditorialColors.dark.hairlineHi,
          width: 1,
        ),
      ),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
    ),
    primarySwatch: Colors.blue,
    brightness: Brightness.dark,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      iconTheme: IconThemeData(color: Colors.white),
      elevation: 0,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.blue), // Fixed: bodyText1 → bodyLarge
      bodyMedium: TextStyle(color: Colors.white), // Fixed: bodyText2 → bodyMedium
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Colors.blue,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.withOpacity(0.1),
        foregroundColor: Colors.blue,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    ),
  );

  // Your custom light theme (from GameApp)
  static final ThemeData lightTheme = ThemeData(
    scaffoldBackgroundColor: EditorialColors.light.pitch,
    extensions: const <ThemeExtension<dynamic>>[EditorialColors.light],
    cardTheme: const CardThemeData(
      color: Colors.lightBlue,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: Colors.blue,
      selectionColor: Colors.blue.shade100,
      selectionHandleColor: Colors.blue,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: EditorialColors.light.cardHi,
      elevation: 0,
      contentTextStyle: TextStyle(
        color: EditorialColors.light.ink,
        fontSize: 13,
        height: 1.35,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      actionTextColor: EditorialColors.light.live,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: EditorialColors.light.hairlineHi,
          width: 1,
        ),
      ),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
    ),
    primarySwatch: Colors.blue,
    brightness: Brightness.light,
    appBarTheme: const AppBarTheme(
      backgroundColor: Color.fromARGB(0, 10, 10, 10),
      foregroundColor: Colors.black,
      elevation: 0,
    ),
    iconTheme: const IconThemeData(color: Colors.white),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color>((states) { // Fixed: MaterialStateProperty → WidgetStateProperty
        if (states.contains(WidgetState.selected)) { // Fixed: MaterialState → WidgetState
          return Colors.blue;
        }
        return Colors.white;
      }),
      trackColor: WidgetStateProperty.resolveWith<Color>((states) { // Fixed: MaterialStateProperty → WidgetStateProperty
        if (states.contains(WidgetState.selected)) { // Fixed: MaterialState → WidgetState
          return Colors.blue.withOpacity(0.5);
        }
        return Colors.grey.withOpacity(0.5);
      }),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.black), // Fixed: bodyText1 → bodyLarge
      bodyMedium: TextStyle(color: Colors.black), // Fixed: bodyText2 → bodyMedium
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Colors.blue,
    ),
  );
}