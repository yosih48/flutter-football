
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:football/models/users.dart';


import '../resources/auth.dart';


class UserProvider extends ChangeNotifier {
  User? _currentUser;

  User? get currentUser => _currentUser;

  bool get isCurrentUserAdmin => _currentUser?.admin ?? false;

  String get currentUserUsername => _currentUser?.name ?? 'Not logged in';

  String get currentUserUid => _currentUser?.id ?? 'Not logged in';

  final AuthService _authService = AuthService();

  Future<void> refreshUser(String email) async {
    try {
      User? user = await AuthService.getUserDetails(email);
      if (user != null) {
        _currentUser = user;
        print("Employee refreshed: ${user.name}");
      } else {
        _currentUser = null;
        print("No employee data retrieved");
      }
      notifyListeners();
    } catch (e) {
      print("Error refreshing employee: $e");
      _currentUser = null;
      notifyListeners();
    }
  }


  void setCurrentEmployee(User employee) {
    _currentUser = employee;
    print("Current employee set: ${employee.name}");
    notifyListeners();
  }

  void clearCurrentEmployee() {
    _currentUser = null;
    print("Current employee cleared");
    notifyListeners();
  }
}
