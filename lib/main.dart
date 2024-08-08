
import 'package:flutter/material.dart';

import 'package:football/screens/games.dart';


void main() => runApp(GameApp());

class GameApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: GamesScreen(),
    );
  }
}


