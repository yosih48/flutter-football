import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:workmanager/workmanager.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationManager {
  static const taskName = 'checkUpcomingGames';
    static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher);
    await _initializeLocalNotifications();
  }

  static Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  static Future<void> scheduleNotifications(
      List<Map<String, dynamic>> games) async {
    print('games in scheduleNotifications');
    // print(games);
    List<String> serializedGames =
        games.map((game) => jsonEncode(game)).toList();
          print('serializedGames');
          print(serializedGames);
    await Workmanager().registerPeriodicTask(
      taskName,
      taskName,
      frequency: Duration(minutes: 15), // Check every 15 minutes
      inputData: {'games': serializedGames},
    );
  }

  static void callbackDispatcher() {
         print('callbackDispatcher');
    Workmanager().executeTask((task, inputData) async {
         print('executeTask');
      if (task == taskName && inputData != null) {
          print('task == taskName');
        // Deserialize the JSON strings back into maps
        List<String> serializedGames = List<String>.from(inputData['games']);
        List<Map<String, dynamic>> games =
            List<Map<String, dynamic>>.from(inputData['games']);

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
          if (timeDifference.inHours > 20 && timeDifference.inHours < 34) {
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
           try {
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
         } catch (e) {
        print('Error sending notification: $e');
      }
    }
  }
    static Future<void> _showLocalNotification(
    String homeTeam,
    
    String awayTeam,
    DateTime gameTime,
  ) async {
       print('_showLocalNotification');
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'game_notifications',
      'Game Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0,
      'Upcoming Game in 2 Hours',
      '$homeTeam vs $awayTeam at ${gameTime.toLocal()}',
      platformChannelSpecifics,
    );
  }
}
