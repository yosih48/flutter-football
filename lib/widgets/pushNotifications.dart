import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:workmanager/workmanager.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class NotificationManager {
  static const taskName = 'checkUpcomingGames';

  static Future<void> scheduleNotifications(
      List<Map<String, dynamic>> games) async {
    print('games in scheduleNotifications');
    // print(games);
    List<String> serializedGames =
        games.map((game) => jsonEncode(game)).toList();
    await Workmanager().registerPeriodicTask(
      taskName,
      taskName,
      frequency: Duration(minutes: 15), // Check every 15 minutes
      inputData: {'games': serializedGames},
    );
  }

  static void callbackDispatcher() {
    Workmanager().executeTask((task, inputData) async {
         print('executeTask');
      if (task == taskName && inputData != null) {
          print('task == taskName');
        // Deserialize the JSON strings back into maps
        List<String> serializedGames = List<String>.from(inputData['games']);
        List games = serializedGames.map((game) => jsonDecode(game)).toList();

        final now = DateTime.now();

        for (var game in games) {
           print('game in games');
          final gameTime = DateTime.parse(game['gameTime']);

          // Convert to local
          DateTime gameTimeLocal = gameTime.toLocal();
          DateTime nowLocal = DateTime.now();
          final timeDifference = gameTimeLocal.difference(nowLocal);

          // Check if the game is between 2 hours and 1 hour 45 minutes away
          // if (timeDifference.inHours == 2 && timeDifference.inMinutes % 60 < 15) {
          if (timeDifference.inHours > 24 && timeDifference.inHours < 34) {
            print('in timeeeeeee');
            await _sendPushNotification(
              game['homeTeam'],
              game['awayTeam'],
              gameTimeLocal,
            );
          }else{
               print('no timeeeeeee');
          }
        }
      }
      return Future.value(true);
    });
  }

  static Future<void> _sendPushNotification(
    String homeTeam,
    String awayTeam,
    DateTime gameTime,
  ) async {
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken != null) {
      final response = await http.post(
        Uri.parse('https://leagues.onrender.com/send-notification'),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'token': fcmToken,
          'title': 'Upcoming Game in 2 Hours',
          'body': '$homeTeam vs $awayTeam at ${gameTime.toLocal()}',
        }),
      );

      if (response.statusCode == 200) {
        print('Notification sent successfully');
      } else {
        print('Failed to send notification');
      }
    }
  }
}
