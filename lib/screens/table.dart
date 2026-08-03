import 'dart:convert';
import 'dart:math';
import 'package:clipboard/clipboard.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:football/models/games.dart';
import 'package:football/models/guesses.dart';
import 'package:football/models/users.dart';
import 'package:football/providers/flutter%20pub%20add%20provider.dart';
import 'package:football/providers/league_data_provider.dart';
import 'package:football/resources/appUpdates.dart';
import 'package:football/resources/auth.dart';
import 'package:football/resources/league_config_service.dart';
import 'package:football/utils/league_logos.dart';
import 'package:football/resources/groupsMethods.dart';
import 'package:football/resources/guessesMethods.dart';
import 'package:football/resources/usersMethods.dart';
import 'package:football/screens/login_screen.dart';
import 'package:football/screens/statistics.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:football/utils/config.dart';
import 'package:football/utils/utils.dart';
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

  String _usersCacheKey(String group, int lg) => '$group|$lg';

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

  // ── Dialog scaffolding ──────────────────────────────────────────────────
  // Same shape language as the season pickers: 20-radius sheet, bold Hebrew
  // title, circular close, and full-width actions with the primary leading.
  bool get _isHe => Localizations.localeOf(context).languageCode == 'he';

  Widget _editorialDialog({
    required String title,
    required Widget body,
    required VoidCallback onClose,
    required List<Widget> actions,
  }) {
    final c = context.col;
    return Dialog(
      backgroundColor: c.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: EType.body(
                        color: c.ink,
                        size: 20,
                        weight: FontWeight.w700,
                        hebrew: _isHe),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: onClose,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.cardHi,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, size: 17, color: c.inkMute),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            body,
            const SizedBox(height: 20),
            // Primary first so it leads (right in RTL) and takes the wider half.
            Row(
              children: [
                for (int i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(flex: i == 0 ? 3 : 2, child: actions[i]),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  TextField _editorialField(
      {required TextEditingController controller, required String label}) {
    final c = context.col;
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );
    return TextField(
      controller: controller,
      cursorColor: c.live,
      style: EType.body(color: c.ink, size: 14, hebrew: _isHe),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: EType.body(color: c.inkDim, size: 14, hebrew: _isHe),
        filled: true,
        fillColor: c.cardHi,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: border(c.hairline),
        enabledBorder: border(c.hairline),
        focusedBorder: border(c.live, 1.5),
      ),
    );
  }

  // Shared pill geometry. Horizontal padding matters only where the button
  // isn't stretched by an Expanded — i.e. the empty-state Wrap.
  Widget _pillBtn({
    required String label,
    required VoidCallback? onPressed,
    required Color fill,
    required Color fg,
    Color? border,
  }) {
    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: border == null
              ? null
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border, width: 1),
                ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: EType.body(
                color: fg, size: 14, weight: FontWeight.w700, hebrew: _isHe),
          ),
        ),
      ),
    );
  }

  Widget _ghostBtn(String label, VoidCallback onPressed, {Color? color}) {
    final c = context.col;
    return _pillBtn(
      label: label,
      onPressed: onPressed,
      fill: Colors.transparent,
      fg: color ?? c.ink,
      border: color ?? c.hairlineHi,
    );
  }

  Widget _solidBtn(String label, VoidCallback onPressed) {
    final c = context.col;
    return _pillBtn(
      label: label,
      onPressed: onPressed,
      fill: c.live,
      fg: Colors.white,
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
          onClose: () => Navigator.of(context).pop(),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.invitecodecopy,
                  style: EType.body(color: c.inkMute, size: 13, hebrew: _isHe)),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: c.cardHi,
                  border: Border.all(color: c.hairline, width: 1),
                  borderRadius: BorderRadius.circular(12),
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
                  style: EType.body(color: c.inkDim, size: 12, hebrew: _isHe)),
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
        showSnackBar(
          context,
          AppLocalizations.of(context)!.groupcreatedsuccessfully,
          tone: SnackTone.success,
        );
        await _addGroupToUser(groupName);
      } else {
        if (!mounted) return;
        String errorMessage = responseData['msg'] ?? 'Unknown error occurred';
        if (errorMessage == 'group name is already exist') {
          errorMessage = AppLocalizations.of(context)!.groupnamealreadyexists;
        }
        showSnackBar(context, errorMessage, tone: SnackTone.error);
      }
    } catch (e) {
      print('Error creating group: $e');
      if (!mounted) return;
      showSnackBar(
        context,
        'Error creating group: ${e.toString()}',
        tone: SnackTone.error,
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
    final nextKey = existingKeys.isEmpty ? 1 : (existingKeys.reduce(max) + 1);

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
          onClose: () => Navigator.of(ctx).pop(),
          body: _editorialField(
            controller: _groupNameController,
            label: l.entergroupname,
          ),
          actions: [
            _solidBtn(l.create, () {
              if (_groupNameController.text.isNotEmpty) {
                final name = _groupNameController.text;
                _groupNameController.clear();
                Navigator.of(ctx).pop();
                _createNewGroup(name);
              }
            }),
            _ghostBtn(l.cancel, () => Navigator.of(ctx).pop()),
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
          onClose: () => Navigator.of(ctx).pop(),
          body: _editorialField(
            controller: _inviteCodeController,
            label: l.enterinvitecode,
          ),
          actions: [
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
            _ghostBtn(l.cancel, () => Navigator.of(ctx).pop()),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    currentUserId = widget.authProvider.currentUser?.id ?? 'Not logged in';
    league = _resolveInitialLeague(widget.userProvider.selectedLeageId);

    final hydrated = _hydrateFromCache();
    _initializeData(background: hydrated);

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

  // UserProvider.selectedLeageId is shared with the games screen, where -1 is a
  // real value meaning "no league filter — show all". Standings has no
  // all-leagues mode, so anything that isn't a currently-supported league falls
  // back to the first configured one. Checking membership rather than just
  // `!= -1` also covers an id for a league since dropped from the remote
  // config. Deliberately does NOT write the resolved value back to the
  // provider: doing so would clear the games screen's filter as a side effect
  // of merely opening this screen.
  int _resolveInitialLeague(int fromProvider) {
    final supported = LeagueConfigService().supportedLeagues;
    if (supported.contains(fromProvider)) return fromProvider;
    return supported.isNotEmpty ? supported.first : 2;
  }

  bool _hydrateFromCache() {
    if (_TableCache.dashboardUserId != currentUserId ||
        _TableCache.dashboard == null) {
      return false;
    }
    final dashboardData = _TableCache.dashboard!;
    final parsedPrivate =
        Map<String, String>.from(dashboardData['privateGroups'] ?? {});
    final parsedPublic =
        Map<String, String>.from(dashboardData['publicGroups'] ?? {});

    _privateGroups = parsedPrivate;
    _publicGroups = parsedPublic;
    _groupsInfo = _TableCache.groupsInfo ?? [];
    _defaultGroupName = _TableCache.defaultGroupName ?? '';
    selectedGroupName = _TableCache.lastSelectedGroupName ??
        _determineSelectedGroupName(_TableCache.defaultGroupName);

    final cachedUsers =
        _TableCache.users[_usersCacheKey(selectedGroupName, league)];
    if (cachedUsers != null) {
      _users = cachedUsers;
    }
    isLoading = false;
    return true;
  }

  Future<void> _initializeData({bool background = false}) async {
    if (!background) setState(() => isLoading = true);

    try {
      final cachedGroupName =
          await SharedPreferencesUtil.getSelectedGroupName();

      final dashboardData =
          await GroupsMethods.fetchDashboardData(currentUserId);
      // Dashboard now ships full group docs in `groupsInfo` so we don't need
      // a second /groups/register round-trip just to know who created the
      // active group. Falls back to an empty list if the backend hasn't been
      // updated yet (older deploys won't have the field).
      final groupsInfo = (dashboardData['groupsInfo'] is List)
          ? List<Map<String, dynamic>>.from(
              (dashboardData['groupsInfo'] as List)
                  .map((g) => Map<String, dynamic>.from(g as Map)))
          : <Map<String, dynamic>>[];

      _TableCache.dashboardUserId = currentUserId;
      _TableCache.dashboard = dashboardData;
      _TableCache.groupsInfo = groupsInfo;
      _TableCache.defaultGroupName = cachedGroupName;

      final parsedPrivate =
          Map<String, String>.from(dashboardData['privateGroups'] ?? {});
      final parsedPublic =
          Map<String, String>.from(dashboardData['publicGroups'] ?? {});

      if (!mounted) return;
      setState(() {
        _privateGroups = parsedPrivate;
        _publicGroups = parsedPublic;
        _groupsInfo = groupsInfo;
        _defaultGroupName = cachedGroupName ?? '';
        selectedGroupName = _determineSelectedGroupName(cachedGroupName);
      });
      _TableCache.lastSelectedGroupName = selectedGroupName;

      if (selectedGroupName.isNotEmpty && _privateGroups.isNotEmpty) {
        await _fetchUsersForSelectedGroup(background: background);
      } else {
        setState(() {
          _users = [];
          isLoading = false;
        });
      }
    } catch (e) {
      print('Failed to initialize data: $e');
      if (!background && mounted) {
        setState(() {
          _users = [];
          isLoading = false;
        });
      }
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

  Future<void> _fetchUsersForSelectedGroup({bool background = false}) async {
    if (selectedGroupName.isEmpty) {
      setState(() {
        _users = [];
        isLoading = false;
      });
      return;
    }

    final key = _usersCacheKey(selectedGroupName, league);
    final cached = _TableCache.users[key];

    if (cached != null) {
      if (mounted) {
        setState(() {
          _users = cached;
          isLoading = false;
        });
      }
      // SWR: always revalidate in background when serving cached data.
      _revalidateUsers(selectedGroupName, league);
      return;
    }

    // If we already have rows on screen (from the previous league), leave
    // them visible and refresh in the background instead of toggling
    // `isLoading=true` — that toggle is what causes the leaderboard area to
    // flash skeletonized content during a league switch.
    final hasExistingRows = _users.isNotEmpty;
    if (!background && !hasExistingRows && mounted) {
      setState(() => isLoading = true);
    }

    try {
      final users =
          await GroupsMethods.fetchGroupUsers(selectedGroupName, league);
      _TableCache.users[key] = users;
      if (!mounted) return;
      if (selectedGroupName == _keyGroup(key) && league == _keyLeague(key)) {
        setState(() {
          _users = users;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Failed to fetch users for group: $e');
      if (!background && mounted) {
        setState(() {
          _users = [];
          isLoading = false;
        });
      }
    }
  }

  Future<void> _revalidateUsers(String group, int lg) async {
    try {
      final users = await GroupsMethods.fetchGroupUsers(group, lg);
      final key = _usersCacheKey(group, lg);
      _TableCache.users[key] = users;
      if (!mounted) return;
      // Only swap into UI if user is still viewing this slice.
      if (selectedGroupName == group && league == lg) {
        setState(() {
          _users = users;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Background users refresh failed: $e');
    }
  }

  String _keyGroup(String key) => key.substring(0, key.lastIndexOf('|'));
  int _keyLeague(String key) =>
      int.parse(key.substring(key.lastIndexOf('|') + 1));

  bool get _isCreatorOfActiveGroup => _groupsInfo.any(
        (g) =>
            g['name'] == selectedGroupName && g['createdBy'] == currentUserId,
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
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
                        Container(width: 18, height: 1, color: sc.live),
                        const SizedBox(width: 10),
                        Text(
                          AppLocalizations.of(innerCtx)!
                              .privategroups
                              .toUpperCase(),
                          style: EType.label(
                              color: sc.ink, size: 11, letterSpacing: 2.4),
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
                            bottom: BorderSide(color: sc.hairline, width: 1),
                            left: BorderSide(
                              color: isActive ? sc.live : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          color: isActive ? sc.liveSoft : Colors.transparent,
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
                                  color: isActive ? sc.live : sc.hairline,
                                  width: 1,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                                style: EType.display(
                                  size: 16,
                                  color: isActive ? sc.live : sc.inkMute,
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
                              tooltip:
                                  AppLocalizations.of(context)!.setAsDefault,
                              icon: Icon(
                                isDefault ? Icons.star : Icons.star_border,
                                color: isDefault ? sc.amber : sc.inkDim,
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
          onClose: () => Navigator.of(ctx).pop(false),
          body: Text(l.leavegroup,
              style: EType.body(color: c.inkMute, size: 13, hebrew: _isHe)),
          actions: [
            _pillBtn(
              label: l.leave,
              onPressed: () => Navigator.of(ctx).pop(true),
              fill: c.flag,
              fg: Colors.white,
            ),
            _ghostBtn(l.cancel, () => Navigator.of(ctx).pop(false)),
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
    final userGroups = Map<String, String>.from(userData['groupID'] ?? {});
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

    final cached = _TableCache.users[_usersCacheKey(newGroupName, league)];
    setState(() {
      selectedGroupName = newGroupName;
      if (cached != null) {
        _users = cached;
        isLoading = false;
      } else {
        isLoading = true;
      }
    });
    _TableCache.lastSelectedGroupName = newGroupName;

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
    final effectivePrivateGroups = isLoading
        ? {'0': AppLocalizations.of(context)!.loadingGroup}
        : _privateGroups;

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
      body: Column(
        children: [
          // ── Stable chrome (NOT skeletonized) ────────────────────────────
          // Keeping the league selector and group header outside the
          // Skeletonizer avoids them flashing / bouncing every time
          // `isLoading` flips when the user switches leagues with no cached
          // data for the new league.
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
            if (selectedGroupName.isNotEmpty && selectedGroupName != 'Public')
              _buildGroupHeader(context, c, _users.length),
            // Only the rows shimmer while we fetch.
            Expanded(
              child: Skeletonizer(
                enabled: isLoading,
                child: _buildLeaderboard(context, effectiveUsers, c),
              ),
            ),
          ],
        ],
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
              style: EType.label(color: c.inkDim, size: 10, letterSpacing: 3)),
          const SizedBox(height: 2),
          Text(
            AppLocalizations.of(context)!.standings.toUpperCase(),
            style: EType.screenTitle(
              size: 26,
              color: c.ink,
              hebrew: Localizations.localeOf(context).languageCode == 'he',
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HeaderActionButton(
                label: AppLocalizations.of(context)!.join,
                icon: Icons.login,
                primary: false,
                onTap: _showJoinGroupDialog,
              ),
              const SizedBox(width: 8),
              _HeaderActionButton(
                label: AppLocalizations.of(context)!.create,
                icon: Icons.add,
                primary: true,
                onTap: _showCreateGroupDialog,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _leagueName() {
    final remote = LeagueConfigService()
        .nameFor(league, Localizations.localeOf(context).languageCode);
    if (remote != null) return remote;
    final l = AppLocalizations.of(context)!;
    switch (league) {
      case 2:
        return l.championsleague;
      case 383:
        return l.ligathaal;
      case 140:
        return l.laliga;
      case 3:
        return l.europaleague;
      case 39:
        return l.premierleague;
      case 848:
        return l.conferenceleague;
      default:
        return '$league';
    }
  }

  Widget _buildGroupHeader(
      BuildContext context, EditorialColors c, int playerCount) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.hairline, width: 1),
        ),
        child: Column(
          children: [
            // Identity + switch
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: c.cardHi,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.live, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      selectedGroupName.isNotEmpty
                          ? selectedGroupName[0].toUpperCase()
                          : '?',
                      style: EType.display(size: 16, color: c.live),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l.group.toUpperCase(),
                            style: EType.label(
                                color: c.inkDim, size: 9, letterSpacing: 2)),
                        const SizedBox(height: 3),
                        Text(
                          selectedGroupName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: EType.display(size: 18, color: c.ink),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _showGroupSwitcherSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: c.hairline, width: 1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(l.switchGroup,
                              style: EType.label(
                                  color: c.inkMute,
                                  size: 11,
                                  letterSpacing: 0.5)),
                          const SizedBox(width: 4),
                          Icon(Icons.unfold_more, color: c.inkMute, size: 14),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // League strip
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: c.liveSoft,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(15)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Image(
                      image: leagueLogoProvider(league),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                          Icons.emoji_events_outlined,
                          size: 16,
                          color: c.live),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(_leagueName(),
                      style: EType.display(
                          size: 14, color: c.ink, letterSpacing: 0.2)),
                  const Spacer(),
                  Text('$playerCount ${l.playersLabel}',
                      style: EType.body(color: c.inkMute, size: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Points helpers ──────────────────────────────────────────────────────
  double _numOf(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
  double _ptsOf(Map u) => _numOf(u['points']?[league.toString()]);
  double _dayOf(Map u) => _numOf(u['thisDayPoints']?[league.toString()]);
  String _fmtPts(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);

  // Previous-rank map: rank each user by points EXCLUDING today's points
  // (points - thisDayPoints). Comparing that to the live rank yields the
  // up/down position-change arrows without any snapshot or backend field.
  Map<String, int> _previousRanks(List<Map<String, dynamic>> rows) {
    final prev = [
      ...rows
    ]..sort((a, b) => (_ptsOf(b) - _dayOf(b)).compareTo(_ptsOf(a) - _dayOf(a)));
    return {
      for (int i = 0; i < prev.length; i++)
        (prev[i]['_id']?.toString() ?? 'x$i'): i + 1,
    };
  }

  Widget _buildLeaderboard(BuildContext context,
      List<Map<String, dynamic>> rows, EditorialColors c) {
    final l = AppLocalizations.of(context)!;
    final sorted = [...rows]..sort((a, b) => _ptsOf(b).compareTo(_ptsOf(a)));
    final prevRank = _previousRanks(rows);
    int deltaOf(String id, int rank) => (prevRank[id] ?? rank) - rank;

    final top3 = sorted.take(3).toList();
    final rest =
        sorted.length > 3 ? sorted.sublist(3) : const <Map<String, dynamic>>[];

    void openStats(Map u) => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Statistics(userId: u['_id'], leagueId: league),
          ),
        );

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        if (top3.isNotEmpty)
          _Podium(
            spots: [
              for (int i = 0; i < top3.length; i++)
                _PodiumData(
                  rank: i + 1,
                  name: top3[i]['displayName']?.toString() ?? '—',
                  points: _fmtPts(_ptsOf(top3[i])),
                  isMe: top3[i]['_id'] == currentUserId,
                  onTap: () => openStats(top3[i]),
                ),
            ],
          ),
        // Column header (name · change · day pts · total pts)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Text('#',
                    style: EType.label(
                        color: c.inkDim, size: 10, letterSpacing: 1.4)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l.name.toUpperCase(),
                    style: EType.label(
                        color: c.inkDim, size: 10, letterSpacing: 1.6)),
              ),
              const SizedBox(width: 28), // change arrow column (no label)
              SizedBox(
                width: 64,
                child: Text(l.daypoints.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EType.label(
                        color: c.inkDim, size: 10, letterSpacing: 0.3)),
              ),
              SizedBox(
                width: 50,
                child: Text(l.sumpoints.toUpperCase(),
                    textAlign: TextAlign.end,
                    style: EType.label(
                        color: c.inkDim, size: 10, letterSpacing: 1.4)),
              ),
            ],
          ),
        ),
        Container(height: 1, color: c.hairline),
        ...rest.asMap().entries.map((e) {
          final rank = e.key + 4;
          final u = e.value;
          final id = u['_id']?.toString() ?? '';
          return _LeaderRow(
            rank: rank,
            name: u['displayName']?.toString() ?? '—',
            dayPoints: _fmtPts(_dayOf(u)),
            dayPositive: _dayOf(u) > 0,
            points: _fmtPts(_ptsOf(u)),
            delta: deltaOf(id, rank),
            isMe: u['_id'] == currentUserId,
            youLabel: l.youLabel,
            onTap: () => openStats(u),
          );
        }),
        const SizedBox(height: 16),
        _buildInviteLeave(context, c, l),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildInviteLeave(
      BuildContext context, EditorialColors c, AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _inviteFriend(selectedGroupName),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: c.live.withValues(alpha: 0.5), width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.share_outlined, color: c.live, size: 16),
                  const SizedBox(width: 8),
                  Text(l.invitefriend,
                      style: EType.label(
                          color: c.live, size: 12, letterSpacing: 1)),
                ],
              ),
            ),
          ),
          if (!isLoading && !_isCreatorOfActiveGroup) ...[
            const SizedBox(height: 10),
            _footerBtn(
              icon: Icons.logout,
              label: l.leave,
              color: c.flag,
              onTap: _leaveActiveGroup,
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
                style: EType.label(color: color, size: 11, letterSpacing: 1.8),
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
              child: Icon(Icons.groups_outlined, size: 30, color: c.inkMute),
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
                _ghostBtn(l.joingroup, _showJoinGroupDialog),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TableCache {
  static String? dashboardUserId;
  static Map<String, dynamic>? dashboard;
  static List<Map<String, dynamic>>? groupsInfo;
  static String? defaultGroupName;
  static String? lastSelectedGroupName;
  static final Map<String, List<Map<String, dynamic>>> users = {};
}

class _HeaderActionButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final IconData? icon;

  const _HeaderActionButton({
    required this.label,
    required this.onTap,
    required this.primary,
    this.icon,
  });

  @override
  State<_HeaderActionButton> createState() => _HeaderActionButtonState();
}

class _HeaderActionButtonState extends State<_HeaderActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.col;

    final Color fillColor = widget.primary ? c.live : c.cardHi;
    final Color textColor = widget.primary ? c.pitch : c.ink;
    final Color borderColor =
        widget.primary ? c.live : c.hairlineHi.withOpacity(0.55);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          height: 40,
          padding: EdgeInsets.symmetric(
            horizontal: widget.icon != null ? 14 : 18,
          ),
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: widget.primary
                ? [
                    BoxShadow(
                      color: c.live.withOpacity(_pressed ? 0.10 : 0.28),
                      blurRadius: _pressed ? 8 : 16,
                      spreadRadius: 0,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: textColor, size: 16),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label,
                style: GoogleFonts.sora(
                  fontSize: 13,
                  color: textColor,
                  fontWeight:
                      widget.primary ? FontWeight.w700 : FontWeight.w600,
                  letterSpacing: 0.2,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Position-change arrow: green up / red down / dash for no change ─────────
class _DeltaArrow extends StatelessWidget {
  const _DeltaArrow({required this.delta});
  final int delta;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    if (delta == 0) {
      return Text('–', style: EType.body(color: c.inkDim, size: 14));
    }
    final up = delta > 0;
    final color = up ? c.live : c.flag;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${delta.abs()}',
            style:
                EType.numeric(color: color, size: 12, weight: FontWeight.w700)),
        Icon(up ? Icons.arrow_drop_up : Icons.arrow_drop_down,
            color: color, size: 18),
      ],
    );
  }
}

// ── One leaderboard row (rank 4+): number · name · change · points ─────────
class _LeaderRow extends StatelessWidget {
  const _LeaderRow({
    required this.rank,
    required this.name,
    required this.dayPoints,
    required this.dayPositive,
    required this.points,
    required this.delta,
    required this.isMe,
    required this.youLabel,
    required this.onTap,
  });
  final int rank;
  final String name;
  final String dayPoints;
  final bool dayPositive;
  final String points;
  final int delta;
  final bool isMe;
  final String youLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isMe ? c.liveSoft : Colors.transparent,
          border: Border(
            bottom: BorderSide(color: c.hairline, width: 1),
            left:
                BorderSide(color: isMe ? c.live : Colors.transparent, width: 3),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text('$rank',
                  style: EType.numeric(
                      color: c.inkDim, size: 13, weight: FontWeight.w500)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: EType.body(
                        color: c.ink,
                        size: 14,
                        weight: isMe ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        border: Border.all(color: c.live, width: 1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(youLabel.toUpperCase(),
                          style: EType.label(
                              color: c.live, size: 9, letterSpacing: 1.2)),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(
              width: 28,
              child: Center(child: _DeltaArrow(delta: delta)),
            ),
            SizedBox(
              width: 64,
              child: Text(dayPoints,
                  textAlign: TextAlign.center,
                  style: EType.numeric(
                      color: dayPositive ? c.live : c.inkMute,
                      size: 13,
                      weight: FontWeight.w500)),
            ),
            SizedBox(
              width: 50,
              child: Text(points,
                  textAlign: TextAlign.end,
                  style: EType.numeric(
                      color: c.ink, size: 15, weight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Podium (top 3): #1 centered and elevated, #2 right, #3 left ────────────
class _PodiumData {
  const _PodiumData({
    required this.rank,
    required this.name,
    required this.points,
    required this.isMe,
    required this.onTap,
  });
  final int rank;
  final String name;
  final String points;
  final bool isMe;
  final VoidCallback onTap;
}

class _Podium extends StatelessWidget {
  const _Podium({required this.spots});
  final List<_PodiumData> spots;

  _PodiumData? _byRank(int r) {
    for (final s in spots) {
      if (s.rank == r) return s;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final r1 = _byRank(1);
    final r2 = _byRank(2);
    final r3 = _byRank(3);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
              child:
                  r2 != null ? _PodiumSpot(data: r2) : const SizedBox.shrink()),
          Expanded(
              child: r1 != null
                  ? _PodiumSpot(data: r1, big: true)
                  : const SizedBox.shrink()),
          Expanded(
              child:
                  r3 != null ? _PodiumSpot(data: r3) : const SizedBox.shrink()),
        ],
      ),
    );
  }
}

class _PodiumSpot extends StatelessWidget {
  const _PodiumSpot({required this.data, this.big = false});
  final _PodiumData data;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final rankColor = data.rank == 1
        ? c.amber
        : data.rank == 2
            ? c.chalk
            : const Color(0xFFCD7F32); // bronze
    final size = big ? 68.0 : 56.0;
    final initial = data.name.isNotEmpty ? data.name[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: data.onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: data.isMe ? c.live : c.cardHi,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: data.isMe ? c.live : rankColor, width: 2),
                ),
                child: Text(initial,
                    style: EType.display(
                        size: big ? 26 : 20,
                        color: data.isMe ? c.pitch : rankColor)),
              ),
              Positioned(
                bottom: -8,
                child: Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: rankColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.pitch, width: 2),
                  ),
                  child: Text('${data.rank}',
                      style: EType.numeric(
                          color: c.pitch, size: 11, weight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(data.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style:
                  EType.body(color: c.ink, size: 12, weight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(data.points,
              style: EType.numeric(
                  color: data.rank == 1 ? c.live : c.ink,
                  size: big ? 18 : 15,
                  weight: FontWeight.w700)),
        ],
      ),
    );
  }
}
