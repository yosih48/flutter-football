import 'package:flutter/material.dart';
import 'package:football/models/games.dart';
import 'package:football/models/guesses.dart';

class GameWidget extends StatelessWidget {
  final Game game;
  final Guess? guess;

  GameWidget({required this.game, this.guess});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    game.home.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.0,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${game.goals.home} - ${game.goals.away}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16.0,
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      game.away.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16.0,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.0),
            
            Row(
              children: [
                Text(
                  game.status.long,
                  style: TextStyle(
                    color: Color(0xff67727d).withOpacity(0.6),
                    fontSize: 14.0,
                  ),
                ),
                if (guess != null)
                  Expanded(
                    child: Align(
                      alignment: Alignment.center,
                      child: Text(
                        '${guess!.homeTeamGoals} - ${guess!.awayTeamGoals}',
                        style: TextStyle(
                          color: Color(0xff67727d).withOpacity(0.6),
                          fontSize: 14.0,
                        ),
                      ),
                    ),
                  ),
                 SizedBox(width:100.0),
              ],
            ),
                       
  
            // Add more game details as needed
          ],
        ),
      ),
    );
  }
}
