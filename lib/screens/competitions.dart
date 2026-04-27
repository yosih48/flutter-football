import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:football/providers/league_data_provider.dart';
import 'package:football/resources/auth.dart';
import 'package:football/responsive/mobile_screen_layout.dart';
import 'package:football/responsive/rsponsive_layout_screen.dart';
import 'package:football/responsive/web_screen_layout.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/colors.dart';
import 'package:football/utils/config.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';


class Competitions extends StatefulWidget {
    final String userEmail;
  final String userName;

  const Competitions({
    super.key,
    required this.userEmail,
    required this.userName,
  });

  @override
  State<Competitions> createState() => _CompetitionsState();
}

class _CompetitionsState extends State<Competitions> {

  Future<void> updateDatabase(name, email) async {
    String _baseUrl = backendUrl;
    final String url = '$_baseUrl/users/profile';

    try {
      // Convert chosenLeagues map to a format that can be JSON encoded
      Map<String, bool> encodableChosenLeagues = {};
      chosenLeagues.forEach((key, value) {
        encodableChosenLeagues[key.toString()] = value;
      });
   
      final Map<String, dynamic> leagueData = {
        'championsLeague': false,
        'israeliLeague': false,
        'spanishLeague': false,
        'europeLeague': false,
        'premierLeague': false,
        'conferenceLeague': false,
        'clubworldcup': false,
        // 'bundesLeague': notificationStates['ליגה גרמנית'],
        'africaLeague': false,
        // 'conferenceLeague': false,
        'euroLeague': false,
        'copaLeague': false,
      };
      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          'email': email,
          'displayName': name,
          'leagueData': leagueData,
          'chosenLeagues': encodableChosenLeagues,
        }),
      );

      if (response.statusCode == 200) {
        print('Profile updated and first login completed');
        // Clear LeagueDataProvider cache after successful update
            final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
              await markFirstLoginComplete();
              // Sync in-memory user + prefs cache so a restart with a failed
              // /users/:id refresh doesn't bounce the user back here.
              await authProvider.markCurrentUserAsReturning();
      
        if (!mounted) return;

        // Navigate to the main app screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const ResponsiveLayout(
              mobileScreenLayout: MobileScreenLayout(),
              webScreenLayout: WebScreenLayout(),
            ),
          ),
          (route) => false, // This removes ALL previous routes
        );
        // LeagueDataProvider().clearCache();
     
      } else {
        print('Failed to update database: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating database: $e');
    }
  }


Future<void> markFirstLoginComplete() async {
    try {
    
      final response = await http.post(
        Uri.parse('$backendUrl/users/mark-first-login-complete'),
        headers: {
     
          'Content-Type': 'application/json',
        },
             body: jsonEncode(<String, String>{
          'email': widget.userEmail,
       
        }),
      );

      if (response.statusCode == 200) {
        print('First login marked as complete');
      }
    } catch (e) {
      print('Error marking first login complete: $e');
    }
  }

  Map<int, bool> chosenLeagues = {
    2: false, // Champions League
    383: false, // Ligat Ha'al
    140: false, // La Liga
    3: false, // Europa League
    39: false, // Premier League
    848: false, // conference league
    // 15: false, // conference league
    // 78: true, // Bundesliga
  };
  final leagueIcons = {
    2: 'https://media.api-sports.io/football/leagues/2.png',
    383: 'https://media.api-sports.io/football/leagues/383.png',
    140: 'https://media.api-sports.io/football/leagues/140.png',
    3: 'https://media.api-sports.io/football/leagues/3.png',
    39: 'https://media.api-sports.io/football/leagues/39.png',
    78: 'https://media.api-sports.io/football/leagues/78.png',
    848: 'https://media.api-sports.io/football/leagues/848.png',
    // 15: 'https://media.api-sports.io/football/leagues/15.png',
  };

  
  @override
  Widget build(BuildContext context) {
        final leagueNames = {
      2: AppLocalizations.of(context)!.championsleague,
      383: AppLocalizations.of(context)!.ligathaal,
      140: AppLocalizations.of(context)!.laliga,
      3: AppLocalizations.of(context)!.europaleague,
      39: AppLocalizations.of(context)!.premierleague,
      78: AppLocalizations.of(context)!.bundesleague,
      848: AppLocalizations.of(context)!.conferenceleague,
      // 15: AppLocalizations.of(context)!.clubworldcup,
    };

 return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        // title: Text(
        //   AppLocalizations.of(context)!.chooseCompetitions,
        //   style: TextStyle(
        //     color: Colors.white,
        //     fontSize: 20,
        //     fontWeight: FontWeight.w600,
        //   ),
        // ),
           automaticallyImplyLeading: false,
        centerTitle: true,
      ),
      body: Column(
        children: [
          SizedBox(height: 32),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              AppLocalizations.of(context)!.chooseCompetitions,
              textAlign: Directionality.of(context) == TextDirection.rtl
                  ? TextAlign.right
                  : TextAlign.left,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(height: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.9,
                ),
                itemCount: chosenLeagues.length,
                itemBuilder: (context, index) {
                  final leagueEntry = chosenLeagues.entries.toList()[index];
                  final leagueId = leagueEntry.key;
                  final isSelected = leagueEntry.value;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        chosenLeagues[leagueId] = !isSelected;
                      });
                      // updateDatabase(widget.userName, widget.userEmail);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: cards,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? Colors.blue : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Icon(
                              isSelected ? Icons.star : Icons.star_border,
                              color:
                                  isSelected ? Colors.blue : Colors.grey[400],
                              size: 18,
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.all(12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 55,
                                  height: 55,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: EdgeInsets.all(10),
                                  child: Image.network(
                                    leagueIcons[leagueId] ?? '',
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(
                                        Icons.sports_soccer,
                                        color: Colors.blue,
                                        size: 32,
                                      );
                                    },
                                  ),
                                ),
                                SizedBox(height: 10),
                                Text(
                                  leagueNames[leagueId] ?? '',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),

      // ✅ Add this bottomNavigationBar:
      bottomNavigationBar: Padding(
        padding: EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: chosenLeagues.values.any((v) => v)
                ? () {
                  updateDatabase(widget.userName, widget.userEmail);
                    print('Continue pressed!');
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              disabledBackgroundColor: Colors.grey[600],
            ),
            child: Text(
             AppLocalizations.of(context)!.continueButton,
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
          ),
        ),
      ),
    );

  }
}