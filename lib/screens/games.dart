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
import 'package:football/widgets/teamSelect.dart';
import 'package:football/widgets/toggleButton.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../models/users.dart';

class GamesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, UserProvider>(
      builder: (context, authProvider, userProvider, child) {
        // Check if user is authenticated
        if (authProvider.currentUser == null) {
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
  bool _showOnlyThisLeagueTodayGames = false;
  late String clientId;
  late String email;
  int selectedIndex = 0;
  bool isLoading = true;

  void updateSelectedIndex(int index) {
    print(index);
    setState(() {
      isLoading = true;
      league = index == 0
          ? 2
          : index == 1
              ? 383
              : index == 2
                  ? 140
                  : 3;
                   
      selectedIndex = index;
    
      Provider.of<UserProvider>(context, listen: false)
          .setselectedLeageId(league);
    });
    _fetchGames(league);
  }

  Map<int, Map<String, TextEditingController>> _guessControllers = {};
  void initState() {
    super.initState();
    clientId = widget.authProvider.currentUser?.id ?? 'Not logged in';
    email = widget.authProvider.currentUser?.email ?? 'Not logged in';
    league = widget.userProvider.selectedLeageId ?? 2;

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

  void toggleShowOnlyTodayGames() {
    setState(() {
      _showOnlyTodayGames = !_showOnlyTodayGames;
    });
    _fetchGames(league);
  }

  void toggleshowOnlyThisLeagueTodayGames() {
    setState(() {
      _showOnlyThisLeagueTodayGames = !_showOnlyThisLeagueTodayGames;
    });
    _fetchGames(league);
  }

  Future<void> _fetchGames(league) async {
    isLoading = true;
    try {
      List<Game> fetchedGames;

      if (_showOnlyTodayGames) {
        fetchedGames = await GamesMethods().fetchAllGames(
            league, _showOnlyThisLeagueTodayGames,
            onlyTodayGames: _showOnlyTodayGames);
      } else {
        fetchedGames = await GamesMethods().fetchGamesForLeague(league);
      }

      setState(() {
        _games = fetchedGames;
        for (var game in _games) {
          if (_guessControllers[game.fixtureId] == null) {
            _guessControllers[game.fixtureId] = {
              'home': TextEditingController(),
              'away': TextEditingController(),
            };
          }
          print(game.league.id);
        }
        isLoading = false;
      });
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
// print(' league: ${league}');
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
          print(' leagueId: ${game.league.id}');
          var guessData = {
            'userID': clientId,
            'gameID': game.fixtureId,
            'gameOriginalID': game.fixtureId,
            'expectedPoints': 0,
            'home_team_goals': homeScore,
            'away_team_goals': awayScore,
            // 'sum_points': 0,
            'leagueID': game.league.id,
            // 'email': email,
          };

          if (existingGuess != null && game.status.long == "Not Started") {
            // Update existing guess

            updatedGuesses.add(guessData);
          }
          if (existingGuess == null) {
            // Create new guess
            guessData['email'] = email;
            guessData['sum_points'] = 0;
            newGuesses.add(guessData);
          }
        }
      }
    }

    if (newGuesses.isEmpty && updatedGuesses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.noguessesfound)),
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
        SnackBar(
            content: Text(AppLocalizations.of(context)!.savedsuccessfully)),
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
        // title: Text(
        //   'games',
        //   style: TextStyle(
        //     color: white, // White color for the team names
        //   ),
        // ),
        backgroundColor: Colors.transparent,
        actions: [
          Row(
            children: [
              if (_showOnlyTodayGames)
                Text(
                  AppLocalizations.of(context)!.thisleague,
                  style: TextStyle(
                      color: white,
                      fontSize: 14 // White color for the team names
                      ),
                ),
              if (_showOnlyTodayGames)
                Transform.scale(
                  scale: 0.6,
                  child: Switch(
                    value: _showOnlyThisLeagueTodayGames,
                    onChanged: (value) {
                      // setState(() {
                      //  _showOnlyThisLeagueTodayGames = value;
                      //   isLoading = true;
                      //   _fetchGames(league);
                      // });
                      toggleshowOnlyThisLeagueTodayGames();
                    },
                    activeColor: Colors.blue,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: Colors.grey,
                  ),
                ),
              Text(
                AppLocalizations.of(context)!.todayonly,
                style: TextStyle(
                    color: white, fontSize: 14 // White color for the team names
                    ),
              ),
              Transform.scale(
                scale: 0.6,
                child: Switch(
                  value: _showOnlyTodayGames,
                  onChanged: (value) {
                    toggleShowOnlyTodayGames();
                  },
                  activeColor: Colors.blue,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          ToggleButtonsSample(
            options: [
              AppLocalizations.of(context)!.championsleague,
              AppLocalizations.of(context)!.ligathaal,
              AppLocalizations.of(context)!.laliga,
              AppLocalizations.of(context)!.europaleague,
            ],
            imageUrls: [
              'https://media.api-sports.io/football/leagues/2.png',
              'https://media.api-sports.io/football/leagues/383.png',
              'https://media.api-sports.io/football/leagues/140.png',
              'https://media.api-sports.io/football/leagues/3.png', // Assuming this is Europa League
            ],
            onSelectionChanged: updateSelectedIndex,
            initialSelection: league == 2
                ? 0
                : league == 383
                    ? 1
                    : league == 140
                        ? 2
                        : 3,
          ),
          SizedBox(
            height: 5,
          ),
          Row(
            // mainAxisAlignment: MainAxisAlignment.center,
            children: [
                   SizedBox(
                width: 5,
              ),
              TeamSelectionButton(
                games: _games,
                clientId: clientId,
                email: email,
                league: league,
                onTeamSelected: (selectedTeam) {
                  print('Selected team: $selectedTeam');
                  // Do something with the selected team
                },
              ),
            ],
          ),
                 SizedBox(
            height: 5,
          ),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : _games.isEmpty
                    ? Center(
                        child: Text(
                          AppLocalizations.of(context)!.nogames,
                          style: TextStyle(
                            color: Colors.white, // Customize the text color
                            fontSize: 20, // Customize the font size
                            fontWeight:
                                FontWeight.bold, // Customize the font weight
                          ),
                        ),
                      )
                    : listView(_games),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _submitAllGuesses,
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        tooltip: 'Submit All Guesses', // Add a tooltip
        child: Icon(Icons.send),
      ),
    );
  }

  ListView listView(List<Game> filteredGames) {
    return ListView.separated(
      itemCount: filteredGames.length,
      itemBuilder: (BuildContext context, int index) {
        final game = filteredGames[index];
        final matchingGuesses =
            _guesses.where((g) => g.gameOriginalId == game.fixtureId).toList();
        final guess = matchingGuesses.isNotEmpty ? matchingGuesses.first : null;
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
                  builder: (context) => GameDetails(
                    gameOriginalId: game.fixtureId,
                    game: game,
                  ),
                ),
              );
          },
        );
      },
      separatorBuilder: (BuildContext context, int index) =>
          Divider(height: 0.0, color: background),
      padding: EdgeInsets.symmetric(horizontal: 2.0, vertical: 2.0),
    );
  }
}
