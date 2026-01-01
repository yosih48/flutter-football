import 'package:flutter/cupertino.dart';
import 'package:football/resources/remote_config_service.dart';
import 'package:football/utils/utils.dart';

class VersionGuard extends StatefulWidget {
  final Widget child;
  const VersionGuard({super.key, required this.child});

  @override
  State<VersionGuard> createState() => _VersionGuardState();
}

class _VersionGuardState extends State<VersionGuard> {
  @override
  void initState() {
    super.initState();
    // מריצים את הבדיקה מיד כשה-Widget עולה
    // משתמשים ב-addPostFrameCallback כדי לוודא שיש Context מוכן לדיאלוג
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVersion();
    });
  }

  Future<void> _checkVersion() async {
    // 1. קריאה לשירות שיצרנו קודם
    bool mustUpdate = await RemoteConfigService().isUpdateRequired();

    // 2. אם צריך עדכון וה-Widget עדיין קיים
    if (mustUpdate && mounted) {
      print('🚨 Showing Force Update Dialog!');
      // 3. הקפצת הדיאלוג החוסם שיצרנו בשלב הקודם
      showForceUpdateDialog(context);
    } else {
      print('✅ Version is OK or widget unmounted.');
    }
  }

  @override
  Widget build(BuildContext context) {
    // מציג את האפליקציה הרגילה בינתיים
    // (הדיאלוג יקפוץ מעליה אם צריך)
    return widget.child;
  }
}
