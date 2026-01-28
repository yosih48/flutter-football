import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:football/utils/config.dart';
import 'package:package_info_plus/package_info_plus.dart';

class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;

  // הנה הגיבוי! זה הערך שיהיה עד שפיירבייס יתעורר
  // שים פה את הכתובת הנוכחית שעובדת (Render Proxy או VPS)
  String apiUrl = 'https://scorecast.yossih.dev/';

  Future<void> initialize() async {
    try {
      await _remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(minutes: 1), // שים 0 לפיתוח!
      ));

      // מגדירים גם פה דיפולט ליתר ביטחון
      await _remoteConfig.setDefaults(<String, dynamic>{
     'api_url': 'https://scorecast.yossih.dev/',
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


  // הפונקציה שבודקת אם צריך לבעוט את המשתמש לחנות
  Future<bool> isUpdateRequired() async {
    try {
      // 1. מה הגרסה שקבענו ב-Firebase שהיא המינימום?
      String minVersion = _remoteConfig.getString('min_required_version');
      if (minVersion.isEmpty) {
        print('⚠️ Remote Config: min_required_version is empty.');
        return false; 
      }

      // 2. מה הגרסה שיש למשתמש כרגע על המכשיר?
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;

      print(
          '🧐 Checking version: Current=$currentVersion (Raw: ${packageInfo.version}+${packageInfo.buildNumber}) vs Min Required=$minVersion');

      // 3. השוואה מתמטית (ולא סתם טקסט)
      bool updateNeeded = _compareVersions(currentVersion, minVersion) < 0;
      print('👉 Update Required: $updateNeeded');
      return updateNeeded;
    } catch (e) {
      print('⚠️ Failed to check version: $e');
      return false; // במקרה של תקלה, לא נחסום את המשתמש
    }
  }

  // פונקציית עזר להשוואת גרסאות (מחזירה -1 אם current קטן מ-min)
  int _compareVersions(String current, String min) {
    // ניקוי תווים מיותרים (כמו build number אחרי +)
    String cleanVersion(String v) => v.split('+').first.trim();

    List<int> parseVersion(String v) {
      return cleanVersion(v)
          .split('.')
          .map((part) => int.tryParse(part) ?? 0) // אם יש משהו לא מספר, נחליף ב-0
          .toList();
    }

    List<int> cParts = parseVersion(current);
    List<int> mParts = parseVersion(min);

    // משווים חלק חלק (Major, Minor, Patch)
    for (int i = 0; i < 3; i++) {
      int c = (i < cParts.length) ? cParts[i] : 0;
      int m = (i < mParts.length) ? mParts[i] : 0;
      if (c < m) return -1; // הגרסה הנוכחית קטנה יותר -> חייב עדכון!
      if (c > m) return 1; // הגרסה הנוכחית גדולה יותר -> הכל טוב
    }
    return 0; // גרסאות זהות
  }


// האם המצב פעיל?
  bool get isMaintenanceMode => _remoteConfig.getBool('is_maintenance_active');

  // איזה הודעה להציג?
  String get maintenanceMessage =>
      _remoteConfig.getString('maintenance_message');









}
