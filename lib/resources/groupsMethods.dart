import 'dart:convert';


import 'dart:math';

import 'package:flutter/material.dart';
import 'package:football/resources/usersMethods.dart';
import 'package:football/utils/config.dart';
import 'package:http/http.dart' as http;
   String _baseUrl = backendUrl;

class GroupsMethods {
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
  Future<void> addGroupToUser(String  groupId,  currentUserId,context) async {
    print(' groupId: ${ groupId}');
  
    try {
    // Fetch the list of groups
    final groups = await fetchGroups();
//  print(' groups: ${ groups}');
    // Find the group with the specified ID
    final group = groups.firstWhere(
      (g) => g['_id'] == groupId,
      // orElse: () => null,
    );
    final user= await UsersMethods().fetchUserById(currentUserId);
   print(' user: ${ user}');
    if (group != null) {
      final groupName = group['name'];

      // Find the next available key in the groupID map
   final existingGroupKeys = user['groupID']?.keys?.map((key) => int.parse(key))?.toList() ?? [];


   
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

