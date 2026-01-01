import 'package:firebase_remote_config/firebase_remote_config.dart';

class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  // הנה הגיבוי! זה הערך שיהיה עד שפיירבייס יתעורר
  // שים פה את הכתובת הנוכחית שעובדת (Render Proxy או VPS)
  String apiUrl = 'https://leagues.onrender.com';

  Future<void> initialize() async {
    try {
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(minutes: 1), // שים 0 לפיתוח!
      ));

      // מגדירים גם פה דיפולט ליתר ביטחון
      await _remoteConfig.setDefaults(<String, dynamic>{
        'api_url': 'https://leagues.onrender.com',
      });

      await _remoteConfig.fetchAndActivate();

      String newUrl = _remoteConfig.getString('api_url');
      if (newUrl.isNotEmpty && newUrl.startsWith('http')) {
        apiUrl = newUrl; // מעדכנים את המשתנה הראשי
        print('🔥 Config Updated: $apiUrl');
      }
    } catch (e) {
      print('Unable to fetch remote config. Using default: $apiUrl');
    }
  }
}
