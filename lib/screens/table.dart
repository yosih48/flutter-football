import 'dart:convert';
import 'dart:math';
import 'package:clipboard/clipboard.dart';
import 'package:flutter/material.dart';
import 'package:football/models/games.dart';
import 'package:football/models/guesses.dart';
import 'package:football/models/users.dart';
import 'package:football/providers/flutter%20pub%20add%20provider.dart';
import 'package:football/providers/league_data_provider.dart';
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
   _fetchUsersForSelectedGroup();
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
                  _initializeData();
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
    _initializeData();
  }

  // Single initialization method that loads everything efficiently
  Future<void> _initializeData() async {
    setState(() => isLoading = true);

    try {
      // Get cached group name first
      final cachedGroupName =
          await SharedPreferencesUtil.getSelectedGroupName();

      // Single API call to get dashboard data
      final dashboardData =
          await GroupsMethods.fetchDashboardData(currentUserId);

      setState(() {
        // Set groups from API response
        _privateGroups =
            Map<String, String>.from(dashboardData['privateGroups'] ?? {});
        _publicGroups =
            Map<String, String>.from(dashboardData['publicGroups'] ?? {});

        print('Private groups: $_privateGroups');
        print('Public groups: $_publicGroups');

        // Determine selected group name
        selectedGroupName = _determineSelectedGroupName(cachedGroupName);
      });

      // Only fetch users if we have a valid group selection
      if (selectedGroupName.isNotEmpty && _privateGroups.isNotEmpty) {
        await _fetchUsersForSelectedGroup();
      } else {
        setState(() {
          _users = [];
          isLoading = false;
        });
      }
    } catch (e) {
      print('Failed to initialize data: $e');
      setState(() {
        _users = [];
        isLoading = false;
      });
    }
  }

  String _determineSelectedGroupName(String? cachedGroupName) {
    // Use widget's selected group name if provided
    if (widget.selectedGroupName != null &&
        widget.selectedGroupName!.isNotEmpty) {
      return widget.selectedGroupName!;
    }

    // Use cached group name if it exists in private groups
    if (cachedGroupName != null &&
        cachedGroupName.isNotEmpty &&
        _privateGroups.containsValue(cachedGroupName)) {
      return cachedGroupName;
    }

    // Default to first private group if available
    if (_privateGroups.isNotEmpty) {
      final firstGroupName = _privateGroups.values.first;
      // Update cache with new selection
      SharedPreferencesUtil.setSelectedGroupName(firstGroupName);
      return firstGroupName;
    }

    return ""; // No valid group found
  }
  Future<void> _fetchUsersForSelectedGroup() async {
    if (selectedGroupName.isEmpty) {
      setState(() {
        _users = [];
        isLoading = false;
      });
      return;
    }

    try {
      // Single API call to get users for the specific group and league
      final users =
          await GroupsMethods.fetchGroupUsers(selectedGroupName, league);

      setState(() {
        _users = users;
        isLoading = false;
      });

      print('Fetched ${users.length} users for group: $selectedGroupName');
    } catch (e) {
      print('Failed to fetch users for group: $e');
      setState(() {
        _users = [];
        isLoading = false;
      });
    }
  }
    // Method to change selected group (call this when user selects different group)
  Future<void> changeSelectedGroup(String newGroupName) async {
    if (newGroupName == selectedGroupName) return;

    setState(() {
      selectedGroupName = newGroupName;
      isLoading = true;
    });

    // Update cache
    await SharedPreferencesUtil.setSelectedGroupName(newGroupName);

    // Fetch users for new group
    await _fetchUsersForSelectedGroup();
  }

  // Refresh method for pull-to-refresh or manual refresh
  Future<void> refreshData() async {
    await _initializeData();
  }

  // Method to refresh only users (lighter refresh)
  Future<void> refreshUsers() async {
    await _fetchUsersForSelectedGroup();
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
                  child: LeagueSelector(
                    userId: currentUserId,
                    currentLeague: league,
                    useToggleButtons: true, // Use ToggleButtonsSample
                    onSelectionChanged: (leagueId, index) {
                      updateSelectedIndex(leagueId);
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
                                   _fetchUsersForSelectedGroup();
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
