import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:football/models/games.dart';
import 'package:football/models/guesses.dart';
import 'package:football/resources/usersMethods.dart';
import 'package:football/resources/gamesMethods.dart';
import 'package:football/resources/playersMethods.dart';
import 'package:football/theme/colors.dart';
import 'package:football/utils/config.dart';
import 'package:http/http.dart' as http;
import 'package:football/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlayerSelectionButton extends StatefulWidget {
  final String clientId;
  final String email;
  final int league;
  final void Function(String)? onPlayerSelected;

  const PlayerSelectionButton({
    Key? key,
    required this.clientId,
    required this.email,
    required this.league,
    this.onPlayerSelected,
  }) : super(key: key);

  @override
  _PlayerSelectionButtonState createState() => _PlayerSelectionButtonState();
}

class _PlayerSelectionButtonState extends State<PlayerSelectionButton> {
  String? selectedPlayer;
  bool isLoading = false;
  bool hasPlayer = false;
  String _baseUrl = backendUrl;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  @override
  void didUpdateWidget(PlayerSelectionButton oldWidget) {
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
      final player = userData['topScorer']?['$leagueId'];

      setState(() {
        if (player != null) {
          selectedPlayer = player;
          hasPlayer = true;
        } else {
          hasPlayer = false;
          selectedPlayer = null;
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

  // Check if selection is still available for current league
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

      // Check if current time is before first game
      bool isBeforeFirstGame = currentTime.isBefore(firstGameDate);

      if (!isBeforeFirstGame) {
        return {
          'showButtons': false,
          'available': false,
          'reason': 'league_started',
          'message': null
        };
      }

      // Check if we're within 1 hour of first game
      final cutoffTime = firstGameDate.subtract(Duration(hours: 1));

      if (currentTime.isAfter(cutoffTime)) {
        return {
          'showButtons': false,
          'available': false,
          'reason': 'time_expired',
          'message': null
        };
      }

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

  // Get subtitle text for player selection
  String _getPlayerSelectionSubtitle() {
    return AppLocalizations.of(context)!.taptoselecttopscorer;
  }

  // Show player selection dialog
  void _showPlayerSelectionDialog() async {
    print('_showPlayerSelectionDialog called');

    // First check if selection is available
    final availability = await _getSelectionAvailability();
    print('Availability check result: $availability');

    if (!availability['available']) {
      print('Selection not available, showing message and returning early');
      _showAvailabilityMessage(availability['message']);
      return;
    }

    print('Selection is available, proceeding to fetch players');
    try {
      // Fetch players for current league using PlayersMethods
      final dataToSend = {'league': widget.league};
      final players = await PlayersMethods().fetchPlayersList(dataToSend);

      if (players.isEmpty) {
        print('No players found, showing error message');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No players found for this league')),
        );
        return;
      }

      String? selectedPlayerLocal;

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setDialogState) {
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
                      hint: Text(AppLocalizations.of(context)!.choosPlayer,
                          style: TextStyle(color: Colors.blue)),
                      isExpanded: true,
                      value: selectedPlayerLocal,
                      items: players.map((String player) {
                        return DropdownMenuItem<String>(
                          value: player,
                          child: Text(player,
                              style: TextStyle(color: Colors.white)),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        setDialogState(() {
                          selectedPlayerLocal = newValue;
                        });
                      },
                    ),
                    SizedBox(height: 20),
                    if (selectedPlayerLocal != null) ...[
                      Text(
                        '$selectedPlayerLocal',
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
                      onPressed: selectedPlayerLocal != null
                          ? () {
                              _savePlayerSelection(selectedPlayerLocal!);
                              Navigator.of(context).pop();
                            }
                          : null,
                      child: Text(AppLocalizations.of(context)!.savePlayer,
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
      print('Error showing player selection dialog: $e');
    }
  }

  // Save player selection
  Future<void> _savePlayerSelection(String selectedPlayer) async {
    final cleanedPlayerName = selectedPlayer.split(' (')[0];
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/users/top-scorer'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, dynamic>{
          '_id': widget.clientId,
          'email': widget.email,
          'topScorer': {
            'topScorer.${widget.league}': cleanedPlayerName,
          },
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(AppLocalizations.of(context)!.playerSavedsuccessfully)),
        );
        // Refresh user data to update the UI
        _fetchUserData();
        // Call callback if provided
        if (widget.onPlayerSelected != null) {
          widget.onPlayerSelected!(selectedPlayer);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)!.failedtoSaveplayer)),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!.errorsavingplayer)),
      );
    }
  }

  // Show availability message
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

  // Show hint to user about selecting a league
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

  // Helper method to build unified card-style button
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
        icon: Icons.sports_soccer,
        text: AppLocalizations.of(context)!.chooseTopScorer,
        subtitle: AppLocalizations.of(context)!.selectleaguefirst,
        onTap: () => _showLeagueSelectionHint(),
      );
    }

    // Show loading state
    if (isLoading) {
      return _buildUnifiedButton(
        icon: Icons.sports_soccer,
        text: AppLocalizations.of(context)!.chooseTopScorer,
        subtitle: "Loading...",
        onTap: () {},
      );
    }

    // Show the selection button with availability check
    // Note: We always check availability regardless of whether user has already selected a player
    return FutureBuilder<Map<String, dynamic>>(
      future: _getSelectionAvailability(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildUnifiedButton(
            icon: Icons.sports_soccer,
            text: AppLocalizations.of(context)!.chooseTopScorer,
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

        // Show different subtitle based on whether user has already selected a player
        String subtitle;
        if (hasPlayer && selectedPlayer != null) {
          // User has already selected a player, show current selection with shorter text
          subtitle = isAvailable
              ? "$selectedPlayer ✓"
              : message ?? AppLocalizations.of(context)!.selectionnotavailable;
        } else {
          // User hasn't selected a player yet
          subtitle = isAvailable
              ? _getPlayerSelectionSubtitle()
              : message ?? AppLocalizations.of(context)!.selectionnotavailable;
        }

        return _buildUnifiedButton(
          icon: Icons.sports_soccer,
          text: AppLocalizations.of(context)!.chooseTopScorer,
          subtitle: subtitle,
          onTap: isAvailable
              ? () => _showPlayerSelectionDialog()
              : () => _showAvailabilityMessage(message ??
                  AppLocalizations.of(context)!.selectionnotavailable),
        );
      },
    );
  }
}
