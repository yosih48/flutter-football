
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
import 'package:provider/provider.dart';


void main() =>   runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        // Other providers...
      ],
      child: GameApp(),
    ),
  );

class GameApp extends StatelessWidget {
   const GameApp({super.key});
  @override
  Widget build(BuildContext context) {
   return MaterialApp(
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
              }else if (snapshot.hasError) {
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


