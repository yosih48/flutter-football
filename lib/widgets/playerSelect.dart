import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:football/models/games.dart';
import 'package:football/models/guesses.dart';
import 'package:football/resources/usersMethods.dart';
import 'package:football/resources/gamesMethods.dart';
import 'package:football/resources/playersMethods.dart';
import 'package:football/theme/colors.dart';
import 'package:football/utils/config.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class PlayerSelectionButton extends StatefulWidget {
  // final List<Game> games;
  final clientId;
  final email;
  final league;
  final void Function(String) onPlayerSelected;

  const PlayerSelectionButton({
    Key? key,
    // required this.games,
    required this.clientId,
    required this.email,
    required this.league,
    required this.onPlayerSelected,
  }) : super(key: key);

  @override
  _PlayerSelectionButtonState createState() => _PlayerSelectionButtonState();
}

class _PlayerSelectionButtonState extends State<PlayerSelectionButton> {
  String? selectedPlayer;
  bool isPlayerButtonEnabled = true;
  bool isLoading = false;
  bool hasPlayer = true;
  List<Game> _allLeagueGames = [];

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchAllLeagueGames();
  }

  void didUpdateWidget(PlayerSelectionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.league != widget.league) {
      _fetchUserData();
      _fetchAllLeagueGames();
    }
  }

  Future<void> _fetchAllLeagueGames() async {
    try {
      final games = await GamesMethods().fetchGamesForLeague(widget.league);
      if (mounted) {
        setState(() {
          _allLeagueGames = games;
        });
      }
    } catch (e) {
      print('Error fetching all league games: $e');
    }
  }

  Future<void> _fetchUserData() async {
    try {
      final userData = await UsersMethods().fetchUserById(widget.clientId);
      final leagueId = widget.league;
      final winner = userData['topScorer']?['$leagueId'];
      // final winner = userData['winner'];

      print(winner);
      if (mounted) {
        setState(() {
          if (winner != null) {
            selectedPlayer = winner;
            hasPlayer = true;
            print(selectedPlayer);
          } else {
            hasPlayer = false;
            selectedPlayer = null;
          }
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching user data: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<List<String>> _fetchAllPlayers() async {
    try {
      // Create data to send - you might need to adjust this based on your backend requirements
      final dataToSend = {
        'league': widget.league,
        // Add any other required parameters for your backend
      };

      final players = await PlayersMethods().fetchPlayersList(dataToSend);
      print('Fetched players: ${players.length}');
      return players;
    } catch (e) {
      print('Error fetching players: $e');
      return [];
    }
  }

  Future<void> savePlayer() async {
    // const _baseUrl = 'https://leagues.onrender.com/users';
    String _baseUrl = backendUrl;
    if (selectedPlayer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(AppLocalizations.of(context)!.pleaseSelectplayerFirst)),
      );
      return;
    }

    final leagueId = widget.league;
    final cleanedPlayerName = selectedPlayer!.split(' (')[0];
    print('league id: ${leagueId}');
    print('selectedPlayer: ${selectedPlayer}');
    print('cleanedPlayerName: ${cleanedPlayerName}');
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/users/top-scorer'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, dynamic>{
          '_id': widget.clientId,
          'email': widget.email,
          'topScorer': {
            'topScorer.$leagueId': cleanedPlayerName,
          },
        }),
      );

      if (response.statusCode == 200) {
        print('User updated successfully');
        if (mounted) {
          setState(() {
            isPlayerButtonEnabled = false;
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(AppLocalizations.of(context)!.playerSavedsuccessfully),
            backgroundColor: cards,
          ),
        );
        _fetchUserData();
      } else {
        print(
            'Users update group Fetch failed with status: ${response.statusCode}');
        print(jsonDecode(response.body));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.failedtoSaveplayer),
            backgroundColor: cards,
          ),
        );
      }
    } catch (error) {
      print('Error editing guesses: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!.errorsavingplayer)),
      );
    }
  }

  void _showTeamSelectionDialog() async {
    final players = await _fetchAllPlayers();
    print('players: ${players}');
    if (selectedPlayer != null && !players.contains(selectedPlayer)) {
      selectedPlayer = null;
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String? localselectedPlayer = selectedPlayer;
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
                  // value: selectedPlayer,
                  hint: Text(AppLocalizations.of(context)!.choosPlayer,
                      style: TextStyle(
                        color:
                            Colors.blue, // Change the input text color to blue
                      )),
                  isExpanded: true,
                  items: players.map((String player) {
                    return DropdownMenuItem<String>(
                      value: player,
                      child: Text(player),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      selectedPlayer = newValue;
                      localselectedPlayer = newValue;
                    });
                  },
                ),
                SizedBox(height: 20),
                if (selectedPlayer != null) ...[
                  Text(
                    '$localselectedPlayer',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
                SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Colors.white, // Set button background to white
                  ),
                  onPressed: isPlayerButtonEnabled
                      ? () {
                          savePlayer();
                          Navigator.of(context).pop();
                        }
                      : null,
                  child: Text(AppLocalizations.of(context)!.savePlayer,
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
  void dispose() {
    // Clean up any resources if needed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Sort the games list by fixture.date to find the first game
    _allLeagueGames.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Get the date of the first game
    DateTime? firstGameDate;
    if (_allLeagueGames.isNotEmpty) {
      firstGameDate = _allLeagueGames[0].date.toUtc();
      print('firstGameDate: ${_allLeagueGames[0].date}');
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

    if (hasPlayer) {
      print('has winner');
      return SizedBox();
      // return Text(
      //   '${AppLocalizations.of(context)!.yourwinner}: $selectedPlayer',
      //   style: TextStyle(
      //     color:
      //         Colors.white, // Light gray color for the "Your guess" and score
      //     fontSize: 18.0,
      //   ),
      // );
    }
    // else{
    //  print('isBeforeFirstGame: ${isBeforeFirstGame}');
    // }
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
              AppLocalizations.of(context)!.chooseTopScorer,
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
