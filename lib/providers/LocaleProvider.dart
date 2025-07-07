import 'package:flutter/material.dart';
import 'dart:ui' as ui;
class LocaleProvider extends ChangeNotifier {
  Locale _locale;

  LocaleProvider() : _locale = _getSystemLocale();

  Locale get locale => _locale;

  // Get system locale, fallback to English if not supported
  static Locale _getSystemLocale() {
    final systemLocale = ui.window.locale;
    final supportedLanguages = ['en', 'he'];

    if (supportedLanguages.contains(systemLocale.languageCode)) {
      return Locale(systemLocale.languageCode);
    }

    // Fallback to English if system language is not supported
    return const Locale('en');
  }

  void setLocale(Locale locale) {
    if (!['en', 'he'].contains(locale.languageCode)) return;
    _locale = locale;
    notifyListeners();
  }

  void clearLocale() {
    _locale =
        _getSystemLocale(); // Reset to system default instead of hardcoded English
    notifyListeners();
  }
}
