import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:football/models/games.dart';
import 'package:football/models/guesses.dart';
import 'package:football/theme/colors.dart';
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
        bool isValid = homeController!.text.isNotEmpty;
    print(isValid);

    return Card(
      color: cards, // Dark background color for the card
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.all(8.0),
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
                      color: (game.status.long == "First Half" ||
                              game.status.long == "Second Half" ||
                              game.status.long == "Halftime")
                          ? Colors.red
                          : Color(0xFF9BA4B5).withOpacity(0.6),
                      fontSize: 14.0,
                    ),
                  ),
                  if (game.status.long == 'Not Started')
                    Text(
                      DateFormat('HH:mm')
                          .format(game.date.toLocal()), // Format the time
                      style: TextStyle(
                        color: Color(0xFF9BA4B5).withOpacity(0.9),
                        fontSize: 14.0,
                      ),
                    ),
                  Text(
                    DateFormat('dd/MM/yy').format(game.date),
                    style: TextStyle(
                      color: Color(0xFF9BA4B5).withOpacity(0.6),
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
                          color: Colors.white, // White color for the team names
                          fontWeight: FontWeight.bold,
                          fontSize: 18.0,
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
                            style: TextStyle(
                              
                              color: Colors
                                  .white, // White color for the input text
                              fontSize: 16.0,
                            ),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color:
                                      isValid ? Color(0xFF9BA4B5) : Colors.red,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color:
                                      isValid ? Color(0xFF9BA4B5) : Colors.red,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color:
                                      isValid ? Color(0xFF9BA4B5) : Colors.red,
                                ),
                              ),
                       
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 12.0, horizontal: 8.0),
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
                            style: TextStyle(
                              color: Colors
                                  .white, // White color for the input text
                              fontSize: 16.0,
                            ),
                                        decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color:
                                      isValid ? Color(0xFF9BA4B5) : Colors.red,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color:
                                      isValid ? Color(0xFF9BA4B5) : Colors.red,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color:
                                      isValid ? Color(0xFF9BA4B5) : Colors.red,
                                ),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 12.0, horizontal: 8.0),
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
                        color: Colors.white, // White color for the team names
                        fontWeight: FontWeight.bold,
                        fontSize: 18.0,
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
                          color: Colors.white, // White color for the team names
                          fontWeight: FontWeight.bold,
                          fontSize: 18.0,
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
                        color:
                            Color(0xFF9BA4B5), // Light gray color for the odds
                        fontSize: 16.0,
                      ),
                    ),
                    // SizedBox(width: 20,),
                    Text(
                      '${game.odds.draw}',
                      style: TextStyle(
                        color:
                            Color(0xFF9BA4B5), // Light gray color for the odds
                        fontSize: 16.0,
                      ),
                    ),
                    //  SizedBox(width: 20,),
                    Text(
                      '${game.odds.away}',
                      style: TextStyle(
                        color:
                            Color(0xFF9BA4B5), // Light gray color for the odds
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
                // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (guess == null && game.status.long != 'Not Started')
                    Expanded(
                      child: Align(
                        alignment: Alignment.center,
                        child: Text(
                          '${'--'} : ${'--'}',
                          style: TextStyle(
                            color: Color(
                                0xFF9BA4B5), // Light gray color for the "Your guess" and score
                            fontSize: 14.0,
                          ),
                        ),
                      ),
                    ),

                  if (guess != null && game.status.long != 'Not Started')
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          AppLocalizations.of(context)!.yourguess,
                          style: TextStyle(
                            color: Color(
                                0xFF9BA4B5), // Light gray color for the "Your guess" and score
                            fontSize: 14.0,
                          ),
                        ),
                      ),
                    ),
                  if (guess != null && game.status.long != 'Not Started')
                    Expanded(
                      child: Align(
                        alignment: Alignment.center,
                        child: Text(
                          '${guess!.homeTeamGoals} - ${guess!.awayTeamGoals}',
                          style: TextStyle(
                            color: Color(
                                0xFF9BA4B5), // Light gray color for the "Your guess" and score
                            fontSize: 14.0,
                          ),
                        ),
                      ),
                    ),
                  if (guess != null && game.status.long != 'Not Started')
                             Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child:
                        Text(
'${guess!.sumPoints % 1 == 0 ? guess!.sumPoints.toInt() : guess!.sumPoints} נקודות ',
                          style: TextStyle(
                            color: Color(0xFF9BA4B5).withOpacity(0.6),
                            fontSize: 14.0,
                          ),
                        ),
                      ),
                    ),
                  // SizedBox(width: 170),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
