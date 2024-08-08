import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:football/models/games.dart';
import 'package:football/resources/gamesMethods.dart';
import 'package:http/http.dart' as http;

void main() => runApp(GameApp());

class GameApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: GamesScreen(),
    );
  }
}

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
          return Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        game.home.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16.0,
                        ),
                      ),
                      Text(
                        '${game.goals.home} - ${game.goals.away}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16.0,
                        ),
                      ),
                      Text(
                        game.away.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16.0,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.0),
                  Text(
                    game.status.long,
                    style: TextStyle(
                      color: Color(0xff67727d).withOpacity(0.6),
                      fontSize: 14.0,
                    ),
                  ),
                  // Add more game details as needed
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
