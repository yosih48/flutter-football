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
import 'package:football/resources/playersMethods.dart';
import 'package:football/screens/gameDetails.dart';
import 'package:football/screens/login_screen.dart';
import 'package:football/theme/colors.dart';
import 'package:football/utils/config.dart';
import 'package:football/widgets/LeagueSelectorChips.dart';

import 'package:football/widgets/gamesCard.dart';

import 'package:football/widgets/toggleButton.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/users.dart';
import 'package:football/utils/utils.dart';

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
  int league = -1;
  bool _hasInitialized = false;
  bool _showOnlyThisLeagueTodayGames = false;
  bool _showOnlyLiveGames = false;
  int? _selectedLeagueFilter;
  late String clientId;
  late String email;
  int selectedIndex = -1;
  bool isLoading = true;
  bool buttonLoading = false;
  DateTime? selectedDate;
  bool _showSelectedDateGames = false;
  String _baseUrl = backendUrl;
  Map<int, Map<String, TextEditingController>> _guessControllers = {};
  bool _hasFetchedInitialGames = false;
  bool useFakeGames = false;
  String formatDateInHebrew(DateTime date, BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    // Get day names using localization
    const Map<String, String> dayKeys = {
      'Monday': 'monday',
      'Tuesday': 'tuesday',
      'Wednesday': 'wednesday',
      'Thursday': 'thursday',
      'Friday': 'friday',
      'Saturday': 'saturday',
      'Sunday': 'sunday',
    };

    // Get month names using localization
    const Map<String, String> monthKeys = {
      'Jan': 'january_short',
      'Feb': 'february_short',
      'Mar': 'march_short',
      'Apr': 'april_short',
      'May': 'may_short',
      'Jun': 'june_short',
      'Jul': 'july_short',
      'Aug': 'august_short',
      'Sep': 'september_short',
      'Oct': 'october_short',
      'Nov': 'november_short',
      'Dec': 'december_short',
    };

    String dayName = DateFormat('EEEE').format(date);
    String monthName = DateFormat('MMM').format(date);
    int dayNumber = date.day;

    // Get localized strings
    String dayKey = dayKeys[dayName] ?? 'monday';
    String monthKey = monthKeys[monthName] ?? 'january_short';

    String localizedDay = _getLocalizedString(localizations, dayKey, dayName);
    String localizedMonth =
        _getLocalizedString(localizations, monthKey, monthName);

    return '$localizedDay,  $dayNumber $localizedMonth';
  }

// Helper function to safely get localized strings
  String _getLocalizedString(
      AppLocalizations localizations, String key, String fallback) {
    try {
      // Use reflection or a switch statement to get the localized string
      switch (key) {
        case 'monday':
          return localizations.monday;
        case 'tuesday':
          return localizations.tuesday;
        case 'wednesday':
          return localizations.wednesday;
        case 'thursday':
          return localizations.thursday;
        case 'friday':
          return localizations.friday;
        case 'saturday':
          return localizations.saturday;
        case 'sunday':
          return localizations.sunday;
        case 'january_short':
          return localizations.january_short;
        case 'february_short':
          return localizations.february_short;
        case 'march_short':
          return localizations.march_short;
        case 'april_short':
          return localizations.april_short;
        case 'may_short':
          return localizations.may_short;
        case 'june_short':
          return localizations.june_short;
        case 'july_short':
          return localizations.july_short;
        case 'august_short':
          return localizations.august_short;
        case 'september_short':
          return localizations.september_short;
        case 'october_short':
          return localizations.october_short;
        case 'november_short':
          return localizations.november_short;
        case 'december_short':
          return localizations.december_short;
        default:
          return fallback;
      }
    } catch (e) {
      return fallback;
    }
  }

  // League ID <-> Name mapping
  String? selectedLeagueName;
  final Map<int, String> leagueIdToName = {
    2: "Champions League",
    383: "Ligat Ha'al",
    140: "La Liga",
    3: "Europa League",
    39: "Premier League",
    78: "Bundesliga",
    848: "Conference League",
    15: "Club World Cup",
  };
  final Map<String, int> leagueNameToId = {
    "Champions League": 2,
    "Ligat Ha'al": 383,
    "La Liga": 140,
    "Europa League": 3,
    "Premier League": 39,
    "Bundesliga": 78,
    "Conference League": 848,
    "Club World Cup": 15,
  };

  void updateSelectedIndex(int index, enabledLeagues, int chipIndex) {
    print('updateSelectedIndex');

    print('selectedIndex: ${selectedIndex}');
    print('index: ${index}');
    print('chipIndex: ${chipIndex}');
    print('league: ${league}');
    setState(() {
      isLoading = true;

      // Toggle logic: if the same chip is pressed, deselect it
      if (selectedIndex == chipIndex) {
        print('league == index');
        // Deselect - reset to no selection
        selectedIndex = -1;
        league = -1; // or null, depending on your data type
        Provider.of<UserProvider>(context, listen: false)
            .setselectedLeageId(-1); // or null

        // Fetch all games without league filter
        _fetchAllUpcomingGames(enabledLeagues, filterDate: selectedDate);
      } else {
        print('league != index');
        // Select the new chip
        selectedIndex = chipIndex;
        league = index;
        Provider.of<UserProvider>(context, listen: false)
            .setselectedLeageId(league);

        // Fetch games with league filter
        _fetchAllUpcomingGames(enabledLeagues,
            filterDate: selectedDate, filterLeague: league);
      }
    });
    //   selectedIndex = index;
    //   league = index;
    //   Provider.of<UserProvider>(context, listen: false)
    //       .setselectedLeageId(league);
    // });
    // // _fetchGames(league);
    // _fetchAllUpcomingGames(enabledLeagues, filterLeague: league);
  }

  void initState() {
    super.initState();
    clientId = widget.authProvider.currentUser?.id ?? 'Not logged in';
    email = widget.authProvider.currentUser?.email ?? 'Not logged in';
    league = widget.userProvider.selectedLeageId ?? -1;
    selectedDate = DateTime.now();
    print('selectedDate: ${selectedDate}');

    print('clientId in games: ${clientId}');

    print(email);
    _fetchGuesses(clientId);
  }

  @override
  // void didChangeDependencies() {
  //   super.didChangeDependencies();

  //   if (!_hasInitialized) {
  //     final args =
  //         ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

  //     if (args != null) {
  //       final String? leagueString = args['league'];
  //       final String? tournamentId = args['tournamentId'];
  //       final String? action = args['action'];

  //       if (leagueString != null) {
  //         league = int.tryParse(leagueString) ?? 2;
  //       }
  //     }

  //     // Fetch initial games for all enabled leagues
  //     UsersMethods().fetchUserById(clientId).then((userData) {
  //       final chosenLeagues =
  //           Map<String, bool>.from(userData['chosenLeagues'] ?? {});
  //       final enabledLeagues = <int>[
  //         if (chosenLeagues['2'] == true) 2,
  //         if (chosenLeagues['383'] == true) 383,
  //         if (chosenLeagues['140'] == true) 140,
  //         if (chosenLeagues['3'] == true) 3,
  //         if (chosenLeagues['39'] == true) 39,
  //         if (chosenLeagues['78'] == true) 78,
  //         if (chosenLeagues['848'] == true) 848,
  //         if (chosenLeagues['15'] == true) 15,
  //       ];
  //       _fetchAllUpcomingGames(enabledLeagues);
  //     });

  //     _hasInitialized = true;
  //   }
  // }
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_hasInitialized) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      if (args != null) {
        final String? leagueString = args['league'];
        final String? tournamentId = args['tournamentId'];
        final String? action = args['action'];

        if (leagueString != null) {
          league = int.tryParse(leagueString) ?? 2;
        }
      }

      _hasInitialized = true;
    }
  }

  void dispose() {
    for (var controllers in _guessControllers.values) {
      controllers['home']?.dispose();
      controllers['away']?.dispose();
    }
    super.dispose();
  }

  // void toggleshowOnlyThisLeagueTodayGames() {
  //   setState(() {
  //     _showOnlyThisLeagueTodayGames = !_showOnlyThisLeagueTodayGames;
  //   });
  //   _fetchGames(league);
  // }

  void toggleShowOnlyLiveGames() async {
    // Toggle the today filter (show only today's games)
    setState(() {
      _showOnlyLiveGames = !_showOnlyLiveGames;
    });

    // Re-fetch games according to new preference
    final userData = await UsersMethods().fetchUserById(clientId);
    final chosenLeagues =
        Map<String, bool>.from(userData['chosenLeagues'] ?? {});
    final enabledLeagues = <int>[
      if (chosenLeagues['2'] == true) 2,
      if (chosenLeagues['383'] == true) 383,
      if (chosenLeagues['140'] == true) 140,
      if (chosenLeagues['3'] == true) 3,
      if (chosenLeagues['39'] == true) 39,
      if (chosenLeagues['78'] == true) 78,
      if (chosenLeagues['848'] == true) 848,
      if (chosenLeagues['15'] == true) 15,
    ];

    if (_showOnlyLiveGames && selectedIndex != -1) {
      print('_showOnlyLiveGames && selectedIndex != -1');
      selectedDate = DateTime.now();
      await _fetchAllUpcomingGames(enabledLeagues,
          filterDate: selectedDate, filterLeague: league);
    } else if (!_showOnlyLiveGames && selectedIndex != -1) {
      print('!_showOnlyLiveGames');
      // selectedDate = DateTime.now();
      await _fetchAllUpcomingGames(enabledLeagues, filterLeague: league);
    } else {
      await _fetchAllUpcomingGames(enabledLeagues);
    }
  }

  String getLocalizedLeagueName(int leagueId, BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    switch (leagueId) {
      case 2:
        return localizations.championsleague;
      case 383:
        return localizations.ligathaal;
      case 140:
        return localizations.laliga;
      case 3:
        return localizations.europaleague;
      case 39:
        return localizations.premierleague;
      case 78:
        return localizations.bundesleague;
      case 848:
        return localizations.conferenceleague;
      case 15:
        return localizations.clubworldcup;
      default:
        return '';
    }
  }

  String getLocalizedLeaguerRound(String round, BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    switch (round) {
      case '8th Finals':
        return 'שמינית גמר';
      case 383:
        return localizations.ligathaal;
      case 140:
        return localizations.laliga;
      case 3:
        return localizations.europaleague;
      case 39:
        return localizations.premierleague;
      case 78:
        return localizations.bundesleague;
      case 848:
        return localizations.conferenceleague;
      case 15:
        return localizations.clubworldcup;
      default:
        return '';
    }
  }

  void _toggleLeagueFilter(int leagueId) async {
    setState(() {
      if (_selectedLeagueFilter == leagueId) {
        _selectedLeagueFilter = null; // Clear filter
      } else {
        _selectedLeagueFilter = leagueId;
      }
      isLoading = true;
    });

    if (_selectedLeagueFilter != null) {
      // Fetch all games for the selected league (ignore date filter)
      final games =
          await GamesMethods().fetchGamesForLeague(_selectedLeagueFilter!);
      setState(() {
        _games = games;
        isLoading = false;
      });
    } else {
      // Restore games for all enabled leagues with the current date filter
      final userData = await UsersMethods().fetchUserById(clientId);
      final chosenLeagues =
          Map<String, bool>.from(userData['chosenLeagues'] ?? {});
      final enabledLeagues = <int>[
        if (chosenLeagues['2'] == true) 2,
        if (chosenLeagues['383'] == true) 383,
        if (chosenLeagues['140'] == true) 140,
        if (chosenLeagues['3'] == true) 3,
        if (chosenLeagues['39'] == true) 39,
        if (chosenLeagues['78'] == true) 78,
        if (chosenLeagues['848'] == true) 848,
        if (chosenLeagues['15'] == true) 15,
      ];
      await _fetchAllUpcomingGames(enabledLeagues, filterDate: selectedDate);
    }
  }

  // Future<void> _selectDate(BuildContext context) async {
  //   try {
  //     final DateTime? picked = await showDatePicker(
  //       context: context,
  //       initialDate: selectedDate ?? DateTime.now(),
  //       firstDate: DateTime(2024),
  //       cancelText: AppLocalizations.of(context)!.cleardatefilter,
  //       lastDate: DateTime(DateTime.now().year + 1),
  //       builder: (BuildContext context, Widget? child) {
  //         return Theme(
  //           data: ThemeData.dark().copyWith(
  //             colorScheme: ColorScheme.dark(
  //               primary: Colors.blue,
  //               onPrimary: Colors.white,
  //               surface: Color(0xFF303030),
  //               onSurface: Colors.white,
  //             ),
  //             dialogBackgroundColor: Color(0xFF303030),
  //           ),
  //           child: child ?? Container(),
  //         );
  //       },
  //     );

  //     if (picked != null) {
  //       setState(() {
  //         selectedDate = picked;
  //         _showOnlyThisLeagueTodayGames =
  //             false; // Reset the filter when date changes
  //       });
  //       _fetchGames(league);
  //     } else if (picked == null && selectedDate != null) {
  //       // User pressed cancel, clear the date
  //       setState(() {
  //         selectedDate = null;
  //         _showOnlyThisLeagueTodayGames = false;
  //       });
  //       _fetchGames(league);
  //     }
  //   } catch (e) {
  //     print('Error showing date picker: $e');
  //     // Show error message to user
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text('Error opening date picker'),
  //         backgroundColor: Colors.red,
  //       ),
  //     );
  //   }
  // }

  // Future<void> _fetchGames(league) async {
  //   print(
  //       ' _fetchGames _showOnlyThisLeagueTodayGames: $_showOnlyThisLeagueTodayGames');

  //   isLoading = true;
  //   try {
  //     List<Game> fetchedGames;

  //     if (selectedDate != null) {
  //       print(
  //           '📅 Loading games for league $league on ${selectedDate!.day}/${selectedDate!.month}');

  //       fetchedGames = await GamesMethods().fetchAllGames(
  //         league,
  //         _showOnlyThisLeagueTodayGames,
  //         selectedDate: selectedDate,
  //       );
  //     } else {
  //       print('📅 Loading games for league $league (no date filter)');
  //       fetchedGames = await GamesMethods().fetchGamesForLeague(
  //         league,
  //         selectedDate: selectedDate,
  //       );
  //     }

  //     setState(() {
  //       _games = fetchedGames;
  //       for (var game in _games) {
  //         if (_guessControllers[game.fixtureId] == null) {
  //           _guessControllers[game.fixtureId] = {
  //             'home': TextEditingController(),
  //             'away': TextEditingController(),
  //           };
  //         }
  //         print(game.league.id);
  //       }
  //       isLoading = false;
  //     });

  //     // Print info about any live games
  //     final liveGames = fetchedGames
  //         .where((game) =>
  //             game.status.short == '1H' ||
  //             game.status.short == '2H' ||
  //             game.status.short == 'HT' ||
  //             game.status.short == 'ET' ||
  //             game.status.short == 'BT' ||
  //             game.status.short == 'P' ||
  //             game.status.short == 'INT')
  //         .toList();

  //     if (liveGames.isNotEmpty) {
  //       print('⚽ Loaded ${liveGames.length} live games');
  //     } else {
  //       print('📊 No live games currently in progress');
  //     }
  //   } catch (e) {
  //     print('Failed to fetch games: $e');
  //   }
  // }

  Future<void> _fetchGuesses(clientId) async {
    print('clientId:${clientId}');
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

  // New method for handling manual refresh with force refresh
  Future<void> _handleManualRefresh() async {
    try {
      List<Game> refreshedGames;

      if (selectedDate != null) {
        if (_showOnlyThisLeagueTodayGames) {
          // Refresh only current league
          print(
              '🔄 Manual refresh: forcing refresh for league $league on ${selectedDate!.day}/${selectedDate!.month}');
          refreshedGames = await GamesMethods().forceRefreshGames(
            league,
            selectedDate: selectedDate,
          );
        } else {
          // Refresh multiple leagues
          print(
              '🔄 Manual refresh: forcing refresh for all leagues on ${selectedDate!.day}/${selectedDate!.month}');
          refreshedGames = [];
          final gamesMethods = GamesMethods();
          // Force refresh all visible leagues
          final leagueIds = [2, 3, 383, 140, 39, 848, 15, 78];
          for (int id in leagueIds) {
            final games = await gamesMethods.forceRefreshGames(
              id,
              selectedDate: selectedDate,
            );
            refreshedGames.addAll(games);
          }
          refreshedGames.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        }
      } else {
        // Just refresh current league if no date selected
        print(
            '🔄 Manual refresh: forcing refresh for league $league (no date filter)');
        refreshedGames = await GamesMethods().forceRefreshGames(
          league,
          selectedDate: selectedDate,
        );
      }

      setState(() {
        _games = refreshedGames;
        for (var game in _games) {
          if (_guessControllers[game.fixtureId] == null) {
            _guessControllers[game.fixtureId] = {
              'home': TextEditingController(),
              'away': TextEditingController(),
            };
          }
        }
      });

      // Show a feedback message to the user
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('Games updated'),
      //     // backgroundColor: Colors.green,
      //     duration: Duration(seconds: 2),
      //   ),
      // );
    } catch (e) {
      print('Failed to refresh games: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Refresh failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Helper: Group games by date
  Map<DateTime, List<Game>> _groupGamesByDate(List<Game> games) {
    final Map<DateTime, List<Game>> grouped = {};
    for (final game in games) {
      final date = DateTime(game.date.year, game.date.month, game.date.day);
      grouped.putIfAbsent(date, () => []).add(game);
    }
    return grouped;
  }

  // Fetch all upcoming games for all enabled leagues
  Future<void> _fetchAllUpcomingGames(List<int> enabledLeagues,
      {DateTime? filterDate, int? filterLeague}) async {
    setState(() {
      isLoading = true;
    });

    if (useFakeGames) {
      // Load fake games from assets
      final fakeGames = await loadFakeGames();
      setState(() {
        _games = fakeGames;
        isLoading = false;
      });
      return;
    }

    print('filterLeague: ${filterLeague}');
    try {
      List<Game> allGames = [];

      // Determine which leagues to fetch from
      List<int> leaguesToFetch;
      if (filterLeague != null && filterLeague != -1) {
        // If filtering by specific league, only fetch from that league
        leaguesToFetch = [filterLeague];
      } else {
        // Otherwise, fetch from all enabled leagues
        leaguesToFetch = enabledLeagues;
      }

      // Determine the earliest date to include
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      final earliestDate = filterDate != null
          ? DateTime(filterDate.year, filterDate.month, filterDate.day)
          : startOfToday;
      print('earliestDate ${earliestDate}');
      for (final leagueId in leaguesToFetch) {
        final games = await GamesMethods().fetchGamesForLeague(leagueId);
        // Include games that are either:
        // 1. Starting today (including live games)
        // 2. Starting in the future

        allGames.addAll(games.where((g) {
          final gameDate = DateTime(g.date.year, g.date.month, g.date.day);
          return gameDate.isAfter(earliestDate.subtract(Duration(days: 1))) ||
              g.status.short == '1H' ||
              g.status.short == '2H' ||
              g.status.short == 'HT';
        }));
      }

      // Apply date filter if specified
      if (filterDate != null) {
        final filterDateStart =
            DateTime(filterDate.year, filterDate.month, filterDate.day);
        final filterDateEnd = filterDateStart.add(Duration(days: 1));
        allGames = allGames
            .where((g) => g.date
                    .isAfter(filterDateStart.subtract(Duration(seconds: 1)))
                // && g.date.isBefore(filterDateEnd)
                )
            .toList();
      }

      // Sort games by date
      allGames.sort((a, b) => a.date.compareTo(b.date));

      setState(() {
        _games = allGames;
        isLoading = false;
      });
    } catch (e) {
      print('Failed to fetch all upcoming games: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: GestureDetector(
          onTap: () async {
            final userData = await UsersMethods().fetchUserById(clientId);
            final chosenLeagues =
                Map<String, bool>.from(userData['chosenLeagues'] ?? {});
            final enabledLeagues = <int>[
              if (chosenLeagues['2'] == true) 2,
              if (chosenLeagues['383'] == true) 383,
              if (chosenLeagues['140'] == true) 140,
              if (chosenLeagues['3'] == true) 3,
              if (chosenLeagues['39'] == true) 39,
              if (chosenLeagues['78'] == true) 78,
              if (chosenLeagues['848'] == true) 848,
              if (chosenLeagues['15'] == true) 15,
            ];
            final picked = await showDatePicker(
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
              print('picked != null');
              print('selectedDate ${selectedDate}');
              setState(() {
                selectedDate = picked;
              });
              await _fetchAllUpcomingGames(enabledLeagues,
                  filterDate: picked, filterLeague: league);
            } else if (picked == null && selectedDate != null) {
              setState(() {
                print('picked == null');
                print('selectedDate ${selectedDate}');
              });
            }
          },
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
          Container(
            margin: EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Text(
                  'Live',
                  style: TextStyle(
                    color: white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: _showOnlyLiveGames,
                    onChanged: (value) {
                      toggleShowOnlyLiveGames();
                    },
                    activeColor: Colors.red,
                    activeTrackColor: Colors.red.withOpacity(0.5),
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: Colors.grey.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          // IconButton(
          //   icon: Icon(
          //     useFakeGames ? Icons.bug_report : Icons.bug_report_outlined,
          //     color: useFakeGames ? Colors.orange : Colors.white,
          //   ),
          //   tooltip: useFakeGames ? 'Using Fake Games' : 'Use Fake Games',
          //   onPressed: () async {
          //     setState(() {
          //       useFakeGames = !useFakeGames;
          //       isLoading = true;
          //     });
          //     final userData = await UsersMethods().fetchUserById(clientId);
          //     final chosenLeagues =
          //         Map<String, bool>.from(userData['chosenLeagues'] ?? {});
          //     final enabledLeagues = <int>[
          //       if (chosenLeagues['2'] == true) 2,
          //       if (chosenLeagues['383'] == true) 383,
          //       if (chosenLeagues['140'] == true) 140,
          //       if (chosenLeagues['3'] == true) 3,
          //       if (chosenLeagues['39'] == true) 39,
          //       if (chosenLeagues['78'] == true) 78,
          //       if (chosenLeagues['848'] == true) 848,
          //       if (chosenLeagues['15'] == true) 15,
          //     ];
          //     await _fetchAllUpcomingGames(enabledLeagues,
          //         filterDate: selectedDate);
          //   },
          // ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: UsersMethods().fetchUserById(clientId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          final userData = snapshot.data!;
          final chosenLeagues =
              Map<String, bool>.from(userData['chosenLeagues'] ?? {});
          final enabledLeagues = <int>[
            if (chosenLeagues['2'] == true) 2,
            if (chosenLeagues['383'] == true) 383,
            if (chosenLeagues['140'] == true) 140,
            if (chosenLeagues['3'] == true) 3,
            if (chosenLeagues['39'] == true) 39,
            if (chosenLeagues['78'] == true) 78,
            if (chosenLeagues['848'] == true) 848,
            if (chosenLeagues['15'] == true) 15,
          ];
          final options = enabledLeagues
              .map((id) => getLocalizedLeagueName(id, context))
              .toList();

          // Fetch games if not already loaded
          if (!_hasFetchedInitialGames) {
            _hasFetchedInitialGames = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _fetchAllUpcomingGames(enabledLeagues, filterDate: selectedDate);
            });
          }

          // Apply filters here in the main build method
          List<Game> filteredGames = _games;

          // Apply league filter if needed
          if (_selectedLeagueFilter != null) {
            filteredGames = filteredGames
                .where((g) => g.league.id == _selectedLeagueFilter)
                .toList();
          }

          // Apply live games filter if needed
          if (_showOnlyLiveGames) {
            filteredGames = filteredGames.where((game) {
              // return ['1H', '2H', 'HT', 'ET', 'BT', 'P', 'INT']
              return ['1H', '2H', 'HT'].contains(game.status.short);
            }).toList();
          }

          // Group games by date
          final groupedGames = _groupGamesByDate(filteredGames);
          final sortedDates = groupedGames.keys.toList()..sort();

          final initialIndex = enabledLeagues.contains(league)
              ? enabledLeagues.indexOf(league)
              : 0; // fallback to 0

          return RefreshIndicator(
            onRefresh: () async {
              await _fetchAllUpcomingGames(enabledLeagues,
                  filterDate: selectedDate);
            },
            color: Colors.blue,
            child: Column(
              children: [
                SizedBox(
                  height: 8,
                ),
                // Always show LeagueSelectorChips
                LeagueSelectorChips(
                  options: options,
                  selectedIndex: selectedIndex,
                  onSelectionChanged: (index) {
                    final selectedLeagueId = enabledLeagues[index];

                    print('League selection changed: $selectedLeagueId');
                    print('initialIndex: $initialIndex');
                    updateSelectedIndex(
                        selectedLeagueId, enabledLeagues, index);
                  },
                ),
                SizedBox(
                  height: 8,
                ),

                // Show team and player selection area only when appropriate
                selectedIndex != -1 && league != -1
                    ? FutureBuilder<Map<String, dynamic>>(
                        future: _getSelectionAvailability(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Container(
                              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildUnifiedButton(
                                      icon: Icons.emoji_events,
                                      text: AppLocalizations.of(context)!.choosewinner,
                                      subtitle: "Loading...",
                                      onTap: () {},
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: _buildUnifiedButton(
                                      icon: Icons.sports_soccer,
                                      text: AppLocalizations.of(context)!.chooseTopScorer,
                                      subtitle: "Loading...",
                                      onTap: () {},
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final availability = snapshot.data ?? {'showButtons': false, 'available': false, 'message': 'Error'};
                          final showButtons = availability['showButtons'] as bool;
                          final isAvailable = availability['available'] as bool;
                          final message = availability['message'] as String?;

                          // Don't show buttons at all if league has started or time expired
                          if (!showButtons) {
                            return SizedBox.shrink();
                          }

                          return Container(
                            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              children: [
                                // Team Selection
                                Expanded(
                                  child: _buildUnifiedButton(
                                    icon: Icons.emoji_events,
                                    text: AppLocalizations.of(context)!.choosewinner,
                                    subtitle: isAvailable 
                                        ? _getTeamSelectionSubtitle()
                                        : message ?? AppLocalizations.of(context)!.selectionnotavailable,
                                    onTap: isAvailable 
                                        ? () => _showTeamSelectionDialog()
                                        : () => _showAvailabilityMessage(message ?? AppLocalizations.of(context)!.selectionnotavailable),
                                  ),
                                ),
                                SizedBox(width: 8),
                                // Player Selection  
                                Expanded(
                                  child: _buildUnifiedButton(
                                    icon: Icons.sports_soccer,
                                    text: AppLocalizations.of(context)!.chooseTopScorer,
                                    subtitle: isAvailable 
                                        ? _getPlayerSelectionSubtitle()
                                        : message ?? AppLocalizations.of(context)!.selectionnotavailable,
                                    onTap: isAvailable 
                                        ? () => _showPlayerSelectionDialog()
                                        : () => _showAvailabilityMessage(message ?? AppLocalizations.of(context)!.selectionnotavailable),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    : Container(
                        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            // Team Selection - No league selected
                            Expanded(
                              child: _buildUnifiedButton(
                                icon: Icons.emoji_events,
                                text: AppLocalizations.of(context)!.choosewinner,
                                subtitle: AppLocalizations.of(context)!.selectleaguefirst,
                                onTap: () => _showLeagueSelectionHint(),
                              ),
                            ),
                            SizedBox(width: 8),
                            // Player Selection - No league selected
                            Expanded(
                              child: _buildUnifiedButton(
                                icon: Icons.sports_soccer,
                                text: AppLocalizations.of(context)!.chooseTopScorer,
                                subtitle: AppLocalizations.of(context)!.selectleaguefirst,
                                onTap: () => _showLeagueSelectionHint(),
                              ),
                            ),
                          ],
                        ),
                      ),

                Expanded(
                  child:
                      _buildGamesList(filteredGames, sortedDates, groupedGames),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: buttonLoading ? null : _submitAllGuesses,
        backgroundColor: buttonLoading ? Colors.grey : Colors.blue,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: Icon(Icons.send),
        label: Text(
          AppLocalizations.of(context)!.send,
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // Helper method to build unified card-style buttons
  Widget _buildUnifiedButton({
    required IconData icon,
    required String text,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey[800]?.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[600]!, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.grey[400],
              size: 24,
            ),
            SizedBox(height: 6),
            Text(
              text,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Check if selection is still available for current league
  Future<Map<String, dynamic>> _getSelectionAvailability() async {
    try {
      final games = await GamesMethods().fetchGamesForLeague(league);
      
      if (games.isEmpty) {
        return {
          'showButtons': true,
          'available': false,
          'reason': 'no_games',
          'message': AppLocalizations.of(context)!.selectionnotavailableyet
        };
      }

      // Sort games by date to find the first game (same logic as original widgets)
      games.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final firstGame = games.first;
      final currentTime = DateTime.now().toUtc();
      final firstGameDate = firstGame.date.toUtc();

      // Use the same logic as original widgets: check if current time is before first game
      bool isBeforeFirstGame = currentTime.isBefore(firstGameDate);

      if (!isBeforeFirstGame) {
        // League has started - don't show buttons at all
        return {
          'showButtons': false,
          'available': false,
          'reason': 'league_started',
          'message': null
        };
      }

      // Check if we're within 1 hour of first game (additional restriction)
      final cutoffTime = firstGameDate.subtract(Duration(hours: 1));
      if (currentTime.isAfter(cutoffTime)) {
        return {
          'showButtons': false,
          'available': false,
          'reason': 'time_expired',
          'message': null
        };
      }

      return {
        'showButtons': true,
        'available': true,
        'reason': 'available',
        'message': null
      };
    } catch (e) {
      print('Error checking selection availability: $e');
      return {
        'showButtons': true,
        'available': false,
        'reason': 'error',
        'message': AppLocalizations.of(context)!.selectionnotavailable
      };
    }
  }

  // Get subtitle text for team selection based on current state
  String _getTeamSelectionSubtitle() {
    return AppLocalizations.of(context)!.taptoselectwinner;
  }

  // Get subtitle text for player selection based on current state  
  String _getPlayerSelectionSubtitle() {
    return AppLocalizations.of(context)!.taptoselecttopscorer;
  }

  // Show team selection dialog
  void _showTeamSelectionDialog() async {
    // First check if selection is available
    final availability = await _getSelectionAvailability();
    if (!availability['available']) {
      _showAvailabilityMessage(availability['message']);
      return;
    }

    try {
      // Fetch teams for current league
      final games = await GamesMethods().fetchGamesForLeague(league);
      final filteredGames = games.where((game) {
        if (game.league.id == 2 || game.league.id == 848 || game.league.id == 3) {
          return !game.league.round.contains("Qualifying") &&
              !game.league.round.contains("Play-offs");
        }
        return true;
      }).toList();
      
      final teams = filteredGames
          .expand((game) => [game.home.name, game.away.name])
          .toSet()
          .toList();

      String? selectedTeam;
      
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
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
                      hint: Text(AppLocalizations.of(context)!.chooseteam,
                          style: TextStyle(color: Colors.blue)),
                      isExpanded: true,
                      items: teams.map((String team) {
                        return DropdownMenuItem<String>(
                          value: team,
                          child: Text(team),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setDialogState(() {
                          selectedTeam = newValue;
                        });
                      },
                    ),
                    SizedBox(height: 20),
                    if (selectedTeam != null) ...[
                      Text(
                        '$selectedTeam',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                    SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                      ),
                      onPressed: selectedTeam != null ? () {
                        _saveTeamSelection(selectedTeam!);
                        Navigator.of(context).pop();
                      } : null,
                      child: Text(AppLocalizations.of(context)!.saveteam,
                          style: TextStyle(color: Colors.blue)),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      print('Error showing team selection dialog: $e');
    }
  }

  // Show player selection dialog  
  void _showPlayerSelectionDialog() async {
    // First check if selection is available
    final availability = await _getSelectionAvailability();
    if (!availability['available']) {
      _showAvailabilityMessage(availability['message']);
      return;
    }

    try {
      // Fetch players for current league using PlayersMethods
      final dataToSend = {'league': league};
      final players = await PlayersMethods().fetchPlayersList(dataToSend);

      String? selectedPlayer;
      
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
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
                      hint: Text(AppLocalizations.of(context)!.choosPlayer,
                          style: TextStyle(color: Colors.blue)),
                      isExpanded: true,
                      items: players.map((String player) {
                        return DropdownMenuItem<String>(
                          value: player,
                          child: Text(player),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setDialogState(() {
                          selectedPlayer = newValue;
                        });
                      },
                    ),
                    SizedBox(height: 20),
                    if (selectedPlayer != null) ...[
                      Text(
                        '$selectedPlayer',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                    SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                      ),
                      onPressed: selectedPlayer != null ? () {
                        _savePlayerSelection(selectedPlayer!);
                        Navigator.of(context).pop();
                      } : null,
                      child: Text(AppLocalizations.of(context)!.savePlayer,
                          style: TextStyle(color: Colors.blue)),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      print('Error showing player selection dialog: $e');
    }
  }

  // Save team selection
  Future<void> _saveTeamSelection(String selectedTeam) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/users/winner'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, dynamic>{
          '_id': clientId,
          'email': email,
          'winner': {
            'winner.$league': selectedTeam,
          },
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.teamSavedsuccessfully)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.failedtoSaveTeam)),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.errorsavingteam)),
      );
    }
  }

  // Save player selection
  Future<void> _savePlayerSelection(String selectedPlayer) async {
    final cleanedPlayerName = selectedPlayer.split(' (')[0];
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/users/top-scorer'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, dynamic>{
          '_id': clientId,
          'email': email,
          'topScorer': {
            'topScorer.$league': cleanedPlayerName,
          },
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.playerSavedsuccessfully)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.failedtoSaveplayer)),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.errorsavingplayer)),
      );
    }
  }

  // Show availability message
  void _showAvailabilityMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange[700],
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(bottom: 80, left: 16, right: 16),
      ),
    );
  }

  // Show hint to user about selecting a league
  void _showLeagueSelectionHint() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.selectleaguefirst + " 👆",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue[700],
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(bottom: 80, left: 16, right: 16),
      ),
    );
  }

// Rename and simplify this method - it now only handles the games list display
  Widget _buildGamesList(List<Game> filteredGames, List<DateTime> sortedDates,
      Map<DateTime, List<Game>> groupedGames) {
    // Loading state
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    // No games at all
    if (_games.isEmpty) {
      return Center(
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
      );
    }

    // No games after filtering
    if (groupedGames.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _showOnlyLiveGames ? Icons.live_tv : Icons.scoreboard_outlined,
              size: 48,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              _showOnlyLiveGames
                  ? AppLocalizations.of(context)!.nolivegames
                  : AppLocalizations.of(context)!.nogames,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // Show games list
    return ListView.builder(
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final date = sortedDates[index];
        var gamesForDate = groupedGames[date]!;
        print('gamesForDate: ${gamesForDate.length}');
        // Sort games by time within the date
        gamesForDate.sort((a, b) {
          // Assuming your Game object has a time field or you can extract time from fixture
          // Replace this with your actual time comparison logic
          return a.date.compareTo(b.date);
        });
        // Group consecutive games by league while maintaining time order
        List<Widget> gameWidgets = [];

        for (int i = 0; i < gamesForDate.length; i++) {
          final game = gamesForDate[i];
          final currentLeagueId = game.league.id;

          // Check if this is the first game or if league changed from previous game
          final bool showLeagueHeader =
              i == 0 || gamesForDate[i - 1].league.id != currentLeagueId;

          // Add league header if needed
          if (showLeagueHeader) {
            final leagueName = getLocalizedLeagueName(currentLeagueId, context);
            gameWidgets.add(
              GestureDetector(
                onTap: () => _toggleLeagueFilter(currentLeagueId),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Row(
                    children: [
                      Text(
                        '$leagueName',
                        style: TextStyle(
                          color: _selectedLeagueFilter == currentLeagueId
                              ? Colors.blue
                              : Colors.grey[300],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_selectedLeagueFilter == currentLeagueId)
                        Padding(
                          padding: const EdgeInsets.only(left: 6.0),
                          child:
                              Icon(Icons.close, size: 14, color: Colors.blue),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }

          // Add game widget
          if (_guessControllers[game.fixtureId] == null) {
            _guessControllers[game.fixtureId] = {
              'home': TextEditingController(),
              'away': TextEditingController(),
            };
          }

          final matchingGuesses = _guesses
              .where((g) => g.gameOriginalId == game.fixtureId)
              .toList();
          final guess =
              matchingGuesses.isNotEmpty ? matchingGuesses.first : null;

          gameWidgets.add(
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
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
                          games: gamesForDate,
                          initialIndex: gamesForDate.indexOf(game),
                          userId: clientId,
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Center(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    Text(
                      formatDateInHebrew(date, context),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${gamesForDate.length} ${AppLocalizations.of(context)!.numberOfGames}',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Games sorted by time, showing league name for each game
            ...gameWidgets,
          ],
        );
      },
    );
  }
}
