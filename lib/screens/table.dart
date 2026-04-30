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
import 'package:football/theme/typography.dart';
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
        if (authProvider.currentUser == null) {
          return LoginScreen();
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
    setState(() {
      selectedIndex = index;
      league = index;
      Provider.of<UserProvider>(context, listen: false)
          .setselectedLeageId(league);
    });
    _fetchUsersForSelectedGroup();
  }

  // ── Editorial dialog scaffolding ────────────────────────────────────────
  Widget _editorialDialog({
    required String title,
    required Widget body,
    required List<Widget> actions,
  }) {
    final c = context.col;
    return Dialog(
      backgroundColor: c.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(2),
        side: BorderSide(color: c.hairline, width: 1),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 18, height: 1, color: c.live),
                const SizedBox(width: 10),
                Text(title.toUpperCase(),
                    style: EType.label(
                        color: c.ink,
                        size: 11,
                        letterSpacing: 2.4)),
              ],
            ),
            const SizedBox(height: 18),
            body,
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: actions,
            ),
          ],
        ),
      ),
    );
  }

  TextField _editorialField(
      {required TextEditingController controller, required String label}) {
    final c = context.col;
    return TextField(
      controller: controller,
      cursorColor: c.live,
      cursorWidth: 1.5,
      style: EType.body(color: c.ink, size: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: EType.label(
            color: c.inkDim, size: 11, letterSpacing: 1.6),
        floatingLabelStyle: EType.label(
            color: c.live, size: 11, letterSpacing: 1.6),
        filled: true,
        fillColor: c.terrace,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: BorderSide(color: c.hairline, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: BorderSide(color: c.hairline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: BorderSide(color: c.live, width: 1),
        ),
      ),
    );
  }

  Widget _ghostBtn(String label, VoidCallback onPressed, {Color? color}) {
    final c = context.col;
    final btnColor = color ?? c.inkMute;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: EType.label(color: btnColor, size: 11, letterSpacing: 1.8),
      ),
    );
  }

  Widget _solidBtn(String label, VoidCallback onPressed) {
    final c = context.col;
    return Material(
      color: c.live,
      borderRadius: BorderRadius.circular(2),
      child: InkWell(
        borderRadius: BorderRadius.circular(2),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Text(
            label.toUpperCase(),
            style: EType.label(
                color: c.pitch, size: 11, letterSpacing: 1.8),
          ),
        ),
      ),
    );
  }

  void _showInviteDialog(String inviteCode) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final c = context.col;
        final l = AppLocalizations.of(context)!;
        return _editorialDialog(
          title: l.invitefriend,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.invitecodecopy,
                  style: EType.body(color: c.inkMute, size: 13)),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: c.terrace,
                  border: Border.all(color: c.hairline, width: 1),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  inviteCode,
                  style: EType.numeric(
                    color: c.live,
                    size: 16,
                    weight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(l.shareinvitecode,
                  style: EType.body(color: c.inkDim, size: 12)),
            ],
          ),
          actions: [
            _solidBtn(l.okLabel, () => Navigator.of(context).pop()),
          ],
        );
      },
    );
  }

  Future<void> _inviteFriend(String groupName) async {
    try {
      final groups = await GroupsMethods().fetchGroups();
      final group = groups.firstWhere((g) => g['name'] == groupName);
      final groupCode = group['_id'];
      await FlutterClipboard.copy(groupCode);
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
        final c = context.col;
        String errorMessage = responseData['msg'] ?? 'Unknown error occurred';
        if (errorMessage == 'group name is already exist') {
          errorMessage =
              AppLocalizations.of(context)!.groupnamealreadyexists;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: c.flag,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Error creating group: $e');
      if (!mounted) return;
      final c = context.col;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating group: ${e.toString()}'),
          backgroundColor: c.flag,
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
    final existingKeys =
        groupID.keys.map((k) => int.tryParse(k) ?? 0).toList();
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
        final l = AppLocalizations.of(ctx)!;
        return _editorialDialog(
          title: l.createnewgroup,
          body: _editorialField(
            controller: _groupNameController,
            label: l.entergroupname,
          ),
          actions: [
            _ghostBtn(l.cancel, () => Navigator.of(ctx).pop()),
            const SizedBox(width: 8),
            _solidBtn(l.create, () {
              if (_groupNameController.text.isNotEmpty) {
                final name = _groupNameController.text;
                _groupNameController.clear();
                Navigator.of(ctx).pop();
                _createNewGroup(name);
              }
            }),
          ],
        );
      },
    );
  }

  void _showJoinGroupDialog() {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        final l = AppLocalizations.of(ctx)!;
        return _editorialDialog(
          title: l.joingroup,
          body: _editorialField(
            controller: _inviteCodeController,
            label: l.enterinvitecode,
          ),
          actions: [
            _ghostBtn(l.cancel, () => Navigator.of(ctx).pop()),
            const SizedBox(width: 8),
            _solidBtn(l.join, () async {
              if (_inviteCodeController.text.isEmpty) return;
              final code = _inviteCodeController.text;
              _inviteCodeController.clear();
              await GroupsMethods()
                  .addGroupToUser(code, currentUserId, context);
              if (!mounted) return;
              await _initializeData();
              if (!mounted) return;
              Navigator.of(ctx).pop();
            }),
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

  Future<void> _initializeData() async {
    setState(() => isLoading = true);

    try {
      final cachedGroupName =
          await SharedPreferencesUtil.getSelectedGroupName();

      final results = await Future.wait([
        GroupsMethods.fetchDashboardData(currentUserId),
        GroupsMethods().fetchGroups(),
      ]);
      final dashboardData = results[0] as Map<String, dynamic>;
      final groupsInfo = results[1] as List<Map<String, dynamic>>;

      final parsedPrivate =
          Map<String, String>.from(dashboardData['privateGroups'] ?? {});
      final parsedPublic =
          Map<String, String>.from(dashboardData['publicGroups'] ?? {});

      setState(() {
        _privateGroups = parsedPrivate;
        _publicGroups = parsedPublic;
        _groupsInfo = groupsInfo;
        _defaultGroupName = cachedGroupName ?? '';
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
    final c = context.col;
    await showModalBottomSheet(
      context: context,
      backgroundColor: c.card,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(2)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (innerCtx, setSheetState) {
            final sc = innerCtx.col;
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 12),
                      width: 36,
                      height: 3,
                      decoration: BoxDecoration(
                        color: sc.hairlineHi,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    child: Row(
                      children: [
                        Container(
                            width: 18, height: 1, color: sc.live),
                        const SizedBox(width: 10),
                        Text(
                          AppLocalizations.of(innerCtx)!
                              .privategroups
                              .toUpperCase(),
                          style: EType.label(
                              color: sc.ink,
                              size: 11,
                              letterSpacing: 2.4),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 1, color: sc.hairline),
                  ..._privateGroups.entries.map((entry) {
                    final name = entry.value;
                    final isActive = name == selectedGroupName;
                    final isDefault = name == _defaultGroupName;
                    return InkWell(
                      onTap: () {
                        Navigator.of(sheetCtx).pop();
                        if (!isActive) changeSelectedGroup(name);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                                color: sc.hairline, width: 1),
                            left: BorderSide(
                              color: isActive
                                  ? sc.live
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          color: isActive
                              ? sc.liveSoft
                              : Colors.transparent,
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: sc.cardHi,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isActive
                                      ? sc.live
                                      : sc.hairline,
                                  width: 1,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                name.isNotEmpty
                                    ? name[0].toUpperCase()
                                    : '?',
                                style: EType.display(
                                  size: 16,
                                  color: isActive
                                      ? sc.live
                                      : sc.inkMute,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                name.toUpperCase(),
                                overflow: TextOverflow.ellipsis,
                                style: EType.display(
                                  size: 16,
                                  color: sc.ink,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: AppLocalizations.of(context)!.setAsDefault,
                              icon: Icon(
                                isDefault ? Icons.star : Icons.star_border,
                                color: isDefault
                                    ? sc.amber
                                    : sc.inkDim,
                                size: 18,
                              ),
                              onPressed: () async {
                                await _setAsDefaultGroup(name);
                                setSheetState(() {});
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _leaveActiveGroup() async {
    if (selectedGroupName.isEmpty || _isCreatorOfActiveGroup) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final c = ctx.col;
        final l = AppLocalizations.of(ctx)!;
        return _editorialDialog(
          title: l.leavethegroup,
          body: Text(l.leavegroup,
              style: EType.body(color: c.inkMute, size: 13)),
          actions: [
            _ghostBtn(l.cancel, () => Navigator.of(ctx).pop(false)),
            const SizedBox(width: 8),
            Material(
              color: c.flag,
              borderRadius: BorderRadius.circular(2),
              child: InkWell(
                borderRadius: BorderRadius.circular(2),
                onTap: () => Navigator.of(ctx).pop(true),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                  child: Text(l.leave.toUpperCase(),
                      style: EType.label(
                          color: c.ink,
                          size: 11,
                          letterSpacing: 1.8)),
                ),
              ),
            ),
          ],
        );
      },
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

  Future<void> refreshUsers() async {
    await _fetchUsersForSelectedGroup();
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final effectivePrivateGroups =
        isLoading ? {'0': AppLocalizations.of(context)!.loadingGroup} : _privateGroups;

    final effectiveUsers = isLoading
        ? List.generate(
            10,
            (index) => {
              'displayName': AppLocalizations.of(context)!.loadingName,
              'thisDayPoints': {league.toString(): '0'},
              'points': {league.toString(): '0'},
              '_id': 'dummy_$index'
            })
        : _users;

    return Scaffold(
      backgroundColor: c.pitch,
      appBar: _buildAppBar(context, c),
      body: Skeletonizer(
        enabled: isLoading,
        child: Column(
          children: [
            const SizedBox(height: 4),
            LeagueSelector(
              userId: currentUserId,
              currentLeague: league,
              useToggleButtons: true,
              onSelectionChanged: (leagueId, index) {
                updateSelectedIndex(leagueId);
              },
            ),
            Container(height: 1, color: c.hairline),
            if (effectivePrivateGroups.isEmpty)
              Expanded(child: _buildEmptyState(context, c))
            else ...[
              if (selectedGroupName.isNotEmpty &&
                  selectedGroupName != 'Public')
                _buildGroupHeader(context, c),
              Expanded(child: _buildLeaderboard(context, effectiveUsers, c)),
              _buildFooterActions(context, c),
            ],
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, EditorialColors c) {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: c.pitch,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 72,
      titleSpacing: 20,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(AppLocalizations.of(context)!.league.toUpperCase(),
              style: EType.label(
                  color: c.inkDim, size: 10, letterSpacing: 3)),
          const SizedBox(height: 2),
          Text(AppLocalizations.of(context)!.standings.toUpperCase(),
              style: EType.display(
                  size: 28, color: c.ink, letterSpacing: 1.4)),
        ],
      ),
      actions: [
        PopupMenuButton<String>(
          tooltip: '',
          position: PopupMenuPosition.under,
          color: c.cardHi,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(2),
            side: BorderSide(color: c.hairline, width: 1),
          ),
          onSelected: (v) {
            if (v == 'create') _showCreateGroupDialog();
            if (v == 'join') _showJoinGroupDialog();
          },
          itemBuilder: (ctx) {
            final mc = ctx.col;
            return [
              PopupMenuItem<String>(
                value: 'create',
                child: Row(
                  children: [
                    Icon(Icons.add, color: mc.live, size: 16),
                    const SizedBox(width: 12),
                    Text(
                      AppLocalizations.of(ctx)!
                          .createnewgroup
                          .toUpperCase(),
                      style: EType.label(
                          color: mc.ink,
                          size: 11,
                          letterSpacing: 1.6),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'join',
                child: Row(
                  children: [
                    Icon(Icons.group_add_outlined,
                        color: mc.live, size: 16),
                    const SizedBox(width: 12),
                    Text(
                      AppLocalizations.of(ctx)!.joingroup.toUpperCase(),
                      style: EType.label(
                          color: mc.ink,
                          size: 11,
                          letterSpacing: 1.6),
                    ),
                  ],
                ),
              ),
            ];
          },
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              border: Border.all(color: c.hairline, width: 1),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Icon(Icons.add, color: c.ink, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupHeader(BuildContext context, EditorialColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: InkWell(
        onTap: _showGroupSwitcherSheet,
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: c.cardHi,
                shape: BoxShape.circle,
                border: Border.all(color: c.live, width: 1),
              ),
              alignment: Alignment.center,
              child: Text(
                selectedGroupName.isNotEmpty
                    ? selectedGroupName[0].toUpperCase()
                    : '?',
                style: EType.display(
                  size: 16,
                  color: c.live,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(AppLocalizations.of(context)!.group.toUpperCase(),
                      style: EType.label(
                          color: c.inkDim,
                          size: 9,
                          letterSpacing: 2)),
                  const SizedBox(height: 4),
                  Text(
                    selectedGroupName.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: EType.display(
                      size: 20,
                      color: c.ink,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: c.hairline, width: 1),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Row(
                children: [
                  Text(AppLocalizations.of(context)!.switchGroup.toUpperCase(),
                      style: EType.label(
                          color: c.inkMute,
                          size: 10,
                          letterSpacing: 1.6)),
                  const SizedBox(width: 4),
                  Icon(Icons.expand_more,
                      color: c.inkMute, size: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboard(
      BuildContext context, List<Map<String, dynamic>> rows, EditorialColors c) {
    final l = AppLocalizations.of(context)!;
    return Column(
      children: [
        // Column header
        Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: c.hairline, width: 1),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text('#',
                    style: EType.label(
                        color: c.inkDim,
                        size: 10,
                        letterSpacing: 1.4)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l.name.toUpperCase(),
                    style: EType.label(
                        color: c.inkDim,
                        size: 10,
                        letterSpacing: 1.6)),
              ),
              SizedBox(
                width: 56,
                child: Text(
                  l.daypoints.toUpperCase(),
                  textAlign: TextAlign.right,
                  style: EType.label(
                      color: c.inkDim,
                      size: 10,
                      letterSpacing: 1.6),
                ),
              ),
              SizedBox(
                width: 56,
                child: Text(
                  l.sumpoints.toUpperCase(),
                  textAlign: TextAlign.right,
                  style: EType.label(
                      color: c.inkDim,
                      size: 10,
                      letterSpacing: 1.6),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            itemCount: rows.length,
            itemBuilder: (ctx, index) {
              final user = rows[index];
              final isMe = user['_id'] == currentUserId;
              final dayPts = user['thisDayPoints']?[league.toString()]
                      ?.toString() ??
                  '0';
              final sumPts =
                  user['points']?[league.toString()]?.toString() ?? '0';
              final dayPtsNum = double.tryParse(dayPts) ?? 0;

              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => Statistics(
                        userId: user['_id'],
                        leagueId: league,
                      ),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isMe ? c.liveSoft : Colors.transparent,
                    border: Border(
                      bottom: BorderSide(
                          color: c.hairline, width: 1),
                      left: BorderSide(
                        color: isMe ? c.live : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: _rankCell(index + 1, c),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                user['displayName'] ?? '—',
                                overflow: TextOverflow.ellipsis,
                                style: EType.body(
                                  color: c.ink,
                                  size: 14,
                                  weight: isMe
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: c.live, width: 1),
                                  borderRadius:
                                      BorderRadius.circular(2),
                                ),
                                child: Text(AppLocalizations.of(context)!.youLabel.toUpperCase(),
                                    style: EType.label(
                                        color: c.live,
                                        size: 9,
                                        letterSpacing: 1.2)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 56,
                        child: Text(
                          dayPts,
                          textAlign: TextAlign.right,
                          style: EType.numeric(
                            color: dayPtsNum > 0
                                ? c.live
                                : c.inkMute,
                            size: 13,
                            weight: FontWeight.w500,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 56,
                        child: Text(
                          sumPts,
                          textAlign: TextAlign.right,
                          style: EType.numeric(
                            color: c.ink,
                            size: 15,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _rankCell(int rank, EditorialColors c) {
    if (rank <= 3) {
      final color = rank == 1
          ? c.amber
          : rank == 2
              ? c.chalk
              : const Color(0xFFCD7F32); // bronze
      return Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          border: Border.all(color: color, width: 1),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(
          rank.toString(),
          style: EType.numeric(
            color: color,
            size: 11,
            weight: FontWeight.w700,
          ),
        ),
      );
    }
    return Text(
      rank.toString().padLeft(2, '0'),
      style: EType.numeric(
        color: c.inkDim,
        size: 12,
        weight: FontWeight.w500,
      ),
    );
  }

  Widget _buildFooterActions(BuildContext context, EditorialColors c) {
    final l = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: c.pitch,
        border:
            Border(top: BorderSide(color: c.hairline, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _footerBtn(
              icon: Icons.share_outlined,
              label: l.invitefriend,
              color: c.live,
              onTap: () => _inviteFriend(selectedGroupName),
            ),
          ),
          if (!isLoading && !_isCreatorOfActiveGroup) ...[
            const SizedBox(width: 10),
            Expanded(
              child: _footerBtn(
                icon: Icons.logout,
                label: l.leave,
                color: c.flag,
                onTap: _leaveActiveGroup,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _footerBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(2),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: color.withOpacity(0.4), width: 1),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 8),
              Text(
                label.toUpperCase(),
                style: EType.label(
                    color: color, size: 11, letterSpacing: 1.8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, EditorialColors c) {
    final l = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: c.hairline, width: 1),
              ),
              child: Icon(Icons.groups_outlined,
                  size: 30, color: c.inkMute),
            ),
            const SizedBox(height: 22),
            Text(
              l.nogroupsfound.toUpperCase(),
              style: EType.display(
                size: 26,
                color: c.ink,
                letterSpacing: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              l.nogroupsmessage,
              textAlign: TextAlign.center,
              style: EType.body(color: c.inkMute, size: 13),
            ),
            const SizedBox(height: 28),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                _solidBtn(l.createnewgroup, _showCreateGroupDialog),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(2),
                    onTap: _showJoinGroupDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: c.hairlineHi, width: 1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        l.joingroup.toUpperCase(),
                        style: EType.label(
                            color: c.ink,
                            size: 11,
                            letterSpacing: 1.8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
