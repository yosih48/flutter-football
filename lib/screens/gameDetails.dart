import 'package:flutter/material.dart';
import 'package:football/models/games.dart';
import 'package:football/models/guesses.dart';
import 'package:football/providers/flutter%20pub%20add%20provider.dart';
import 'package:football/resources/guessesMethods.dart';
import 'package:football/resources/usersMethods.dart';
import 'package:football/screens/table.dart';
import 'package:football/theme/colors.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class GameDetails extends StatefulWidget {
  final gameOriginalId;
  final Game game;

  const GameDetails(
      {super.key, required this.gameOriginalId, required this.game});

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
  @override
  void initState() {
    super.initState();
    league = widget.game.league.id;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    currentUserId = userProvider.currentUserId!;

    print('currentUserId: ${currentUserId}');

    _fetchUserGroups();
    _fetchGuesses(selectedGroupName);
  }

  Future<void> _fetchUserGroups() async {
    try {
      Map<String, dynamic> userData =
          await UsersMethods().fetchUserById(currentUserId);
      setState(() {
        //   _userGroups = Map<String, String>.from(userData['groupID'] ?? {});
        //   print(_userGroups);

        //  selectedGroupName = _userGroups.values.first;
        //       _fetchGuesses(selectedGroupName);

        Map<String, String> tempGroups =
            Map<String, String>.from(userData['groupID'] ?? {});

        // Remove the 'public' group if it exists
        tempGroups.removeWhere((key, value) => value.toLowerCase() == 'public');

        // Assign the filtered map to _userGroups
        _userGroups = tempGroups;

        print(_userGroups);
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        // selectedGroupName = userProvider.selectedGroupName;
        // Check if _userGroups is not empty before accessing first value
        if (_userGroups.isNotEmpty && userProvider.selectedGroupName != 'public') {
          // print('  userProvider.selectedGroupName: ${userProvider.selectedGroupName}');
          // selectedGroupName = _userGroups.values.first;
          selectedGroupName = userProvider.selectedGroupName;
          _fetchGuesses(selectedGroupName);
        } else {
          selectedGroupName = _userGroups.values.first;
             _fetchGuesses(selectedGroupName);
          // Handle the case when no groups are left after removing 'public'
          print('No groups available after removing public');
          // You might want to set a default state or show a message to the user
        }
      });
    } catch (e) {
      print('Failed to fetch user groups: $e');
    }
  }

  Future<void> _fetchGuesses(groupName) async {
    // final userProvider = Provider.of<UserProvider>(context, listen: false);
    // selectedGroupName = userProvider.selectedGroupName;

    try {
      final guesses =
          await GuessesMethods().fetchAllUsersGuesses(widget.gameOriginalId);
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
      //     for (var guessWithName in _guessesWithNames) {
      //   print(guessWithName.userGroups);
      // }
    } catch (e, stackTrace) {
      print('Failed to fetch guesses: $e');
      print('Stack trace: $stackTrace');
      // You might want to show an error message to the user here
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        // title: Text(
        //   'Game Details',
        //   style: TextStyle(
        //     color: white, // White color for the team names
        //   ),
        // ),
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(
          color: Colors.white, // Set the color of the arrow icon to white
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
    return Card(
      color: cards,
      margin: EdgeInsets.all(16.0),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGameHeader(),
            SizedBox(height: 8.0),
            _buildTeamScores(),
            SizedBox(height: 8.0),
            // Add any additional rows here
          ],
        ),
      ),
    );
  }

  Widget _buildGameHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          widget.game.status.long,
          style: TextStyle(
            color: (widget.game.status.long == "First Half" ||
                    widget.game.status.long == "Second Half" ||
                    widget.game.status.long == "Halftime")
                ? Colors.red
                : Color(0xFF9BA4B5).withOpacity(0.6),
            fontSize: 14.0,
          ),
        ),
        Text(
          DateFormat('dd/MM/yy').format(widget.game.date),
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
          child: _buildTeamInfo(widget.game.home, isHome: true),
        ),
        SizedBox(width: 8.0),
        Text(
          '${widget.game.goals.home} - ${widget.game.goals.away}',
          style: TextStyle(
            color: Colors.white, // White color for the team names
            fontWeight: FontWeight.bold,
            fontSize: 18.0,
          ),
        ),
        SizedBox(width: 8.0),
        Expanded(
          child: _buildTeamInfo(widget.game.away, isHome: false),
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
        if (isHome) ...[
          SizedBox(width: 6.0),
          _buildTeamLogo(team),
        ],
      ],
    );
  }

  Widget _buildTeamLogo(Team team) {
    return Image.network(
      team.logo,
      width: 24.0,
      height: 24.0,
    );
  }

  Widget _buildGuessesTable() {
    return Column(
      children: [
        if (_userGroups.isNotEmpty)
          Container(
            width: 300,
            child: DropdownButton<String>(
              value: selectedGroupName,
              dropdownColor: cards,
              style: TextStyle(color: Colors.white, fontSize: 16.0),
              isExpanded: true,
              items: _userGroups.entries.map((entry) {
                return DropdownMenuItem<String>(
                  value: entry.value,
                  child:
                      Text(entry.value, style: TextStyle(color: Colors.white)),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    selectedGroupName = newValue;
                  });
                  print(newValue);
                  _fetchGuesses(newValue);
                }
              },
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
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
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
                                        style: TextStyle(color: Colors.white),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Center(
                                      child: Text(
                                        '${guessWithName.guess.homeTeamGoals} - ${guessWithName.guess.awayTeamGoals}',
                                        style: TextStyle(color: Colors.white),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Center(
                                      child: Text(
                                        guessWithName.guess.sumPoints % 1 == 0
                                            ? guessWithName.guess.sumPoints
                                                .toInt()
                                                .toString()
                                            : guessWithName.guess.sumPoints
                                                .toString(),
                                        style: TextStyle(color: Colors.white),
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
}
