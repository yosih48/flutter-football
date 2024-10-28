import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:football/models/games.dart';
import 'package:football/models/users.dart';
import 'package:football/providers/flutter%20pub%20add%20provider.dart';
import 'package:football/resources/appUpdates.dart';
import 'package:football/resources/auth.dart';
import 'package:football/resources/firebase_messaging_service.dart';
import 'package:football/resources/gamesMethods.dart';
import 'package:football/responsive/mobile_screen_layout.dart';
import 'package:football/responsive/rsponsive_layout_screen.dart';
import 'package:football/responsive/web_screen_layout.dart';
import 'package:football/screens/gameDetails.dart';
import 'package:football/screens/games.dart';
import 'package:football/screens/login_screen.dart';
import 'package:football/screens/profile.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Don't call Firebase.initializeApp() here
  print("Handling a background message: ${message.messageId}");
}

Future<void> setupFirebaseMessaging() async {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: null,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      flutterLocalNotificationsPlugin.show(
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
      );
    }
  });
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('A new onMessageOpenedApp event was published!');
    _handleMessage(message);
  });

  // Add this: Check if the app was opened from a notification when it was terminated
  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    if (message != null) {
      print('App opened from terminated state');
      _handleMessage(message);
    }
  });
}

void _handleMessage(RemoteMessage message) {
  if (message.data['screen'] == 'game_details') {
    navigatorKey.currentState?.pushNamed('/game_details');
  }
}

Future<List<Game>> _fetchGames(int league) async {
  return await GamesMethods().fetchGamesForLeague(
    league,
    selectedDate: DateTime.now().copyWith(
        hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0),
  );
}












void handleNotificationNavigation(Map<String, dynamic> data) async {
  print('handleNotificationNavigation');
  print(data);
  if (data['screen'] == 'game_points_details') {
    int gameId = int.parse(data['gameId']);
    int leagueId = int.parse(data['league']);
     print(data['league']);
     print(data['gameId']);
     print(data['userId']);
     print(data['screen']);
    // Fetch the list of games for the league
    List<Game> fetchedGames = await _fetchGames(leagueId);
    // Create a Game object from the notification data
    // Find the specific game by ID
    Game? game = fetchedGames.firstWhere(
      (g) => g.fixtureId == gameId,
    );

    // Navigate to GameDetails screen
    Navigator.of(navigatorKey.currentContext!).push(
      MaterialPageRoute(
        builder: (context) => GameDetails(
          gameOriginalId: int.parse(data['gameId']),
          game: game,
          userId: data['userId'],
        ),
      ),
    );
  }
}

void main() async {
  // Ensure that plugin services are initialized
  WidgetsFlutterBinding.ensureInitialized();

  final authProvider = AuthProvider();
  await authProvider.initializeApp();

  final storage = FlutterSecureStorage();

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(
    _firebaseMessagingBackgroundHandler,
  );
  await FirebaseMessagingService.initialize();
  // You can now use the storage in your AuthProvider if needed
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(
          value: authProvider,
        ),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: GameApp(),
    ),
  );
}

class GameApp extends StatelessWidget {
  const GameApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      theme: ThemeData(
        primarySwatch: Colors.blue, // Sets the primary color to blue
        textTheme: TextTheme(
            // bodyText1: TextStyle(color: Colors.blue), // Default text color
            // bodyText2: TextStyle(color: Colors.blue), // Another text style

            ),
        progressIndicatorTheme: ProgressIndicatorThemeData(
          color: Colors.blue, // Default color for CircularProgressIndicator
        ),
      ),
      debugShowCheckedModeBanner: false,
      title: 'Localizations Sample App',
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        Locale('en'), // English
        Locale('he'), // hebrew refreshUser
      ],
      home: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          if (authProvider.isInitializing) {
            print('main isInitializing');
            print(authProvider.isInitializing);
            return Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return authProvider.currentUser != null
              ? MobileScreenLayout()
              : LoginScreen();
        },
      ),
      routes: {
        '/game_details': (context) => GamesScreen(),
      },
    );
  }
}
