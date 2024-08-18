import 'dart:convert';
import 'dart:math';
import 'package:clipboard/clipboard.dart';
import 'package:flutter/material.dart';
import 'package:football/models/games.dart';
import 'package:football/models/guesses.dart';
import 'package:football/models/users.dart';
import 'package:football/providers/flutter%20pub%20add%20provider.dart';
import 'package:football/resources/auth.dart';
import 'package:football/resources/groupsMethods.dart';
import 'package:football/resources/guessesMethods.dart';
import 'package:football/resources/usersMethods.dart';
import 'package:football/screens/login_screen.dart';
import 'package:football/widgets/toggleButton.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

class TableScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, UserProvider>(
      builder: (context, authProvider, userProvider, child) {
        // Check if user is authenticated
        if (authProvider.user == null) {
          return LoginScreen(); // Or some other widget for unauthenticated users
        }
        return TableScreenContent(
          authProvider: authProvider,
          userProvider: userProvider,
        );
      },
    );
  }
}

class TableScreenContent extends StatefulWidget {
  final AuthProvider authProvider;
  final UserProvider userProvider;

  TableScreenContent({
    required this.authProvider,
    required this.userProvider,
  });

  @override
  TableScreenContentState createState() => TableScreenContentState();
}

class TableScreenContentState extends State<TableScreenContent> {
  List<Map<String, dynamic>> _users = [];
  int selectedIndex = 0;
  String _selectedGroupName = '';
  Map<String, String> _userGroups = {};
  int league = 2;
  late String currentUserId;
   Map<String, dynamic> user = {};
   TextEditingController _inviteCodeController = TextEditingController();
  void updateSelectedIndex(int index) {
    print(index);
    setState(() {
      league = index == 0
          ? 2
          : index == 1
              ? 4
              : 140;
      selectedIndex = index;
    });
    _fetchUsersForGroup(_selectedGroupName);
  }
    void _showInviteDialog(String inviteCode) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Invite Friend'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Invite code copied to clipboard:'),
              SizedBox(height: 10),
              Text(inviteCode, style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 20),
              Text(
                  'Share this code with your friend to invite them to the group.'),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _inviteFriend(String groupName) async {
    print(groupName);
    // try {
    //   final response = await http.post(
    //     Uri.parse('https://leagues.onrender.com/groups/createInvite'),
    //     body: json.encode({'groupName': groupName}),
    //     headers: {'Content-Type': 'application/json'},
    //   );

    //   if (response.statusCode == 200) {
    //   } else {
    //     print('Failed to create invite code');
    //   }
    // } catch (e) {
    //   print('Error creating invite: $e');
    // }
        // final inviteCode = json.decode(response.body)['inviteCode'];
        FlutterClipboard.copy(groupName)
        .then((value) => print('copied'));
              _showInviteDialog(groupName);
    //  await FlutterClipboardManager.copyToClipBoard(groupName);
  }
   void _showJoinGroupDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Join Group'),
          content: TextField(
            controller: _inviteCodeController,
            decoration: InputDecoration(hintText: "Enter invite code"),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text('Join'),
              onPressed: ()async {
                if (_inviteCodeController.text.isNotEmpty) {
              await  GroupsMethods().addGroupToUser(_inviteCodeController.text, user, currentUserId);
              _fetchUserGroups();
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }
  //   Future<void> _addGroupToUser(String groupName) async {
  //   final existingGroupKeys =
  //       user['groupID']?.keys?.map((key) => int.parse(key))?.toList() ?? [];
  //   final nextKey = existingGroupKeys.isEmpty
  //       ? 1
  //       : (existingGroupKeys.reduce(max) + 1).toString();
  //   print('existingGroupKeys: ${existingGroupKeys}');
  //   final url = Uri.parse('https://leagues.onrender.com/users/');
  //   try {
  //     final response = await http.put(
  //       url,
  //       body: jsonEncode({
  //         '_id': currentUserId,
  //         'groups': user['groupID'],
  //         'email': user['email'],
  //         '\$set': {
  //           'groupID.$nextKey': groupName,
  //         },
  //       }),
  //       headers: {
  //         'Content-type': 'application/json; charset=UTF-8',
  //       },
  //     );

  //     if (response.statusCode == 200) {
  //       final data = json.decode(response.body);
  //       if (data['message'] == 'Group name already exists') {
  //         print('Group name already exists');
  //         // Show snackbar or alert
  //       } else {
  //         print('User updated successfully');
  //         // Show success snackbar
  //         _fetchUserGroups(); // Refresh user data
  //       }
  //     } else {
  //       print('User update failed with status: ${response.statusCode}');
  //       // Show error snackbar
  //     }
  //   } catch (e) {
  //     print('Error updating user: $e');
  //     // Show error snackbar
  //   }
  // }

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
        if (_userGroups.isNotEmpty) {
          _selectedGroupName = _userGroups.values.first;
          _fetchUsersForGroup(_selectedGroupName);
        }
      });
    } catch (e) {
      print('Failed to fetch user groups: $e');
    }
  }

  Future<void> _fetchUsersForGroup(String groupName) async {
    try {
      List<Map<String, dynamic>> allUsers =
          await UsersMethods().fetchAllUsers();
      setState(() {
        _users = allUsers.where((user) {
          Map<String, dynamic>? groupID = user['groupID'];
          return groupID != null && groupID.containsValue(groupName);
        }).toList()
          ..sort((a, b) {
            num pointsA = a['points']?[league.toString()] ?? 0;
            num pointsB = b['points']?[league.toString()] ?? 0;
            return pointsB.compareTo(pointsA); // Sort in descending order
          });
      });
    } catch (e) {
      print('Failed to fetch users for group: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Table'),
               actions: [
          IconButton(
            icon: Icon(Icons.group_add),
            onPressed: _showJoinGroupDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          ToggleButtonsSample(
            options: ['champ', 'euro', 'spain'],
            onSelectionChanged: updateSelectedIndex,
            initialSelection: 0,
          ),
          Expanded(
            child: table(league),
          ),
        ],
      ),
    );
  }

  Widget table(league) {
    return Column(
      children: [
        DropdownButton<String>(
          value: _selectedGroupName,
          items: _userGroups.entries.map((entry) {
            return DropdownMenuItem<String>(
              value: entry.value,
              child: Text(entry.value),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedGroupName = newValue;
              });
              _fetchUsersForGroup(newValue);
            }
          },
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('name')),
                  DataColumn(label: Text('day points')),
                  DataColumn(label: Text('sum points')),
                  // DataColumn(label: Text('Sum Points')),
                ],
                rows: _users
                    .map((user) => DataRow(
                          cells: [
                            DataCell(
                              Center(
                                child: Text(
                                  user['displayName'] ?? '0',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            DataCell(
                              Center(
                                child: Text(
                                  user['thisDayPoints']?[league.toString()]
                                          ?.toString() ??
                                      '0',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            DataCell(
                              Center(
                                child: Text(
                                  user['points']?[league.toString()]
                                          ?.toString() ??
                                      '0',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ))
                    .toList(),
              ),
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.share),
          onPressed: () => _inviteFriend(_selectedGroupName),
        ),
      ],
    );
  }
}
