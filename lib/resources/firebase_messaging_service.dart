import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:football/main.dart';
import 'package:football/models/games.dart';
import 'package:football/resources/gamesMethods.dart';
import 'package:football/screens/gameDetails.dart';
import 'package:url_launcher/url_launcher.dart';

class FirebaseMessagingService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Dynamic notification action handler
  static Future<void> _handleDynamicNotificationAction(Map<String, dynamic> data) async {
    print('Handling dynamic notification with data: $data');
    
    final String? actionType = data['action_type'];
    final String? screen = data['screen'];
    
    switch (actionType) {
      case 'navigate':
        
        await _handleNavigationAction(data);
        break;
      case 'external_url':
        await _handleExternalUrlAction(data);
        break;
      case 'custom_action':
        await _handleCustomAction(data);
        break;
      default:
        // Fallback to legacy handling for backward compatibility
        await _handleLegacyNotificationAction(data);
        break;
    }
  }

  static Future<void> _handleNavigationAction(Map<String, dynamic> data) async {
    final String? routeName = data['route_name'];
    final String? routeParamsString = data['route_params'];
    final bool clearStack = data['clear_stack'] != null ? data['clear_stack'] : true; // Default to clearing stack

    Map<String, dynamic>? routeParams;
    if (routeParamsString != null) {
      try {
        routeParams = json.decode(routeParamsString);
      } catch (e) {
        print('Error parsing route_params: $e');
        routeParams = {};
      }
    }

    if (routeName != null) {
      print('Navigating to route: $routeName with params: $routeParams, clearStack: $clearStack');
      
      // Handle parameterized routes
      switch (routeName) {
        case '/game_details':
          if (routeParams != null) {
            await _navigateToGameDetailsFromNotification(routeParams, clearStack);
          } else {
            if (clearStack) {
              navigatorKey.currentState?.pushNamedAndRemoveUntil('/game_details', (route) => false);
            } else {
              navigatorKey.currentState?.pushNamed('/game_details');
            }
          }
          break;
        case '/games':
          if (clearStack) {
            navigatorKey.currentState?.pushNamedAndRemoveUntil('/games', (route) => false, arguments: routeParams);
          } else {
            navigatorKey.currentState?.pushNamed('/games', arguments: routeParams);
          }
          break;
        case '/profile':
          if (clearStack) {
            navigatorKey.currentState?.pushNamedAndRemoveUntil('/profile', (route) => false);
          } else {
            navigatorKey.currentState?.pushNamed('/profile');
          }
          break;
        case '/leaderboard':
          if (clearStack) {
            navigatorKey.currentState?.pushNamedAndRemoveUntil('/leaderboard', (route) => false);
          } else {
            navigatorKey.currentState?.pushNamed('/leaderboard');
          }
          break;
        case '/settings':
          if (clearStack) {
            navigatorKey.currentState?.pushNamedAndRemoveUntil('/settings', (route) => false);
          } else {
            navigatorKey.currentState?.pushNamed('/settings');
          }
          break;
        case '/table':
          if (clearStack) {
            navigatorKey.currentState?.pushNamedAndRemoveUntil('/table', (route) => false);
          } else {
            navigatorKey.currentState?.pushNamed('/table');
          }
          break;
        default:
          // Try to navigate to the route directly
          try {
            if (clearStack) {
              navigatorKey.currentState?.pushNamedAndRemoveUntil(routeName, (route) => false, arguments: routeParams);
            } else {
              navigatorKey.currentState?.pushNamed(routeName, arguments: routeParams);
            }
          } catch (e) {
            print('Failed to navigate to route $routeName: $e');
          }
          break;
      }
    }
  }

  static Future<void> _handleExternalUrlAction(Map<String, dynamic> data) async {
    final String? url = data['url'];
    if (url != null) {
      print('Opening external URL: $url');
      try {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          print('Cannot launch URL: $url');
        }
      } catch (e) {
        print('Error launching URL: $e');
      }
    }
  }

  static Future<void> _handleCustomAction(Map<String, dynamic> data) async {
    final String? actionName = data['action_name'];
    final Map<String, dynamic>? actionData = data['action_data'] != null 
        ? Map<String, dynamic>.from(data['action_data']) 
        : null;

    print('Executing custom action: $actionName with data: $actionData');
    
    // You can extend this with more custom actions as needed
    switch (actionName) {
      case 'show_dialog':
        _showCustomDialog(actionData);
        break;
      case 'show_snackbar':
        _showCustomSnackbar(actionData);
        break;
      case 'refresh_data':
        _refreshAppData(actionData);
        break;
      default:
        print('Unknown custom action: $actionName');
        break;
    }
  }

  static void _showCustomDialog(Map<String, dynamic>? data) {
    if (data != null && navigatorKey.currentContext != null) {
      showDialog(
        context: navigatorKey.currentContext!,
        builder: (context) => AlertDialog(
          title: Text(data['title'] ?? 'Notification'),
          content: Text(data['message'] ?? ''),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  static void _showCustomSnackbar(Map<String, dynamic>? data) {
    if (data != null && navigatorKey.currentContext != null) {
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        SnackBar(
          content: Text(data['message'] ?? 'Notification'),
          backgroundColor: data['color'] != null ? Color(int.parse(data['color'])) : null,
          duration: Duration(seconds: data['duration'] ?? 3),
        ),
      );
    }
  }

  static void _refreshAppData(Map<String, dynamic>? data) {
    // You can implement app-wide data refresh logic here
    print('Refreshing app data with params: $data');
    // For example: trigger a provider refresh, reload games, etc.
  }

  static Future<void> _navigateToGameDetails(Map<String, dynamic> params) async {
    await _navigateToGameDetailsFromNotification(params, false);
  }

  static Future<void> _navigateToGameDetailsFromNotification(Map<String, dynamic> params, bool clearStack) async {
    try {
      int gameId = int.parse(params['gameId'].toString());
      int leagueId = int.parse(params['league'].toString());
      String? userId = params['userId']?.toString();

      print('Fetching games for league: $leagueId');
      List<Game> fetchedGames = await _fetchGames(leagueId);
      
      Game? game = fetchedGames.firstWhere(
        (g) => g.fixtureId == gameId,
        orElse: () => throw Exception('Game not found'),
      );
      
      int initialIndex = fetchedGames.indexWhere((g) => g.fixtureId == gameId);
      if (initialIndex == -1) {
        throw Exception('Game not found in fetched games list');
      }

      final route = MaterialPageRoute(
        builder: (context) => GameDetails(
          gameOriginalId: gameId,
          game: game,
          games: fetchedGames,
          initialIndex: initialIndex,
          userId: userId ?? '',
        ),
      );

      if (clearStack) {
        navigatorKey.currentState?.pushAndRemoveUntil(route, (route) => false);
      } else {
        navigatorKey.currentState?.push(route);
      }
    } catch (e) {
      print('Error navigating to game details: $e');
    }
  }

  // Legacy handler for backward compatibility
  static Future<void> _handleLegacyNotificationAction(Map<String, dynamic> data) async {
    final String? screen = data['screen'];
    
    switch (screen) {
      case 'game_points_details':
        await handleNotificationNavigation(data);
        break;
      case 'game_details':
        print('Navigating to games screen');
        navigatorKey.currentState?.pushNamed('/game_details');
        break;
      default:
        print('Unknown legacy screen type: $screen');
        break;
    }
  }

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
          print("Notification data: $data");
          _handleDynamicNotificationAction(data);
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
    
    // Use the new dynamic handler
    _handleDynamicNotificationAction(message.data);
  }

  static Future<void> handleNotificationNavigation(Map<String, dynamic> data) async {
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
        
        // Find the index of the current game in the fetched games list
        int initialIndex = fetchedGames.indexWhere((g) => g.fixtureId == gameId);
        if (initialIndex == -1) {
          throw Exception('Game not found in fetched games list');
        }

        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => GameDetails(
              gameOriginalId: gameId,
              game: game,
              games: fetchedGames,
              initialIndex: initialIndex,
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
