import 'package:flutter/material.dart';
import 'package:football/models/games.dart';
import 'package:football/models/guesses.dart';
import 'package:football/resources/guessesMethods.dart';

class GameDetails extends StatefulWidget {
  final gameOriginalId;


  const GameDetails({super.key, required this. gameOriginalId});

  @override
  State<GameDetails> createState() => _GameDetailsState();
}

class _GameDetailsState extends State<GameDetails> {
  List<Guess> _guesses = [];

  @override
  void initState() {
    super.initState();
 
  _fetchGuesses( widget.gameOriginalId);
  }
  Future<void> _fetchGuesses(gameId) async {
      print('gameId ${gameId}');
    try {
      final guesses = await GuessesMethods().fetchAllUsersGuesses(gameId);
     
      setState(() {
        _guesses = guesses;
      });
    print( _guesses);
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
        title: Text('Game Details'),
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Email')),
              DataColumn(label: Text('Guess')),
              DataColumn(label: Text('Sum Points')),
            ],
            rows: _guesses.map((guess) => DataRow(
              cells: [
                DataCell(Text(guess.email)),
                DataCell(Text('${guess.homeTeamGoals} - ${guess.awayTeamGoals}')),
                DataCell(Text(guess.sumPoints.toString())),
              ],
            )).toList(),
          ),
        ),
      ),
    );

  }
}