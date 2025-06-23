import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:football/models/games.dart';

//for displaying snackbars
showSnackBar(BuildContext context, String text) {
  return ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(text),
    ),
  );
}

/// Loads and parses fake_games.json from assets into a List<Game>.
Future<List<Game>> loadFakeGames() async {
  final String jsonString =
      await rootBundle.loadString('assets/fake_games.json');
  final List<dynamic> jsonList = json.decode(jsonString);
  return jsonList.map((e) => Game.fromJson(e)).toList();
}
