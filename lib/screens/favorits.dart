import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:football/providers/flutter%20pub%20add%20provider.dart';
import 'package:football/resources/auth.dart';
import 'package:football/resources/usersMethods.dart';
import 'package:football/theme/colors.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

class FavoritsScreen extends StatefulWidget {
  const FavoritsScreen({super.key});

  @override
  State<FavoritsScreen> createState() => _FavoritsScreenState();
}

class _FavoritsScreenState extends State<FavoritsScreen> {
  late String displayName;
  late String email;
  bool isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadUserPreferences();
  }

  Map<String, bool> leagueStates = {
    'ליגת אלופות': false,
    'ליגת העל': false,
    'ליגה ספרדית': false,
    'ליגה אירופית': false,
  };
  Future<void> _loadUserPreferences() async {
    final userProvider = await Provider.of<AuthProvider>(context);
    final userId = userProvider.currentUser!.id;


    try {
      Map<String, dynamic> userData =
          await UsersMethods().fetchUserById(userId);
      Map<String, dynamic> snetEmail = userData['snetEmail'];

      setState(() {
        leagueStates['ליגת אלופות'] = snetEmail['2'] ?? false;
        leagueStates['ליגה אירופית'] = snetEmail['3'] ?? false;
        leagueStates['ליגה ספרדית'] = snetEmail['140'] ?? false;
        leagueStates['ליגת העל'] = snetEmail['383'] ?? false;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading user preferences: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> updateDatabase(name, email) async {
    print(leagueStates);
    final String url =
        'https://leagues.onrender.com/users/profile'; // Replace with your actual API endpoint
    final Map<String, dynamic> leagueData = {
      'championsLeague': leagueStates['ליגת אלופות'],
      'israeliLeague': leagueStates['ליגת העל'],
      'spanishLeague': leagueStates['ליגה ספרדית'],
      'europeLeague': leagueStates['ליגה אירופית'],
      'premierLeague': false,
      'africaLeague': false,
      'conferenceLeague': false,
      'euroLeague': false,
      'copaLeague': false,
    };

    try {
      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          'email': email, // Replace with actual user email
          'displayName': name, // Replace with actual user name
          'leagueData': leagueData,
        }),
      );

      if (response.statusCode == 200) {
        print('Database updated successfully');
      } else {
        print('Failed to update database: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating database: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<AuthProvider>(context);
    final name = userProvider.currentUser!.name;
    final email = userProvider.currentUser!.email;
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'התראות',
          style: TextStyle(
            color: white, // White color for the team names
          ),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Padding(
                   padding: EdgeInsets.only(top: 50.0),
           
                  child: Transform.scale(
                    scale: 0.9,
                    child: SwitchListTile(
                      title: Text(
                        'בחירת כל התחרויות',
                        style: TextStyle(
                          color: white, // White color for the team names
                        ),
                      ),
                      value: leagueStates.values.every((value) => value),
                      onChanged: (bool value) {
                        setState(() {
                          leagueStates.updateAll((key, _) => value);
                        });
                        updateDatabase(name, email);
                      },
                      activeColor:
                          Colors.blue, // White color for the switch when it's on
                      inactiveThumbColor: Colors
                          .white, // White color for the switch thumb when it's off
                      inactiveTrackColor: Colors
                          .grey, // Optional: Light grey for the track when it's off
                    ),
                  ),
                ),
                ...leagueStates.entries.map((entry) {
                  String leagueName = entry.key;
                  String subtitle = '';
                  IconData icon = Icons.sports_soccer;

                  switch (leagueName) {
                    case 'ליגת אלופות':
                      subtitle = 'אירופה';
                      icon = Icons.sports_soccer;
                      break;
                    case 'ליגת העל':
                      subtitle = 'ישראל';
                      icon = Icons.sports_soccer;
                      break;
                    case 'ליגה ספרדית':
                      subtitle = 'ספרד';
                      icon = Icons.sports_soccer;
                      break;
                    case 'ליגה אירופית':
                      subtitle = 'אירופה';
                      icon = Icons.sports_soccer;
                      break;
                  }

                  return Transform.scale(
                    scale: 0.9,
                    child: SwitchListTile(
                      title: Text(
                        leagueName,
                        style: TextStyle(
                          color: white, // White color for the team names
                        ),
                      ),
                      subtitle: Text(subtitle),
                      secondary: Icon(icon),
                      value: entry.value,
                      onChanged: (bool value) {
                        print(userProvider.currentUser!.name);
                        print(userProvider.currentUser!.email);
                        setState(() {
                          leagueStates[leagueName] = value;
                        });
                        updateDatabase(name, email);
                      },
                      activeColor: Colors
                          .blue, // White color for the switch when it's on
                      inactiveThumbColor: Colors
                          .white, // White color for the switch thumb when it's off
                      inactiveTrackColor: Colors
                          .grey, // Optional: Light grey for the track when it's off
                    ),
                  );
                }).toList(),
              ],
            ),
    );
  }
}
