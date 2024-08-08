import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:football/models/users.dart';
import 'package:http/http.dart' as http;

class AuthService {
  static const _baseUrl = 'https://leagues.onrender.com/users';

  // Login function
  static Future<Map<String, dynamic>> login(String email, String password) async {
print(email);
print(password);

    final url = Uri.parse('$_baseUrl/login');
    final body = json.encode({'email': email, 'password': password});

    final response = await http.post(
      url,
      headers: { "Content-type": "application/json; charset=UTF-8",},
      body: body,
    );
print(body);
    if (response.statusCode == 200) {
      // Login successful
      return json.decode(response.body);
    } else {
      // Login failed
      throw Exception('Failed to login: ${response.statusCode}');
    }
  }
  static Future<User?> getUserDetails(String email) async {
    final url = Uri.parse('$_baseUrl/user');
    final response = await http.get(
      url,
      // headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      // User details retrieved successfully
      final userJson = json.decode(response.body);
      return User.fromJson(userJson);
    } else {
      // Failed to retrieve user details
      return null;
    }
  }
  // Register function (optional)
  static Future<Map<String, dynamic>> register(
    String displayName,
    String email,
    String password,
  ) async {
    final url = Uri.parse('$_baseUrl/register');
    final body = json.encode({
      'displayName': displayName,
      'email': email,
      'password': password,
    });

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode == 201) {
      // Registration successful
      return json.decode(response.body);
    } else {
      // Registration failed
      throw Exception('Failed to register: ${response.statusCode}');
    }
  }
}

class AuthProvider extends ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;
  String? _token;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;

  Future<void> login(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      final result = await AuthService.login(email, password);
      _currentUser = User.fromJson(result['user']);
      _token = result['token'];
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    _token = null;
    notifyListeners();
  }

  Future<void> refreshUser(String email) async {
    try {
      _isLoading = true;
      notifyListeners();

      _currentUser = await AuthService.getUserDetails(email);
    } catch (e) {
      print("Error refreshing user: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Stream<User?> authStateChanges() {
    return Stream.value(_currentUser);
  }
}