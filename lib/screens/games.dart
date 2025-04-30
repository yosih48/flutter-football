import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:football/models/games.dart';
import 'package:football/models/guesses.dart';
import 'package:football/models/users.dart';
import 'package:football/models/users.dart';
import 'package:football/models/users.dart';
import 'package:football/providers/flutter%20pub%20add%20provider.dart';
import 'package:football/resources/appUpdates.dart';
import 'package:football/resources/auth.dart';
import 'package:football/resources/gamesMethods.dart';
import 'package:football/resources/guessesMethods.dart';
import 'package:football/resources/usersMethods.dart';
import 'package:football/screens/gameDetails.dart';
import 'package:football/screens/login_screen.dart';
import 'package:football/theme/colors.dart';
import 'package:football/utils/config.dart';

import 'package:football/widgets/gamesCard.dart';
import 'package:football/widgets/teamSelect.dart';
import 'package:football/widgets/toggleButton.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
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
  // bool _showOnlyTodayGames = false;
  bool _showOnlyThisLeagueTodayGames = false;
  late String clientId;
  late String email;
  int selectedIndex = 0;
  bool isLoading = true;
  bool buttonLoading = false;
  DateTime? selectedDate;
  bool _showSelectedDateGames = false;

  String _baseUrl = backendUrl;
  void updateSelectedIndex(int index) {
    print(index);
    setState(() {
      isLoading = true;
      league = index == 0
          ? 2 // Champions League
          : index == 1
              ? 383 // Ligat Ha'al
              : index == 2
                  ? 140 // La Liga
                  : index == 3
                      ? 3 // Europa League
                      : index == 4
                          ? 39 // Premier League
                          : index == 5
                              ? 78 // Bundesliga
                              : 2; // Default to Champions League

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
    selectedDate = DateTime.now().copyWith(
        hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);
    print('clientId in games: ${clientId}');

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

  // void toggleShowOnlyTodayGames() {
  //   setState(() {
  //     _showOnlyTodayGames = !_showOnlyTodayGames;
  //   });
  //   _fetchGames(league);
  // }

  void toggleshowOnlyThisLeagueTodayGames() {
    setState(() {
      _showOnlyThisLeagueTodayGames = !_showOnlyThisLeagueTodayGames;
    });
    _fetchGames(league);
  }

  Future<void> _selectDate(BuildContext context) async {
    try {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: selectedDate ?? DateTime.now(),
        firstDate: DateTime(2024),
        lastDate: DateTime(DateTime.now().year + 1),
        builder: (BuildContext context, Widget? child) {
          return Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: ColorScheme.dark(
                primary: Colors.blue,
                onPrimary: Colors.white,
                surface: Color(0xFF303030),
                onSurface: Colors.white,
              ),
              dialogBackgroundColor: Color(0xFF303030),
            ),
            child: child ?? Container(),
          );
        },
      );

      if (picked != null) {
        setState(() {
          selectedDate = picked;
          _showOnlyThisLeagueTodayGames =
              false; // Reset the filter when date changes
        });
        _fetchGames(league);
      } else if (picked == null && selectedDate != null) {
        // User pressed cancel, clear the date
        setState(() {
          selectedDate = null;
          _showOnlyThisLeagueTodayGames = false;
        });
        _fetchGames(league);
      }
    } catch (e) {
      print('Error showing date picker: $e');
      // Show error message to user
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening date picker'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _fetchGames(league) async {
    isLoading = true;
    try {
      List<Game> fetchedGames;

      if (selectedDate != null) {
        print('selectedDate != null');

        fetchedGames = await GamesMethods().fetchAllGames(
          league,
          _showOnlyThisLeagueTodayGames,
          selectedDate: selectedDate,
        );
      } else {
        fetchedGames = await GamesMethods().fetchGamesForLeague(
          league,
          selectedDate: selectedDate,
        );
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
    if (buttonLoading) return;

    setState(() {
      buttonLoading = true;
    });
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
      setState(() {
        buttonLoading = false;
      });
      return;
    }

    final newGuessUrl = Uri.parse('$_baseUrl/guesses/add');
    final updateGuessUrl = Uri.parse('$_baseUrl/guesses/');
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
    setState(() {
      buttonLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: GestureDetector(
          onTap: () => _selectDate(context),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.calendar_today,
                  color: Colors.blue,
                  size: 28,
                ),
                if (selectedDate != null)
                  Positioned(
                    bottom: 4,
                    child: Text(
                      '${selectedDate!.day}',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          if (selectedDate != null)
            Container(
              margin: EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  Text(
                    AppLocalizations.of(context)!.thisleague,
                    style: TextStyle(
                      color: white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: !_showOnlyThisLeagueTodayGames,
                      onChanged: (value) {
                        toggleshowOnlyThisLeagueTodayGames();
                      },
                      activeColor: Colors.blue,
                      activeTrackColor: Colors.blue.withOpacity(0.5),
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: Colors.grey.withOpacity(0.5),
                    ),
                  ),
                  Text(
                    AppLocalizations.of(context)!.allleagus,
                    style: TextStyle(
                      color: white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: EdgeInsets.symmetric(vertical: 8),
            child: FutureBuilder<Map<String, dynamic>>(
              future: UsersMethods().fetchUserById(clientId),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final userData = snapshot.data!;
                  final chosenLeagues =
                      Map<String, bool>.from(userData['chosenLeagues'] ?? {});

                  // Create filtered lists based on chosen leagues
                  final enabledLeagues = <int>[
                    if (chosenLeagues['2'] == true) 2,
                    if (chosenLeagues['383'] == true) 383,
                    if (chosenLeagues['140'] == true) 140,
                    if (chosenLeagues['3'] == true) 3,
                    if (chosenLeagues['39'] == true) 39,
                    if (chosenLeagues['78'] == true) 78,
                  ];

                  final options = enabledLeagues.map((id) {
                    switch (id) {
                      case 2:
                        return AppLocalizations.of(context)!.championsleague;
                      case 383:
                        return AppLocalizations.of(context)!.ligathaal;
                      case 140:
                        return AppLocalizations.of(context)!.laliga;
                      case 3:
                        return AppLocalizations.of(context)!.europaleague;
                      case 39:
                        return AppLocalizations.of(context)!.premierleague;
                      case 78:
                        return  AppLocalizations.of(context)!.bundesleague;
                      default:
                        return '';
                    }
                  }).toList();

                  final imageUrls = enabledLeagues.map((id) {
                    return 'https://media.api-sports.io/football/leagues/$id.png';
                  }).toList();

                  return ToggleButtonsSample(
                    options: options,
                    imageUrls: imageUrls,
                    onSelectionChanged: (index) {
                      updateSelectedIndex(index);
                    },
                    initialSelection: enabledLeagues.indexOf(league),
                  );
                }
                return CircularProgressIndicator();
              },
            ),
          ),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TeamSelectionButton(
                    // games: _games,
                    clientId: clientId,
                    email: email,
                    league: league,
                    onTeamSelected: (selectedTeam) {
                      print('Selected team: $selectedTeam');
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  )
                : _games.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.scoreboard_outlined,
                              size: 48,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              AppLocalizations.of(context)!.nogames,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          await Future.delayed(Duration(seconds: 1));
                          _fetchGames(league);
                        },
                        color: Colors.blue,
                        child: listView(_games),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: buttonLoading ? null : _submitAllGuesses,
        backgroundColor: buttonLoading ? Colors.grey : Colors.blue,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: buttonLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Icon(Icons.send),
        label: Text(
          AppLocalizations.of(context)!.send,
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  ListView listView(List<Game> filteredGames) {
    return ListView.separated(
      physics: AlwaysScrollableScrollPhysics(),
      itemCount: filteredGames.length,
      itemBuilder: (BuildContext context, int index) {
        final game = filteredGames[index];
        final matchingGuesses =
            _guesses.where((g) => g.gameOriginalId == game.fixtureId).toList();
        final guess = matchingGuesses.isNotEmpty ? matchingGuesses.first : null;
        if (_guessControllers[game.fixtureId] == null) {
          _guessControllers[game.fixtureId] = {
            'home': TextEditingController(),
            'away': TextEditingController(),
          };
        }
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: GameWidget(
            game: game,
            guess: guess,
            homeController: _guessControllers[game.fixtureId]?['home'],
            awayController: _guessControllers[game.fixtureId]?['away'],
            onTap: (context) async {
              if (game.status.long != "Not Started") {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GameDetails(
                      gameOriginalId: game.fixtureId,
                      game: game,
                      userId: clientId,
                    ),
                  ),
                );
              }
            },
          ),
        );
      },
      separatorBuilder: (BuildContext context, int index) =>
          Divider(height: 0.0, color: background),
      padding: EdgeInsets.symmetric(horizontal: 2.0, vertical: 2.0),
    );
  }
}
