import 'package:flutter/material.dart';
import 'package:football/providers/LocaleProvider.dart';
import 'package:football/providers/theme_provider.dart';
import 'package:football/screens/account_screen.dart';
import 'package:football/screens/instructionsb.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:football/l10n/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

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
    // All color references go through `c` — the only change needed when
    // migrating a screen to support both light and dark mode.
    final c = context.col;
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: c.pitch,
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
                          color: c.inkDim,
                          size: 10,
                          letterSpacing: 3)),
                  const SizedBox(height: 2),
                  Text(l.settings.toUpperCase(),
                      style: EType.display(
                          size: 28,
                          color: c.ink,
                          letterSpacing: 1.4)),
                ],
              ),
            ),

            // ── Menu list ─────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  _sectionLabel('ACCOUNT', c),
                  const SizedBox(height: 12),

                  _SettingsRow(
                    icon: Icons.person_outline,
                    label: l.settings_account,
                    c: c,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AccountScreen()),
                    ),
                  ),

                  const SizedBox(height: 20),
                  _sectionLabel('APP', c),
                  const SizedBox(height: 12),

                  _SettingsRow(
                    icon: Icons.info_outline,
                    label: l.settings_rules,
                    c: c,
                    onTap: () =>
                        showInstructionsBottomSheet(context),
                  ),

                  const SizedBox(height: 8),

                  // Theme toggle — DARK / LIGHT
                  _ThemeRow(l: l, c: c),

                  const SizedBox(height: 8),

                  // Language toggle — ENG / HEB
                  _LanguageRow(l: l, c: c),

                  const SizedBox(height: 32),

                  // Version stamp
                  if (appVersion.isNotEmpty)
                    Center(
                      child: Text(
                        'v$appVersion',
                        style: EType.label(
                            color: c.inkFaint,
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

  Widget _sectionLabel(String text, EditorialColors c) {
    return Row(
      children: [
        Container(width: 18, height: 1, color: c.live),
        const SizedBox(width: 10),
        Text(text,
            style: EType.label(
                color: c.inkMute, size: 10, letterSpacing: 2.4)),
      ],
    );
  }
}

// ── Settings row ─────────────────────────────────────────────────────────
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.c,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final EditorialColors c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: c.card,
          border: Border.all(color: c.hairline, width: 1),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: c.terrace,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: c.hairline, width: 1),
              ),
              child: Icon(icon, size: 16, color: c.inkMute),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: EType.label(
                    color: c.ink, size: 11, letterSpacing: 1.8),
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 12, color: c.inkDim),
          ],
        ),
      ),
    );
  }
}

// ── Theme row — DARK / LIGHT segmented toggle ─────────────────────────────
class _ThemeRow extends StatelessWidget {
  const _ThemeRow({required this.l, required this.c});
  final AppLocalizations l;
  final EditorialColors c;

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final isDark = themeProvider.isDarkMode;
        return Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: c.card,
            border: Border.all(color: c.hairline, width: 1),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: c.terrace,
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: c.hairline, width: 1),
                ),
                child: Icon(
                  isDark
                      ? Icons.dark_mode_outlined
                      : Icons.light_mode_outlined,
                  size: 16,
                  color: c.inkMute,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  l.settings_theme.toUpperCase(),
                  style: EType.label(
                      color: c.ink, size: 11, letterSpacing: 1.8),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: c.terrace,
                  border: Border.all(color: c.hairline, width: 1),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ModeChip(
                      label: l.settings_dark,
                      active: isDark,
                      c: c,
                      roundLeft: true,
                      onTap: () {
                        if (!isDark) themeProvider.setDarkMode(true);
                      },
                    ),
                    Container(
                        width: 1, height: 28, color: c.hairline),
                    _ModeChip(
                      label: l.settings_light,
                      active: !isDark,
                      c: c,
                      roundRight: true,
                      onTap: () {
                        if (isDark) themeProvider.setDarkMode(false);
                      },
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

// ── Language row ──────────────────────────────────────────────────────────
class _LanguageRow extends StatelessWidget {
  const _LanguageRow({required this.l, required this.c});
  final AppLocalizations l;
  final EditorialColors c;

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, _) {
        final isEn = localeProvider.locale.languageCode == 'en';
        return Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: c.card,
            border: Border.all(color: c.hairline, width: 1),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: c.terrace,
                  borderRadius: BorderRadius.circular(2),
                  border:
                      Border.all(color: c.hairline, width: 1),
                ),
                child: Icon(Icons.language_outlined,
                    size: 16, color: c.inkMute),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  l.settings_language.toUpperCase(),
                  style: EType.label(
                      color: c.ink, size: 11, letterSpacing: 1.8),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: c.terrace,
                  border:
                      Border.all(color: c.hairline, width: 1),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ModeChip(
                      label: l.settings_eng,
                      active: isEn,
                      c: c,
                      roundLeft: true,
                      onTap: () => context
                          .read<LocaleProvider>()
                          .setLocale(const Locale('en')),
                    ),
                    Container(
                        width: 1, height: 28, color: c.hairline),
                    _ModeChip(
                      label: l.settings_heb,
                      active: !isEn,
                      c: c,
                      roundRight: true,
                      onTap: () => context
                          .read<LocaleProvider>()
                          .setLocale(const Locale('he')),
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

// ── Shared segmented chip (theme + language rows) ─────────────────────────
class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.active,
    required this.c,
    required this.onTap,
    this.roundLeft = false,
    this.roundRight = false,
  });
  final String label;
  final bool active;
  final EditorialColors c;
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
          color: active ? c.live : Colors.transparent,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(roundLeft ? 2 : 0),
            bottomLeft: Radius.circular(roundLeft ? 2 : 0),
            topRight: Radius.circular(roundRight ? 2 : 0),
            bottomRight: Radius.circular(roundRight ? 2 : 0),
          ),
        ),
        child: Text(
          label.toUpperCase(),
          style: EType.label(
            color: active ? c.pitch : c.inkMute,
            size: 11,
            letterSpacing: 1.6,
          ),
        ),
      ),
    );
  }
}
