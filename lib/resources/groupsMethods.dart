import 'dart:convert';

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:football/resources/usersMethods.dart';
import 'package:football/utils/config.dart';
import 'package:football/utils/utils.dart';
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

  // Resolve a group from a code the user typed. The backend accepts both the
  // short joinCode (e.g. "K7QP2M") and, for backward compatibility, a raw group
  // _id (the old long share code). Falls back to a client-side _id match if the
  // endpoint is unavailable (e.g. backend not yet deployed).
  Future<Map<String, dynamic>?> fetchGroupByCode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return null;
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/groups/byCode/${Uri.encodeComponent(trimmed)}'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['error'] == false && data['msg'] != null) {
          return Map<String, dynamic>.from(data['msg']);
        }
      }
      // 404 / not found → no group for this code.
      if (response.statusCode == 404) return null;
    } catch (e) {
      print('fetchGroupByCode error (falling back to _id match): $e');
    }
    // Fallback: old behaviour — match the raw _id against the full group list.
    try {
      final groups = await fetchGroups();
      for (final g in groups) {
        if (g['_id'] == trimmed) return Map<String, dynamic>.from(g);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> addGroupToUser(String groupCode, currentUserId, context) async {
    print(' groupCode: ${groupCode}');

    try {
      // Resolve the group from the typed code (short joinCode or raw _id).
      final group = await fetchGroupByCode(groupCode);
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
            showSnackBar(
              context,
              "אתה כבר חבר בקבוצה זו",
              tone: SnackTone.warning,
            );
          } else {
            print('User updated successfully');
            showSnackBar(
              context,
              "הצטרפת לקבוצה בצלחה",
              tone: SnackTone.success,
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

  // ── Shared with the bracket: create / leave / delete a normal league ──
  // Same endpoints the normal leaderboard (table.dart) uses, so the bracket
  // competes inside the very same friend-leagues.

  // Create a private league (group). Returns the created group map, or null.
  Future<Map<String, dynamic>?> createGroup(String name, String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/groups/add'),
        headers: {'Content-type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'name': name,
          'createdBy': userId,
          'type': 'private',
          'code': DateTime.now().millisecondsSinceEpoch,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data is Map && data['error'] == false) {
        return Map<String, dynamic>.from(data['msg']);
      }
      return null;
    } catch (e) {
      print('createGroup error: $e');
      return null;
    }
  }

  // Leave a league: drop the matching key from the user's groupID map and PUT.
  Future<bool> leaveGroup(String userId, String groupName) async {
    try {
      final user = await UsersMethods().fetchUserById(userId);
      final groupID = Map<String, dynamic>.from(user['groupID'] ?? {});
      final key = groupID.entries
          .firstWhere((e) => e.value == groupName,
              orElse: () => const MapEntry('', ''))
          .key;
      if (key.isEmpty) return false;
      groupID.remove(key);
      final res = await http.put(
        Uri.parse('$_baseUrl/users/'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'_id': userId, 'groupID': groupID}),
      );
      return res.statusCode == 200;
    } catch (e) {
      print('leaveGroup error: $e');
      return false;
    }
  }

  // Owner deletes a league.
  Future<bool> deleteGroup(String groupId, String name) async {
    try {
      final res = await http.delete(
        Uri.parse('$_baseUrl/groups/'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'groupId': groupId, 'name': name}),
      );
      return res.statusCode == 200;
    } catch (e) {
      print('deleteGroup error: $e');
      return false;
    }
  }
}
