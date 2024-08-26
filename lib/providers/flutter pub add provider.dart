
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:football/models/users.dart';


import '../resources/auth.dart';


class UserProvider extends ChangeNotifier {
  User? _currentUser;
   String _selectedGroupName = 'default';
   int _selectedLeageId = 2;

   String get selectedGroupName => _selectedGroupName;
   int get selectedLeageId => _selectedLeageId;
  User? get currentUser => _currentUser;


  bool get isCurrentUserAdmin => _currentUser?.admin ?? false;

  String get currentUserUsername => _currentUser?.name ?? 'Not logged in';

  String get currentUserUid => _currentUser?.id ?? 'Not logged in';
  String get currentUserEmail => _currentUser?.email ?? 'Not logged in'; 
  String get currentUserToken => _currentUser?.newToken ?? 'Not logged in'; 

  final AuthService _authService = AuthService();

  Future<void> refreshUser(String email) async {
    try {
      User? user = await AuthService.getUserDetails(currentUserToken);
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

  void setSelectedGroupName(String groupName) {
    _selectedGroupName = groupName;
    notifyListeners();
  }
  void setselectedLeageId(int id) {
    _selectedLeageId = id;
    print('_selectedLeageId ${_selectedLeageId}');
    notifyListeners();
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
