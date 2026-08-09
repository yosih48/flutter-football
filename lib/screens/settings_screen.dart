import 'package:flutter/material.dart';
// Navigation to the account screen is disabled — see _identityCard below.
// import 'package:football/screens/account_screen.dart';
import 'package:football/screens/favorits.dart';
import 'package:football/screens/instructionsb.dart';
import 'package:football/screens/login_screen.dart';
import 'package:football/utils/utils.dart';
import 'package:provider/provider.dart';
import 'package:football/providers/flutter pub add provider.dart';
import 'package:football/providers/LocaleProvider.dart';
import 'package:football/providers/theme_provider.dart';
import 'package:football/resources/auth.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
    final c = context.col;
    final l = AppLocalizations.of(context)!;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = authProvider.currentUser;

    final userName = user?.name ?? '';
    final userEmail = user?.email ?? '';
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: c.pitch,
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            // ── Header ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.appLabel.toUpperCase(),
                      style: EType.label(
                          color: c.inkDim, size: 10, letterSpacing: 3)),
                  const SizedBox(height: 2),
                  Text(
                    l.settings,
                    style: EType.screenTitle(
                      size: 26,
                      color: c.ink,
                      hebrew:
                          Localizations.localeOf(context).languageCode == 'he',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (user != null) ...[
              // Account screen is no longer reachable from here — delete
              // account now lives at the bottom of this screen instead.
              // Restore by uncommenting the onTap below (and the
              // account_screen import at the top).
              _identityCard(
                c,
                userName,
                userEmail,
                initial,
                // onTap: () => Navigator.of(context).push(
                //   MaterialPageRoute(builder: (_) => const AccountScreen()),
                // ),
              ),
              const SizedBox(height: 24),
            ],

            // ── Preferences ─────────────────────────────────────────
            _greenHeader(c, l.preferencesSection),
            const SizedBox(height: 10),
            _GroupedCard(rows: [
              _ThemeCard(l: l, grouped: true),
              _LanguageCard(l: l, grouped: true),
            ]),
            const SizedBox(height: 24),

            // ── Application ─────────────────────────────────────────
            _greenHeader(c, l.appLabel),
            const SizedBox(height: 10),
            _appLinksCard(context, c, l),
            const SizedBox(height: 20),

            // ── Sign out ────────────────────────────────────────────
            if (user != null) ...[
              _signOutCard(context, c, l, user, authProvider, userProvider),
              const SizedBox(height: 20),
            ],

            if (appVersion.isNotEmpty)
              // Center(
              //   child: Text('v$appVersion',
              //       style: EType.label(
              //           color: c.inkFaint, size: 10, letterSpacing: 1.6)),
              // ),

            // ── Delete account ──────────────────────────────────────
            if (user != null) ...[
              const SizedBox(height: 14),
              Center(
                  child: _deleteAccountLink(context, c, l, user, authProvider)),
            ],
          ],
        ),
      ),
    );
  }

  // ── Section header (green dash) ────────────────────────────────────────
  Widget _greenHeader(EditorialColors c, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 3,
            decoration: BoxDecoration(
              color: c.live,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(label.toUpperCase(),
              style:
                  EType.label(color: c.inkDim, size: 11, letterSpacing: 1.8)),
        ],
      ),
    );
  }

  // ── Identity card ──────────────────────────────────────────────────────
  // [onTap] is optional: with navigation to the account screen disabled the
  // card is purely informational, so it renders untappable and without the
  // trailing chevron.
  Widget _identityCard(
      EditorialColors c, String name, String email, String initial,
      {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.hairline, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.live, shape: BoxShape.circle),
              child: Text(initial,
                  style: EType.display(size: 20, color: Colors.white)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name.isNotEmpty ? name : '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EType.body(
                          color: c.ink, size: 16, weight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EType.body(color: c.inkMute, size: 12)),
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              Icon(Icons.chevron_left, size: 22, color: c.inkDim),
            ],
          ],
        ),
      ),
    );
  }

  // ── Application links (grouped card) ───────────────────────────────────
  Widget _appLinksCard(
      BuildContext context, EditorialColors c, AppLocalizations l) {
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.hairline, width: 1),
      ),
      child: Column(
        children: [
          _linkRow(
            c,
            icon: Icons.notifications_none,
            title: l.notifications,
            subtitle: l.notifSubtitle,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const FavoritsScreen(initialTab: 1)),
            ),
          ),
          Divider(height: 1, color: c.hairline, indent: 14, endIndent: 14),
          _linkRow(
            c,
            icon: Icons.info_outline,
            title: l.settings_rules,
            subtitle: l.rulesSubtitle,
            onTap: () => showInstructionsBottomSheet(context),
          ),
        ],
      ),
    );
  }

  Widget _linkRow(
    EditorialColors c, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            _IconTile(icon: icon, color: c.inkMute),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: EType.body(
                          color: c.ink, size: 15, weight: FontWeight.w600)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: EType.body(color: c.inkMute, size: 12)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_left, size: 22, color: c.inkDim),
          ],
        ),
      ),
    );
  }

  // ── Sign out card (red-accented) ───────────────────────────────────────
  Widget _signOutCard(
    BuildContext context,
    EditorialColors c,
    AppLocalizations l,
    dynamic user,
    AuthProvider authProvider,
    UserProvider userProvider,
  ) {
    return InkWell(
      onTap: () async {
        final nav = Navigator.of(context);
        final confirm = await _showEditorialDialog(
          context: context,
          title: l.confirmsignout,
          body: l.leaveapp,
          confirmLabel: l.yes,
          confirmColor: c.flag,
          cancelLabel: l.cancel,
        );
        if (confirm == true) {
          userProvider.setSelectedGroupName('public');
          await authProvider.signOut(user.id);
          nav.pushNamedAndRemoveUntil('/login', (route) => false);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.hairline, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Row(
          children: [
            _IconTile(icon: Icons.logout, color: c.flag),
            const SizedBox(width: 14),
            Expanded(
              child: Text(l.signout,
                  style: EType.body(
                      color: c.flag, size: 15, weight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_left, size: 22, color: c.flag),
          ],
        ),
      ),
    );
  }

  // ── Delete account (subtle link at the very bottom) ────────────────────
  Widget _deleteAccountLink(BuildContext context, EditorialColors c,
      AppLocalizations l, dynamic user, AuthProvider authProvider) {
    return GestureDetector(
      onTap: () async {
        final nav = Navigator.of(context);
        final messenger = ScaffoldMessenger.of(context);
        final cc = context.col;
        final confirm = await _showEditorialDialog(
          context: context,
          title: l.deleteaccount,
          body: l.deleteaccountconfirm,
          confirmLabel: l.delete,
          confirmColor: cc.flag,
          cancelLabel: l.cancel,
        );
        if (confirm == true) {
          nav.push(PageRouteBuilder(
            opaque: false,
            barrierDismissible: false,
            pageBuilder: (_, __, ___) =>
                Center(child: CircularProgressIndicator(color: cc.live)),
          ));
          try {
            final ok = await authProvider.deleteAccount(user.id);
            if (ok) {
              nav.pop();
              await authProvider.signOut(user.id);
              nav.pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
              messenger.showSnackBar(buildEditorialSnackBar(
                text: l.accountDeleted,
                colors: cc,
                tone: SnackTone.success,
              ));
            }
          } catch (e) {
            nav.pop();
            messenger.showSnackBar(buildEditorialSnackBar(
              text: '${l.failedToDeleteAccount}$e',
              colors: cc,
              tone: SnackTone.error,
            ));
          }
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, size: 14, color: c.flag),
            const SizedBox(width: 8),
            Text(l.deleteaccount.toUpperCase(),
                style: EType.label(color: c.flag, size: 10, letterSpacing: 2)),
          ],
        ),
      ),
    );
  }

  Future<bool?> _showEditorialDialog({
    required BuildContext context,
    required String title,
    required String body,
    required String confirmLabel,
    required Color confirmColor,
    required String cancelLabel,
  }) {
    final c = context.col;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.hairline, width: 1),
          ),
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: EType.body(
                      color: c.ink, size: 18, weight: FontWeight.w600)),
              const SizedBox(height: 10),
              Text(body, style: EType.body(color: c.inkMute, size: 13)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _GhostBtn(
                      label: cancelLabel,
                      onTap: () => Navigator.of(ctx).pop(false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SolidBtn(
                      label: confirmLabel,
                      color: confirmColor,
                      onTap: () => Navigator.of(ctx).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tinted icon tile ───────────────────────────────────────────────────────
class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}

// Hairline between two rows inside one grouped card, inset to the rows'
// horizontal padding so it reads as a rule rather than a seam.
class _GroupDivider extends StatelessWidget {
  const _GroupDivider();

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(height: 1, color: c.hairline),
    );
  }
}

// One card holding several rows with no gaps between them — a hairline is
// woven in between each pair instead. Rows must be built with `grouped: true`
// so they don't draw a surface of their own.
class _GroupedCard extends StatelessWidget {
  const _GroupedCard({required this.rows});
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) children.add(const _GroupDivider());
      children.add(rows[i]);
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.hairline, width: 1),
      ),
      child: Column(children: children),
    );
  }
}

// ── A settings card row: icon + title/subtitle + a trailing segmented ──────
class _SettingsCardRow extends StatelessWidget {
  const _SettingsCardRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.grouped = false,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;

  /// When true the row draws no surface of its own — the parent supplies one
  /// continuous card and separates rows with a hairline instead of a gap.
  final bool grouped;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Container(
      decoration: grouped
          ? null
          : BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.hairline, width: 1),
            ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          _IconTile(icon: icon, color: c.live),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: EType.body(
                        color: c.ink, size: 15, weight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(subtitle, style: EType.body(color: c.inkMute, size: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );
  }
}

// ── Segmented pill toggle (two options; active one filled green) ───────────
class _SegOption {
  const _SegOption(this.label, this.active, this.onTap);
  final String label;
  final bool active;
  final VoidCallback onTap;
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.options});
  final List<_SegOption> options;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.pitch,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.hairline, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options
            .map((o) => GestureDetector(
                  onTap: o.onTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: o.active ? c.live : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(o.label,
                        style: EType.label(
                            color: o.active ? Colors.white : c.inkMute,
                            size: 12,
                            letterSpacing: 0.5)),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

// ── Theme card ─────────────────────────────────────────────────────────────
class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.l, this.grouped = false});
  final AppLocalizations l;
  final bool grouped;

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, tp, _) {
        final isDark = tp.isDarkMode;
        return _SettingsCardRow(
          icon: isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
          title: l.settings_theme,
          subtitle: l.themeSubtitle,
          grouped: grouped,
          trailing: _Segmented(options: [
            _SegOption(l.settings_light, !isDark, () => tp.setDarkMode(false)),
            _SegOption(l.settings_dark, isDark, () => tp.setDarkMode(true)),
          ]),
        );
      },
    );
  }
}

// ── Language card ──────────────────────────────────────────────────────────
class _LanguageCard extends StatelessWidget {
  const _LanguageCard({required this.l, this.grouped = false});
  final AppLocalizations l;
  final bool grouped;

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleProvider>(
      builder: (context, lp, _) {
        final isEn = lp.locale.languageCode == 'en';
        return _SettingsCardRow(
          icon: Icons.language_outlined,
          title: l.settings_language,
          subtitle: l.languageSubtitle,
          grouped: grouped,
          trailing: _Segmented(options: [
            _SegOption(
                l.settings_heb, !isEn, () => lp.setLocale(const Locale('he'))),
            _SegOption(
                l.settings_eng, isEn, () => lp.setLocale(const Locale('en'))),
          ]),
        );
      },
    );
  }
}

// ── Dialog buttons ───────────────────────────────────────────────────────
class _GhostBtn extends StatelessWidget {
  const _GhostBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: c.hairline, width: 1),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(label.toUpperCase(),
            style: EType.label(color: c.ink, size: 11, letterSpacing: 1.6)),
      ),
    );
  }
}

class _SolidBtn extends StatelessWidget {
  const _SolidBtn(
      {required this.label, required this.color, required this.onTap});
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(label.toUpperCase(),
            style: EType.label(color: c.pitch, size: 11, letterSpacing: 1.6)),
      ),
    );
  }
}
