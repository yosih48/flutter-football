import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:football/models/games.dart';
import 'package:football/models/guesses.dart';
import 'package:football/resources/usersMethods.dart';
import 'package:football/theme/colors.dart';
import 'package:football/utils/config.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class TeamSelectionButton extends StatefulWidget {
  final List<Game> games;
  final clientId;
  final email;
  final league;
  final void Function(String) onTeamSelected;

  const TeamSelectionButton({
    Key? key,
    required this.games,
    required this.clientId,
    required this.email,
    required this.league,
    required this.onTeamSelected,
  }) : super(key: key);

  @override
  _TeamSelectionButtonState createState() => _TeamSelectionButtonState();
}

class _TeamSelectionButtonState extends State<TeamSelectionButton> {
  String? selectedTeam;
  bool isWinnerButtonEnabled = true;
  bool isLoading = false;
  bool hasWinner = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  void didUpdateWidget(TeamSelectionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.league != widget.league) {
      // The league has changed, trigger the logic to fetch new games or data

      _fetchUserData();
    }
  }

  Future<void> _fetchUserData() async {
 
    try {
      final userData = await UsersMethods().fetchUserById(widget.clientId);
      final leagueId = widget.league;
      final winner = userData['winner']?['$leagueId'];
      // final winner = userData['winner'];
    
      print(winner);
      setState(() {
        if (winner != null) {
        

          selectedTeam = winner;
          hasWinner = true;
          print(selectedTeam);
        } else {
          hasWinner = false;
          selectedTeam = null;
        }
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching user data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  List<String> _fetchAllTeams() {

    final filteredGames = widget.games.where((game) {
      if (game.league.id == 2 || game.league.id == 848 || game.league.id == 3) {
        return !game.league.round.contains("Qualifying") &&
            !game.league.round.contains("Play-offs");
      }
      return true;
    }).toList();

    return filteredGames
        .expand((game) => [game.home.name, game.away.name])
        .toSet()
        .toList();
  }

  Future<void> saveTeam() async {

      // const _baseUrl = 'https://leagues.onrender.com/users';
  const _baseUrl = backendUrl;
    if (selectedTeam == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a team first')),
      );
      return;
    }

    final leagueId = widget.league;
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/users/winner'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, dynamic>{
          '_id': widget.clientId,
          'email': widget.email,
          'winner': {
            'winner.$leagueId': selectedTeam,
          },
        }),
      );

      if (response.statusCode == 200) {
        print('User updated successfully');
        setState(() {
          isWinnerButtonEnabled = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Team saved successfully')),
          
        );
                      _fetchUserData();

      } else {
        print(
            'Users update group Fetch failed with status: ${response.statusCode}');
        print(jsonDecode(response.body));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save team')),
        );
      }
    } catch (error) {
      print('Error editing guesses: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An error occurred while saving the team')),
      );
    }
  }

  void _showTeamSelectionDialog() async {
    final teams = await _fetchAllTeams();
    print('teams: ${teams}');
    if (selectedTeam != null && !teams.contains(selectedTeam)) {
      selectedTeam = null;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String? localSelectedTeam = selectedTeam;
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            backgroundColor: cards,
            title: Text(
              AppLocalizations.of(context)!.teamcannotbechanged,
              style: TextStyle(color: Colors.red, fontSize: 16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<String>(
                  // value: selectedTeam,
                  hint: Text(AppLocalizations.of(context)!.chooseteam,
                      style: TextStyle(
                        color:
                            Colors.blue, // Change the input text color to blue
                      )),
                  isExpanded: true,
                  items: teams.map((String team) {
                    return DropdownMenuItem<String>(
                      value: team,
                      child: Text(team),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      selectedTeam = newValue;
                      localSelectedTeam = newValue;
                 
                    });
                  },
                ),
                SizedBox(height: 20),
                if (selectedTeam != null) ...[
                Text(
                  '$localSelectedTeam',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                ],
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: isWinnerButtonEnabled
                      ? () {
                          saveTeam();
                          Navigator.of(context).pop();
                        }
                      : null,
                  child: Text(AppLocalizations.of(context)!.saveteam,
                      style: TextStyle(color: Colors.blue)),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Sort the games list by fixture.date to find the first game
    // widget.games.sort((a, b) => a['date'].compareTo(b['fixture']['date']));

 
    // Get the date of the first game
    DateTime? firstGameDate;
    if (widget.games.isNotEmpty) {
      firstGameDate = widget.games[0].date.toUtc();
    }
    
    DateTime currentTimeUtc = DateTime.now().toUtc();
    // Check if the current time is before the first game date
    bool isBeforeFirstGame =
        firstGameDate != null && currentTimeUtc.isBefore(firstGameDate);


    if (isLoading) {
      return CircularProgressIndicator(
        color: Colors.transparent,

      );
    }

    if (hasWinner) {
      print('has winner');
          return SizedBox();
      // return Text(
      //   '${AppLocalizations.of(context)!.yourwinner}: $selectedTeam',
      //   style: TextStyle(
      //     color:
      //         Colors.white, // Light gray color for the "Your guess" and score
      //     fontSize: 18.0,
      //   ),
      // );
    }
    if (isBeforeFirstGame)
      return Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          TextButton.icon(
            icon: Icon(
              Icons.add,
              color: Colors.white,
            ),
            label: Text(
              AppLocalizations.of(context)!.choosewinner,
              style: TextStyle(
                color: white,
              ),
            ),
            onPressed: _showTeamSelectionDialog,
          ),
        ],
      );

    return SizedBox();
  }
}
