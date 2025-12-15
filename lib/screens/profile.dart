import 'dart:convert';
import 'dart:math';
import 'package:football/providers/flutter%20pub%20add%20provider.dart';
import 'package:football/resources/auth.dart';
import 'package:football/resources/groupsMethods.dart';


import 'package:football/screens/login_screen.dart';
import 'package:football/screens/table.dart';
import 'package:football/theme/colors.dart';
import 'package:football/utils/config.dart';
import 'package:football/widgets/SharedPreferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:football/resources/usersMethods.dart';
import 'package:provider/provider.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:football/screens/account_screen.dart';
import 'package:football/providers/theme_provider.dart';

import 'instructionsb.dart';


// AppLocalizations.of(context)!.assigncall
class ProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, UserProvider>(
      builder: (context, authProvider, userProvider, child) {
        // Check if user is authenticated
        if (authProvider.currentUser == null) {
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
  Map<String, String> _userWinners = {};
  Map<String, String> _userTopScorer = {};
  Map<String, int> _userTopScorerPoints = {};
  List<Map<String, dynamic>> _groupsInfo = [];
  bool _isLoadingGroups = true;
  bool _showWinners = true; // Toggle state for Winners/Top Scorers
  late String currentUserId;
  late String currentUserEmail;
  TextEditingController _groupNameController = TextEditingController();
  Map<String, dynamic> user = {};
  late String selectedGroupName = "";
  //  const _baseUrl = 'https://leagues.onrender.com';
  String _baseUrl = backendUrl;
  @override
  void initState() {
    super.initState();
    currentUserId = widget.authProvider.currentUser?.id ?? 'Not logged in';
    currentUserEmail =
        widget.authProvider.currentUser?.email ?? 'Not logged in';
   
    _fetchUserData();
    _initializeGroupSelection(); 
  }

Future<void> _initializeGroupSelection() async {
    await _fetchUserGroups(); // Fetch groups first
    await _loadSelectedGroupName(); // Then load/set the selected group
  }

Future<void> _loadSelectedGroupName() async {
    final sharedGroupName = await SharedPreferencesUtil.getSelectedGroupName();
    String groupName;

    if (sharedGroupName == null) {
      // Use first group from user's groups as default, fallback to 'public'
      if (_userGroups.isNotEmpty) {
        groupName = _userGroups.values.first;
      } else {
        groupName = 'public'; // Fallback if no groups exist
      }
      await SharedPreferencesUtil.setSelectedGroupName(groupName);
    } else {
      groupName = sharedGroupName;
    }

    setState(() {
      selectedGroupName = groupName;
    });
    print('selectedGroupName shared: ${selectedGroupName}');
  }

 Future<void> _fetchUserGroups() async {
    try {
      Map<String, dynamic> userData =
          await UsersMethods().fetchUserById(currentUserId);
      List<Map<String, dynamic>> groupsInfo =
          await GroupsMethods().fetchGroups();

      setState(() {
        _userGroups = Map<String, String>.from(userData['groupID'] ?? {});
        _userWinners = Map<String, String>.from(userData['winner'] ?? {});
        _userTopScorer = Map<String, String>.from(userData['topScorer'] ?? {});
        _userTopScorerPoints =
            Map<String, int>.from(userData['topScorerPoints'] ?? {});
        _groupsInfo = groupsInfo;

        // Remove the complex default group selection logic from here
        // It's now handled in _loadSelectedGroupName()

        Provider.of<UserProvider>(context, listen: false)
            .setCurrentUser(currentUserId);
        _isLoadingGroups = false;
      });
    } catch (e) {
      print('Failed to fetch user groups: $e');
      setState(() {
        _isLoadingGroups = false;
      });
    }
  }

  Future<void> leaveGroup(String groupName) async {
    // Find the group ID to delete
    String? groupIdToDelete = _userGroups.entries
        .firstWhere((entry) => entry.value == groupName,
            orElse: () => MapEntry('', ''))
        .key;

    if (groupIdToDelete.isEmpty) {
      print('Group not found');
      return;
    }

    // Show confirmation dialog
    bool isConfirmed = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: cards,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            AppLocalizations.of(context)!.leavethegroup,
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: Text(
            AppLocalizations.of(context)!.leavegroup,
            style: TextStyle(color: Colors.white70),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                AppLocalizations.of(context)!.cancel,
                style: TextStyle(color: Colors.grey),
              ),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                   backgroundColor: Colors.red.withOpacity(0.2),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                   elevation: 0,
                ),
                child: Text(
                  AppLocalizations.of(context)!.leave,
                  style: TextStyle(color: Colors.red),
                ),
                onPressed: () async {
                  final sharedGroupName =
                      await SharedPreferencesUtil.getSelectedGroupName();

                  Navigator.of(context).pop(true);
                  if (sharedGroupName == groupName) {
                    await SharedPreferencesUtil.setSelectedGroupName('public');

                    _loadSelectedGroupName();
                  }
                }),
          ],
        );
      },
    );

    if (isConfirmed == true) {
      // Remove the group from the local state
      setState(() {
        _userGroups.remove(groupIdToDelete);
      });

      // Update the server
      try {
        final response = await http.put(
          Uri.parse('$_baseUrl/users/'),
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: jsonEncode(<String, dynamic>{
            '_id': currentUserId,
            'groupID': _userGroups,
          }),
        );

        if (response.statusCode == 200) {
          print('Successfully left the group');
          // You might want to update the UserProvider here
          // Provider.of<UserProvider>(context, listen: false).updateGroups(_userGroups);
        } else {
          print('Failed to leave group. Status code: ${response.statusCode}');
          // Revert the local change if the server update failed
          await _fetchUserGroups();
        }
      } catch (e) {
        print('Error leaving group: $e');
        // Revert the local change if there was an error
        await _fetchUserGroups();
      }
    } else {
      print('Group leaving cancelled by user');
    }
  }

  Future<void> _createNewGroup(String groupName) async {
    final url = Uri.parse('$_baseUrl/groups/add');
    try {
      final response = await http.post(
        url,
        body: jsonEncode({
          'name': groupName,
          'createdBy': currentUserId,
          'type': 'private',
          'code': DateTime.now().millisecondsSinceEpoch,
        }),
        headers: {
          'Content-type': 'application/json; charset=UTF-8',
          // 'Authorization': 'Bearer ${userToken}', // Uncomment if needed
        },
      );
      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Group created successfully
          ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.groupcreatedsuccessfully),
            backgroundColor: primary,
            duration: Duration(seconds: 3),
          ),
        );
        await _addGroupToUser(groupName);
       } else {
        // Handle error from server
        String errorMessage = responseData['msg'] ?? 'Unknown error occurred';
 
 if(errorMessage == 'group name is already exist'){
  errorMessage = AppLocalizations.of(context)!.groupnamealreadyexists;
 }       // Display error message to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      } 
    } catch (e) {
      print('Error creating group: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating group: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _fetchUserData() async {
    // Fetch user data including groupID
    // This is a placeholder - replace with your actual API call
    try {
      final _user = await UsersMethods().fetchUserById(currentUserId);

      print('_user: ${_user}');
      setState(() {
        user = Map<String, String>.from(_user['groupID'] ?? {});
        print(' user: ${user}');
      });
    } catch (e) {
      print('Error fetching user data: $e');
    }
  }

  Future<void> _addGroupToUser(String groupName) async {
    final existingGroupKeys =
        user?.keys?.map((key) => int.parse(key))?.toList() ?? [];
    final nextKey = existingGroupKeys.isEmpty
        ? 1
        : (existingGroupKeys.reduce(max) + 1).toString();

    final url = Uri.parse('$_baseUrl/users/');
    try {
      final response = await http.put(
        url,
        body: jsonEncode({
          '_id': currentUserId,
          'groups': user['groupID'],
          'email': currentUserEmail,
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
          backgroundColor: cards,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            AppLocalizations.of(context)!.createnewgroup,
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: _groupNameController,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.entergroupname,
              labelStyle: TextStyle(
                color: primary, 
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                    color: Colors.white24),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: primary, width: 2.0),
              ),
            ),
            style: TextStyle(
              color: Colors.white, 
            ),
            cursorColor: primary,
          ),
          actions: <Widget>[
            TextButton(
              child: Text(AppLocalizations.of(context)!.cancel,
                  style: TextStyle(color: Colors.grey)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(AppLocalizations.of(context)!.create,
                  style: TextStyle(fontWeight: FontWeight.bold)),
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
    final allowedGroupIds = {'383', '2', '140', '3', '39', '848'};
    final filteredWinners = _userWinners.entries
        .where((entry) => allowedGroupIds.contains(entry.key))
        .fold<Map<String, String>>({}, (map, entry) {
      map[entry.key] = entry.value;
      return map;
    });
    final selectedGroup = Provider.of<UserProvider>(context);

    return Scaffold(
    backgroundColor:  background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          color: background,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: kToolbarHeight + 40),
             
              // Profile Header
              Container(
                margin: EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.mygroups,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                       "Manage your groups and predictions",
                       style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24),

              // Create Group Button
              Container(
                margin: EdgeInsets.symmetric(horizontal: 20),
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: primary.withOpacity(0.4),
                  ),
                  icon: Icon(
                    Icons.add_circle_outline,
                    color: Colors.white,
                    size: 24,
                  ),
                  label: Text(
                    AppLocalizations.of(context)!.createnewgroup.toUpperCase(),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  onPressed: _showCreateGroupDialog,
                ),
              ),

              SizedBox(height: 32),

              // Groups List
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  "YOUR GROUPS",
                  style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ),
              SizedBox(height: 12),
              Container(
                margin: EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: cards,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                   boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                ),
                child: _isLoadingGroups
                    ? Container(
                        height: 120,
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(primary),
                          ),
                        ),
                      )
                    : ClipRRect(
                       borderRadius: BorderRadius.circular(24),
                       child: usersGroups(selectedGroup),
                      ),
              ),

              SizedBox(height: 32),

              // Winners/Top Scorers Toggle Section
              if (_userWinners.isNotEmpty || _userTopScorer.isNotEmpty) ...[
                 Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    "STATISTICS",
                    style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(4),
                  margin: EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: cards,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _showWinners = true),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: _showWinners
                                  ? primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.emoji_events,
                                  color: _showWinners ? Colors.white : Colors.grey,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  AppLocalizations.of(context)!.yourwinners,
                                  style: TextStyle(
                                    color: _showWinners
                                        ? Colors.white
                                        : Colors.grey,
                                    fontSize: 14,
                                    fontWeight: _showWinners
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 4),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _showWinners = false),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: !_showWinners
                                  ? primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.sports_soccer,
                                  color: !_showWinners ? Colors.white : Colors.grey,
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  AppLocalizations.of(context)!.topScorers ??
                                      "Top Scorers",
                                  style: TextStyle(
                                    color: !_showWinners
                                        ? Colors.white
                                        : Colors.grey,
                                    fontSize: 14,
                                    fontWeight: !_showWinners
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 16),
                   decoration: BoxDecoration(
                    color: cards,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                     boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: AnimatedSwitcher(
                      duration: Duration(milliseconds: 300),
                      child: _showWinners
                          ? usersWinners(
                              key: ValueKey('winners'),
                              userWinners: _userWinners,
                              filteredWinners: filteredWinners,
                            )
                          : usersTopScorers(
                              key: ValueKey('topScorers'),
                              userTopScorers: _userTopScorer,
                              userTopScorerPoints: _userTopScorerPoints,
                              filteredTopScorers: _userTopScorer.entries
                                  .where((entry) =>
                                      allowedGroupIds.contains(entry.key))
                                  .fold<Map<String, String>>({}, (map, entry) {
                                map[entry.key] = entry.value;
                                return map;
                              }),
                            ),
                    ),
                  ),
                ),
              ],

              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget usersGroups(UserProvider selectedGroup) {
    // Filter out 'public' group
    final filteredGroups = _userGroups.entries
        .where((entry) => entry.value.toLowerCase() != 'public')
        .toList();

    return filteredGroups.isEmpty
        ? Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                     padding: EdgeInsets.all(16),
                     decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
                     child: Icon(Icons.group_off_outlined, size: 32, color: Colors.grey),
                  ),
                  SizedBox(height: 16),
                  Text(
                    // AppLocalizations.of(context)!.nogroupsyet,
                     AppLocalizations.of(context)!.notmemberanygroup,
                     textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            ),
          )
        : ListView.separated(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(vertical: 8),
            itemCount: filteredGroups.length,
            separatorBuilder: (context, index) => Divider(
              color: Colors.white.withOpacity(0.05),
              height: 1,
              indent: 70,
            ),
            itemBuilder: (context, index) {
              final groupEntry = filteredGroups[index];
              final groupId = groupEntry.key;
              final groupName = groupEntry.value;

              final isCreator = _groupsInfo.any((group) =>
                  (group['name'] == groupName &&
                      group['createdBy'] == currentUserId));

              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          TableScreen(selectedGroupName: groupName),
                    ),
                  );
                },
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                       Container(
                         width: 50,
                         height: 50,
                        decoration: BoxDecoration(
                          color: primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          groupName[0].toUpperCase(),
                          style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             Text(
                                groupName,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                             SizedBox(height: 4),
                             Text(
                                isCreator ? "Creator" : "Member",
                                style: TextStyle(
                                  color: isCreator ? primary : Colors.grey,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (!isCreator)
                        IconButton(
                          icon: Icon(Icons.exit_to_app,
                              color: Colors.red.withOpacity(0.7), size: 20),
                          onPressed: () => leaveGroup(groupName),
                        ),
                      IconButton(
                        icon: Icon(
                          Icons.star,
                          size: 20,
                          color: selectedGroupName == groupName
                              ? Colors.amber
                              : Colors.white10,
                        ),
                        onPressed: () async {
                          selectedGroup.setSelectedGroupName(groupName);
                          final prefs = await SharedPreferences.getInstance();
                          prefs.setString('selectedGroupName', groupName);
                          _loadSelectedGroupName();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }
}

class usersWinners extends StatelessWidget {
  const usersWinners({
    super.key,
    required Map<String, String> userWinners,
    required this.filteredWinners,
  }) : _userWinners = userWinners;

  final Map<String, String> _userWinners;
  final Map<String, String> filteredWinners;

  @override
  Widget build(BuildContext context) {
    return _userWinners.isEmpty
        ? Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Container(
                     padding: EdgeInsets.all(16),
                     decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
                     child: Icon(Icons.emoji_events_outlined,
                      size: 32, color: Colors.grey),
                   ),
                  SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.noWinnersYet,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            ),
          )
        : ListView.separated(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(vertical: 8),
            itemCount: filteredWinners.length,
            separatorBuilder: (context, index) => Divider(
              color: Colors.white.withOpacity(0.05),
              height: 1,
              indent: 72,
            ),
            itemBuilder: (context, index) {
              String groupId = filteredWinners.keys.elementAt(index);
              String groupName = filteredWinners.values.elementAt(index);

              String leagueName = '';
              Color leagueColor = Colors.blue;

              switch (groupId) {
                case '2':
                  leagueName = AppLocalizations.of(context)!.championsleague;
                  leagueColor = Colors.blue;
                  break;
                case '383':
                  leagueName = AppLocalizations.of(context)!.ligathaal;
                  leagueColor = Colors.green;
                  break;
                case '140':
                  leagueName = AppLocalizations.of(context)!.laliga;
                  leagueColor = Colors.orange;
                  break;
                case '3':
                  leagueName = AppLocalizations.of(context)!.europaleague;
                  leagueColor = Colors.purple;
                  break;
                case '39':
                  leagueName = AppLocalizations.of(context)!.premierleague;
                  leagueColor = Colors.pinkAccent;
                  break;
                case '848':
                  leagueName = AppLocalizations.of(context)!.conferenceleague;
                  leagueColor = Colors.teal;
                  break;
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                     Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: leagueColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Image.network(
                          'https://media.api-sports.io/football/leagues/$groupId.png',
                          width: 24,
                          height: 24,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.emoji_events, color: leagueColor);
                          },
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           Text(
                            leagueName,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            AppLocalizations.of(context)!.yourprediction ??
                                "Your prediction",
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: leagueColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: leagueColor.withOpacity(0.2)),
                      ),
                      child: Text(
                        groupName,
                        style: TextStyle(
                          color: leagueColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
  }
}

class usersTopScorers extends StatelessWidget {
  const usersTopScorers({
    super.key,
    required Map<String, String> userTopScorers,
    required this.userTopScorerPoints,
    required this.filteredTopScorers,
  }) : _userTopScorers = userTopScorers;

  final Map<String, String> _userTopScorers;
  final Map<String, int> userTopScorerPoints;
  final Map<String, String> filteredTopScorers;

  @override
  Widget build(BuildContext context) {
    return filteredTopScorers.isEmpty
        ? Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   Container(
                     padding: EdgeInsets.all(16),
                     decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
                     child: Icon(Icons.sports_soccer_outlined,
                      size: 32, color: Colors.grey),
                   ),
                  SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.noTopScorersYet,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            ),
          )
        : ListView.separated(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(vertical: 8),
            itemCount: filteredTopScorers.length,
            separatorBuilder: (context, index) => Divider(
              color: Colors.white.withOpacity(0.05),
              height: 1,
              indent: 72,
            ),
            itemBuilder: (context, index) {
              String groupId = filteredTopScorers.keys.elementAt(index);
              String topScorerName = filteredTopScorers.values.elementAt(index);

              String leagueName = '';
              Color leagueColor = Colors.blue;

              switch (groupId) {
                case '2':
                  leagueName = AppLocalizations.of(context)!.championsleague;
                  leagueColor = Colors.blue;
                  break;
                case '383':
                  leagueName = AppLocalizations.of(context)!.ligathaal;
                  leagueColor = Colors.green;
                  break;
                case '140':
                  leagueName = AppLocalizations.of(context)!.laliga;
                  leagueColor = Colors.orange;
                  break;
                case '3':
                  leagueName = AppLocalizations.of(context)!.europaleague;
                  leagueColor = Colors.purple;
                  break;
                case '39':
                  leagueName = AppLocalizations.of(context)!.premierleague;
                  leagueColor = Colors.pinkAccent;
                  break;
                case '848':
                  leagueName = AppLocalizations.of(context)!.conferenceleague;
                  leagueColor = Colors.teal;
                  break;
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: leagueColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Image.network(
                          'https://media.api-sports.io/football/leagues/$groupId.png',
                          width: 24,
                          height: 24,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.sports_soccer, color: leagueColor);
                          },
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                            Text(
                              leagueName,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  AppLocalizations.of(context)!.topScorerPoints ??
                                      "Points:",
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '${userTopScorerPoints[groupId] ?? 0}'
                                  ' ${AppLocalizations.of(context)!.pst}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                         ],
                      ),
                    ),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: leagueColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: leagueColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.sports_soccer,
                            color: leagueColor,
                            size: 14,
                          ),
                          SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: 80),
                            child: Text(
                              topScorerName,
                              style: TextStyle(
                                color: leagueColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
  }
}
