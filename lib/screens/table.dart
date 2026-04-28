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
import 'package:football/utils/config.dart';
import 'package:football/widgets/SharedPreferences.dart';
import 'package:football/widgets/toggleButton.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:football/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:skeletonizer/skeletonizer.dart';

class TableScreen extends StatelessWidget {
  final String? selectedGroupName;
  // 'create' / 'join' / null — auto-opens the matching dialog after first build.
  final String? autoOpenAction;

  TableScreen({this.selectedGroupName, this.autoOpenAction});
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
          autoOpenAction: autoOpenAction,
        );
      },
    );
  }
}

class TableScreenContent extends StatefulWidget {
  final AuthProvider authProvider;
  final UserProvider userProvider;
  final String? selectedGroupName;
  final String? autoOpenAction;

  TableScreenContent({
    required this.authProvider,
    required this.userProvider,
    this.selectedGroupName,
    this.autoOpenAction,
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
  List<Map<String, dynamic>> _groupsInfo = [];
  String _defaultGroupName = '';
  TextEditingController _inviteCodeController = TextEditingController();
  final TextEditingController _groupNameController = TextEditingController();

  @override
  void dispose() {
    _inviteCodeController.dispose();
    _groupNameController.dispose();
    super.dispose();
  }
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

  Future<void> _createNewGroup(String groupName) async {
    final url = Uri.parse('$backendUrl/groups/add');
    try {
      final response = await http.post(
        url,
        body: jsonEncode({
          'name': groupName,
          'createdBy': currentUserId,
          'type': 'private',
          'code': DateTime.now().millisecondsSinceEpoch,
        }),
        headers: {'Content-type': 'application/json; charset=UTF-8'},
      );
      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                AppLocalizations.of(context)!.groupcreatedsuccessfully),
            duration: Duration(seconds: 3),
          ),
        );
        await _addGroupToUser(groupName);
      } else {
        if (!mounted) return;
        String errorMessage = responseData['msg'] ?? 'Unknown error occurred';
        if (errorMessage == 'group name is already exist') {
          errorMessage =
              AppLocalizations.of(context)!.groupnamealreadyexists;
        }
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating group: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _addGroupToUser(String groupName) async {
    Map<String, dynamic> userData;
    try {
      userData = await UsersMethods().fetchUserById(currentUserId);
    } catch (e) {
      print('Error fetching user for group add: $e');
      return;
    }
    final groupID = Map<String, String>.from(userData['groupID'] ?? {});
    final existingKeys = groupID.keys.map((k) => int.tryParse(k) ?? 0).toList();
    final nextKey =
        existingKeys.isEmpty ? 1 : (existingKeys.reduce(max) + 1);

    final email = widget.authProvider.currentUser?.email;
    try {
      final response = await http.put(
        Uri.parse('$backendUrl/users/'),
        body: jsonEncode({
          '_id': currentUserId,
          'email': email,
          '\$set': {'groupID.$nextKey': groupName},
        }),
        headers: {'Content-type': 'application/json; charset=UTF-8'},
      );
      if (response.statusCode == 200) {
        await _initializeData();
      } else {
        print('User update failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating user: $e');
    }
  }

  void _showCreateGroupDialog() {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: cards,
          title: Text(
            AppLocalizations.of(ctx)!.createnewgroup,
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          content: TextField(
            controller: _groupNameController,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(ctx)!.entergroupname,
              labelStyle: TextStyle(color: Colors.blue),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.blue),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.blue, width: 2.0),
              ),
            ),
            style: TextStyle(color: Colors.white),
            cursorColor: Colors.blue,
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                AppLocalizations.of(ctx)!.cancel,
                style: TextStyle(color: Colors.blue),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
              child: Text(
                AppLocalizations.of(ctx)!.create,
                style: TextStyle(color: Colors.blue),
              ),
              onPressed: () {
                if (_groupNameController.text.isNotEmpty) {
                  final name = _groupNameController.text;
                  _groupNameController.clear();
                  Navigator.of(ctx).pop();
                  _createNewGroup(name);
                }
              },
            ),
          ],
        );
      },
    );
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
                if (_inviteCodeController.text.isEmpty) return;
                final code = _inviteCodeController.text;
                _inviteCodeController.clear();
                await GroupsMethods()
                    .addGroupToUser(code, currentUserId, context);
                if (!mounted) return;
                await _initializeData();
                if (!mounted) return;
                Navigator.of(context).pop();
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

    if (widget.autoOpenAction != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.autoOpenAction == 'create') {
          _showCreateGroupDialog();
        } else if (widget.autoOpenAction == 'join') {
          _showJoinGroupDialog();
        }
      });
    }
  }

  // Single initialization method that loads everything efficiently
  Future<void> _initializeData() async {
    setState(() => isLoading = true);

    try {
      final cachedGroupName =
          await SharedPreferencesUtil.getSelectedGroupName();

      // Parallel fetch: dashboard + groups info (for creator detection)
      final results = await Future.wait([
        GroupsMethods.fetchDashboardData(currentUserId),
        GroupsMethods().fetchGroups(),
      ]);
      final dashboardData = results[0] as Map<String, dynamic>;
      final groupsInfo = results[1] as List<Map<String, dynamic>>;

      print('=== DEBUG: dashboardData keys: ${dashboardData.keys}');
      print('=== DEBUG: dashboardData FULL: $dashboardData');
      print('=== DEBUG: privateGroups raw: ${dashboardData['privateGroups']}');
      print('=== DEBUG: publicGroups raw: ${dashboardData['publicGroups']}');

      final parsedPrivate = Map<String, String>.from(dashboardData['privateGroups'] ?? {});
      final parsedPublic = Map<String, String>.from(dashboardData['publicGroups'] ?? {});
      print('=== DEBUG: parsedPrivate count: ${parsedPrivate.length}, entries: $parsedPrivate');
      print('=== DEBUG: parsedPublic count: ${parsedPublic.length}, entries: $parsedPublic');

      setState(() {
        _privateGroups = parsedPrivate;
        _publicGroups = parsedPublic;
        _groupsInfo = groupsInfo;
        _defaultGroupName = cachedGroupName ?? '';
        selectedGroupName = _determineSelectedGroupName(cachedGroupName);
      });
      print('=== DEBUG: selectedGroupName: $selectedGroupName');

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
  bool get _isCreatorOfActiveGroup => _groupsInfo.any(
        (g) =>
            g['name'] == selectedGroupName &&
            g['createdBy'] == currentUserId,
      );

  Future<void> _setAsDefaultGroup(String name) async {
    await SharedPreferencesUtil.setSelectedGroupName(name);
    if (!mounted) return;
    setState(() => _defaultGroupName = name);
    Provider.of<UserProvider>(context, listen: false)
        .setSelectedGroupName(name);
  }

  Future<void> _showGroupSwitcherSheet() async {
    if (_privateGroups.isEmpty) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: cards,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (innerCtx, setSheetState) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.lock, color: Colors.blue, size: 18),
                      SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(innerCtx)!.privategroups,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                ..._privateGroups.entries.map((entry) {
                  final name = entry.value;
                  final isActive = name == selectedGroupName;
                  final isDefault = name == _defaultGroupName;
                  return ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 20),
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.withOpacity(0.15),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      name,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: isActive
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    trailing: IconButton(
                      tooltip: 'Set as default',
                      icon: Icon(
                        Icons.star,
                        color: isDefault
                            ? Colors.amber
                            : Colors.grey.withOpacity(0.4),
                      ),
                      onPressed: () async {
                        await _setAsDefaultGroup(name);
                        setSheetState(() {});
                      },
                    ),
                    onTap: () {
                      Navigator.of(sheetCtx).pop();
                      if (!isActive) changeSelectedGroup(name);
                    },
                  );
                }).toList(),
                SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _leaveActiveGroup() async {
    if (selectedGroupName.isEmpty || _isCreatorOfActiveGroup) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cards,
        title: Text(
          AppLocalizations.of(ctx)!.leavethegroup,
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          AppLocalizations.of(ctx)!.leavegroup,
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            child: Text(
              AppLocalizations.of(ctx)!.cancel,
              style: TextStyle(color: Colors.blue),
            ),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TextButton(
            child: Text(
              AppLocalizations.of(ctx)!.leave,
              style: TextStyle(color: Colors.red),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    Map<String, dynamic> userData;
    try {
      userData = await UsersMethods().fetchUserById(currentUserId);
    } catch (e) {
      print('Error fetching user for leave: $e');
      return;
    }
    final userGroups =
        Map<String, String>.from(userData['groupID'] ?? {});
    final keyToRemove = userGroups.entries
        .firstWhere(
          (e) => e.value == selectedGroupName,
          orElse: () => MapEntry('', ''),
        )
        .key;
    if (keyToRemove.isEmpty) return;
    final leftGroupName = selectedGroupName;
    userGroups.remove(keyToRemove);

    try {
      final response = await http.put(
        Uri.parse('$backendUrl/users/'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          '_id': currentUserId,
          'groupID': userGroups,
        }),
      );
      if (response.statusCode == 200) {
        if (_defaultGroupName == leftGroupName) {
          await SharedPreferencesUtil.setSelectedGroupName('public');
        }
        if (!mounted) return;
        setState(() {
          selectedGroupName = '';
        });
        await _initializeData();
      } else {
        print('Leave group failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error leaving group: $e');
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
    final effectivePrivateGroups = isLoading
        ? {'0': 'Loading Group'}
        : _privateGroups;

    final effectiveUsers = isLoading
        ? List.generate(
            10,
            (index) => {
                  'displayName': 'Loading Name',
                  'thisDayPoints': {league.toString(): '0'},
                  'points': {league.toString(): '0'},
                  '_id': 'dummy_$index'
                })
        : _users;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
       
        title: SizedBox.shrink(),
        actions: [
          PopupMenuButton<String>(
            tooltip: '',
            position: PopupMenuPosition.under,
            color: cards,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            onSelected: (v) {
              if (v == 'create') _showCreateGroupDialog();
              if (v == 'join') _showJoinGroupDialog();
            },
            itemBuilder: (ctx) => [
              PopupMenuItem<String>(
                value: 'create',
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline,
                        color: Colors.blue, size: 20),
                    SizedBox(width: 12),
                    Text(
                      AppLocalizations.of(ctx)!.createnewgroup,
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'join',
                child: Row(
                  children: [
                    Icon(Icons.group_add, color: Colors.blue, size: 20),
                    SizedBox(width: 12),
                    Text(
                      AppLocalizations.of(ctx)!.joingroup,
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
            child: Container(
              margin: EdgeInsets.only(right: 16),
              padding:
                  EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, color: Colors.blue, size: 20),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_drop_down,
                      color: Colors.blue, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Skeletonizer(
        enabled: isLoading,
        child: Column(
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
                    if (effectivePrivateGroups.isEmpty)
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
          SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding:
                      EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(Icons.add_circle_outline, size: 20),
                label: Text(
                  AppLocalizations.of(context)!.createnewgroup,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onPressed: _showCreateGroupDialog,
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: BorderSide(color: Colors.blue),
                  padding:
                      EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(Icons.group_add, size: 20),
                label: Text(
                  AppLocalizations.of(context)!.joingroup,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onPressed: _showJoinGroupDialog,
              ),
            ],
          ),
        ],
      ),
    ),
  )
  else
       SizedBox.shrink(),
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
                if (effectivePrivateGroups.isNotEmpty &&
                    selectedGroupName.isNotEmpty &&
                    selectedGroupName != 'Public')
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _showGroupSwitcherSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.group,
                                  color: Colors.blue, size: 18),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  selectedGroupName,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Icon(Icons.arrow_drop_down,
                                  color: Colors.blue, size: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (effectivePrivateGroups.isNotEmpty)
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
                                  rows: effectiveUsers.asMap().entries.map((entry) {
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
                  (effectivePrivateGroups.isNotEmpty)
                      ? Container(
                          margin: EdgeInsets.all(16),
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  backgroundColor:
                                      Colors.blue.withOpacity(0.1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                ),
                                icon: Icon(Icons.share,
                                    color: Colors.blue, size: 20),
                                label: Text(
                                  AppLocalizations.of(context)!
                                      .invitefriend,
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                onPressed: () =>
                                    _inviteFriend(selectedGroupName),
                              ),
                              if (!isLoading && !_isCreatorOfActiveGroup)
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    backgroundColor:
                                        Colors.red.withOpacity(0.1),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 12),
                                  ),
                                  icon: Icon(Icons.exit_to_app,
                                      color: Colors.red, size: 20),
                                  label: Text(
                                    AppLocalizations.of(context)!.leave,
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  onPressed: _leaveActiveGroup,
                                ),
                            ],
                          ),
                        )
                      : SizedBox(height: 2),
              ],
            ),
      ),
    );
  }
}
