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
        if (authProvider.currentUser == null) {
          return LoginScreen();
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
  TextEditingController _inviteCodeController = TextEditingController();

  void updateSelectedIndex(int index) {
    setState(() {
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            AppLocalizations.of(context)!.invitefriend,
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context)!.invitecodecopy,
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(inviteCode,
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: primary, fontSize: 18, letterSpacing: 1)),
              ),
              SizedBox(height: 20),
              Text(
                AppLocalizations.of(context)!.shareinvitecode,
                 style: TextStyle(color: Colors.white70, fontSize: 12),
                 textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'OK',
                style: TextStyle(color: primary, fontWeight: FontWeight.bold),
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
      final groups = await GroupsMethods().fetchGroups();
      final group = groups.firstWhere(
        (g) => g['name'] == groupName,
      );
      final groupCode = group['_id'];
      await FlutterClipboard.copy(groupCode);
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
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(AppLocalizations.of(context)!.joingroup,
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: _inviteCodeController,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.enterinvitecode,
              labelStyle: TextStyle(
                color: Colors.blue,
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                    color: Colors.blue),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.blue, width: 2.0),
              ),
            ),
            style: TextStyle(
              color: Colors.white,
            ),
            cursorColor: Colors.blue,
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(AppLocalizations.of(context)!.join,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
    _initializeData();
  }

  Future<void> _initializeData() async {
    setState(() => isLoading = true);
    try {
      final cachedGroupName =
          await SharedPreferencesUtil.getSelectedGroupName();
      final dashboardData =
          await GroupsMethods.fetchDashboardData(currentUserId);

      setState(() {
        _privateGroups =
            Map<String, String>.from(dashboardData['privateGroups'] ?? {});
        _publicGroups =
            Map<String, String>.from(dashboardData['publicGroups'] ?? {});
        selectedGroupName = _determineSelectedGroupName(cachedGroupName);
      });

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
    if (widget.selectedGroupName != null &&
        widget.selectedGroupName!.isNotEmpty) {
      return widget.selectedGroupName!;
    }
    if (cachedGroupName != null &&
        cachedGroupName.isNotEmpty &&
        _privateGroups.containsValue(cachedGroupName)) {
      return cachedGroupName;
    }
    if (_privateGroups.isNotEmpty) {
      final firstGroupName = _privateGroups.values.first;
      SharedPreferencesUtil.setSelectedGroupName(firstGroupName);
      return firstGroupName;
    }
    return "";
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
      final users =
          await GroupsMethods.fetchGroupUsers(selectedGroupName, league);
      setState(() {
        _users = users;
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
  
  Future<void> changeSelectedGroup(String newGroupName) async {
    if (newGroupName == selectedGroupName) return;
    setState(() {
      selectedGroupName = newGroupName;
      isLoading = true;
    });
    await SharedPreferencesUtil.setSelectedGroupName(newGroupName);
    await _fetchUsersForSelectedGroup();
  }

  Future<void> refreshData() async {
    await _initializeData();
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
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
           GestureDetector(
             onTap: _showJoinGroupDialog,
             child: Container(
                margin: EdgeInsets.only(right: 16),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(Icons.group_add, color: primary, size: 18),
                    SizedBox(width: 4),
                    Text(
                      AppLocalizations.of(context)!.joingroup,
                       style: TextStyle(color: primary, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
             ),
           ),
        ],
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primary),
              ),
            )
          : Column(
              children: [
                SizedBox(height: 8),
                LeagueSelector(
                  userId: currentUserId,
                  currentLeague: league,
                  // Use standardized chips instead of toggle buttons for consistency
                  useToggleButtons: false, 
                  onSelectionChanged: (leagueId, index) {
                    updateSelectedIndex(leagueId);
                  },
                ),
                SizedBox(height: 16),
                _buildGroupSelector(),
                SizedBox(height: 16),
                _buildHeaderStats(),
                SizedBox(height: 8),
                Expanded(
                  child: _privateGroups.isEmpty 
                      ? _buildEmptyState() 
                      : _buildRankingList(),
                ),
              ],
            ),
      floatingActionButton: (_privateGroups.isNotEmpty) ? FloatingActionButton(
        onPressed: () => _inviteFriend(selectedGroupName),
        backgroundColor: primary,
        child: Icon(Icons.share, color: Colors.white),
        tooltip: AppLocalizations.of(context)!.invitefriend,
      ) : null,
    );
  }

  Widget _buildGroupSelector() {
     if (_privateGroups.isEmpty) return SizedBox.shrink();

     return Container(
       margin: EdgeInsets.symmetric(horizontal: 16),
       padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
       decoration: BoxDecoration(
         color: cards,
         borderRadius: BorderRadius.circular(12),
         border: Border.all(color: Colors.white.withOpacity(0.05)),
       ),
       child: DropdownButtonHideUnderline(
         child: DropdownButton<String>(
           value: _privateGroups.isNotEmpty && selectedGroupName.isNotEmpty && _privateGroups.containsValue(selectedGroupName)
              ? selectedGroupName
              : (_privateGroups.isNotEmpty ? _privateGroups.values.first : null),
           dropdownColor: Color(0xFF2C343A),
           style: TextStyle(
             color: Colors.white,
             fontSize: 16.0,
             fontWeight: FontWeight.w600,
           ),
           icon: Icon(Icons.keyboard_arrow_down, color: primary),
           isExpanded: true,
           items: _privateGroups.entries.map((entry) {
             return DropdownMenuItem<String>(
               value: entry.value,
               child: Row(
                 children: [
                   Container(
                     padding: EdgeInsets.all(4),
                     decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                     child: Icon(Icons.shield, color: Colors.blue, size: 14),
                   ),
                   SizedBox(width: 12),
                   Text(
                     entry.value,
                     style: TextStyle(color: Colors.white),
                   ),
                 ],
               ),
             );
           }).toList(),
           onChanged: (String? newValue) {
             if (newValue != null) {
               changeSelectedGroup(newValue);
             }
           },
         ),
       ),
     );
  }

  Widget _buildHeaderStats() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(AppLocalizations.of(context)!.name, style: TextStyle(color: Colors.grey, fontSize: 12))),
          Expanded(flex: 1, child: Text(AppLocalizations.of(context)!.daypoints, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12))),
          Expanded(flex: 1, child: Text(AppLocalizations.of(context)!.sumpoints, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group_off_outlined, size: 64, color: Colors.white10),
            SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.nogroupsfound,
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
             SizedBox(height: 8),
            Text(
               AppLocalizations.of(context)!.nogroupsmessage,
               textAlign: TextAlign.center,
               style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankingList() {
    return RefreshIndicator(
      onRefresh: refreshData,
      color: primary,
      backgroundColor: cards,
      child: ListView.separated(
        itemCount: _users.length,
        padding: EdgeInsets.fromLTRB(16, 0, 16, 80),
        separatorBuilder: (context, index) => SizedBox(height: 12),
        itemBuilder: (context, index) {
          final user = _users[index];
          final isTop3 = index < 3;
          
          Color rankColor;
          if (index == 0) rankColor = Color(0xFFFFD700); // Gold
          else if (index == 1) rankColor = Color(0xFFC0C0C0); // Silver
          else if (index == 2) rankColor = Color(0xFFCD7F32); // Bronze
          else rankColor = Colors.grey[700]!;

          final bool isMe = user['_id'] == currentUserId;

          return GestureDetector(
             onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => Statistics(
                      userId: user['_id'],
                      leagueId: league,
                    ),
                  ),
                );
             },
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isMe ? primary.withOpacity(0.1) : cards,
                borderRadius: BorderRadius.circular(16),
                border: isMe ? Border.all(color: primary.withOpacity(0.5)) : null,
              ),
              child: Row(
                children: [
                  // Rank
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isTop3 ? rankColor.withOpacity(0.2) : Colors.transparent,
                      shape: BoxShape.circle,
                      border: isTop3 ? Border.all(color: rankColor, width: 1) : null,
                    ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: isTop3 ? rankColor : Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  // Name
                  Expanded(
                    flex: 3,
                    child: Text(
                      user['displayName'] ?? 'Unknown',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Day Points
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      decoration: BoxDecoration(
                         color: Colors.white.withOpacity(0.05),
                         borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        user['thisDayPoints']?[league.toString()]?.toString() ?? '0',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  // Total Points
                  Expanded(
                    flex: 1,
                     child: Text(
                        user['points']?[league.toString()]?.toString() ?? '0',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
