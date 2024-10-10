import 'dart:async';
import 'dart:convert';


import 'package:flutter/material.dart';
import 'package:football/main.dart';
import 'package:football/models/users.dart';
import 'package:football/providers/flutter%20pub%20add%20provider.dart';
import 'package:football/responsive/mobile_screen_layout.dart';
import 'package:football/responsive/rsponsive_layout_screen.dart';
import 'package:football/responsive/web_screen_layout.dart';
import 'package:football/utils/config.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // static const _baseUrl = 'https://leagues.onrender.com/users';
  // static const _baseUrl = 'http://10.0.2.2:5000/users';
  static const _baseUrl =  '$backendUrl/users';



  static Future<Map<String, dynamic>> googleLogin(
      String idToken, String? fcmToken, BuildContext context) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/verify-google-user'),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(<String, String>{
        'token': idToken,
        'fcmToken': fcmToken ?? '',
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to authenticate with Google');
    }
  }










  // Login function
  static Future<Map<String, dynamic>> login(
      String email, String password,String? fcmToken) async {
        print('second login');
        print(fcmToken);
    try {
      final url = Uri.parse('$_baseUrl/login');
      final body = json.encode({'email': email, 'password': password, 'fcmToken': fcmToken ?? '',});

      final response = await http.post(
        url,
        headers: {
          "Content-type": "application/json; charset=UTF-8",
        },
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
    } catch (e, stackTrace) {
      print('Stack trace: $stackTrace');
      print('Error during login: $e');
      throw Exception('Error during login: $stackTrace');
    }
  }

  static Future<User?> getUserDetails(String token, String userId) async {
    print('Getting user details for userId: $userId');
    print('Using token: $token');

    final url = Uri.parse('$_baseUrl/${userId}');
    print('Requesting URL: $url');

    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
    );

    print('Response status code: ${response.statusCode}');
    print('Response body: ${response.body}');

    if (response.statusCode == 200) {
      final responseBody = json.decode(response.body);
      print('Decoded response body: $responseBody');

      User? user;
      if (responseBody is List && responseBody.isNotEmpty) {
        user = User.fromJson(responseBody[0]);
        print('responseBody is List');
        print(user.id);
      } else if (responseBody is Map<String, dynamic>) {
        final Map<String, dynamic> userMap = {
          'id': responseBody['_id'],
          'name': responseBody['displayName'],
          'admin': responseBody['isAdmin'],
          'email': responseBody['email'],
          'newToken':
              responseBody['newToken'], // Assuming this exists in the response
          'groups': responseBody['groupID'],
        };
        user = User.fromJson(userMap);
        print('responseBody is map');
        print(userMap);
        print(user);
      } else {
        throw Exception('Unexpected response format');
      }

      print('Created user object: $user');
      print('User ID: ${user.id}');
      return user;
    } else {
      throw Exception('Failed to get user details: ${response.statusCode}');
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
        '2': 0 // Changed 2 to '2'
      },
      'thisDayPoints': {
        '2': 0 // Changed 2 to '2'
      },
      'isAdmin': false,
      'groupID': {
        '1': "public" // Changed 2 to '2'
      },
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
      print(response.body);
      throw Exception('Failed to register: ${response.statusCode}');
    }
  }
}

class AuthProvider with ChangeNotifier {
  User? _currentUser;
  User? get user => _currentUser;
  bool _isLoading = false;
  bool _isInitializing = true;
  final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  // final StreamController<User?> _authStateController = StreamControcller<User?>.broadcast();

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;

  Future<void> googleLogin(String idToken, String? fcmToken, BuildContext context) async {
    print('Google login');
    print(fcmToken);
    _isLoading = true;
    notifyListeners();

    try {
      final userData = await AuthService.googleLogin(idToken, fcmToken, context);
      _currentUser = User.fromJson(userData);
      await _secureStorage.write(
          key: 'auth_token', value: _currentUser!.newToken);
      await _secureStorage.write(key: 'user_id', value: _currentUser!.id);
      print('Google Login successful: ${_currentUser?.email}');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const ResponsiveLayout(
            mobileScreenLayout: MobileScreenLayout(),
            webScreenLayout: WebScreenLayout(),
          ),
        ),
      );
      // Navigate to GamesScreen
      // navigatorKey.currentState?.pushReplacementNamed('/game_details');
    } catch (e) {
      print('Google Login failed: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }













  Future<void> initializeApp() async {
    final String? token = await _secureStorage.read(key: 'auth_token');
    final String? userId = await _secureStorage.read(key: 'user_id');
    print(userId);
    if (token != null && userId != null) {
      print('token != null');
      try {
        await refreshUser(token, userId);
      } catch (e) {
        print("Error refreshing user: $e");
        await signOut(userId);
      }
    }
    _isInitializing = false;
    print(_isInitializing);
    print(' _isInitializing = false');
    print(isInitializing);
    notifyListeners();
  }

  Future<void> login(String email, String password, String? fcmToken) async {
    print('login');
    print(fcmToken);
    _isLoading = true;
    notifyListeners();

    try {
      final userData = await AuthService.login(email, password, fcmToken);
      _currentUser = User.fromJson(userData);
      await _secureStorage.write(
          key: 'auth_token', value: _currentUser!.newToken);
      await _secureStorage.write(key: 'user_id', value: _currentUser!.id);
      print('Login successful: ${_currentUser?.email}');
    } catch (e) {
      print('Login failed: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshUser(String token, String userId) async {
    try {
      final user = await AuthService.getUserDetails(token, userId);
      print('user in refresh');
      print(user);
      if (user != null) {
        _currentUser = user;
        await _secureStorage.write(key: 'auth_token', value: token);
        await _secureStorage.write(key: 'user_id', value: userId);
      } else {
        throw Exception('Failed to refresh user');
      }
    } catch (e) {
      print("Error refreshing user: $e");
      await signOut(userId);
      rethrow;
    }
    notifyListeners();
  }
  static const _baseUrl = 'http://10.0.2.2:5000/users';
  Future<void> signOut(userID) async {
  
    await _secureStorage.delete(key: 'auth_token');
    await _secureStorage.delete(key: 'user_id');

    // Clear SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

      try {
      final response = await http.post(
        Uri.parse('$_baseUrl/logout'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'userId': userID,
        }),
      );

      if (response.statusCode == 200) {
        // Handle successful logout
        print('Logout successful');
      } else {
        throw Exception('Failed to log out');
      }
    } catch (e) {
      print('Error during logout: $e');
    }
    _currentUser = null;
    notifyListeners();
  }

  Future<User?> ensureUserLoaded() async {
    print('ensureUserLoaded ');
    print('_currentUser : ${_currentUser!.id}');
    if (_currentUser != null && _currentUser!.id.isNotEmpty) {
      return _currentUser;
    }

    final String? token = await _secureStorage.read(key: 'auth_token');
    final String? userId = await _secureStorage.read(key: 'user_id');
    print('userId : ${userId}');
    print('token ${token}');
    if (token != null && userId != null) {
      try {
        await refreshUser(token, userId);
        if (_currentUser != null && _currentUser!.id.isNotEmpty) {
          return _currentUser;
        } else {
          throw Exception('User data is invalid after refresh');
        }
      } catch (e) {
        print("Error ensuring user loaded: $e");
        await signOut(userId);
      }
    }

    return null;
  }

  // Don't forget to close the stream when the provider is disposed

  Future<void> register(
      String displayName, String email, String password) async {
    print(' AuthProvider ${displayName}');
    try {
      _isLoading = true;
      notifyListeners();

      final userData = await AuthService.register(displayName, email, password);
      print(' userData ${userData}');
      _currentUser = User.fromJson(userData);
      // _authStateController.add(_currentUser);

      print('Registration successful: ${_currentUser?.email}');
    } catch (e) {
      print('Registration failed: $e');
      // _authStateController.addError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
