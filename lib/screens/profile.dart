import 'dart:convert';
import 'dart:math';
import 'package:football/providers/flutter%20pub%20add%20provider.dart';
import 'package:football/resources/auth.dart';
import 'package:football/screens/login_screen.dart';
import 'package:football/screens/table.dart';
import 'package:football/theme/colors.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:football/resources/usersMethods.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, UserProvider>(
      builder: (context, authProvider, userProvider, child) {
        // Check if user is authenticated
        if (authProvider.user == null) {
          return LoginScreen(); // Or some other widget for unauthenticated users
        }
        return ProfileScreenContent(
          authProvider: authProvider,
          userProvider: userProvider,
        );
      },
    );
  }
}

class ProfileScreenContent extends StatefulWidget {
  final AuthProvider authProvider;
  final UserProvider userProvider;

  ProfileScreenContent({
    required this.authProvider,
    required this.userProvider,
  });
  @override
  _ProfileScreenContentState createState() => _ProfileScreenContentState();
}

class _ProfileScreenContentState extends State<ProfileScreenContent> {
  Map<String, String> _userGroups = {};
  late String currentUserId;
  TextEditingController _groupNameController = TextEditingController();
  Map<String, dynamic> user = {};

  @override
  void initState() {
    super.initState();
    currentUserId = widget.authProvider.user?.id ?? 'Not logged in';
    _fetchUserGroups();
  }

  Future<void> _fetchUserGroups() async {
    try {
      Map<String, dynamic> userData =
          await UsersMethods().fetchUserById(currentUserId);
      setState(() {
        _userGroups = Map<String, String>.from(userData['groupID'] ?? {});
      });
    } catch (e) {
      print('Failed to fetch user groups: $e');
    }
  }

  Future<void> _createNewGroup(String groupName) async {
    final url = Uri.parse('https://leagues.onrender.com/groups/add');
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
        await _addGroupToUser(groupName);
      } else {
        throw Exception('Failed to create group');
      }
    } catch (e) {
      print('Error creating group: $e');
      // Show error message to user
    }
  }

  Future<void> _addGroupToUser(String groupName) async {
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
          _fetchUserGroups(); // Refresh user data
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

  void _showCreateGroupDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Create New Group'),
          content: TextField(
            controller: _groupNameController,
            decoration: InputDecoration(hintText: "Enter group name"),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text('Create'),
              onPressed: () {
                if (_groupNameController.text.isNotEmpty) {
                  _createNewGroup(_groupNameController.text);
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedGroup = Provider.of<UserProvider>(context);
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: Text('הקבוצות שלי', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF16181b), Color(0xFF16181b)],
          ),
        ),
        child: Column(
          children: [
            SizedBox(
                height: kToolbarHeight +
                    100), // This accommodates the AppBar height
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('My Groups',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    icon: Icon(Icons.add),
                    label: Text(
                      'צור קבוצה',
                      style: TextStyle(
                          color: Colors.white), // Change the color here
                    ),
                    onPressed: _showCreateGroupDialog,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors
                          .white, // This changes the color of the icon and text
                    ),
                  )
                ],
              ),
            ),
            //  SizedBox(height: 10),
            Expanded(
              child: _userGroups.isEmpty
                  ? Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _userGroups.length,
                      itemBuilder: (context, index) {
                        String groupId = _userGroups.keys.elementAt(index);
                        String groupName = _userGroups.values.elementAt(index);
                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => TableScreen(
                                      selectedGroupName: groupName)),
                            );
                          },
                          child: ListTile(
                  
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: Colors.grey,
                              child: Text(groupName[0],
                                  style: TextStyle(color: Colors.white)),
                              radius: 18,
                            ),
                            title: Text(
                              groupName,
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16),
                              textAlign: TextAlign.right,
                            ),
                   trailing: Row(
                              mainAxisSize: MainAxisSize
                                  .min, // Ensures the Row takes up only the necessary width
                              children: [
                                IconButton(
                                  icon: Icon(Icons.star,
                                    color: selectedGroup.selectedGroupName ==
                                            groupName
                                        ? Colors.amber
                                        : Colors.white,
                                  ),
                                  onPressed: () {
                                     
                                      selectedGroup.setSelectedGroupName(groupName);
                                      print(' set groupName: ${groupName}');
                                     
              
                                  },
                                ),
                                IconButton(
                                  icon: Icon(Icons.exit_to_app,
                                      color: Colors.white),
                                  onPressed: () {
                                    // Handle exit action
                                    print('Exiting group: $groupName');
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                final authProvider =
                    Provider.of<AuthProvider>(context, listen: false);
                await authProvider.signOut();
                if (context.mounted) {}
              },
              child: const Text('Signout'),
            ),
          ],
        ),
      ),
    );
  }
}
