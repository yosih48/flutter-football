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
import 'package:football/theme/colors.dart';
import 'package:football/widgets/toggleButton.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

class TableScreen extends StatelessWidget {
  final String? selectedGroupName;

  TableScreen({this.selectedGroupName});
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
          selectedGroupName: selectedGroupName,
        );
      },
    );
  }
}

class TableScreenContent extends StatefulWidget {
  final AuthProvider authProvider;
  final UserProvider userProvider;
  final String? selectedGroupName;

  TableScreenContent({
    required this.authProvider,
    required this.userProvider,
    this.selectedGroupName,
  });

  @override
  TableScreenContentState createState() => TableScreenContentState();
}

class TableScreenContentState extends State<TableScreenContent> {
  List<Map<String, dynamic>> _users = [];
  int selectedIndex = 0;
  late String selectedGroupName ="";
  Map<String, String> _userGroups = {};
  int league = 2;
  late String currentUserId;
  //  Map<String, dynamic> user = {};
  TextEditingController _inviteCodeController = TextEditingController();
  void updateSelectedIndex(int index) {
    print(index);
    setState(() {
      league = index == 0
          ? 2
          : index == 1
              ? 383
              : 140;
      selectedIndex = index;
             Provider.of<UserProvider>(context, listen: false)
          .setselectedLeageId(league);
    });
    _fetchUsersForGroup(selectedGroupName);
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
    try {
      // Fetch the list of groups
      final groups = await GroupsMethods().fetchGroups();

      // Find the group with the specified name
      final group = groups.firstWhere(
        (g) => g['name'] == groupName,
      );

      if (group != null) {
        // Copy the group's code to the clipboard
        final groupCode = group['_id'];
        await FlutterClipboard.copy(groupCode);
        print('Group code copied: $groupCode');

        // Show the invite dialog
        _showInviteDialog(groupCode);
      } else {
        print('Group not found');
      }
    } catch (e) {
      print('Error inviting friend: $e');
    }
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
              onPressed: () async {
                if (_inviteCodeController.text.isNotEmpty) {
                  await GroupsMethods().addGroupToUser(
                      _inviteCodeController.text, currentUserId, context);
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

  @override
  void initState() {
    super.initState();
    currentUserId = widget.authProvider.user?.id ?? 'Not logged in';
  league = widget.userProvider.selectedLeageId ?? 2;
    _fetchUserGroups();
  }

  Future<void> _fetchUserGroups() async {
    try {
      Map<String, dynamic> userData =
          await UsersMethods().fetchUserById(currentUserId);
      setState(() {
        _userGroups = Map<String, String>.from(userData['groupID'] ?? {});

        final selectedGroup = Provider.of<UserProvider>(context, listen: false);

        if (_userGroups.isNotEmpty) {
          if (selectedGroup.selectedGroupName == 'default') {
            // Assign the first value from _userGroups
            selectedGroupName = _userGroups.values.first;
          } else {
            // Otherwise, use the value from selectedGroup
            selectedGroupName =
                widget.selectedGroupName ?? selectedGroup.selectedGroupName;
          }

          _fetchUsersForGroup(selectedGroupName);
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
        //  print('users: ${_users}');
      });
    } catch (e) {
      print('Failed to fetch users for group: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Table',
          style: TextStyle(
            color: white, // White color for the team names
          ),
        ),
        actions: [
          TextButton.icon(
            icon: Icon(
              Icons.group_add,
              color: Colors.white,
            ),
            label: Text(
              'הצטרף לקבוצה',
              style: TextStyle(
                color: white, // White color for the team names
              ),
            ),
            onPressed: _showJoinGroupDialog,
          ),
        ],
        iconTheme: IconThemeData(
          color: Colors.white, // Set the color of the arrow icon to white
        ),
      ),
      body: Column(
        children: [
          ToggleButtonsSample(
            options: ['Champ', 'Israel', 'Spain'],
            onSelectionChanged: updateSelectedIndex,
            initialSelection:  league == 2
        ? 0
        : league == 383
            ? 1
            : 2,
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
          value: selectedGroupName,
          dropdownColor: cards, // Set the dropdown background color
          style: TextStyle(
            color: Colors.white, // Set the dropdown text color
            fontSize: 16.0,
          ),
          items: _userGroups.entries.map((entry) {
            return DropdownMenuItem<String>(
              value: entry.value,
              child: Text(
                entry.value,
                style: TextStyle(
                  color: Colors.white, // Set the dropdown item text color
                ),
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() {
                selectedGroupName = newValue;
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
                  DataColumn(
                      label: Text(
                    'name',
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  )),
                  DataColumn(
                      label: Text('day points',
                          style: TextStyle(
                            color: Colors.white,
                          ))),
                  DataColumn(
                      label: Text('sum points',
                          style: TextStyle(
                            color: Colors.white,
                          ))),
                  // DataColumn(label: Text('Sum Points')),
                ],
                rows: _users
                    .map((user) => DataRow(
                          cells: [
                            DataCell(
                              Center(
                                child: Text(user['displayName'] ?? '0',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                    )),
                              ),
                            ),
                            DataCell(
                              Center(
                                child: Text(
                                    user['thisDayPoints']?[league.toString()]
                                            ?.toString() ??
                                        '0',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                    )),
                              ),
                            ),
                            DataCell(
                              Center(
                                child: Text(
                                    user['points']?[league.toString()]
                                            ?.toString() ??
                                        '0',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                    )),
                              ),
                            ),
                          ],
                        ))
                    .toList(),
              ),
            ),
          ),
        ),
        TextButton.icon(
          icon: Icon(
            Icons.add,
            color: Colors.white,
          ),
          label: Text(
            'הזמן חברים',
            style: TextStyle(
              color: white, // White color for the team names
            ),
          ),
          onPressed: () => _inviteFriend(selectedGroupName),
        ),
      ],
    );
  }
}
