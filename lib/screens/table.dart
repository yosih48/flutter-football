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
import 'package:football/screens/statistics.dart';
import 'package:football/theme/colors.dart';
import 'package:football/widgets/SharedPreferences.dart';
import 'package:football/widgets/toggleButton.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:football/l10n/app_localizations.dart';
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
  Map<String, String> _privateGroups = {};
  Map<String, String> _publicGroups = {};
  //  Map<String, dynamic> user = {};
  TextEditingController _inviteCodeController = TextEditingController();
  void updateSelectedIndex(int index) {
    print(index);
    setState(() {
      // league = index == 0
      //     ? 2 // Champions League
      //     : index == 1
      //         ? 383 // Ligat Ha'al
      //         : index == 2
      //             ? 140 // La Liga
      //             : index == 3
      //                 ? 3 // Europa League
      //                 : index == 4
      //                     ? 39 // Premier League
      //                          : index == 5
      //                         ? 848 // conferenceleague
      //                         : index == 6
      //                             ? 15 // Club World Cup
      //                             : index == 7
      //                                 ? 78 //Bundesliga
      //                         : 2; // Default to Champions League
      selectedIndex = index;
      league = index;
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white, // Set button background to white
              ),
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
        ? widget.selectedGroupName!
        : groupName != null
            ? groupName!
            : ""); // Use empty string instead of null
    print('widget.selectedGroupName');
    print(widget.selectedGroupName);
  });
  print('selectedGroupName shared: ${selectedGroupName}');
}

Future<void> _fetchUserGroups() async {
  final groupName = await SharedPreferencesUtil.getSelectedGroupName();

  try {
    Map<String, dynamic> userData = await UsersMethods().fetchUserById(currentUserId);
    final allGroups = await GroupsMethods().fetchGroups();

    print('All groups fetched: ${allGroups.length}');
    print('User group IDs: ${userData['groupID']}');

    setState(() {
      final userGroupIds = Map<String, String>.from(userData['groupID'] ?? {});

      // Separate private and public groups
      _privateGroups = {};
      _publicGroups = {};

      for (var group in allGroups) {
        final groupId = group['_id'];
        final groupName = group['name'];
        final groupType = group['type'];

        print('Group: $groupName, ID: $groupId, Type: $groupType');

        if (groupType == 'private' && userGroupIds.containsValue(groupName)) {
          _privateGroups[groupId] = groupName;
          print('Added to private: $groupName');
        } else if (groupType == 'public') {
          _publicGroups[groupId] = groupName;
          print('Added to public: $groupName');
        } else if (groupType == null) {
          if (userGroupIds.containsValue(groupName)) {
            _privateGroups[groupId] = groupName;
            print('Added to private (fallback): $groupName');
          } else {
            _publicGroups[groupId] = groupName;
            print('Added to public (fallback): $groupName');
          }
        }
      }

      print('Private groups: $_privateGroups');
      print('Public groups: $_publicGroups');

      // Set initial selectedGroupName if it's empty or not in private groups
      if (selectedGroupName.isEmpty || !_privateGroups.containsValue(selectedGroupName)) {
        if (_privateGroups.isNotEmpty) {
          selectedGroupName = _privateGroups.values.first;
          // Update SharedPreferences with the new selection
          SharedPreferencesUtil.setSelectedGroupName(selectedGroupName);
        } else {
          selectedGroupName = ""; // Keep empty if no private groups
        }
      }

      final selectedGroup = Provider.of<UserProvider>(context, listen: false);
      
      // Only fetch users if there are private groups and selectedGroupName is not empty
      if (_privateGroups.isNotEmpty && selectedGroupName.isNotEmpty) {
        _fetchUsersForGroup(selectedGroupName);
      } else {
        // Clear users list and show empty state
        _users = [];
        isLoading = false;
      }
    });
  } catch (e) {
    print('Failed to fetch user groups: $e');
    setState(() {
      _users = [];
      isLoading = false;
    });
  }
}

Future<void> _fetchUsersForGroup(String groupName) async {
  if (groupName.isEmpty || _privateGroups.isEmpty) {
    setState(() {
      _users = [];
      isLoading = false;
    });
    return;
  }

  try {
    List<Map<String, dynamic>> allUsers = await UsersMethods().fetchAllUsers();
    setState(() {
      _users = allUsers.where((user) {
        Map<String, dynamic>? groupID = user['groupID'];
        return groupID != null && groupID.containsValue(groupName);
      }).toList()
        ..sort((a, b) {
          num pointsA = a['points']?[league.toString()] ?? 0;
          num pointsB = b['points']?[league.toString()] ?? 0;
          return pointsB.compareTo(pointsA);
        });
      isLoading = false;
    });
  } catch (e) {
    print('Failed to fetch users for group: $e');
    setState(() {
      _users = [];
      isLoading = false;
    });
  }
}
  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
       
        title: Text(
          selectedGroupName != 'Public'?selectedGroupName: '' ,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 16),
            child: TextButton.icon(
              style: TextButton.styleFrom(
                backgroundColor: Colors.blue.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              icon: Icon(
                Icons.group_add,
                color: Colors.blue,
                size: 20,
              ),
              label: Text(
                AppLocalizations.of(context)!.joingroup,
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onPressed: _showJoinGroupDialog,
            ),
          ),
        ],
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            )
          : Column(
              children: [
                Container(
                  margin: EdgeInsets.symmetric(vertical: 8),
                  child: FutureBuilder<Map<String, dynamic>>(
                    future: UsersMethods().fetchUserById(currentUserId),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        final userData = snapshot.data!;
                        final chosenLeagues = Map<String, bool>.from(
                            userData['chosenLeagues'] ?? {});

                        // Create filtered lists based on chosen leagues
                        final enabledLeagues = <int>[
                          if (chosenLeagues['2'] == true) 2,
                          if (chosenLeagues['383'] == true) 383,
                          if (chosenLeagues['140'] == true) 140,
                          if (chosenLeagues['3'] == true) 3,
                          if (chosenLeagues['39'] == true) 39,
                          if (chosenLeagues['78'] == true) 78,
                          if (chosenLeagues['848'] == true) 848,
                          if (chosenLeagues['15'] == true) 15,
                        ];

                        final options = enabledLeagues.map((id) {
                          switch (id) {
                            case 2:
                              return AppLocalizations.of(context)!
                                  .championsleague;
                            case 383:
                              return AppLocalizations.of(context)!.ligathaal;
                            case 140:
                              return AppLocalizations.of(context)!.laliga;
                            case 3:
                              return AppLocalizations.of(context)!.europaleague;
                            case 39:
                              return AppLocalizations.of(context)!
                                  .premierleague;
                            case 78:
                              return AppLocalizations.of(context)!.bundesleague;
                            case 848:
                              return AppLocalizations.of(context)!
                                  .conferenceleague;
                            case 15:
                              return AppLocalizations.of(context)!.clubworldcup;
                            default:
                              return '';
                          }
                        }).toList();

                        final imageUrls = enabledLeagues.map((id) {
                          return 'https://media.api-sports.io/football/leagues/$id.png';
                        }).toList();

                        return ToggleButtonsSample(
                          options: options,
                          imageUrls: imageUrls,
                          onSelectionChanged: (index) {
                            final selectedLeagueId = enabledLeagues[index];
                            updateSelectedIndex(selectedLeagueId);
                          },
                          initialSelection: enabledLeagues.indexOf(league),
                        );
                      }
                      return CircularProgressIndicator();
                    },
                  ),
                ),
                Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Private Groups Dropdown
                    // Container(
                    //   margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    //   child: Text(
                    //     AppLocalizations.of(context)!.privategroups ??
                    //         'Private Groups',
                    //     style: TextStyle(
                    //       color: Colors.white,
                    //       fontSize: 16,
                    //       fontWeight: FontWeight.w600,
                    //     ),
                    //   ),
                    // ),
                    if (_privateGroups.isEmpty)
  Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.group_off, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
          AppLocalizations.of(context)!.nogroupsfound,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.nogroupsmessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
        ],
      ),
    ),
  )
  else
       Container(
                             margin:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                      ),
                     padding: EdgeInsets.symmetric(horizontal: 16),
                      child: _privateGroups.isEmpty
                          ? Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: Colors.blue, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                              AppLocalizations.of(context)!
                                          .notmemberanygroup,
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                   value: _privateGroups.isNotEmpty && selectedGroupName.isNotEmpty && _privateGroups.containsValue(selectedGroupName)
    ? selectedGroupName
    : (_privateGroups.isNotEmpty ? _privateGroups.values.first : null),
                                dropdownColor: cards,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.w500,
                                ),
                                icon: Icon(Icons.arrow_drop_down,
                                    color: Colors.blue),
                                isExpanded: true,
                                items: _privateGroups.entries.map((entry) {
                                  return DropdownMenuItem<String>(
                                    value: entry.value,
                                    child: Row(
                                      children: [
                                        Icon(Icons.lock,
                                            color: Colors.blue, size: 16),
                                        SizedBox(width: 8),
                                        Text(
                                          entry.value,
                                          style: TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
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
                    ),
                    // Public Groups Dropdown
                    // Container(
                    //   margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    //   child: Text(
                    //     AppLocalizations.of(context)!.publicgroups ??
                    //         'Public Groups',
                    //     style: TextStyle(
                    //       color: Colors.white,
                    //       fontSize: 16,
                    //       fontWeight: FontWeight.w600,
                    //     ),
                    //   ),
                    // ),
                  //   Container(
                  //       margin:
                  //           EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  //       decoration: BoxDecoration(
                  //         color: Colors.blue.withOpacity(0.1),
                  //         borderRadius: BorderRadius.circular(12),
                  //       ),
                  //       padding: EdgeInsets.symmetric(horizontal: 16),
                  //       child: DropdownButtonHideUnderline(
                  //         child: DropdownButton<String>(
                  //  value: _publicGroups.isNotEmpty
                  //               ? _publicGroups.values.first
                  //               : null,
                  //           dropdownColor: cards,
                  //           style: TextStyle(
                  //             color: Colors.white,
                  //             fontSize: 16.0,
                  //             fontWeight: FontWeight.w500,
                  //           ),
                  //           icon: Icon(Icons.arrow_drop_down,
                  //               color: Colors.blue),
                  //           isExpanded: true,
                        
                  //           items: _publicGroups.entries.map((entry) {
                  //             return DropdownMenuItem<String>(
                  //               value: entry.value,
                  //               child: Row(
                  //                 children: [
                  //                   Icon(Icons.public,
                  //                  color: Colors.blue, size: 16),
                  //                   SizedBox(width: 8),
                  //                   Text(
                  //                     entry.value,
                  //                     style: TextStyle(
                  //                       color: Colors.white,
                  //                     ),
                  //                   ),
                  //                 ],
                  //               ),
                  //             );
                  //           }).toList(),
                  //           onChanged: (String? newValue) {
                  //             if (newValue != null) {
                  //               setState(() {
                  //                 selectedGroupName = newValue;
                  //               });
                  //               _fetchUsersForGroup(newValue);
                  //             }
                  //           },
                  //         ),
                  //       ))
                  ],
                ),
                   if (_privateGroups.isNotEmpty)
                Expanded(
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  dividerColor: Colors.blue.withOpacity(0.1),
                                ),
                                child: DataTable(
                                  headingRowHeight: 50,
                                  dataRowHeight: 56,
                                  columnSpacing: 16,
                                  horizontalMargin: 16,
                                  headingRowColor: MaterialStateProperty.all(
                                    Colors.blue.withOpacity(0.1),
                                  ),
                                  columns: [
                                    DataColumn(
                                      label: Text(
                                        AppLocalizations.of(context)!.name,
                                        style: TextStyle(
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Text(
                                        AppLocalizations.of(context)!.daypoints,
                                        style: TextStyle(
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      numeric: true,
                                    ),
                                    DataColumn(
                                      label: Text(
                                        AppLocalizations.of(context)!.sumpoints,
                                        style: TextStyle(
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      numeric: true,
                                    ),
                                  ],
                                  rows: _users.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final user = entry.value;
                                    print('entry${entry}');
                                    print('user${user}');
                                    return DataRow(
                                      color: MaterialStateProperty.resolveWith<
                                          Color?>(
                                        (Set<MaterialState> states) {
                                          if (index % 2 == 0) {
                                            return Colors.blue
                                                .withOpacity(0.03);
                                          }
                                          return null;
                                        },
                                      ),
                                      cells: [
                                        DataCell(
                                          Row(
                                            children: [
                                              Text(
                                                '${index + 1}.',
                                                style: TextStyle(
                                                  color: Colors.grey,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                user['displayName'] ?? '0',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    Statistics(
                                                  userId: user['_id'],
                                                  leagueId: league,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        DataCell(
                                          Text(
                                            user['thisDayPoints']
                                                        ?[league.toString()]
                                                    ?.toString() ??
                                                '0',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    Statistics(
                                                  userId: user['_id'],
                                                  leagueId: league,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        DataCell(
                                          Text(
                                            user['points']?[league.toString()]
                                                    ?.toString() ??
                                                '0',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    Statistics(
                                                  userId: user['_id'],
                                                  leagueId: league,
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                  (_privateGroups.isNotEmpty)
                    ? Container(
                        margin: EdgeInsets.all(16),
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.blue.withOpacity(0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                          icon: Icon(
                            Icons.share,
                            color: Colors.blue,
                            size: 20,
                          ),
                          label: Text(
                            AppLocalizations.of(context)!.invitefriend,
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onPressed: () => _inviteFriend(selectedGroupName),
                        ),
                      )
                    : SizedBox(
                        height: 2,
                      ),
              ],
            ),
    );
  }
}
