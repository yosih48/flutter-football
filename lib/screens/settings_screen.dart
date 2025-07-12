import 'package:flutter/material.dart';
import 'package:football/providers/LocaleProvider.dart';
import 'package:football/providers/theme_provider.dart';
import 'package:football/screens/account_screen.dart';
import 'package:football/screens/instructionsb.dart';
import 'package:football/theme/colors.dart';
import 'package:provider/provider.dart';
import 'package:football/resources/auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

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
                color: theme.colorScheme.onPrimary,
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
                    color: theme.shadowColor.withOpacity(0.05),
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
                    text: AppLocalizations.of(context)!.settings_account,
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
                    text: AppLocalizations.of(context)!.settings_rules,
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
                  _languageSettingsTile(context),
                  _ThemeSettingsTile(context),
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

Widget _ThemeSettingsTile(BuildContext context) {
  final theme = Theme.of(context);
  return Consumer<ThemeProvider>(
    builder: (context, themeProvider, _) {
      return ListTile(
        leading: Icon(
          themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
          color: theme.colorScheme.primary,
        ),
        title: Text(
          AppLocalizations.of(context)!.settings_theme,
          style: theme.textTheme.bodyText1,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: themeProvider.isDarkMode,
              onChanged: (value) {
                themeProvider.toggleTheme();
              },
              activeColor: theme.colorScheme.primary,
            ),
          ],
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        shape: Border(
          bottom: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
        ),
      );
    },
  );
}

// Language settings tile with toggle buttons
Widget _languageSettingsTile(BuildContext context) {
  final theme = Theme.of(context);

  return Consumer<LocaleProvider>(
    builder: (context, localeProvider, child) {
      return ListTile(
        leading: Icon(Icons.language, color: theme.colorScheme.secondary),
        title: Text(
          AppLocalizations.of(context)!.settings_language,
          style: theme.textTheme.bodyText1,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // English button
            ElevatedButton(
              onPressed: () {
                context.read<LocaleProvider>().setLocale(Locale('en'));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: localeProvider.locale.languageCode == 'en'
                    ? theme.colorScheme.primary
                    : theme.colorScheme.primary.withOpacity(0.1),
                foregroundColor: localeProvider.locale.languageCode == 'en'
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.primary,
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size(0, 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Text(
                AppLocalizations.of(context)!.settings_eng,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(width: 8),
            // Hebrew button
            ElevatedButton(
              onPressed: () {
                context.read<LocaleProvider>().setLocale(Locale('he'));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: localeProvider.locale.languageCode == 'he'
                    ? theme.colorScheme.primary
                    : theme.colorScheme.primary.withOpacity(0.1),
                foregroundColor: localeProvider.locale.languageCode == 'he'
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.primary,
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size(0, 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Text(
                AppLocalizations.of(context)!.settings_heb,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        shape: Border(
          bottom: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
        ),
      );
    },
  );
}
