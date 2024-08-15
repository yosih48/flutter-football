import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:football/models/games.dart';
import 'package:football/models/guesses.dart';
import 'package:intl/intl.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

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
  }) {
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    game.status.long,
                    style: TextStyle(
                      color: Color(0xff67727d).withOpacity(0.6),
                      fontSize: 14.0,
                    ),
                  ),
                  Text(
                    DateFormat('dd/MM/yy').format(game.date),
                    style: TextStyle(
                      color: Color(0xff67727d).withOpacity(0.6),
                      fontSize: 14.0,
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 8.0,
              ),
              Row(
                children: [
                  // SizedBox(width: 8.0),
                  Expanded(
                    child: Align(
                      alignment: Alignment.center,
                      child: Text(
                        game.home.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16.0,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  //  SizedBox(width: 6.0),
                  Image.network(
                    game.home.logo,
                    width: 24.0,
                    height: 24.0,
                  ),
                  SizedBox(width: 8.0),
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
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(
                                  1), // Limit input to 1 character
                              FilteringTextInputFormatter
                                  .digitsOnly, // Allow only digits
                            ],
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
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(
                                  1), // Limit input to 1 character
                              FilteringTextInputFormatter
                                  .digitsOnly, // Allow only digits
                            ],
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
                  SizedBox(width: 8.0),
                  Image.network(
                    game.away.logo,
                    width: 24.0,
                    height: 24.0,
                  ),
                  // SizedBox(width: 6.0),
                  Expanded(
                    child: Align(
                      alignment: Alignment.center,
                      child: Text(
                        game.away.name,
                        //  '${game.odds.draw}',

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
              if (game.status.long == "Not Started")
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: 1,
                    ),
                    Text(
                      '${game.odds.home}',
                      style: TextStyle(
                        color: Color(0xff67727d).withOpacity(0.6),
                        fontSize: 16.0,
                      ),
                    ),
                    // SizedBox(width: 20,),
                    Text(
                      '${game.odds.draw}',
                      style: TextStyle(
                        color: Color(0xff67727d).withOpacity(0.6),
                        fontSize: 16.0,
                      ),
                    ),
                    //  SizedBox(width: 20,),
                    Text(
                      '${game.odds.away}',
                      style: TextStyle(
                        color: Color(0xff67727d).withOpacity(0.6),
                        fontSize: 16.0,
                      ),
                    ),

                    SizedBox(
                      width: 1,
                    ),
                  ],
                ),
              SizedBox(height: 8.0),
              Row(
                children: [
                  if (guess != null && game.status.long != 'Not Started')
                    Expanded(
                      child: Align(
                        alignment: Alignment
                            .centerRight, // Align the first text to the right
                        child: Text(AppLocalizations.of(context)!.yourguess),
                      ),
                    ),
                       if (guess != null && game.status.long != 'Not Started')
                  Container(
                    width: 190,
                    // color: Colors.black,
                    child: Expanded(
                      child: Align(
                        alignment: Alignment
                            .centerRight, // Align the second text to the center
                        child: Text(
                          '${guess!.homeTeamGoals} - ${guess!.awayTeamGoals}',
                          style: TextStyle(
                            color: Color(0xff67727d).withOpacity(0.6),
                            fontSize: 14.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                  //  SizedBox(width: 100.0),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
