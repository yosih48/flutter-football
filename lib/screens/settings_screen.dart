import 'package:flutter/material.dart';
import 'package:football/screens/account_screen.dart';
import 'package:football/screens/instructionsb.dart';
import 'package:provider/provider.dart';
import 'package:football/resources/auth.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsScreen extends StatefulWidget {
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      appVersion = info.version;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = Provider.of<AuthProvider>(context).currentUser;
    final userName = user?.name ?? 'User Name';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          SizedBox(height: 40),
          CircleAvatar(
            radius: 48,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.7),
            child: Text(
              userName.isNotEmpty ? userName[0] : '',
              style: TextStyle(
                fontSize: 48,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: 16),
          Text(
            userName,
            style: theme.textTheme.headline6
                ?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'v$appVersion',
            style: theme.textTheme.caption,
          ),
          SizedBox(height: 24),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: ListView(
                padding: EdgeInsets.symmetric(vertical: 16),
                children: [
                  _settingsTile(
                    context,
                    icon: Icons.person,
                    text: 'חשבון',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AccountScreen(),
                        ),
                      );

                    },
                  ),
                  // _settingsTile(
                  //   context,
                  //   icon: Icons.list_alt,
                  //   text: 'תוצאות ברירת מחדל',
                  //   onTap: () {},
                  // ),
                  _settingsTile(
                    context,
                    icon: Icons.info_outline,
                    text: 'חוקי המשחק',
                    onTap: () {
                      showInstructionsBottomSheet(context);
                    },
                  ),
                  // _settingsTile(
                  //   context,
                  //   icon: Icons.chat_bubble_outline,
                  //   text: 'תמיכה',
                  //   onTap: () {},
                  // ),
                  // _settingsTile(
                  //   context,
                  //   icon: Icons.lock_outline,
                  //   text: 'מדיניות פרטיות',
                  //   onTap: () {},
                  // ),
                  // _settingsTile(
                  //   context,
                  //   icon: Icons.logout,
                  //   text: 'התנתקות',
                  //   onTap: () {},
                  // ),
                ],
              ),
            ),
          ),
        ],
      ),
      // Add your bottom navigation bar here if needed
    );
  }

  Widget _settingsTile(BuildContext context,
      {required IconData icon,
      required String text,
      required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.secondary),
      title: Text(
        text,
        style: theme.textTheme.bodyText1,
      ),
      trailing: Icon(Icons.chevron_left, color: theme.colorScheme.secondary),
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      shape: Border(
        bottom: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
      ),
    );
  }
}
