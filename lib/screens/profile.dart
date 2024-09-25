import 'dart:convert';
import 'dart:math';
import 'package:football/providers/flutter%20pub%20add%20provider.dart';
import 'package:football/resources/auth.dart';
import 'package:football/resources/groupsMethods.dart';
import 'package:football/screens/login_screen.dart';
import 'package:football/screens/table.dart';
import 'package:football/theme/colors.dart';
import 'package:football/widgets/SharedPreferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:football/resources/usersMethods.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  List<Map<String, dynamic>> _groupsInfo = [];
  late String currentUserId;
  late String currentUserEmail;
  TextEditingController _groupNameController = TextEditingController();
  Map<String, dynamic> user = {};
  late String selectedGroupName = "";

  @override
  void initState() {
    super.initState();
    currentUserId = widget.authProvider.currentUser?.id ?? 'Not logged in';
    currentUserEmail =
        widget.authProvider.currentUser?.email ?? 'Not logged in';
    _loadSelectedGroupName();
    _fetchUserData();
    _fetchUserGroups();
  }

  Future<void> _loadSelectedGroupName() async {
    final groupName = await SharedPreferencesUtil.getSelectedGroupName();
    setState(() {
      selectedGroupName = groupName!;
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
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        print(userProvider.selectedGroupName);
        _userGroups = Map<String, String>.from(userData['groupID'] ?? {});
        _userWinners = Map<String, String>.from(userData['winner'] ?? {});
        _groupsInfo = groupsInfo;
        print(_userGroups);
        print(_userWinners);
        if (userProvider.selectedGroupName == 'default') {
          String selectedGroup;

          if (_userGroups.isNotEmpty) {
            var groupValues = _userGroups.values.toList();

            if (groupValues.first.toLowerCase() == 'public' &&
                groupValues.length > 1) {
              selectedGroup = groupValues[1];
            } else {
              selectedGroup = groupValues.first;
            }
          } else {
            // Handle the case when _userGroups is empty
            selectedGroup = 'default'; // or any other default value you prefer
          }

          Provider.of<UserProvider>(context, listen: false)
              .setSelectedGroupName(_userGroups.values.first);
        }
        Provider.of<UserProvider>(context, listen: false)
            .setCurrentUser(currentUserId);
      });
    } catch (e) {
      print('Failed to fetch user groups: $e');
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
          title: Text(
            AppLocalizations.of(context)!.leavethegroup,
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            AppLocalizations.of(context)!.leavegroup,
            style: TextStyle(color: Colors.white),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                AppLocalizations.of(context)!.cancel,
                style: TextStyle(color: Colors.blue),
              ),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text(
                AppLocalizations.of(context)!.leave,
                style: TextStyle(color: Colors.blue),
              ),
              onPressed: () => Navigator.of(context).pop(true),
            ),
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
          Uri.parse('https://leagues.onrender.com/users/'),
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

    final url = Uri.parse('https://leagues.onrender.com/users/');
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
          title: Text(
            AppLocalizations.of(context)!.createnewgroup,
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          content: TextField(
            controller: _groupNameController,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.entergroupname,
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
              child: Text(AppLocalizations.of(context)!.create,
                  style: TextStyle(color: Colors.blue)),
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
    final allowedGroupIds = {'383', '2', '140', '3'};

// Filter the _userWinners based on allowedGroupIds
    final filteredWinners = _userWinners.entries
        .where((entry) => allowedGroupIds.contains(entry.key))
        .fold<Map<String, String>>({}, (map, entry) {
      map[entry.key] = entry.value;
      return map;
    });
    final selectedGroup = Provider.of<UserProvider>(context);

    print('selectedGroup : ${selectedGroup.selectedGroupName}');

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        // title: Text(AppLocalizations.of(context)!.mygroups, style: TextStyle(color: Colors.white)),
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
                  Text(AppLocalizations.of(context)!.mygroups,
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    icon: Icon(Icons.add),
                    label: Text(
                      AppLocalizations.of(context)!.createnewgroup,
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
                        bool isCreator = _groupsInfo.any((group) =>
                            group['name'] == groupName &&
                                group['createdBy'] == currentUserId ||
                            groupName == 'public');
                        return InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => TableScreen(
                                      selectedGroupName: groupName)),
                            );
                          },
                          child: Card(
                            child: ListTile(
                              tileColor: cards,
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 2),
                              leading: CircleAvatar(
                                backgroundColor: Colors.grey,
                                child: Text(groupName[0],
                                    style: TextStyle(color: Colors.white)),
                                radius: 18,
                              ),
                              title: Text(
                                groupName,
                                style: TextStyle(
                                    color: Colors.white, fontSize: 16),
                                textAlign: TextAlign.right,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize
                                    .min, // Ensures the Row takes up only the necessary width
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.star,
                                      color: selectedGroupName ==
                                              groupName
                                          ? Colors.amber
                                          : Colors.white,
                                    ),
                                    onPressed: () async {
                         
                                      selectedGroup
                                          .setSelectedGroupName(groupName);
                                      final prefs =
                                          await SharedPreferences.getInstance();
                                      await prefs.setString(
                                          'selectedGroupName', groupName);
                                      _loadSelectedGroupName();
                                      print(' set groupName: ${groupName}');
                                      // Navigate back or show a confirmation
                                    },
                                  ),
                                  !isCreator
                                      ? IconButton(
                                          icon: Icon(Icons.exit_to_app,
                                              color: Colors.white),
                                          onPressed: () {
                                            leaveGroup(groupName);
                                            print('Exiting group: $groupName');
                                          },
                                        )
                                      : Opacity(
                                          opacity:
                                              0.0, // Makes the button invisible
                                          child: IconButton(
                                            icon: Icon(Icons
                                                .exit_to_app), // Same icon as the visible button
                                            onPressed:
                                                () {}, // No action required
                                          ),
                                        ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
                      Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(AppLocalizations.of(context)!.yourwinners,
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
           
                ],
              ),
            ),
            SizedBox(height: 4,),
                        Expanded(

                          
              child: _userWinners.isEmpty
                  ? Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                        itemCount: filteredWinners.length,
                      itemBuilder: (context, index) {
                        String groupId = filteredWinners.keys.elementAt(index);
                        String groupName =
                            filteredWinners.values.elementAt(index);
            
                        return Card(
                          child: ListTile(
                            tileColor: cards,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 2),
                            leading: CircleAvatar(
                              backgroundColor: Colors.grey,
                              child: Text(groupName[0],
                                  style: TextStyle(color: Colors.white)),
                              radius: 18,
                            ),
                            title: 
                                                  Row(
                              mainAxisSize: MainAxisSize
                                  .min, // Ensures the Row takes up only the necessary width
                              children: [
                          Text(groupId == '2'? AppLocalizations.of(context)!.championsleague: groupId =='383'?AppLocalizations.of(context)!.ligathaal: groupId =='140'? AppLocalizations.of(context)!.laliga :AppLocalizations.of(context)!.europaleague ,
                              style: TextStyle(
                                    color:
                                        white, fontSize: 14.0 // White color for the team names
                                  ),
                          ),
                                                
                              ],
                            ),
                     
                            trailing:
              Text(
                              groupName,
                              style:
                                  TextStyle(color: Colors.white, fontSize: 16),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        );
                      },
                    ),
            ),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                final authProvider =
                    Provider.of<AuthProvider>(context, listen: false);
                bool? confirmSignOut = await showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      backgroundColor: cards,
                      title: Text(
                        AppLocalizations.of(context)!.confirmsignout,
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      content: Text(
                        AppLocalizations.of(context)!.leaveapp,
                        style: TextStyle(color: Colors.white),
                      ),
                      actions: <Widget>[
                        TextButton(
                          child: Text(
                            AppLocalizations.of(context)!.cancel,
                            style: TextStyle(color: Colors.blue),
                          ),
                          onPressed: () => Navigator.of(context).pop(false),
                        ),
                        TextButton(
                          child: Text(
                            AppLocalizations.of(context)!.yes,
                            style: TextStyle(color: Colors.blue),
                          ),
                          onPressed: () => Navigator.of(context).pop(true),
                        ),
                      ],
                    );
                  },
                );

                if (confirmSignOut == true) {
                  Provider.of<UserProvider>(context, listen: false)
                      .setSelectedGroupName('default');
                  await authProvider.signOut(currentUserId);
                  if (context.mounted) {
                    // Perform any additional actions if needed
                  }
                }
              },
              child: Text(AppLocalizations.of(context)!.signout),
            ),
            SizedBox(
              height: 20.0,
            )
          ],
        ),
      ),
    );
  }
}
