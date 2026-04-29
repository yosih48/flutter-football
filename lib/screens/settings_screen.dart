import 'package:flutter/material.dart';
import 'package:football/providers/LocaleProvider.dart';
import 'package:football/providers/theme_provider.dart';
import 'package:football/screens/account_screen.dart';
import 'package:football/screens/instructionsb.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:provider/provider.dart';
import 'package:football/resources/auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:football/l10n/app_localizations.dart';

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
    if (mounted) setState(() => appVersion = info.version);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final user = Provider.of<AuthProvider>(context).currentUser;
    final userName = user?.name ?? '';
    final userEmail = user?.email ?? '';
    final initial =
        userName.isNotEmpty ? userName[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: Editorial.pitch,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('APP',
                      style: EType.label(
                          color: Editorial.inkDim,
                          size: 10,
                          letterSpacing: 3)),
                  const SizedBox(height: 2),
                  Text(l.settings.toUpperCase(),
                      style: EType.display(
                          size: 28,
                          color: Editorial.ink,
                          letterSpacing: 1.4)),
                ],
              ),
            ),

            // ── Identity card ─────────────────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Editorial.card,
                border: Border(
                  top: BorderSide(color: Editorial.live, width: 2),
                  left: BorderSide(color: Editorial.hairline, width: 1),
                  right: BorderSide(color: Editorial.hairline, width: 1),
                  bottom: BorderSide(color: Editorial.hairline, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Editorial.cardHi,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Editorial.live, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: EType.display(
                          size: 28,
                          color: Editorial.ink,
                          letterSpacing: 0),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName.isNotEmpty
                              ? userName.toUpperCase()
                              : '—',
                          overflow: TextOverflow.ellipsis,
                          style: EType.display(
                              size: 20,
                              color: Editorial.ink,
                              letterSpacing: 0.8),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userEmail,
                          overflow: TextOverflow.ellipsis,
                          style: EType.body(
                              color: Editorial.inkMute, size: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Menu list ─────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  _sectionLabel('ACCOUNT'),
                  const SizedBox(height: 12),

                  _SettingsRow(
                    icon: Icons.person_outline,
                    label: l.settings_account,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => AccountScreen()),
                    ),
                  ),

                  const SizedBox(height: 20),
                  _sectionLabel('APP'),
                  const SizedBox(height: 12),

                  _SettingsRow(
                    icon: Icons.info_outline,
                    label: l.settings_rules,
                    onTap: () => showInstructionsBottomSheet(context),
                  ),

                  const SizedBox(height: 8),

                  // Language row — inline editorial toggle
                  _LanguageRow(l: l),

                  const SizedBox(height: 32),

                  // Version stamp
                  if (appVersion.isNotEmpty)
                    Center(
                      child: Text(
                        'v$appVersion',
                        style: EType.label(
                            color: Editorial.inkFaint,
                            size: 10,
                            letterSpacing: 1.6),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Row(
      children: [
        Container(width: 18, height: 1, color: Editorial.live),
        const SizedBox(width: 10),
        Text(text,
            style: EType.label(
                color: Editorial.inkMute, size: 10, letterSpacing: 2.4)),
      ],
    );
  }
}

// ── Settings row ────────────────────────────────────────────────────────
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Editorial.card,
      borderRadius: BorderRadius.circular(2),
      child: InkWell(
        borderRadius: BorderRadius.circular(2),
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Editorial.hairline, width: 1),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Editorial.terrace,
                  borderRadius: BorderRadius.circular(2),
                  border:
                      Border.all(color: Editorial.hairline, width: 1),
                ),
                child:
                    Icon(icon, size: 16, color: Editorial.inkMute),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: EType.label(
                      color: Editorial.ink,
                      size: 11,
                      letterSpacing: 1.8),
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  size: 12, color: Editorial.inkDim),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Language row ────────────────────────────────────────────────────────
class _LanguageRow extends StatelessWidget {
  const _LanguageRow({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, _) {
        final isEn = localeProvider.locale.languageCode == 'en';
        return Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Editorial.card,
            border: Border.all(color: Editorial.hairline, width: 1),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Editorial.terrace,
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                      color: Editorial.hairline, width: 1),
                ),
                child: Icon(Icons.language_outlined,
                    size: 16, color: Editorial.inkMute),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  l.settings_language.toUpperCase(),
                  style: EType.label(
                      color: Editorial.ink,
                      size: 11,
                      letterSpacing: 1.8),
                ),
              ),
              // Segmented language toggle
              Container(
                decoration: BoxDecoration(
                  color: Editorial.terrace,
                  border:
                      Border.all(color: Editorial.hairline, width: 1),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LangChip(
                      code: l.settings_eng,
                      active: isEn,
                      onTap: () => context
                          .read<LocaleProvider>()
                          .setLocale(const Locale('en')),
                      roundLeft: true,
                    ),
                    Container(
                        width: 1,
                        height: 28,
                        color: Editorial.hairline),
                    _LangChip(
                      code: l.settings_heb,
                      active: !isEn,
                      onTap: () => context
                          .read<LocaleProvider>()
                          .setLocale(const Locale('he')),
                      roundRight: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip({
    required this.code,
    required this.active,
    required this.onTap,
    this.roundLeft = false,
    this.roundRight = false,
  });
  final String code;
  final bool active;
  final VoidCallback onTap;
  final bool roundLeft;
  final bool roundRight;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Editorial.live : Colors.transparent,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(roundLeft ? 2 : 0),
            bottomLeft: Radius.circular(roundLeft ? 2 : 0),
            topRight: Radius.circular(roundRight ? 2 : 0),
            bottomRight: Radius.circular(roundRight ? 2 : 0),
          ),
        ),
        child: Text(
          code.toUpperCase(),
          style: EType.label(
            color: active ? Editorial.pitch : Editorial.inkMute,
            size: 11,
            letterSpacing: 1.6,
          ),
        ),
      ),
    );
  }
}
