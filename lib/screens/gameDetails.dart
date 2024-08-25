import 'package:flutter/material.dart';
import 'package:football/models/games.dart';
import 'package:football/models/guesses.dart';
import 'package:football/resources/guessesMethods.dart';
import 'package:football/theme/colors.dart';
import 'package:intl/intl.dart';

class GameDetails extends StatefulWidget {
  final gameOriginalId;
   final Game game;


  const GameDetails({super.key, required this. gameOriginalId, required this.game});

  @override
  State<GameDetails> createState() => _GameDetailsState();
}

class _GameDetailsState extends State<GameDetails> {
  List<Guess> _guesses = [];
List<GuessWithNames> _guessesWithNames = [];
  @override
  void initState() {
    super.initState();
 
  _fetchGuesses( widget.gameOriginalId);
  }
  Future<void> _fetchGuesses(gameId) async {
      print('gameId ${gameId}');
    try {
      final guesses = await GuessesMethods().fetchAllUsersGuesses(gameId);
        final callService = CallService();
      final guessesWithNames = await Future.wait(
          guesses.map((guess) => callService.getGuessWithNames(guess)));

       setState(() {
        _guessesWithNames = guessesWithNames;
      });
      print(_guessesWithNames);
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
        backgroundColor: background,
      appBar: AppBar(
        title: Text('Game Details',
          style: TextStyle(
            color: white, // White color for the team names
          ),
        ),
            backgroundColor: Colors.transparent,
                 iconTheme: IconThemeData(
          color: Colors.white, // Set the color of the arrow icon to white
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildGameCard(),
            _buildGuessesTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildGameCard() {
    return Card(
        color: cards,
      margin: EdgeInsets.all(16.0),
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGameHeader(),
            SizedBox(height: 8.0),
            _buildTeamScores(),
            SizedBox(height: 8.0),
            // Add any additional rows here
          ],
        ),
      ),
    );
  }

  Widget _buildGameHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          widget.game.status.long,
              style: TextStyle(
                      color: (widget.game.status.long == "First Half" ||
                              widget.game.status.long == "Second Half" ||
                              widget.game.status.long == "Halftime")
                          ? Colors.red
                          : Color(0xFF9BA4B5).withOpacity(0.6),
                      fontSize: 14.0,
                    ),
        ),
        Text(
          DateFormat('dd/MM/yy').format(widget.game.date),
         style: TextStyle(
            color: Color(0xFF9BA4B5).withOpacity(0.9),
            fontSize: 14.0,
          ),
        ),
      ],
    );
  }

  Widget _buildTeamScores() {
    return Row(
      children: [
        Expanded(
          child: _buildTeamInfo(widget.game.home, isHome: true),
        ),
        SizedBox(width: 8.0),
        Text(
          '${widget.game.goals.home} - ${widget.game.goals.away}',
              style: TextStyle(
            color: Colors.white, // White color for the team names
            fontWeight: FontWeight.bold,
            fontSize: 18.0,
          ),
        ),
        SizedBox(width: 8.0),
        Expanded(
          child: _buildTeamInfo(widget.game.away, isHome: false),
        ),
      ],
    );
  }

  Widget _buildTeamInfo(Team team, {required bool isHome}) {
    return Row(
      mainAxisAlignment:
          isHome ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!isHome) _buildTeamLogo(team),
        SizedBox(width: 6.0),
        Flexible(
          child: Text(
            team.name,
                  style: TextStyle(
              color: Colors.white, // White color for the team names
              fontWeight: FontWeight.bold,
              fontSize: 18.0,
            ),
            overflow: TextOverflow.ellipsis,
            textAlign: isHome ? TextAlign.right : TextAlign.left,
          ),
        ),
        if (isHome) ...[
          SizedBox(width: 6.0),
          _buildTeamLogo(team),
        ],
      ],
    );
  }

  Widget _buildTeamLogo(Team team) {
    return Image.network(
      team.logo,
      width: 24.0,
      height: 24.0,
    );
  }

  Widget _buildGuessesTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('user name',
            style: TextStyle(
              color: Colors.white,
            ),
          )),
          DataColumn(label: Text('Guess',
            style: TextStyle(
              color: Colors.white,
            ),
          )),
          DataColumn(label: Text('Sum Points',
            style: TextStyle(
              color: Colors.white,
            ),
          )),
        ],
   rows: _guessesWithNames
    .map((guessWithName) => DataRow(
          cells: [
            DataCell(
              Center(
                child: Text(
                  guessWithName.userName,
                           style: TextStyle(
                            color: Colors.white,
                          ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            DataCell(
              Center(
                child: Text(
                  '${guessWithName.guess.homeTeamGoals} - ${guessWithName.guess.awayTeamGoals}',
                  textAlign: TextAlign.center,
                            style: TextStyle(
                            color: Colors.white,
                          ),
                ),
              ),
            ),
            DataCell(
              Center(
                child: Text(
                  guessWithName.guess.sumPoints.toString(),
                  textAlign: TextAlign.center,
                            style: TextStyle(
                            color: Colors.white,
                          ),
                ),
                
              ),
            ),
          ],
        ))
    .toList(),
      ),
    );

  }
}