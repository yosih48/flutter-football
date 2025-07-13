import 'package:flutter/material.dart';
import 'package:football/utils/colors.dart';

// 1. Define your custom colors class
class AppColors {
  final Color primary;
  final Color secondary;
  final Color background;
  final Color surface;
  final TextStyle text;
  final TextStyle textSecondary;
  final TextStyle caption;
  final Color error;
  final Color success;

  const AppColors({
    required this.primary,
    required this.secondary,
    required this.background,
    required this.surface,
    required this.text,
    required this.textSecondary,
    required this.caption,
    required this.error,
    required this.success,
  });

  // Define your color schemes
  static const AppColors lightColors = AppColors(
    primary: Colors.blue,
    secondary: Colors.blueAccent,
    background: Colors.white,
    surface: Color(0xFFF5F5F5),
    text: TextStyle(color: Colors.black, fontSize: 16),
    textSecondary: TextStyle(color: Colors.grey, fontSize: 14),
    caption: TextStyle(color: Colors.grey, fontSize: 12),
    error: Colors.red,
    success: Colors.green,
  );

  static const AppColors darkColors = AppColors(
    primary: Colors.blue,
    secondary: Colors.blueAccent,
    background: Color(0xFF121212),
    surface: Color(0xFF1E1E1E),
    text: TextStyle(color: Colors.white, fontSize: 16),
    textSecondary: TextStyle(color: Colors.grey, fontSize: 14),
    caption: TextStyle(color: Colors.grey, fontSize: 12),
    error: Colors.red,
    success: Colors.green,
  );
}

// 2. Create your custom theme provider
class CustomThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  AppColors _currentColors = AppColors.lightColors;

  bool get isDarkMode => _isDarkMode;
  AppColors get colors => _currentColors;

  // Switch between light and dark
  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    _currentColors = _isDarkMode ? AppColors.darkColors : AppColors.lightColors;
    notifyListeners();
  }

  // Set custom colors dynamically
  void setCustomColors(AppColors colors) {
    _currentColors = colors;
    notifyListeners();
  }

  // Change individual colors
  void changePrimaryColor(Color color) {
    _currentColors = AppColors(
      primary: color,
      secondary: _currentColors.secondary,
      background: _currentColors.background,
      surface: _currentColors.surface,
      text: _currentColors.text,
      textSecondary: _currentColors.textSecondary,
      caption: _currentColors.caption,
      error: _currentColors.error,
      success: _currentColors.success,
    );
    notifyListeners();
  }

  // Generate ThemeData based on current colors
  ThemeData get themeData {
    return ThemeData(
      brightness: _isDarkMode ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme(
        brightness: _isDarkMode ? Brightness.dark : Brightness.light,
        primary: _currentColors.primary,
        onPrimary: _isDarkMode ? Colors.white : Colors.black,
        secondary: _currentColors.secondary,
        onSecondary: _isDarkMode ? Colors.white : Colors.black,
        error: _currentColors.error,
        onError: Colors.white,
        surface: _currentColors.surface,
        onSurface: _currentColors.text.color!, 
        background: blueColor, onBackground: blueColor,
      ),
      scaffoldBackgroundColor: _currentColors.background,
      cardTheme: CardTheme(
        color: _currentColors.surface,
        shadowColor: _currentColors.primary.withOpacity(0.1),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: _currentColors.background,
        foregroundColor: _currentColors.text.color, // This sets the back button and text color
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _currentColors.primary.withOpacity(0.1),
          foregroundColor: _currentColors.primary,
          elevation: 0,
        ),
      ),
      textTheme: TextTheme(
        bodyLarge: _currentColors.text,
        bodyMedium: _currentColors.text,
        bodySmall: _currentColors.textSecondary,

      ),
    );
  }
}
