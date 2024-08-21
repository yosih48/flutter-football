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

void main() async {
  // Ensure that plugin services are initialized
  WidgetsFlutterBinding.ensureInitialized();
  Workmanager().initialize(
    NotificationManager.callbackDispatcher,
    isInDebugMode: true,
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


