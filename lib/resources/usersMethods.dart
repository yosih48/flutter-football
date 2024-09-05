import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:football/models/users.dart';
import 'package:http/http.dart' as http;

class UsersMethods {
Future<List<Map<String, dynamic>>>fetchAllUsers() async {
  print('fetchAllUsers');
  final url = Uri.parse('https://leagues.onrender.com/users/register');

  try {
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      
      if (responseData != null && responseData is List) {
        return List<Map<String, dynamic>>.from(responseData);
      } else {
        throw Exception('Invalid response data format');
      }
    } else {
      throw Exception('Failed to load users: ${response.statusCode}');
    }
  } catch (e) {
    print('Error fetching users: $e');
    rethrow;
  }
}
Future<Map<String, dynamic>> fetchUserById(String userId) async {
  print('fetchAllUsers');
  final url = Uri.parse('https://leagues.onrender.com/users/${userId}');

  try {
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);

      if (responseData != null && responseData is Map<String, dynamic>) {
        return responseData;
      } else {
        throw Exception('Invalid response data format');
      }
    } else {
      throw Exception('Failed to load users: ${response.statusCode}');
    }
  } catch (e) {
    print('Error fetching users: $e');
    rethrow;
  }
}
  Future<void> _createNewGroup(String groupName, currentUserId) async {
    final url = Uri.parse('${const String.fromEnvironment('VUE_APP_HOST')}groups/add');
    try {
      final response = await http.post(
        url,
        body: jsonEncode({
          'name': groupName,
          'createdBy': currentUserId,
          'code': DateTime.now().millisecondsSinceEpoch,
        }),
        headers: {
          'Content-type': 'application/json; charset=UTF-8',
          // 'Authorization': 'Bearer ${userToken}', // Uncomment if needed
        },
      );

      if (response.statusCode == 200) {
        // Group created successfully
        // _fetchUserGroups(); // Refresh the groups list
      } else {
        throw Exception('Failed to create group');
      }
    } catch (e) {
      print('Error creating group: $e');
      // Show error message to user
    }
  }

Future<String> sendEmail(String email) async {
    try {
      print('Sending email to: $email');
      var response = await http.post(
        Uri.parse('https://leagues.onrender.com/users/forgotPass'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          'email': email,
        }),
      );
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonObject = jsonDecode(response.body);
        print('Decoded JSON: $jsonObject');

        if (jsonObject != null && jsonObject['error'] == false) {
          print('JSON object error is false');
          String resetToken = jsonObject['newToken'];
          print('Token received: $resetToken');
          return resetToken;
        } else {
          print('JSON object error is true or null');
          throw Exception('Email not registered or other error');
        }
      } else {
        print('Non-200 status code');
        throw Exception('Failed to load users: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception caught in sendEmail: $e');
      throw e;
    }
  }





}