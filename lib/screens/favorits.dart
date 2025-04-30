import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:football/providers/flutter%20pub%20add%20provider.dart';
import 'package:football/resources/auth.dart';
import 'package:football/resources/usersMethods.dart';
import 'package:football/theme/colors.dart';
import 'package:football/utils/config.dart';
import 'package:football/widgets/toggleButton.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class FavoritsScreen extends StatefulWidget {
  const FavoritsScreen({super.key});

  @override
  State<FavoritsScreen> createState() => _FavoritsScreenState();
}

class _FavoritsScreenState extends State<FavoritsScreen> {
  late String displayName;
  late String email;
  bool isLoading = true;
  String userId = '';
  int selectedTab = 0; // 0 for notifications, 1 for chosen leagues

  Map<String, bool> notificationStates = {
    'ליגת אלופות': false,
    'ליגת העל': false,
    'ליגה ספרדית': false,
    'ליגה אירופית': false,
    'ליגה אנגלית': false,
    // 'ליגה גרמנית': false,
  };

  Map<int, bool> chosenLeagues = {
    2: true, // Champions League
    383: true, // Ligat Ha'al
    140: true, // La Liga
    3: true, // Europa League
    39: true, // Premier League
    // 78: true, // Bundesliga
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadUserPreferences();
  }

  Future<void> _loadUserPreferences() async {
    setState(() {
      isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final user = await authProvider.ensureUserLoaded();

      if (user != null) {
        setState(() {
          userId = user.id;
        });
        _getUserInfo();
      } else {
        print('User is null after ensuring loaded');
      }
    } catch (e) {
      print('Error loading user preferences: $e');
    }
  }

  Future<void> _getUserInfo() async {
    try {
      Map<String, dynamic> userData =
          await UsersMethods().fetchUserById(userId);
      Map<String, dynamic> snetEmail = userData['snetEmail'] ?? {};
      Map<String, dynamic> chosenLeaguesData = userData['chosenLeagues'] ?? {};

      setState(() {
        // Load notification states
        notificationStates['ליגת אלופות'] = snetEmail['2'] ?? false;
        notificationStates['ליגה אירופית'] = snetEmail['3'] ?? false;
        notificationStates['ליגה ספרדית'] = snetEmail['140'] ?? false;
        notificationStates['ליגת העל'] = snetEmail['383'] ?? false;
        notificationStates['ליגה אנגלית'] = snetEmail['39'] ?? false;
        // notificationStates['ליגה גרמנית'] = snetEmail['78'] ?? false;

        // Load chosen leagues
        chosenLeagues[2] = chosenLeaguesData['2'] ?? true;
        chosenLeagues[3] = chosenLeaguesData['3'] ?? true;
        chosenLeagues[140] = chosenLeaguesData['140'] ?? true;
        chosenLeagues[383] = chosenLeaguesData['383'] ?? true;
        chosenLeagues[39] = chosenLeaguesData['39'] ?? true;
        // chosenLeagues[78] = chosenLeaguesData['78'] ?? true;

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
    String _baseUrl = backendUrl;
    final String url = '$_baseUrl/users/profile';

    try {
      // Convert chosenLeagues map to a format that can be JSON encoded
      Map<String, bool> encodableChosenLeagues = {};
      chosenLeagues.forEach((key, value) {
        encodableChosenLeagues[key.toString()] = value;
      });
      final Map<String, dynamic> leagueData = {
        'championsLeague': notificationStates['ליגת אלופות'],
        'israeliLeague': notificationStates['ליגת העל'],
        'spanishLeague': notificationStates['ליגה ספרדית'],
        'europeLeague': notificationStates['ליגה אירופית'],
        'premierLeague': notificationStates['ליגה אנגלית'],
        'premierLeague': notificationStates['ליגה אנגלית'],
        // 'bundesLeague': notificationStates['ליגה גרמנית'],
        'africaLeague': false,
        'conferenceLeague': false,
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
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          selectedTab == 0
              ? AppLocalizations.of(context)!.notifications
              : AppLocalizations.of(context)!.chooseleagues,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            )
          : Column(
              children: [
                Container(
                  margin: EdgeInsets.symmetric(vertical: 8),
                  child: ToggleButtonsSample(
                    options: [
                      AppLocalizations.of(context)!.notifications,
                      AppLocalizations.of(context)!.chooseleagues,
                    ],
                    imageUrls: [
                      'https://img.icons8.com/ios/50/ffffff/notification-center.png',
                      'https://img.icons8.com/ios/50/ffffff/football2.png',
                    ],
                    onSelectionChanged: (index) {
                      setState(() {
                        selectedTab = index;
                      });
                    },
                    initialSelection: selectedTab,
                  ),
                ),
                Expanded(
                  child: selectedTab == 0
                      ? _buildNotificationsTab(name, email)
                      : _buildChosenLeaguesTab(name, email),
                ),
              ],
            ),
    );
  }

  Widget _buildNotificationsTab(String name, String email) {
    final leagueInfo = {
      'ליגת אלופות': {'subtitle': 'אירופה', 'id': '2'},
      'ליגת העל': {'subtitle': 'ישראל', 'id': '383'},
      'ליגה ספרדית': {'subtitle': 'ספרד', 'id': '140'},
      'ליגה אירופית': {'subtitle': 'אירופה', 'id': '3'},
      'ליגה אנגלית': {'subtitle': 'אנגליה', 'id': '39'},
      // 'בונדסליגה': {'subtitle': 'גרמניה', 'id': '78'},
    };

    return ListView(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SwitchListTile(
            title: Text(
              AppLocalizations.of(context)!.chooseallcompetitions,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            value: notificationStates.values.every((value) => value),
            onChanged: (bool value) {
              setState(() {
                notificationStates.updateAll((key, _) => value);
              });
              updateDatabase(name, email);
            },
            activeColor: Colors.blue,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey.withOpacity(0.5),
          ),
        ),
        ...notificationStates.entries.map((entry) {
          String leagueName = entry.key;
          String subtitle = leagueInfo[leagueName]?['subtitle'] ?? '';
          String leagueId = leagueInfo[leagueName]?['id'] ?? '';

          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SwitchListTile(
              title: Text(
                leagueName,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              // subtitle: Text(
              //   subtitle,
              //   style: TextStyle(
              //     color: Colors.grey,
              //   ),
              // ),
              secondary: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: entry.value
                      ? Colors.blue.withOpacity(0.1)
                      : Colors.transparent,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Image.network(
                    'https://media.api-sports.io/football/leagues/$leagueId.png',
                    width: 24,
                    height: 24,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.sports_soccer, color: Colors.blue);
                    },
                  ),
                ),
              ),
              value: entry.value,
              onChanged: (bool value) {
                setState(() {
                  notificationStates[leagueName] = value;
                });
                updateDatabase(name, email);
              },
              activeColor: Colors.blue,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: Colors.grey.withOpacity(0.5),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildChosenLeaguesTab(String name, String email) {
    final leagueNames = {
      2: AppLocalizations.of(context)!.championsleague,
      383: AppLocalizations.of(context)!.ligathaal,
      140: AppLocalizations.of(context)!.laliga,
      3: AppLocalizations.of(context)!.europaleague,
      39: AppLocalizations.of(context)!.premierleague,
      78: AppLocalizations.of(context)!.bundesleague,
    };

    final leagueIcons = {
      2: 'https://media.api-sports.io/football/leagues/2.png',
      383: 'https://media.api-sports.io/football/leagues/383.png',
      140: 'https://media.api-sports.io/football/leagues/140.png',
      3: 'https://media.api-sports.io/football/leagues/3.png',
      39: 'https://media.api-sports.io/football/leagues/39.png',
      78: 'https://media.api-sports.io/football/leagues/78.png',
    };

    return ListView(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SwitchListTile(
            title: Text(
              AppLocalizations.of(context)!.chooseallcompetitions,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            value: chosenLeagues.values.every((value) => value),
            onChanged: (bool value) {
              setState(() {
                chosenLeagues.updateAll((key, _) => value);
              });
              updateDatabase(name, email);
            },
            activeColor: Colors.blue,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey.withOpacity(0.5),
          ),
        ),
        ...chosenLeagues.entries.map((entry) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SwitchListTile(
              title: Text(
                leagueNames[entry.key] ?? '',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              secondary: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: entry.value
                      ? Colors.blue.withOpacity(0.1)
                      : Colors.transparent,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Image.network(
                    leagueIcons[entry.key] ?? '',
                    width: 24,
                    height: 24,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.sports_soccer, color: Colors.blue);
                    },
                  ),
                ),
              ),
              value: entry.value,
              onChanged: (bool value) {
                setState(() {
                  chosenLeagues[entry.key] = value;
                });
                updateDatabase(name, email);
              },
              activeColor: Colors.blue,
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: Colors.grey.withOpacity(0.5),
            ),
          );
        }).toList(),
      ],
    );
  }
}
