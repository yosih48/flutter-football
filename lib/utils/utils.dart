import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:football/models/games.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:football/l10n/app_localizations.dart';

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


void showForceUpdateDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false, // אי אפשר לסגור בלחיצה בצד
    builder: (BuildContext context) {
      // WillPopScope (או PopScope בגרסאות חדשות) מונע לחיצה על כפתור "חזור" במכשיר
      return WillPopScope(
        onWillPop: () async => false, 
        child: AlertDialog(
          title: Text(AppLocalizations.of(context)!.forceUpdateTitle),
          content: Text(AppLocalizations.of(context)!.forceUpdateContent),
          actions: [
            ElevatedButton(
              onPressed: () {
                _launchStore();
              },
              child: Text(AppLocalizations.of(context)!.forceUpdateButton),
            ),
          ],
        ),
      );
    },
  );
}

void _launchStore() {
  // שים פה את הלינק שלך לחנות!
  const androidUrl = 'https://play.google.com/store/apps/details?id=com.yosi.football';
  // const iosUrl = 'https://apps.apple.com/...'; 
  
  final url = Uri.parse(Platform.isAndroid ? androidUrl : androidUrl); // כרגע שמתי אנדרואיד לשניהם
  launchUrl(url, mode: LaunchMode.externalApplication);
}