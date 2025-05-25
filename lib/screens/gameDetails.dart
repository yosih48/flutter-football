import 'package:flutter/material.dart';
import 'package:football/models/games.dart';
import 'package:football/models/guesses.dart';
import 'package:football/providers/flutter%20pub%20add%20provider.dart';
import 'package:football/resources/auth.dart';
import 'package:football/resources/guessesMethods.dart';
import 'package:football/resources/usersMethods.dart';
import 'package:football/screens/login_screen.dart';
import 'package:football/screens/profile.dart';
import 'package:football/screens/table.dart';
import 'package:football/theme/colors.dart';
import 'package:football/widgets/SharedPreferences.dart';
import 'package:football/widgets/teamLinks.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class GameDetails extends StatefulWidget {
  final gameOriginalId;
  final userId;
  final Game game;
  final List<Game> games;
  final int initialIndex;

  const GameDetails({
    super.key,
    required this.gameOriginalId,
    required this.game,
    required this.games,
    required this.initialIndex,
    this.userId,
  });

  @override
  State<GameDetails> createState() => _GameDetailsState();
}

class _GameDetailsState extends State<GameDetails> {
  List<Guess> _guesses = [];
  List<Map<String, dynamic>> _users = [];
  late String currentUserId;
  late int league;
  List<GuessWithNames> _guessesWithNames = [];
  late String selectedGroupName = "";
  Map<String, String> _userGroups = {};
  bool isLoading = true;
  late int _currentIndex;
  late Game _currentGame;

    Color getStatusColor(String status) {
    switch (status) {
      case "First Half":
      case "Second Half":
      case "Extra Time":
        return Colors.red;
      case "Halftime":
        return Colors.orange;
      case "Not Started":
        return Colors.grey;
      case "Match Finished":
        return Colors.green;
      case "Postponed":
      case "TBD":
        return Colors.yellow;
      default:
        return Color(0xFF9BA4B5).withOpacity(0.9);
    }
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    print('widget.initialIndex:${widget.initialIndex}');
    _currentGame = widget.games[_currentIndex];
    league = _currentGame.league.id;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    currentUserId = widget.userId;
    _fetchUserGroups();
    _fetchGuesses(selectedGroupName);
  }

  void _navigateToGame(int newIndex) {
    if (newIndex >= 0 && newIndex < widget.games.length) {
      setState(() {
        _currentIndex = newIndex;
        _currentGame = widget.games[newIndex];
        isLoading = true;
      });
      _fetchGuesses(selectedGroupName);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(
          color: Colors.white,
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildGameCard(),
                  _buildGuessesTable(),
                ],
              ),
            ),
    );
  }

  Widget _buildGameCard() {
    return GestureDetector(
      onHorizontalDragEnd: (DragEndDetails details) {
        if (details.primaryVelocity! < 0 ) {

          // Swipe right - go to previous game
          if (_currentIndex > 0 && widget.games[_currentIndex - 1].status.long != "Not Started") {
            print(widget.games[_currentIndex - 1].home.name);
        
            _navigateToGame(_currentIndex - 1);
          }
        } else if (details.primaryVelocity! > 0) {
    
          // Swipe left - go to next game
          if (_currentIndex < widget.games.length - 1 && widget.games[_currentIndex + 1].status.long != "Not Started") {
            _navigateToGame(_currentIndex + 1);
          }
        }
      },
      child: Stack(
        children: [
          Card(
            color: cards,
            margin: EdgeInsets.all(12.0),
            child: Padding(
              padding: EdgeInsets.only(
                  top: 8.0, bottom: 24.0, right: 16.0, left: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGameHeader(),
                  SizedBox(height: 16.0),
                  _buildTeamScores(),
                  SizedBox(height: 8.0),
                ],
              ),
            ),
          ),
          // Right arrow

          if (_currentIndex > 0 
          && widget.games[_currentIndex - 1].status.long != "Not Started"
          )
          
            Positioned(
              right: 10,
              top: 10,
              bottom: 0,
              child: Center(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      // color: Colors.black.withOpacity(0.5),
                      // shape: BoxShape.circle,
                      ),
                  child: IconButton(
                    icon: Icon(Icons.arrow_back_ios,
                        color: Colors.white, size: 20),
                    onPressed: () => _navigateToGame(_currentIndex - 1),
                  ),
                ),
              ),
            ),
          // Left arrow

          if (_currentIndex < widget.games.length - 1 
          && widget.games[_currentIndex + 1].status.long != "Not Started"
          )
            Positioned(
              left: 10,
              top: 10,
              bottom: 0,
              child: Center(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      // color: Colors.black.withOpacity(0.5),
                      // shape: BoxShape.circle,
                      ),
                  child: IconButton(
                    icon: Icon(Icons.arrow_forward_ios,
                        color: Colors.white, size: 20),
                    onPressed: () => _navigateToGame(_currentIndex + 1),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGameHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          // _currentGame.status.elapsed.toString(),
                   (_currentGame.status.long == "First Half" ||
                  _currentGame.status.long == "Second Half")
              ? "${_currentGame.status.elapsed}'"
              : _currentGame.status.long,
          style: TextStyle(
           color: getStatusColor(_currentGame.status.long),
            fontSize: 14.0,
          ),
        ),
        Text(
          DateFormat('dd/MM/yy').format(_currentGame.date),
          style: TextStyle(
            color: Color(0xFF9BA4B5).withOpacity(0.9),
            fontSize: 14.0,
          ),
        ),
      ],
    );
  }

  Widget _buildTeamScores() {
    return Row(
      children: [
        Expanded(
          child: _buildTeamInfo(_currentGame.home, isHome: true),
        ),
        SizedBox(width: 8.0),
        Text(
          '${_currentGame.goals.home} - ${_currentGame.goals.away}',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18.0,
          ),
        ),
        SizedBox(width: 8.0),
        Expanded(
          child: _buildTeamInfo(_currentGame.away, isHome: false),
        ),
      ],
    );
  }

  Widget _buildTeamInfo(Team team, {required bool isHome}) {
    return Row(
      mainAxisAlignment:
          isHome ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!isHome) _buildTeamLogo(team),
        SizedBox(width: 6.0),
        Flexible(
          child: GestureDetector(
            onTap: () => TeamLinkHandler.linkToTeam(team.name),
            child: Text(
              team.name,
              style: TextStyle(
                color: Colors.white, // White color for the team names
                fontWeight: FontWeight.bold,
                fontSize: 14.0,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: isHome ? TextAlign.right : TextAlign.left,
            ),
          ),
        ),
        if (isHome) ...[
          SizedBox(width: 6.0),
          _buildTeamLogo(team),
        ],
      ],
    );
  }

  Widget _buildTeamLogo(Team team) {
    return GestureDetector(
      onTap: () => TeamLinkHandler.linkToTeam(team.name),
      child: Image.network(
        team.logo,
        width: 24.0,
        height: 24.0,
      ),
    );
  }

  Widget _buildGuessesTable() {
    return Column(
      children: [
        if (_userGroups.isNotEmpty)
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedGroupName,
                dropdownColor: cards,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.0,
                  fontWeight: FontWeight.w500,
                ),
                icon: Icon(Icons.arrow_drop_down, color: Colors.blue),
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
                    _fetchGuesses(newValue);
                  }
                },
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 10.0),
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => TableScreen()),
              ),
              child: Text(
                AppLocalizations.of(context)!.joingrouptoseefreinds,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        if (_userGroups.isNotEmpty)
          if (_guessesWithNames.isNotEmpty)
            Container(
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
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints(minWidth: constraints.maxWidth),
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
                                      AppLocalizations.of(context)!.guess,
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
                            rows: _guessesWithNames
                                .map((guessWithName) => DataRow(
                                      cells: [
                                        DataCell(
                                          Center(
                                            child: Text(
                                              guessWithName.userName,
                                              style: TextStyle(
                                                  color: Colors.white),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Center(
                                            child: Text(
                                              '${guessWithName.guess.homeTeamGoals} - ${guessWithName.guess.awayTeamGoals}',
                                              style: TextStyle(
                                                  color: Colors.white),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Center(
                                            child: Text(
                                              guessWithName.guess.sumPoints %
                                                          1 ==
                                                      0
                                                  ? guessWithName
                                                      .guess.sumPoints
                                                      .toInt()
                                                      .toString()
                                                  : guessWithName
                                                      .guess.sumPoints
                                                      .toString(),
                                              style: TextStyle(
                                                  color: Colors.white),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ))
                                .toList(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'אין ניחושים',
                style: TextStyle(color: Colors.white),
              ),
            ),
      ],
    );
  }

  Future<void> _fetchUserGroups() async {
    try {
      Map<String, dynamic> userData =
          await UsersMethods().fetchUserById(currentUserId);
      setState(() {
        Map<String, String> tempGroups =
            Map<String, String>.from(userData['groupID'] ?? {});

        // Remove the 'public' group if it exists
        tempGroups.removeWhere((key, value) => value.toLowerCase() == 'public');

        // Assign the filtered map to _userGroups
        _userGroups = tempGroups;

        print(_userGroups);
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        // Check if _userGroups is not empty before accessing first value
        if (_userGroups.isNotEmpty &&
            userProvider.selectedGroupName != 'public') {
          selectedGroupName = userProvider.selectedGroupName;

          _fetchGuesses(selectedGroupName);
        } else {
          selectedGroupName = _userGroups.values.first;

          _fetchGuesses(selectedGroupName);
          // Handle the case when no groups are left after removing 'public'
          print('No groups available after removing public');
        }
      });
    } catch (e) {
      print('Failed to fetch user groups: $e');
    }
  }

  Future<void> _fetchGuesses(groupName) async {
    try {
      final guesses =
          await GuessesMethods().fetchAllUsersGuesses(_currentGame.fixtureId);
      final callService = CallService();
      final guessesWithNames = await Future.wait(
          guesses.map((guess) => callService.getGuessWithNames(guess)));

      final filteredGuesses = guessesWithNames.where((guessWithName) {
        return guessWithName.userGroups.values.contains(groupName);
      }).toList();

      setState(() {
        _guessesWithNames = filteredGuesses;
        isLoading = false;
      });
    } catch (e, stackTrace) {
      print('Failed to fetch guesses: $e');
      print('Stack trace: $stackTrace');
    }
  }
}
