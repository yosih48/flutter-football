import 'package:flutter/material.dart';
import 'package:football/providers/flutter%20pub%20add%20provider.dart';
import 'package:football/resources/auth.dart';
import 'package:football/resources/usersMethods.dart';
import 'package:football/screens/login_screen.dart';
import 'package:football/theme/colors.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

class ProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, UserProvider>(
      builder: (context, authProvider, userProvider, child) {
        if (authProvider.currentUser == null) {
          return LoginScreen();
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
  Map<String, String> _userWinners = {};
  Map<String, String> _userTopScorer = {};
  Map<String, int> _userTopScorerPoints = {};
  bool _isLoading = true;
  bool _showWinners = true;
  late String currentUserId;
  late String currentUserEmail;
  late String currentUserName;

  @override
  void initState() {
    super.initState();
    currentUserId = widget.authProvider.currentUser?.id ?? '';
    currentUserEmail = widget.authProvider.currentUser?.email ?? '';
    currentUserName = widget.authProvider.currentUser?.name ?? '';
    _fetchPersonalData();
  }

  Future<void> _fetchPersonalData() async {
    try {
      final userData = await UsersMethods().fetchUserById(currentUserId);
      if (!mounted) return;
      setState(() {
        _userWinners = Map<String, String>.from(userData['winner'] ?? {});
        _userTopScorer =
            Map<String, String>.from(userData['topScorer'] ?? {});
        _userTopScorerPoints =
            Map<String, int>.from(userData['topScorerPoints'] ?? {});
        _isLoading = false;
      });
      Provider.of<UserProvider>(context, listen: false)
          .setCurrentUser(currentUserId);
    } catch (e) {
      print('Failed to fetch personal data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
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

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: kToolbarHeight + 20),
            _buildPersonalHeader(),
            SizedBox(height: 32),
            _buildToggle(),
            SizedBox(height: 16),
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: cards.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              constraints: BoxConstraints(minHeight: 220),
              child: Skeletonizer(
                enabled: _isLoading,
                child: AnimatedSwitcher(
                  duration: Duration(milliseconds: 300),
                  child: _showWinners
                      ? usersWinners(
                          key: ValueKey('winners'),
                          userWinners: _isLoading
                              ? {'2': 'Loading', '39': 'Loading'}
                              : _userWinners,
                          filteredWinners: _isLoading
                              ? {'2': 'Loading', '39': 'Loading'}
                              : filteredWinners,
                        )
                      : usersTopScorers(
                          key: ValueKey('topScorers'),
                          userTopScorers: _isLoading
                              ? {'2': 'Loading', '39': 'Loading'}
                              : _userTopScorer,
                          userTopScorerPoints: _isLoading
                              ? {'2': 10, '39': 20}
                              : _userTopScorerPoints,
                          filteredTopScorers: _isLoading
                              ? {'2': 'Loading', '39': 'Loading'}
                              : _userTopScorer.entries
                                  .where((entry) =>
                                      allowedGroupIds.contains(entry.key))
                                  .fold<Map<String, String>>({},
                                      (map, entry) {
                                  map[entry.key] = entry.value;
                                  return map;
                                }),
                        ),
                ),
              ),
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalHeader() {
    final initial =
        currentUserName.isNotEmpty ? currentUserName[0].toUpperCase() : '?';
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.blue.withOpacity(0.2),
            child: Text(
              initial,
              style: TextStyle(
                color: Colors.blue,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentUserName.isNotEmpty ? currentUserName : '—',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  currentUserEmail,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showWinners = true),
              child: Container(
                padding:
                    EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: _showWinners
                      ? Colors.blue.withOpacity(0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _showWinners
                        ? Colors.blue
                        : Colors.grey.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.emoji_events,
                      color: _showWinners ? Colors.blue : Colors.grey,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context)!.yourwinners,
                      style: TextStyle(
                        color:
                            _showWinners ? Colors.blue : Colors.grey,
                        fontSize: 16,
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
          SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showWinners = false),
              child: Container(
                padding:
                    EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: !_showWinners
                      ? Colors.blue.withOpacity(0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: !_showWinners
                        ? Colors.blue
                        : Colors.grey.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.sports_soccer,
                      color: !_showWinners ? Colors.blue : Colors.grey,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context)!.topScorers ??
                          "Top Scorers",
                      style: TextStyle(
                        color:
                            !_showWinners ? Colors.blue : Colors.grey,
                        fontSize: 16,
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
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.emoji_events_outlined,
                        size: 36, color: Colors.blue),
                  ),
                  SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.noWinnersYet,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    AppLocalizations.of(context)!.noWinnersHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          )
        : ListView.separated(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            padding: EdgeInsets.all(8),
            itemCount: filteredWinners.length,
            separatorBuilder: (context, index) => Divider(
              color: Colors.white.withOpacity(0.1),
              height: 1,
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
                  leagueColor = Colors.purple;
                  break;
                case '848':
                  leagueName = AppLocalizations.of(context)!.conferenceleague;
                  leagueColor = Colors.purple;
                  break;
              }

              return ListTile(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: leagueColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
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
                title: Text(
                  leagueName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  AppLocalizations.of(context)!.yourprediction ??
                      "Your prediction",
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
                trailing: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: leagueColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
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
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.sports_soccer_outlined,
                        size: 36, color: Colors.blue),
                  ),
                  SizedBox(height: 16),
                  Text(
                    AppLocalizations.of(context)!.noTopScorersYet,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    AppLocalizations.of(context)!.noTopScorersHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          )
        : ListView.separated(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            padding: EdgeInsets.all(8),
            itemCount: filteredTopScorers.length,
            separatorBuilder: (context, index) => Divider(
              color: Colors.white.withOpacity(0.1),
              height: 1,
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
                  leagueColor = Colors.purple;
                  break;
                case '848':
                  leagueName = AppLocalizations.of(context)!.conferenceleague;
                  leagueColor = Colors.purple;
                  break;
              }

              return ListTile(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: leagueColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
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
                title: Text(
                  leagueName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Row(
                  children: [
                    Text(
                      AppLocalizations.of(context)!.topScorerPoints ??
                          "Goals Points",
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(width: 5),
                    Text(
                      '${userTopScorerPoints[groupId] ?? 0}'
                      ' ${AppLocalizations.of(context)!.pst}',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
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
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: 100),
                            child: Text(
                              topScorerName,
                              style: TextStyle(
                                color: leagueColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
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
