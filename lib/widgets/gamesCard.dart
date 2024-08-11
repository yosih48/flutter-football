import 'package:flutter/material.dart';
import 'package:football/models/games.dart';
import 'package:football/models/guesses.dart';

class GameWidget extends StatelessWidget {
  final Game game;
  final Guess? guess;
  final Function(BuildContext) onTap;
  final TextEditingController? homeController;
  final TextEditingController? awayController;
  GameWidget({
    required this.game,
    this.guess,
    required this.onTap,
    this.homeController,
    this.awayController,
  }){
    // Set initial values for controllers if a guess exists
    if (guess != null) {
      homeController!.text = guess!.homeTeamGoals.toString();
      awayController!.text = guess!.awayTeamGoals.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    print(homeController);
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.0),
        child: InkWell(
          onTap: () => onTap(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Image.network(
                    game.home.logo,
                    width: 24.0,
                    height: 24.0,
                  ),
                  SizedBox(width: 8.0),
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
                  if (game.status.long == "Not Started")
                    Row(
                      children: [
                        SizedBox(
                          width: 40,
                          height: 50,
                          child: TextField(
                            controller: homeController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        Text(' - '),
                        SizedBox(
                          width: 40,
                          height: 50,
                          child: TextField(
                            controller: awayController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
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
                  SizedBox(width: 8.0),
                  Image.network(
                    game.away.logo,
                    width: 24.0,
                    height: 24.0,
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
                  // if (guess != null)
                  //   Expanded(
                  //     child: Align(
                  //       alignment: Alignment.center,
                  //       child: Text(
                  //         '${guess!.homeTeamGoals} - ${guess!.awayTeamGoals}',
                  //         style: TextStyle(
                  //           color: Color(0xff67727d).withOpacity(0.6),
                  //           fontSize: 14.0,
                  //         ),
                  //       ),
                  //     ),
                  //   ),
                  SizedBox(width: 100.0),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
