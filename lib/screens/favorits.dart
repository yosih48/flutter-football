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
    'קונפרנס ליג': false,
    // 'ליגה גרמנית': false,
  };

  Map<int, bool> chosenLeagues = {
    2: true, // Champions League
    383: true, // Ligat Ha'al
    140: true, // La Liga
    3: true, // Europa League
    39: true, // Premier League
    848: true, // conference league
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
        notificationStates['קונפרנס ליג'] = snetEmail['848'] ?? false;
        // notificationStates['ליגה גרמנית'] = snetEmail['78'] ?? false;

        // Load chosen leagues
        chosenLeagues[2] = chosenLeaguesData['2'] ?? true;
        chosenLeagues[3] = chosenLeaguesData['3'] ?? true;
        chosenLeagues[140] = chosenLeaguesData['140'] ?? true;
        chosenLeagues[383] = chosenLeaguesData['383'] ?? true;
        chosenLeagues[39] = chosenLeaguesData['39'] ?? true;
        chosenLeagues[848] = chosenLeaguesData['848'] ?? true;
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
        // Ensure notification states are consistent with chosen leagues
    if (notificationStates['ליגת אלופות'] == true && chosenLeagues[2] == false) {
      notificationStates['ליגת אלופות'] = false;
    }
    if (notificationStates['ליגת העל'] == true && chosenLeagues[383] == false) {
      notificationStates['ליגת העל'] = false;
    }
    if (notificationStates['ליגה ספרדית'] == true && chosenLeagues[140] == false) {
      notificationStates['ליגה ספרדית'] = false;
    }
    if (notificationStates['ליגה אירופית'] == true && chosenLeagues[3] == false) {
      notificationStates['ליגה אירופית'] = false;
    }
    if (notificationStates['ליגה אנגלית'] == true && chosenLeagues[39] == false) {
      notificationStates['ליגה אנגלית'] = false;
    }
    if (notificationStates['קונפרנס ליג'] == true && chosenLeagues[848] == false) {
      notificationStates['קונפרנס ליג'] = false;
    }
    // if (notificationStates['ליגה גרמנית'] == true && chosenLeagues[78] == false) {
    //   notificationStates['ליגה גרמנית'] = false;
    // }
      final Map<String, dynamic> leagueData = {
        'championsLeague': notificationStates['ליגת אלופות'],
        'israeliLeague': notificationStates['ליגת העל'],
        'spanishLeague': notificationStates['ליגה ספרדית'],
        'europeLeague': notificationStates['ליגה אירופית'],
        'premierLeague': notificationStates['ליגה אנגלית'],
        'conferenceLeague': notificationStates['קונפרנס ליג'],
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
      'קונפרנס ליג': {'subtitle': 'אירופה', 'id': '848'},
      // 'בונדסליגה': {'subtitle': 'גרמניה', 'id': '78'},
    };
 // Mapping between notification state keys and league IDs
  final notificationKeyToLeagueId = {
    'ליגת אלופות': 2,
    'ליגת העל': 383,
    'ליגה ספרדית': 140,
    'ליגה אירופית': 3,
    'ליגה אנגלית': 39,
    'קונפרנס ליג': 848,
    // 'ליגה גרמנית': 78,
  };
   // Filter notificationStates to only include enabled leagues from chosenLeagues
  Map<String, bool> filteredNotificationStates = {};
  notificationStates.forEach((leagueName, value) {
    int? leagueId = notificationKeyToLeagueId[leagueName];
    if (leagueId != null && chosenLeagues[leagueId] == true) {
      filteredNotificationStates[leagueName] = value;
    }
  });

  // Check if there are any enabled leagues at all
  bool hasEnabledLeagues = filteredNotificationStates.isNotEmpty;
  return hasEnabledLeagues ? ListView(
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
          value: filteredNotificationStates.values.every((value) => value) && 
                 filteredNotificationStates.isNotEmpty,
          onChanged: (bool value) {
            setState(() {
              // Only update notification states for leagues that are enabled
              notificationStates.forEach((key, _) {
                int? leagueId = notificationKeyToLeagueId[key];
                if (leagueId != null && chosenLeagues[leagueId] == true) {
                  notificationStates[key] = value;
                }
              });
            });
            updateDatabase(name, email);
          },
          activeColor: Colors.blue,
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: Colors.grey.withOpacity(0.5),
        ),
      ),
      ...filteredNotificationStates.entries.map((entry) {
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
  ) : Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.sports_soccer_outlined,
          size: 64,
          color: Colors.grey,
        ),
        SizedBox(height: 16),
        Text(
          AppLocalizations.of(context)?.noEnabledLeagues ?? 
          'No leagues available for notifications',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        Text(
          AppLocalizations.of(context)?.enableLeaguesFirst ?? 
          'Please enable leagues in the Chosen Leagues tab first',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
        // SizedBox(height: 24),
        // ElevatedButton(
        //   onPressed: () {
        //     setState(() {
        //       selectedTab = 1; // Switch to chosen leagues tab
        //     });
        //   },
        //   style: ElevatedButton.styleFrom(
        //     backgroundColor: Colors.blue,
        //     padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        //     shape: RoundedRectangleBorder(
        //       borderRadius: BorderRadius.circular(20),
        //     ),
        //   ),
        //   child: Text(
        //     AppLocalizations.of(context)?.goToChosenLeagues ?? 'Go to Chosen Leagues',
        //     style: TextStyle(color: Colors.white),
        //   ),
        // ),
      ],
    ),
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
      848: AppLocalizations.of(context)!.conferenceleague,
    };

    final leagueIcons = {
      2: 'https://media.api-sports.io/football/leagues/2.png',
      383: 'https://media.api-sports.io/football/leagues/383.png',
      140: 'https://media.api-sports.io/football/leagues/140.png',
      3: 'https://media.api-sports.io/football/leagues/3.png',
      39: 'https://media.api-sports.io/football/leagues/39.png',
      78: 'https://media.api-sports.io/football/leagues/78.png',
      848: 'https://media.api-sports.io/football/leagues/848.png',
    };
 // Map to translate league IDs to notification state keys
  final leagueIdToNotificationKey = {
    2: 'ליגת אלופות',
    383: 'ליגת העל',
    140: 'ליגה ספרדית',
    3: 'ליגה אירופית',
    39: 'ליגה אנגלית',
    848: 'קונפרנס ליג',
    // 78: 'ליגה גרמנית',
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
               // If user disables all leagues, also disable all notifications
              if (!value) {
                notificationStates.updateAll((key, _) => false);
              }
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
                      // If user disables a league, also disable its notification
                if (!value) {
                  String? notificationKey = leagueIdToNotificationKey[entry.key];
                  if (notificationKey != null) {
                    notificationStates[notificationKey] = false;
                  }
                }
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
