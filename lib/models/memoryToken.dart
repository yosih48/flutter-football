class TokenManager {
  static String? _token;
  static DateTime? _expirationTime;

  static void setToken(String token) {
    _token = token;
    _expirationTime = DateTime.now().add(Duration(minutes: 3));
  }

  static String? getToken() {
    if (_token != null &&
        _expirationTime != null &&
        DateTime.now().isBefore(_expirationTime!)) {
      return _token;
    }
    return null;
  }

  static bool isTokenValid() {
    return getToken() != null;
  }
}
