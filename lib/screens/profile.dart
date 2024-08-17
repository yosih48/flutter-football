import 'dart:convert';
import 'package:football/providers/flutter%20pub%20add%20provider.dart';
import 'package:football/resources/auth.dart';
import 'package:football/screens/login_screen.dart';
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
        _fetchUserGroups(); // Refresh the groups list
      } else {
        throw Exception('Failed to create group');
      }
    } catch (e) {
      print('Error creating group: $e');
      // Show error message to user
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
    return Scaffold(
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
            colors: [Color(0xFF1E3A5F), Color(0xFF16243B)],
          ),
        ),
        child: Column(
          children: [
                SizedBox(height: kToolbarHeight + 100), // This accommodates the AppBar height
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('My Groups', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: _showCreateGroupDialog,
                    child: Text('Create New Group', style: TextStyle(color: Colors.white)),
                  ),
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
                        return ListTile(
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: 
                                  CircleAvatar(
                            backgroundColor: Colors.grey,
                            child: Text(groupName[0], style: TextStyle(color: Colors.white)),
                            radius: 25,
                          ),
                                           
                          title: Text(
                            groupName,
                            style: TextStyle(color: Colors.white, fontSize: 18),
                            textAlign: TextAlign.right,
                          ),
                          trailing: 
                          IconButton(
                            icon: Icon(Icons.exit_to_app, color: Colors.white),
                            onPressed: () {
                              // Handle exit action
                              print('Exiting group: $groupName');
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}