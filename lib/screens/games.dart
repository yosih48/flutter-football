import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:football/models/games.dart';
import 'package:football/models/guesses.dart';
import 'package:football/resources/gamesMethods.dart';
import 'package:football/resources/guessesMethods.dart';
import 'package:football/screens/gameDetails.dart';
import 'package:football/widgets/gamesCard.dart';
import 'package:http/http.dart' as http;

class GamesScreen extends StatefulWidget {
  @override
  _GamesScreenState createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  List<Game> _games = [];
  List<Guess> _guesses = [];
  int league = 39;
  String clientId = '6584aceb503733cfc6418e98';
  String email = 'yosihofman21@gmail.com';
  Map<int, Map<String, TextEditingController>> _guessControllers = {};
  void initState() {
    super.initState();
    _fetchGames(league);
    _fetchGuesses(clientId);
  }

  @override
  void dispose() {
    for (var controllers in _guessControllers.values) {
      controllers['home']?.dispose();
      controllers['away']?.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchGames(int leagueId) async {
    print('leagueId ${leagueId}');

    try {
      final games = await GamesMethods().fetchGames(leagueId);
      setState(() {
        _games = games;
      });
      setState(() {
        for (var game in _games) {
          if (_guessControllers[game.fixtureId] == null) {
            _guessControllers[game.fixtureId] = {
              'home': TextEditingController(),
              'away': TextEditingController(),
            };
          }
        }
      });
      // print(_games);
    } catch (e) {
      print('Failed to fetch games: $e');
    }
  }

  Future<void> _fetchGuesses(clientId) async {
    print('clientId ${clientId}');
    try {
      final guesses = await GuessesMethods().fetchThisUserGuesses(clientId);

      setState(() {
        _guesses = guesses;
      });

      setState(() {
        for (var guess in _guesses) {
          var controllers = _guessControllers[guess.gameOriginalId];
          if (controllers != null) {
            controllers['home']?.text = guess.homeTeamGoals.toString();
            controllers['away']?.text = guess.awayTeamGoals.toString();
          }
        }
      });
    } catch (e, stackTrace) {
      print('Failed to fetch guesses: $e');
      print('Stack trace: $stackTrace');
      // You might want to show an error message to the user here
    }
  }

  Future<void> _submitAllGuesses() async {
    List<Map<String, dynamic>> guesses = [];
    for (var game in _games) {
      var controllers = _guessControllers[game.fixtureId];
      if (controllers != null) {
        var homeScore = controllers['home']?.text;
        var awayScore = controllers['away']?.text;

        print("Game ${game.fixtureId} - Home: $homeScore, Away: $awayScore");

        if (homeScore != null &&
            awayScore != null &&
            homeScore.isNotEmpty &&
            awayScore.isNotEmpty) {
          guesses.add({
            'userID': clientId, // Replace with actual user ID
            'gameID': game.fixtureId,
            'gameOriginalID': game.fixtureId,
            'expectedPoints': 0, // You may need to calculate this
            'home_team_goals': homeScore,
            'away_team_goals':awayScore,
            'sum_points': 0,
            'leagueID': league, // Replace with actual league ID
            'email': email, // Replace with actual user email
          });
        }
      }
    }

    if (guesses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No guesses to submit")),
      );
      return;
    }

    final url = Uri.parse('https://leagues.onrender.com/guesses/add');
    bool allSuccessful = true;

    for (var guess in guesses) {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(guess), // Send each guess individually
      );

      if (response.statusCode != 200) {
        allSuccessful = false;
        print("Failed to submit guess: ${response.body}");
      }
    }

    if (allSuccessful) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("All guesses submitted successfully")),
      );
      _fetchGuesses(clientId); // Refresh guesses after submission
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to submit some guesses")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('games'),
      ),
      body: ListView.builder(
        itemCount: _games.length,
        itemBuilder: (BuildContext context, int index) {
          final game = _games[index];
          final matchingGuesses = _guesses
              .where((g) => g.gameOriginalId == game.fixtureId)
              .toList();
          final guess =
              matchingGuesses.isNotEmpty ? matchingGuesses.first : null;
          // Ensure controllers exist for this game
          if (_guessControllers[game.fixtureId] == null) {
            _guessControllers[game.fixtureId] = {
              'home': TextEditingController(),
              'away': TextEditingController(),
            };
          }
          return GameWidget(
            game: game,
            guess: guess,
            homeController: _guessControllers[game.fixtureId]?['home'],
            awayController: _guessControllers[game.fixtureId]?['away'],
            onTap: (context) async {
              print(game.fixtureId);
              // Your onTap logic here
              print('Game tapped!');
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      GameDetails(gameOriginalId: game.fixtureId),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _submitAllGuesses,
        child: Icon(Icons.send),
        tooltip: 'Submit All Guesses',
      ),
    );
  }
}
