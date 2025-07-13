import 'package:flutter/material.dart';
import 'package:football/theme/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {

  
  ThemeData _themeData = ThemeData.light();

  ThemeData get themeData => _themeData;

  bool get isDarkMode => _themeData.brightness == Brightness.dark;

  // Your custom dark theme (from GameApp)
  static final ThemeData darkTheme = ThemeData.from(
    
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      // brightness: Brightness.dark,
     
    ),
  ).copyWith(
    scaffoldBackgroundColor: background,
    cardTheme: CardTheme(
      color: cards, // Set the card background color
      shadowColor: Colors.blue.withOpacity(0.1),
    ),
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
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white, // This sets the back button and text color to white
      iconTheme: IconThemeData(color: Colors.white), // Ensures all icons are white
      elevation: 0,
    ),
    textTheme: TextTheme(
      bodyText1: TextStyle(color: Colors.blue), // Default text color
      bodyText2: TextStyle(color: Colors.white), // Another text style
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: Colors.blue, // Default color for CircularProgressIndicator
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.withOpacity(0.1),
        foregroundColor: Colors.blue,
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    ),
    extensions: <ThemeExtension<dynamic>>[
      const CustomColors(cards: cards, secondText: Colors.white),
    ],
    
  );

  // Your custom light theme (from GameApp)
  static final ThemeData lightTheme = ThemeData.from(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.light,
    ),
  ).copyWith(
    scaffoldBackgroundColor: white,
    cardTheme: CardTheme(
      color: Colors.lightBlue, // Set the card background color
    ),
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
    appBarTheme: AppBarTheme(
      backgroundColor: const Color.fromARGB(0, 10, 10, 10),
      foregroundColor: Colors.black, // This sets the back button and text color to black for light theme
      elevation: 0,
    ),
    iconTheme: IconThemeData(color: Colors.white),
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith<Color>((states) {
        if (states.contains(MaterialState.selected)) {
          return Colors.blue; // Active thumb = primary color
        }
        return Colors.white; // Inactive thumb = white (from iconTheme)
      }),
      trackColor: MaterialStateProperty.resolveWith<Color>((states) {
        if (states.contains(MaterialState.selected)) {
          return Colors.blue; // Active track = primary with opacity
        }
        return Colors.grey.withOpacity(0.5); // Inactive track = disabled color with opacity
      }),
    ),
    textTheme: TextTheme(
      bodyText1: TextStyle(color: Colors.black), // Default text color for light theme
      bodyText2: TextStyle(color: Colors.black), // Another text style for light theme
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: Colors.blue, // Default color for CircularProgressIndicator
    ),
    extensions: <ThemeExtension<dynamic>>[
      const CustomColors(cards: Colors.lightBlue, secondText: Colors.black),
    ],
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

class CustomColors extends ThemeExtension<CustomColors> {
  final Color? cards;
  final Color? secondText;
  const CustomColors({this.cards, this.secondText});

  @override
  CustomColors copyWith({Color? cards, Color? secondText}) {
    return CustomColors(
      cards: cards ?? this.cards,
      secondText: secondText ?? this.secondText,
    );
  }

  @override
  CustomColors lerp(ThemeExtension<CustomColors>? other, double t) {
    if (other is! CustomColors) return this;
    return CustomColors(
      cards: Color.lerp(cards, other.cards, t),
      secondText: Color.lerp(secondText, other.secondText, t),
    );
  }
}
