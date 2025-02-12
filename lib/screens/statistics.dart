import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:football/models/guesses.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:football/resources/guessesMethods.dart';
import 'package:football/theme/colors.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:cupertino_icons/cupertino_icons.dart';

class Statistics extends StatefulWidget {
  final userId;
  final leagueId;
  const Statistics({super.key, this.userId, this.leagueId});

  @override
  State<Statistics> createState() => _StatisticsState();
}

class _StatisticsState extends State<Statistics> {
  List<Guess> userGuesses = [];
  List<Guess> directGuesses = [];
  List<Guess> directionGuesses = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserGuesses();
  }

  Future<void> _fetchUserGuesses() async {
    try {
      List<Guess> guesses =
          await GuessesMethods().fetchThisUserGuesses(widget.userId);
      print(guesses);

      int leagueID = widget.leagueId;

      // Filter guesses by leagueID
      List<Guess> filteredGuesses =
          guesses.where((item) => item.leagueId == leagueID).toList();

      print(guesses);
      print(filteredGuesses.length);
      // Separate direct and direction guesses
      List<Guess> direct =
          filteredGuesses.where((item) => item.direct == 1).toList();
      List<Guess> direction =
          filteredGuesses.where((item) => item.direction == 1).toList();

      setState(() {
        userGuesses = filteredGuesses;
        directGuesses = direct;
        directionGuesses = direction;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching user guesses: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
          backgroundColor: Colors.transparent,
              iconTheme: IconThemeData(
          color: Colors.white, // Set the color of the arrow icon to white
        ),
        title: Text(
          AppLocalizations.of(context)!.statistics,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: white,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  SizedBox(height: 16),
                  _buildStatCard(
                    AppLocalizations.of(context)!.totalGuesses,
                    userGuesses.length.toString(),
                    Icons.bar_chart,
                    Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  _buildStatCard(
                    AppLocalizations.of(context)!.directGuesses,
                    directGuesses.length.toString(),
                    Icons.my_location,
                    Colors.green,
                  ),
                  const SizedBox(height: 16),
                  _buildStatCard(
                    AppLocalizations.of(context)!.directionGuesses,
                    directionGuesses.length.toString(),
                    CupertinoIcons.scope,
                    Colors.orange,
                  ),
                ],
              ),
            ),
    );
  }
}

Widget _buildStatCard(String title, String value, IconData icon, Color color) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.1),
      borderRadius: BorderRadius.circular(15),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 10,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 30,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: white.withOpacity(0.7),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: TextStyle(
                    color: white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
