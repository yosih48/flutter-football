import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

class GroupsMethods {
Future<List<Map<String, dynamic>>> fetchGroups() async {
    print('fetchGroups');
    final url = Uri.parse('https://leagues.onrender.com/groups/register');

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
  Future<void> addGroupToUser(String groupName, user, currentUserId) async {
    final existingGroupKeys =
        user['groupID']?.keys?.map((key) => int.parse(key))?.toList() ?? [];
    final nextKey = existingGroupKeys.isEmpty
        ? 1
        : (existingGroupKeys.reduce(max) + 1).toString();
    print('existingGroupKeys: ${existingGroupKeys}');
    final url = Uri.parse('https://leagues.onrender.com/users/');
    try {
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
          // Show snackbar or alert
        } else {
          print('User updated successfully');
          // Show success snackbar
          // _fetchUserGroups(); // Refresh user data
        }
      } else {
        print('User update failed with status: ${response.statusCode}');
        // Show error snackbar
      }
    } catch (e) {
      print('Error updating user: $e');
      // Show error snackbar
    }
  }









}

