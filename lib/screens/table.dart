import 'dart:convert';
import 'dart:math';
import 'package:clipboard/clipboard.dart';
import 'package:flutter/material.dart';
import 'package:football/models/games.dart';
import 'package:football/models/guesses.dart';
import 'package:football/models/users.dart';
import 'package:football/providers/flutter%20pub%20add%20provider.dart';
import 'package:football/resources/appUpdates.dart';
import 'package:football/resources/auth.dart';
import 'package:football/resources/groupsMethods.dart';
import 'package:football/resources/guessesMethods.dart';
import 'package:football/resources/usersMethods.dart';
import 'package:football/screens/login_screen.dart';
import 'package:football/theme/colors.dart';
import 'package:football/widgets/SharedPreferences.dart';
import 'package:football/widgets/toggleButton.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
class TableScreen extends StatelessWidget {
  final String? selectedGroupName;

  TableScreen({this.selectedGroupName});
  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, UserProvider>(
      builder: (context, authProvider, userProvider, child) {
        // Check if user is authenticated
        if (authProvider.currentUser == null) {
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
  late String selectedGroupName = "";
  Map<String, String> _userGroups = {};
  int league = 2;
  late String currentUserId;
  bool isLoading = true;
  //  Map<String, dynamic> user = {};
  TextEditingController _inviteCodeController = TextEditingController();
  void updateSelectedIndex(int index) {
    print(index);
    setState(() {
      league = index == 0
          ? 2
          : index == 1
              ? 383
              : index == 2
                  ? 140
                  : 3;
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
          backgroundColor: cards,
          title: Text(
            AppLocalizations.of(context)!.invitefriend,
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context)!.invitecodecopy,
                style: TextStyle(color: Colors.white),
              ),
              SizedBox(height: 10),
              Text(inviteCode,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white)),
              SizedBox(height: 20),
              Text(
                AppLocalizations.of(context)!.shareinvitecode,
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'OK',
                style: TextStyle(color: Colors.blue),
              ),
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

      // Copy the group's code to the clipboard
      final groupCode = group['_id'];
      await FlutterClipboard.copy(groupCode);
      print('Group code copied: $groupCode');

      // Show the invite dialog
      _showInviteDialog(groupCode);
    } catch (e) {
      print('Error inviting friend: $e');
    }
  }

  void _showJoinGroupDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: cards,
          title: Text(AppLocalizations.of(context)!.joingroup,
              style: TextStyle(color: Colors.white, fontSize: 14)),
          content: TextField(
            controller: _inviteCodeController,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.enterinvitecode,
              labelStyle: TextStyle(
                color: Colors.blue, // Change this to your desired color
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                    color: Colors.blue), // Bottom border color when enabled
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.blue, width: 2.0),
                // Bottom border color when focused, with thicker border
              ),
            ),
            style: TextStyle(
              color: Colors.white, // Change the input text color to blue
            ),
            cursorColor: Colors.blue,
          ),
          actions: <Widget>[
            TextButton(
              child: Text(AppLocalizations.of(context)!.cancel,
                  style: TextStyle(color: Colors.blue)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text(AppLocalizations.of(context)!.join,
                  style: TextStyle(color: Colors.blue)),
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
    currentUserId = widget.authProvider.currentUser?.id ?? 'Not logged in';
    league = widget.userProvider.selectedLeageId ?? 2;
    print('currentUserId table: ${currentUserId}');
    _loadSelectedGroupName();
    _fetchUserGroups();
  }

  Future<void> _loadSelectedGroupName() async {
    final groupName = await SharedPreferencesUtil.getSelectedGroupName();
    print('groupName: ${groupName}');
    setState(() {
      selectedGroupName = (widget.selectedGroupName != null
          ? widget.selectedGroupName
          : groupName != null
              ? groupName!
              : 'public')!;
      print('widget.selectedGroupName');
      print(widget.selectedGroupName);
    });
    print('selectedGroupName shared: ${selectedGroupName}');
  }

  Future<void> _fetchUserGroups() async {
    final groupName = await SharedPreferencesUtil.getSelectedGroupName();

    try {
      Map<String, dynamic> userData =
          await UsersMethods().fetchUserById(currentUserId);
      setState(() {
        _userGroups = Map<String, String>.from(userData['groupID'] ?? {});

        final selectedGroup = Provider.of<UserProvider>(context, listen: false);

        // if (_userGroups.isNotEmpty) {
        //   if (selectedGroup.selectedGroupName == 'default') {
        //     // Assign the first value from _userGroups
        //     selectedGroupName = _userGroups.values.first;
        //   } else {
        //     // Otherwise, use the value from selectedGroup
        //     selectedGroupName =
        //         widget.selectedGroupName ?? selectedGroup.selectedGroupName;
        //   }

        // }
        _fetchUsersForGroup(selectedGroupName);
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
        isLoading = false;
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
        // title: Text(
        //   AppLocalizations.of(context)!.table,
        //   style: TextStyle(
        //     color: white, // White color for the team names
        //   ),
        // ),
        actions: [
          TextButton.icon(
            icon: Icon(
              Icons.group_add,
              color: Colors.white,
            ),
            label: Text(
              AppLocalizations.of(context)!.joingroup,
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
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                ToggleButtonsSample(
                  options: [
                    AppLocalizations.of(context)!.championsleague,
                    AppLocalizations.of(context)!.ligathaal,
                    AppLocalizations.of(context)!.laliga,
                    AppLocalizations.of(context)!.europaleague,
                  ],
                  imageUrls: [
                    'https://media.api-sports.io/football/leagues/2.png',
                    'https://media.api-sports.io/football/leagues/383.png',
                    'https://media.api-sports.io/football/leagues/140.png',
                    'https://media.api-sports.io/football/leagues/3.png', // Assuming this is Europa League
                  ],
                  onSelectionChanged: updateSelectedIndex,
                  initialSelection: league == 2
                      ? 0
                      : league == 383
                          ? 1
                          : league == 140
                              ? 2
                              : 3,
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
        Container(
          width: 300,
          child: DropdownButton<String>(
            value: selectedGroupName,
            dropdownColor: cards,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.0,
            ),
            isExpanded: true,
            items: _userGroups.entries.map((entry) {
              return DropdownMenuItem<String>(
                value: entry.value,
                child: Text(
                  entry.value,
                  style: TextStyle(
                    color: Colors.white,
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
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      columnSpacing: 0,
                      horizontalMargin: 0,
                      columns: [
                        DataColumn(
                          label: Expanded(
                            child: Center(
                              child: Text(
                                AppLocalizations.of(context)!.name,
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Expanded(
                            child: Center(
                              child: Text(
                                AppLocalizations.of(context)!.daypoints,
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Expanded(
                            child: Center(
                              child: Text(
                                AppLocalizations.of(context)!.sumpoints,
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ],
                      rows: _users
                          .map((user) => DataRow(
                                cells: [
                                  DataCell(
                                    Center(
                                      child: Text(
                                        user['displayName'] ?? '0',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Center(
                                      child: Text(
                                        user['thisDayPoints']
                                                    ?[league.toString()]
                                                ?.toString() ??
                                            '0',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Colors.white),
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
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ))
                          .toList(),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        TextButton.icon(
          icon: Icon(
            Icons.add,
            color: Colors.white,
          ),
          label: Text(
            AppLocalizations.of(context)!.invitefriend,
            style: TextStyle(
              color: white,
            ),
          ),
          onPressed: () => _inviteFriend(selectedGroupName),
        ),
      ],
    );
  }
}
