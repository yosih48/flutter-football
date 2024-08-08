import 'package:flutter/material.dart';
import 'package:football/models/games.dart';

class GameWidget extends StatelessWidget {
  final Game game;

  GameWidget({required this.game});

  @override
  Widget build(BuildContext context) {
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
  }
}
