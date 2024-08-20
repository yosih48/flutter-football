import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:football/models/games.dart';
import 'package:football/models/guesses.dart';
import 'package:football/models/users.dart';
import 'package:football/models/users.dart';
import 'package:football/models/users.dart';
import 'package:football/providers/flutter%20pub%20add%20provider.dart';
import 'package:football/resources/auth.dart';
import 'package:football/resources/gamesMethods.dart';
import 'package:football/resources/guessesMethods.dart';
import 'package:football/screens/gameDetails.dart';
import 'package:football/screens/login_screen.dart';
import 'package:football/theme/colors.dart';
import 'package:football/widgets/gamesCard.dart';
import 'package:football/widgets/toggleButton.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/users.dart';

class GamesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, UserProvider>(
      builder: (context, authProvider, userProvider, child) {
        // Check if user is authenticated
        if (authProvider.user == null) {
          return LoginScreen(); // Or some other widget for unauthenticated users
        }
        return _GamesScreenContent(
          authProvider: authProvider,
          userProvider: userProvider,
        );
      },
    );
  }
}

class _GamesScreenContent extends StatefulWidget {
  final AuthProvider authProvider;
  final UserProvider userProvider;

  _GamesScreenContent({
    required this.authProvider,
    required this.userProvider,
  });

  @override
  _GamesScreenContentState createState() => _GamesScreenContentState();
}

class _GamesScreenContentState extends State<_GamesScreenContent> {

  List<Game> _games = [];
  List<Guess> _guesses = [];
  int league = 2;
bool _showOnlyTodayGames = false;
  late String clientId;
  late String email;
    int selectedIndex = 0;
    void updateSelectedIndex(int index) {
      print(index);
    setState(() {
    league = index == 0 ? 2 :index == 1? 4: 140;
      selectedIndex = index;
     
    });
      _fetchGames(league); 
  }

  Map<int, Map<String, TextEditingController>> _guessControllers = {};
  void initState() {
    super.initState();
    clientId = widget.authProvider.user?.id ?? 'Not logged in';
    email = widget.authProvider.user?.email ?? 'Not logged in';
    print(clientId);
    print(email);
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
bool isGameToday(String formattedDate) {
  final today = DateFormat('dd/MM/yy').format(DateTime.now());
  return formattedDate == today;
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
  List<Map<String, dynamic>> newGuesses = [];
  List<Map<String, dynamic>> updatedGuesses = [];

  for (var game in _games) {
    var controllers = _guessControllers[game.fixtureId];
    if (controllers != null) {
      var homeScore = controllers['home']?.text;
      var awayScore = controllers['away']?.text;

      if (homeScore != null &&
          awayScore != null &&
          homeScore.isNotEmpty &&
          awayScore.isNotEmpty) {
        
        // Check if a guess already exists for this game
     Guess? existingGuess;
try {
  existingGuess = _guesses.firstWhere(
    (g) => g.gameOriginalId == game.fixtureId,
  );
} catch (e) {
  // No matching guess found
  existingGuess = null;
}

        var guessData = {
          'userID': clientId,
          'gameID': game.fixtureId,
          'gameOriginalID': game.fixtureId,
          'expectedPoints': 0,
          'home_team_goals': homeScore,
          'away_team_goals': awayScore,
          'sum_points': 0,
          'leagueID': league,
          // 'email': email,
        };

           if (existingGuess != null) {
          // Update existing guess
          updatedGuesses.add(guessData);
        } else {
          // Create new guess
            guessData['email'] = email;
          newGuesses.add(guessData);
        }
      }
    }
  }

  if (newGuesses.isEmpty && updatedGuesses.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("No new or updated guesses to submit")),
    );
    return;
  }

  final newGuessUrl = Uri.parse('https://leagues.onrender.com/guesses/add');
  final updateGuessUrl = Uri.parse('https://leagues.onrender.com/guesses/');
  bool allSuccessful = true;

  // Submit new guesses
  for (var guess in newGuesses) {
    final response = await http.post(
      newGuessUrl,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(guess),
    );

    if (response.statusCode != 200) {
      allSuccessful = false;
      print("Failed to submit new guess: ${response.body}");
    }
  }

  // Update existing guesses
  for (var guess in updatedGuesses) {
    final response = await http.put(
      updateGuessUrl,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(guess),
    );

    if (response.statusCode != 200) {
      allSuccessful = false;
      print("Failed to update guess: ${response.body}");
    }
  }

  if (allSuccessful) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("All guesses submitted or updated successfully")),
    );
    _fetchGuesses(clientId); // Refresh guesses after submission
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Failed to submit or update some guesses")),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: background,
      appBar: AppBar(
        title: Text('games',
  style: TextStyle(
  color: white, // White color for the team names

),
        ),
           backgroundColor: Colors.transparent,
              actions: [
        Row(
          children: [
            Text('Today only',
              style: TextStyle(
  color: white, // White color for the team names

),
            ),
            Switch(
              value: _showOnlyTodayGames,
              onChanged: (value) {
                setState(() {
                  _showOnlyTodayGames = value;
                });
              },
            ),
          ],
        ),
      ],
      ),
            body: Column(
        children: [
          ToggleButtonsSample(
            options: [
              'champ',
              'euro',
              // 'english',
              'spain'
              // AppLocalizations.of(context)!.opens,
              // AppLocalizations.of(context)!.history
            ],
            onSelectionChanged: updateSelectedIndex,
            initialSelection: 0,
          ),
          Expanded(
            child: listView(),
          ),
        ],
      ),
 floatingActionButton: FloatingActionButton(
        onPressed: _submitAllGuesses,
        child: Icon(Icons.send),
        tooltip: 'Submit All Guesses',
      ),
    );
  }

  ListView listView() {
      final filteredGames = _showOnlyTodayGames
      ? _games.where((game) => isGameToday( DateFormat('dd/MM/yy').format(game.date))).toList()
      : _games;
    return ListView.separated(
      itemCount: filteredGames.length,
      itemBuilder: (BuildContext context, int index) {
        final game = filteredGames[index];
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
              if (game.status.long != "Not Started")
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    GameDetails(gameOriginalId: game.fixtureId,
                  game: game,
                ),
              ),
            );
          },
        );
      },
  separatorBuilder: (BuildContext context, int index) => Divider(height: 0.0, color: background),
    padding: EdgeInsets.symmetric(horizontal: 2.0, vertical: 2.0),
    );
  }
}
