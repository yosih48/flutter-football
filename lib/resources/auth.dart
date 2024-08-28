import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:football/models/users.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static const _baseUrl = 'https://leagues.onrender.com/users';

  // Login function
  static Future<Map<String, dynamic>> login(String email, String password) async {

  try {
    print(email);
    print(password);

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
      } catch (e, stackTrace) {
            print('Stack trace: $stackTrace');
      print('Error during login: $e');
      throw Exception('Error during login: $stackTrace');
    }
  }
  static Future<User?> getUserDetails(String  token) async {
    final url = Uri.parse('$_baseUrl/user');
    final response = await http.get(
      url,
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
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
final FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  // Future<void> login(String email, String password) async {

    // try {
    //   _isLoading = true;
    //   notifyListeners();

    //   final userData = await AuthService.login(email, password);
    //   print(userData);
    //   _currentUser = User.fromJson(userData); // Assuming you have a User.fromJson constructor
    //     print(_currentUser);
    //       await _secureStorage.write(key: 'auth_token', value: _currentUser!.newToken);
    //   _authStateController.add(_currentUser);
      
    //   print('Login successful: ${_currentUser?.email}');
    // } catch (e) {
    //   print('Login failed: $e');
    //   _authStateController.addError(e);
    // } finally {
    //   _isLoading = false;
    //   notifyListeners();
    // }
// }






  // AuthProvider() {
  //   // Initialize the stream with the current user state
  //   _authStateController.add(_currentUser);
  // }
  //   AuthProvider() {
  //   _initializeAuthState();
  // }
  //   Future<void> _initializeAuthState() async {
  //   final String? token = await _secureStorage.read(key: 'auth_token');
  //   if (token != null) {
  //     // If a token exists, try to get the user details
  //     await refreshUser(token);
  //   } else {
  //     _authStateController.add(null);
  //   }
  // }

  // bool get isLoading => _isLoading;

  // User? get currentUser => _currentUser;

  // Future<void> refreshUser(String  token) async {
  //   try {
  //     _isLoading = true;
  //     notifyListeners();

  //     _currentUser = await AuthService.getUserDetails( token);
  //     // Emit the new user state
  //     _authStateController.add(_currentUser);
  //   } catch (e) {
  //     print("Error refreshing user: $e");
  //       await signOut();
  //   } finally {
  //     _isLoading = false;
  //     notifyListeners();
  //   }
  // }

  // Stream<User?> authStateChanges() {
  //   print('authStateChanges');
  //   return _authStateController.stream;
  // }
  AuthProvider() {
    _initializeAuthState();
  }

  Future<void> _initializeAuthState() async {
    final String? token = await _secureStorage.read(key: 'auth_token');
    if (token != null) {
      await refreshUser(token);
    } else {
      _authStateController.add(null);
    }
  }

  Future<void> login(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      final userData = await AuthService.login(email, password);
      _currentUser = User.fromJson(userData);
      await _secureStorage.write(
          key: 'auth_token', value: _currentUser!.newToken);
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

  Future<void> refreshUser(String token) async {
    try {
      _isLoading = true;
      notifyListeners();

      _currentUser = await AuthService.getUserDetails(token);
      _authStateController.add(_currentUser);
    } catch (e) {
      print("Error refreshing user: $e");
      await signOut();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }









  // Don't forget to close the stream when the provider is disposed
  // @override
  // void dispose() {
  //   _authStateController.close();
  //   super.dispose();
  // }
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

  Stream<User?> authStateChanges() => _authStateController.stream;

  bool get isLoading => _isLoading;
  User? get currentUser => _currentUser;
    Future<void> signOut() async {
    try {
      _isLoading = true;
      notifyListeners();
  await _secureStorage.delete(key: 'auth_token');
      // Clear the current user
      _currentUser = null;

      // Emit the new (null) user state
      _authStateController.add(null);

      print('Sign out successful');
    } catch (e) {
      print('Sign out failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
