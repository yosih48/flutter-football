import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:football/main.dart';
import 'package:football/models/games.dart';
import 'package:football/resources/gamesMethods.dart';
import 'package:football/screens/gameDetails.dart';

class FirebaseMessagingService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    await _firebaseMessaging.requestPermission();
    await _initializeLocalNotifications();

    // Set up message handlers
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Set up notification tap handlers
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    // Check for initial notification that launched the app
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      print("Handling initial message");
      _handleMessageTap(initialMessage);
    }
  }

  static Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );

    // Initialize with callback for notification taps
    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print("Local notification tapped: ${response.payload}");
      
        if (response.payload != null) {
          final Map<String, dynamic> data = json.decode(response.payload!);
            print("Screen value: ${data['screen']}");
            if(data['screen'] == 'game_points_details'){

          handleNotificationNavigation(data);
            }else if(data['screen'] == 'game_details'){
            print('Navigating to games screen');
            navigatorKey.currentState?.pushNamed('/game_details');
            }
        }
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'high_importance_channel',
            'High Importance Notifications',
            importance: Importance.high,
          ),
        );

    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  static Future<void> _firebaseMessagingBackgroundHandler(
      RemoteMessage message) async {
    print("Handling a background message: ${message.messageId}");
    // Don't initialize Firebase here
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    print("Received foreground message: ${message.messageId}");
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        payload: json.encode(message.data), // Include the data payload
      );
    }
  }

  static void _handleMessageTap(RemoteMessage message) {
    print("Message tapped: ${message.messageId}");
    print("Message data: ${message.data}");
    if(message.data['screen'] == 'game_points_details'){

    handleNotificationNavigation(message.data);
    }else if(message.data['screen'] == 'game_details'){
        print('Navigating to games screen');
      navigatorKey.currentState?.pushNamed('/game_details');
    }
  }

  static void handleNotificationNavigation(Map<String, dynamic> data) async {
    print('handleNotificationNavigation called with data: $data');
    if (data['screen'] == 'game_points_details') {
      try {
        int gameId = int.parse(data['gameId']);
        int leagueId = int.parse(data['league']);

        print('Fetching games for league: $leagueId');
        List<Game> fetchedGames = await _fetchGames(leagueId);
        print(fetchedGames);
        Game? game = fetchedGames.firstWhere(
          
          (g) => g.fixtureId == gameId,
          orElse: () => throw Exception('Game not found'),
        );
        print(game);
        print('Navigating to game details for game: ${game.fixtureId}');
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => GameDetails(
              gameOriginalId: gameId,
              game: game,
              userId: data['userId'],
            ),
          ),
        );
      } catch (e) {
        print('Error handling notification navigation: $e');
        // Handle error appropriately
      }
    }
  }

  static Future<List<Game>> _fetchGames(int league) async {
    return await GamesMethods().fetchGamesForLeague(
      league,
      // selectedDate: DateTime.now().copyWith(
      //   hour: 0,
      //   minute: 0,
      //   second: 0,
      //   millisecond: 0,
      //   microsecond: 0,
      // ),
    );
  }
}
