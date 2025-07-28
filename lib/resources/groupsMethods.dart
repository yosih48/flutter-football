import 'dart:convert';

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:football/resources/usersMethods.dart';
import 'package:football/utils/config.dart';
import 'package:http/http.dart' as http;

String _baseUrl = backendUrl;

class GroupsMethods {
  // 1. Single call to get all dashboard data
  static Future<Map<String, dynamic>> fetchDashboardData(String userId) async {

    
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/users/user-groups/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
            'Failed to load dashboard data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching dashboard data: $e');
      throw Exception('Failed to fetch dashboard data: $e');
    }
  }

  // 2. Get users for specific group and league
  static Future<List<Map<String, dynamic>>> fetchGroupUsers(
      String groupName, int league) async {


        print( 'fetchGroupUsers: groupName: $groupName, league: $league');
    try {
      final response = await http.get(
        Uri.parse(
            '$_baseUrl/users/groups/${Uri.encodeComponent(groupName)}/users/$league'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        return data.map((user) => Map<String, dynamic>.from(user)).toList();
      } else {
        throw Exception('Failed to load group users: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching group users: $e');
      throw Exception('Failed to fetch group users: $e');
    }
  }

  // 3. Get only user's groups (lighter call)
  static Future<Map<String, dynamic>> fetchUserGroups(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/users/users/$userId/groups'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load user groups: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching user groups: $e');
      throw Exception('Failed to fetch user groups: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchGroups() async {
    print('fetchGroups');
    final url = Uri.parse('$_baseUrl/groups/register');

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

  Future<void> addGroupToUser(String groupId, currentUserId, context) async {
    print(' groupId: ${groupId}');

    try {
      // Fetch the list of groups
      final groups = await fetchGroups();
//  print(' groups: ${ groups}');
      // Find the group with the specified ID
      final group = groups.firstWhere(
        (g) => g['_id'] == groupId,
        // orElse: () => null,
      );
      final user = await UsersMethods().fetchUserById(currentUserId);
      print(' user: ${user}');
      if (group != null) {
        final groupName = group['name'];

        // Find the next available key in the groupID map
        final existingGroupKeys =
            user['groupID']?.keys?.map((key) => int.parse(key))?.toList() ?? [];

        int nextKey = 1;
        if (existingGroupKeys.isNotEmpty) {
          print('existingGroupKeys is not empty');
          // Sort keys to find the first missing key
          existingGroupKeys.sort();
          for (int i = 1; i <= existingGroupKeys.length; i++) {
            if (!existingGroupKeys.contains(i)) {
              nextKey = i;
              break;
            }
          }
          // If all keys are continuous, take the next number after the max
          if (nextKey == 1) {
            nextKey = existingGroupKeys.last + 1;
          }
        }

        print('user email: ${user['email']}');
        print('nextKey: ${nextKey}');
        print('existingGroupKeys: ${existingGroupKeys}');
        final url = Uri.parse('$_baseUrl/users/');

        final response = await http.put(
          url,
          body: jsonEncode({
            '_id': currentUserId,
            'groups': user['groupID'],
            'email': user['email'],
            '\$set': {
              'groupID.$nextKey': groupName,
            },
          }),
          headers: {
            'Content-type': 'application/json; charset=UTF-8',
          },
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['message'] == 'Group name already exists') {
            print('Group name already exists');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("אתה כבר חבר בקבוצה זו")),
            );
          } else {
            print('User updated successfully');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("הצטרפת לקבוצה בצלחה")),
            );
          }
        } else {
          print('User update failed with status: ${response.statusCode}');
          // Show error snackbar
        }
      } else {
        print('Group not found');
        // Handle group not found case
      }
    } catch (e) {
      print('Error updating user: $e');
      // Show error snackbar
    }
  }
}
