import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:football/models/users.dart';
import 'package:football/providers/flutter%20pub%20add%20provider.dart';
import 'package:football/resources/auth.dart';
import 'package:football/responsive/mobile_screen_layout.dart';
import 'package:football/responsive/rsponsive_layout_screen.dart';
import 'package:football/responsive/web_screen_layout.dart';
import 'package:football/screens/games.dart';
import 'package:football/screens/login_screen.dart';
import 'package:football/widgets/pushNotifications.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() async {
  // Ensure that plugin services are initialized
  WidgetsFlutterBinding.ensureInitialized();
   print('Initializing Workmanager');
  Workmanager().initialize(
    // NotificationManager.callbackDispatcher,
      callbackDispatcher,
       isInDebugMode: true
  );
  
   print('Workmanager initialized');
   Workmanager().registerPeriodicTask(
    "2",
     
    //This is the value that will be
    // returned in the callbackDispatcher
    "simplePeriodicTask",
     
    // When no frequency is provided
    // the default 15 minutes is set.
    // Minimum frequency is 15 min.
    // Android will automatically change
    // your frequency to 15 min
    // if you have configured a lower frequency.
    frequency: Duration(minutes: 15),
  );
  // Initialize flutter_secure_storage
  final storage = FlutterSecureStorage();
  await Firebase.initializeApp();
  // You can now use the storage in your AuthProvider if needed
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: GameApp(),
    ),
  );
}
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) {
     
    // initialise the plugin of flutterlocalnotifications.
    FlutterLocalNotificationsPlugin flip = new FlutterLocalNotificationsPlugin();
     
    // app_icon needs to be a added as a drawable
    // resource to the Android head project.
    var android = new AndroidInitializationSettings('@mipmap/ic_launcher');
  
     
    // initialise settings for both Android and iOS device.
    var settings = new InitializationSettings(android: android);
    flip.initialize(settings);
    _showNotificationWithDefaultSound(flip);
    return Future.value(true);
  });
}
Future _showNotificationWithDefaultSound(flip) async {
   
  // Show a notification after every 15 minute with the first
  // appearance happening a minute after invoking the method
  // ignore: prefer_const_constructors
  var androidPlatformChannelSpecifics = new AndroidNotificationDetails(
      'your channel id',
      'your channel name',
      // 'your channel description',
      importance: Importance.max,
      priority: Priority.high
  );
  // var iOSPlatformChannelSpecifics = new IOSNotificationDetails();
   
  // initialise channel platform for both Android and iOS device.
  var platformChannelSpecifics = new NotificationDetails(
      android: androidPlatformChannelSpecifics,
      // iOSPlatformChannelSpecifics
  );
  await flip.show(0, 'GeeksforGeeks',
    'Your are one step away to connect with GeeksforGeeks',
    platformChannelSpecifics, payload: 'Default_Sound'
  );
}
class GameApp extends StatelessWidget {
   const GameApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
          return StreamBuilder<User?>(
            stream: authProvider.authStateChanges(),
            builder: (context, snapshot) {
              if (authProvider.isLoading) {
                print('is Loading');
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasData) {
                print('hasData');
                return const ResponsiveLayout(
                  mobileScreenLayout: MobileScreenLayout(),
                  webScreenLayout: WebScreenLayout(),
                );
              } else if (snapshot.hasError) {
                print('haserror');
                return Center(
                  child: Text('${snapshot.error}'),
                );
              }
              print('nothing');
              return const LoginScreen();
            },
          );
        },
      ),
    );
  }
}


