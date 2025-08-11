import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:football/models/games.dart';
import 'package:football/models/guesses.dart';
import 'package:football/resources/usersMethods.dart';
import 'package:football/resources/gamesMethods.dart';
import 'package:football/theme/colors.dart';
import 'package:football/utils/config.dart';
import 'package:http/http.dart' as http;
import 'package:football/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TeamSelectionButton extends StatefulWidget {
  final String clientId;
  final String email;
  final int league;
  final void Function(String)? onTeamSelected;

  const TeamSelectionButton({
    Key? key,
    required this.clientId,
    required this.email,
    required this.league,
    this.onTeamSelected,
  }) : super(key: key);

  @override
  _TeamSelectionButtonState createState() => _TeamSelectionButtonState();
}

class _TeamSelectionButtonState extends State<TeamSelectionButton> {
  String? selectedTeam;
  bool isLoading = false;
  bool hasWinner = false;
  String _baseUrl = backendUrl;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  @override
  void didUpdateWidget(TeamSelectionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.league != widget.league) {
      _fetchUserData();
    }
  }

  Future<void> _fetchUserData() async {
    if (widget.league == -1) return; // Don't fetch if no league selected

    setState(() {
      isLoading = true;
    });

    try {
      final userData = await UsersMethods().fetchUserById(widget.clientId);
      final leagueId = widget.league;
      final winner = userData['winner']?['$leagueId'];

      setState(() {
        if (winner != null) {
          selectedTeam = winner;
          hasWinner = true;
        } else {
          hasWinner = false;
          selectedTeam = null;
        }
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching user data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  // _realApi method (from teamSelect.dart)
  Future<List<dynamic>> _realApi(dynamic leagueId) async {
    print('_realApi called with dataToSend: $leagueId');
    print('Making request to: ${_baseUrl}/getTeams');

    final response = await http.post(
      Uri.parse('${_baseUrl}/getTeams'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'data': leagueId}),
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      return responseData['games'] as List<dynamic>;
    } else {
      throw Exception('Failed to load teams: ${response.statusCode}');
    }
  }

  // _fetchAllTeams method (from teamSelect.dart)
  Future<List<String>> _fetchAllTeams() async {
    print('_fetchAllTeams called');

    try {
      final teams = await _realApi(widget.league.toString());
      // Extract team names from the teams data structure
      return teams
          .map((teamData) => teamData['team']['name']?.toString() ?? '')
          .where((teamName) => teamName.isNotEmpty)
          .toList();
    } catch (e) {
      print('Error in _fetchAllTeams: $e');
      return [];
    }
  }

  // Check if selection is still available for current league (moved from games.dart)
  Future<Map<String, dynamic>> _getSelectionAvailability() async {
    print('_getSelectionAvailability called for league: ${widget.league}');

    try {
      final games = await GamesMethods().fetchGamesForLeague(widget.league);
      print('Retrieved ${games.length} games for availability check');

      if (games.isEmpty) {
        print('No games found - returning not available');
        return {
          'showButtons': true,
          'available': false,
          'reason': 'no_games',
          'message': AppLocalizations.of(context)!.selectionnotavailableyet
        };
      }

      // Sort games by date to find the first game
      games.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final firstGame = games.first;
      final currentTime = DateTime.now().toUtc();
      final firstGameDate = firstGame.date.toUtc();

      print('Current time: $currentTime');
      print('First game date: $firstGameDate');

      // Check if current time is before first game
      bool isBeforeFirstGame = currentTime.isBefore(firstGameDate);
      print('Is before first game: $isBeforeFirstGame');

      if (!isBeforeFirstGame) {
        // League has started - don't show buttons at all
        print('League has started - returning not available');
        return {
          'showButtons': false,
          'available': false,
          'reason': 'league_started',
          'message': null
        };
      }

      // Check if we're within 1 hour of first game
      final cutoffTime = firstGameDate.subtract(Duration(hours: 1));
      print('Cutoff time (1 hour before first game): $cutoffTime');

      if (currentTime.isAfter(cutoffTime)) {
        print('Past cutoff time - returning not available');
        return {
          'showButtons': false,
          'available': false,
          'reason': 'time_expired',
          'message': null
        };
      }

      print('Selection is available!');
      return {
        'showButtons': true,
        'available': true,
        'reason': 'available',
        'message': null
      };
    } catch (e) {
      print('Error checking selection availability: $e');
      return {
        'showButtons': true,
        'available': false,
        'reason': 'error',
        'message': AppLocalizations.of(context)!.selectionnotavailable
      };
    }
  }

  // Get subtitle text for team selection (moved from games.dart)
  String _getTeamSelectionSubtitle() {
    return AppLocalizations.of(context)!.taptoselectwinner;
  }

  // Show team selection dialog (moved from games.dart)
  void _showTeamSelectionDialog() async {
    print('_showTeamSelectionDialog called');

    // First check if selection is available
    final availability = await _getSelectionAvailability();
    print('Availability check result: $availability');

    if (!availability['available']) {
      print('Selection not available, showing message and returning early');
      _showAvailabilityMessage(availability['message']);
      return;
    }

    print('Selection is available, proceeding to fetch teams');
    try {
      // Use the existing _fetchAllTeams function
      final teams = await _fetchAllTeams();
      print('Teams from _fetchAllTeams: $teams');
      print('Teams count: ${teams.length}');

      if (teams.isEmpty) {
        print('No teams found, showing error message');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No teams found for this league')),
        );
        return;
      }

      String? selectedTeamLocal;

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
              print('Dialog builder called with teams: $teams');
              return AlertDialog(
                backgroundColor: cards,
                title: Text(
                  AppLocalizations.of(context)!.teamcannotbechanged,
                  style: TextStyle(color: Colors.red, fontSize: 16),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 10),
                    DropdownButton<String>(
                      hint: Text(AppLocalizations.of(context)!.chooseteam,
                          style: TextStyle(color: Colors.blue)),
                      isExpanded: true,
                      value: selectedTeamLocal,
                      items: teams.map((String team) {
                        print('Creating dropdown item for team: $team');
                        return DropdownMenuItem<String>(
                          value: team,
                          child:
                              Text(team, style: TextStyle(color: Colors.white)),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        print('Dropdown selection changed to: $newValue');
                        setDialogState(() {
                          selectedTeamLocal = newValue;
                        });
                      },
                    ),
                    SizedBox(height: 20),
                    if (selectedTeamLocal != null) ...[
                      Text(
                        '$selectedTeamLocal',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                    SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                      ),
                      onPressed: selectedTeamLocal != null
                          ? () {
                              _saveTeamSelection(selectedTeamLocal!);
                              Navigator.of(context).pop();
                            }
                          : null,
                      child: Text(AppLocalizations.of(context)!.saveteam,
                          style: TextStyle(color: Colors.blue)),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      print('Error showing team selection dialog: $e');
    }
  }

  // Save team selection (moved from games.dart)
  Future<void> _saveTeamSelection(String selectedTeam) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/users/winner'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, dynamic>{
          '_id': widget.clientId,
          'email': widget.email,
          'winner': {
            'winner.${widget.league}': selectedTeam,
          },
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(AppLocalizations.of(context)!.teamSavedsuccessfully)),
        );
        // Refresh user data to update the UI
        _fetchUserData();
        // Call callback if provided
        if (widget.onTeamSelected != null) {
          widget.onTeamSelected!(selectedTeam);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)!.failedtoSaveTeam)),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.errorsavingteam)),
      );
    }
  }

  // Show availability message (moved from games.dart)
  void _showAvailabilityMessage(String? message) {
    if (message == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange[700],
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(bottom: 80, left: 16, right: 16),
      ),
    );
  }

  // Show hint to user about selecting a league (moved from games.dart)
  void _showLeagueSelectionHint() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.selectleaguefirst + " 👆",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue[700],
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(bottom: 80, left: 16, right: 16),
      ),
    );
  }

  // Helper method to build unified card-style button (moved from games.dart)
  Widget _buildUnifiedButton({
    required IconData icon,
    required String text,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.grey[800]?.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[600]!, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.grey[400],
              size: 24,
            ),
            SizedBox(height: 6),
            Text(
              text,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Don't show anything if no league is selected
    if (widget.league == -1) {
      return _buildUnifiedButton(
        icon: Icons.emoji_events,
        text: AppLocalizations.of(context)!.choosewinner,
        subtitle: AppLocalizations.of(context)!.selectleaguefirst,
        onTap: () => _showLeagueSelectionHint(),
      );
    }

    // Show loading state
    if (isLoading) {
      return _buildUnifiedButton(
        icon: Icons.emoji_events,
        text: AppLocalizations.of(context)!.choosewinner,
        subtitle: "Loading...",
        onTap: () {},
      );
    }

    // Show the selection button with availability check
    // Note: We always check availability regardless of whether user has already selected a team
    return FutureBuilder<Map<String, dynamic>>(
      future: _getSelectionAvailability(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildUnifiedButton(
            icon: Icons.emoji_events,
            text: AppLocalizations.of(context)!.choosewinner,
            subtitle: "Loading...",
            onTap: () {},
          );
        }

        final availability = snapshot.data ??
            {'showButtons': false, 'available': false, 'message': 'Error'};
        final showButtons = availability['showButtons'] as bool;
        final isAvailable = availability['available'] as bool;
        final message = availability['message'] as String?;

        // Don't show button at all if league has started or time expired
        if (!showButtons) {
          return SizedBox.shrink();
        }

        // Show different subtitle based on whether user has already selected a team
        String subtitle;
        if (hasWinner && selectedTeam != null) {
          // User has already selected a team, show current selection with shorter text
          subtitle = isAvailable
              ? "$selectedTeam ✓"
              : message ?? AppLocalizations.of(context)!.selectionnotavailable;
        } else {
          // User hasn't selected a team yet
          subtitle = isAvailable
              ? _getTeamSelectionSubtitle()
              : message ?? AppLocalizations.of(context)!.selectionnotavailable;
        }

        return _buildUnifiedButton(
          icon: Icons.emoji_events,
          text: AppLocalizations.of(context)!.choosewinner,
          subtitle: subtitle,
          onTap: isAvailable
              ? () => _showTeamSelectionDialog()
              : () => _showAvailabilityMessage(message ??
                  AppLocalizations.of(context)!.selectionnotavailable),
        );
      },
    );
  }
}
