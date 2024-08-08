import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:football/models/games.dart';
import 'package:football/resources/gamesMethods.dart';
import 'package:football/widgets/gamesCard.dart';
import 'package:http/http.dart' as http;



class GamesScreen extends StatefulWidget {
  @override
  _GamesScreenState createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  List<Game> _games = [];
  int league = 4;
  @override
  void initState() {
    super.initState();
   _fetchGames(league);
  }


  Future<void> _fetchGames(int leagueId) async {
    print('leagueId ${leagueId}');

    try {
      final games = await GamesMethods().fetchGames(leagueId);
      setState(() {
        _games = games;
      });
      print(_games);
    } catch (e) {
      print('Failed to fetch games: $e');
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
          return GameWidget(game: game);
        },
      ),
    );
  }
}
