import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:football/models/games.dart';
import 'package:football/models/users.dart';
import 'package:football/providers/LocaleProvider.dart';
import 'package:football/providers/flutter%20pub%20add%20provider.dart';
import 'package:football/providers/league_data_provider.dart';
import 'package:football/providers/theme_provider.dart';
import 'package:football/resources/appUpdates.dart';
import 'package:football/resources/auth.dart';
import 'package:football/resources/firebase_messaging_service.dart';
import 'package:football/resources/gamesMethods.dart';
import 'package:football/resources/league_config_service.dart';
import 'package:football/resources/rate_app_service.dart';
import 'package:football/resources/player_names_config_service.dart';
import 'package:football/resources/remote_config_service.dart';
import 'package:football/resources/stat_labels_config_service.dart';
import 'package:football/resources/team_names_config_service.dart';
import 'package:football/utils/player_names_he.dart';
import 'package:football/responsive/mobile_screen_layout.dart';
import 'package:football/responsive/rsponsive_layout_screen.dart';
import 'package:football/responsive/web_screen_layout.dart';
import 'package:football/screens/competitions.dart';
import 'package:football/screens/gameDetails.dart';
import 'package:football/screens/games.dart';
import 'package:football/screens/login_screen.dart';
import 'package:football/screens/profile.dart';
import 'package:football/screens/table.dart';
import 'package:football/theme/colors.dart';
import 'package:football/widgets/VersionGuard.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();





void main() async {
  // Ensure that plugin services are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase must be initialized BEFORE AuthProvider, because AuthProvider's
  // refreshUser() resolves the backend URL via RemoteConfigService, whose
  // singleton constructor reads FirebaseRemoteConfig.instance.
  await Firebase.initializeApp();
  await RemoteConfigService().initialize();
  // Must run after RemoteConfigService — it resolves backendUrl.
  await LeagueConfigService().initialize();
  // Hebrew team-name overrides from the backend (same source as the compiled
  // baseline in localized_team_name.dart). Also needs backendUrl resolved.
  await TeamNamesConfigService().initialize();
  // Hebrew fixture-stat-label overrides (baseline in localized_stat_label.dart).
  await StatLabelsConfigService().initialize();
  await FirebaseMessagingService.initialize();
  // Curated Hebrew player names (bundled asset) — loaded once so lineup/event
  // names resolve on first frame; falls back to transliteration if absent.
  await PlayerNamesHe.load();
  // Backend player-name overrides on top of the bundled asset (same source as
  // notification copy). Needs backendUrl resolved and load() run first.
  await PlayerNamesConfigService().initialize();

  // Cheap, no network — bumps the launch counter that gates the rate-app prompt.
  await RateAppService().recordLaunch();

  final authProvider = AuthProvider();
  await authProvider.initializeApp();
  // You can now use the storage in your AuthProvider if needed
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(
          value: authProvider,
        ),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => LeagueDataProvider()),
      ],
      child: GameApp(),
    ),
  );
}

class GameApp extends StatelessWidget {
  const GameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, LocaleProvider>(
      builder: (context, themeProvider, localeProvider, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          theme: themeProvider.themeData,
          locale: localeProvider.locale,
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
            Locale('he'), // Hebrew
          ],
          // --- THE MAGIC HAPPENS HERE ---
          // I wrapped the entire Auth Consumer with the VersionGuard.
          // This ensures the version check happens regardless of the user's login state.
          home: VersionGuard(
            child: Consumer<AuthProvider>(
              builder: (context, authProvider, _) {
                if (authProvider.isInitializing) {
                  print('main isInitializing');
                  print(authProvider.isInitializing);
                  return Scaffold(
                      body: Center(child: CircularProgressIndicator()));
                }
                if (authProvider.currentUser != null) {
                  // User is logged in, check if it's first login
                  if (authProvider.currentUser!.isFirstLogin) {
                    return Competitions(
                      userEmail: authProvider.currentUser!.email,
                      userName: authProvider.currentUser!.name,
                    );
                  }
                  return MobileScreenLayout();
                }

                return LoginScreen();
              },
            ),
          ),
          // ------------------------------
          routes: {
            '/game_details': (context) => GamesScreen(),
            '/games': (context) => GamesScreen(),
            '/table': (context) => TableScreen(),
            '/profile': (context) => ProfileScreen(),
            '/login': (context) => LoginScreen(),
          },
        );
      },
    );
  }
}

 