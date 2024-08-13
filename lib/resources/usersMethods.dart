import 'dart:convert';

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

}