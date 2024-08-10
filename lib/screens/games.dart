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
  int league = 4;
  String clientId = '6584aceb503733cfc6418e98';
  @override
  void initState() {
    super.initState();
   _fetchGames(league);
  _fetchGuesses(clientId);
  }


  Future<void> _fetchGames(int leagueId) async {
    print('leagueId ${leagueId}');

    try {
      final games = await GamesMethods().fetchGames(leagueId);
      setState(() {
        _games = games;
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
    
    } 
 catch (e, stackTrace) {
  print('Failed to fetch guesses: $e');
  print('Stack trace: $stackTrace');
  // You might want to show an error message to the user here
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
        final matchingGuesses = _guesses.where((g) => g.gameOriginalId == game.fixtureId).toList();
          final guess = matchingGuesses.isNotEmpty ? matchingGuesses.first : null;
          return GameWidget(game: game, guess: guess,
            onTap: (context) async{
              print( game.fixtureId);
    // Your onTap logic here
    print('Game tapped!');
                   await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => GameDetails(
                                gameOriginalId: game.fixtureId
                                ),
                              ),
                            );
  },
          );
        },
      ),
    );
  }
}
