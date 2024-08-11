import 'dart:async';
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
      print('Login successful');
      return json.decode(response.body);
    } else {
        print(' Login failed');
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

    print('register displayName ${displayName}');
    final url = Uri.parse('$_baseUrl/add');
    final body = json.encode({
      'displayName': displayName,
      'email': email,
      'password': password,
    'points': {
      '2': 0  // Changed 2 to '2'
    },
    'thisDayPoints': {
      '2': 0  // Changed 2 to '2'
    },
             'isAdmin': false,
    });

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
print(body);
    if (response.statusCode == 201) {
      // Registration successful
      print('Registration successful');
      return json.decode(response.body);
    } else {
      // Registration failed
      throw Exception('Failed to register: ${response.statusCode}');
    }
  }
}
class AuthProvider with ChangeNotifier {
  User? _currentUser;
    User? get user => _currentUser;
  bool _isLoading = false;
  final StreamController<User?> _authStateController = StreamController<User?>.broadcast();
  Future<void> login(String email, String password) async {

    try {
      _isLoading = true;
      notifyListeners();

      final userData = await AuthService.login(email, password);
      print(userData);
      _currentUser = User.fromJson(userData); // Assuming you have a User.fromJson constructor
        print(_currentUser);
      _authStateController.add(_currentUser);
      
      print('Login successful: ${_currentUser?.email}');
    } catch (e) {
      print('Login failed: $e');
      _authStateController.addError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
    Future<void> register(String displayName, String email, String password) async {
      print(' AuthProvider ${displayName}');
    try {
      _isLoading = true;
      notifyListeners();

      final userData = await AuthService.register(displayName, email, password);
       print(' userData ${userData }');
      _currentUser = User.fromJson(userData);
      _authStateController.add(_currentUser);
      
      print('Registration successful: ${_currentUser?.email}');
    } catch (e) {
      print('Registration failed: $e');
      _authStateController.addError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  AuthProvider() {
    // Initialize the stream with the current user state
    _authStateController.add(_currentUser);
  }

  bool get isLoading => _isLoading;

  User? get currentUser => _currentUser;

  Future<void> refreshUser(String email) async {
    try {
      _isLoading = true;
      notifyListeners();

      _currentUser = await AuthService.getUserDetails(email);
      // Emit the new user state
      _authStateController.add(_currentUser);
    } catch (e) {
      print("Error refreshing user: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Stream<User?> authStateChanges() {
    print('authStateChanges');
    return _authStateController.stream;
  }

  // Don't forget to close the stream when the provider is disposed
  @override
  void dispose() {
    _authStateController.close();
    super.dispose();
  }

  // Add a method to handle sign out
  Future<void> signOut() async {
    // Implement your sign out logic here
    _currentUser = null;
    _authStateController.add(null);
    notifyListeners();
  }
}
