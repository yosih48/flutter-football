import 'package:flutter/material.dart';
import 'package:football/screens/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:football/providers/flutter pub add provider.dart';
import 'package:football/resources/auth.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:football/utils/utils.dart';
import 'package:football/l10n/app_localizations.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = authProvider.currentUser;
    final l = AppLocalizations.of(context)!;

    final userName = user?.name ?? '';
    final userEmail = user?.email ?? '';
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: c.pitch,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Back + Header ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 24, 0),
              child: Row(
                children: [
                  _IconBtn(
                    icon: Icons.arrow_back_ios_new,
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.settings.toUpperCase(),
                          style: EType.label(
                              color: c.inkMute,
                              size: 10,
                              letterSpacing: 3)),
                      const SizedBox(height: 2),
                      Text(l.account.toUpperCase(),
                          style: EType.display(
                              size: 28,
                              color: c.ink,
                              letterSpacing: 1.4)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            if (user == null)
              Expanded(
                child: Center(
                  child: Text(l.noUserFound,
                      style: EType.body(color: c.inkMute)),
                ),
              )
            else ...[
              // ── Identity block ─────────────────────────────────────
              Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: c.card,
                  border: Border(
                    top: BorderSide(color: c.live, width: 2),
                    left: BorderSide(color: c.hairline, width: 1),
                    right: BorderSide(color: c.hairline, width: 1),
                    bottom: BorderSide(color: c.hairline, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: c.cardHi,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: c.live, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: EType.display(
                            size: 32,
                            color: c.ink,
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
                                size: 22,
                                color: c.ink,
                                letterSpacing: 0.8),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.email_outlined,
                                  size: 12, color: c.inkDim),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  userEmail,
                                  overflow: TextOverflow.ellipsis,
                                  style: EType.body(
                                      color: c.ink, size: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── Section label ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: _sectionLabel(l.dangerZoneLabel.toUpperCase(), c),
              ),

              // ── Sign Out row ───────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: _ActionRow(
                  icon: Icons.exit_to_app_outlined,
                  label: l.signout.toUpperCase(),
                  accent: c.flag,
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
                      nav.pushNamedAndRemoveUntil(
                          '/login', (route) => false);
                    }
                  },
                ),
              ),

              const Spacer(),

              // ── Delete account ─────────────────────────────────────
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: GestureDetector(
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
                          pageBuilder: (_, __, ___) => Center(
                            child: CircularProgressIndicator(
                                color: cc.live),
                          ),
                        ));
                        try {
                          final ok =
                              await authProvider.deleteAccount(user.id);
                          if (ok) {
                            nav.pop();
                            await authProvider.signOut(user.id);
                            nav.pushAndRemoveUntil(
                              MaterialPageRoute(
                                  builder: (_) => const LoginScreen()),
                              (route) => false,
                            );
                            messenger.showSnackBar(
                              buildEditorialSnackBar(
                                text: l.accountDeleted,
                                colors: cc,
                                tone: SnackTone.success,
                              ),
                            );
                          }
                        } catch (e) {
                          nav.pop();
                          messenger.showSnackBar(
                            buildEditorialSnackBar(
                              text: '${l.failedToDeleteAccount}$e',
                              colors: cc,
                              tone: SnackTone.error,
                            ),
                          );
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_outline,
                              size: 14, color: c.flag),
                          const SizedBox(width: 8),
                          Text(
                            l.deleteaccount.toUpperCase(),
                            style: EType.label(
                                color: c.flag,
                                size: 10,
                                letterSpacing: 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, EditorialColors c) {
    return Row(
      children: [
        Container(width: 18, height: 1, color: c.flag),
        const SizedBox(width: 10),
        Text(text,
            style: EType.label(
                color: c.ink, size: 10, letterSpacing: 2.4)),
      ],
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
            border: Border(
              top: BorderSide(color: confirmColor, width: 2),
              left: BorderSide(color: c.hairline, width: 1),
              right: BorderSide(color: c.hairline, width: 1),
              bottom: BorderSide(color: c.hairline, width: 1),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title.toUpperCase(),
                  style: EType.display(
                      size: 22,
                      color: c.ink,
                      letterSpacing: 0.8)),
              const SizedBox(height: 12),
              Text(body,
                  style:
                      EType.body(color: c.inkDim, size: 13)),
              const SizedBox(height: 28),
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

// ── Action row ───────────────────────────────────────────────────────────
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: c.card,
          border: Border(
            top: BorderSide(color: accent, width: 2),
            left: BorderSide(color: c.hairline, width: 1),
            right: BorderSide(color: c.hairline, width: 1),
            bottom: BorderSide(color: c.hairline, width: 1),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(
                    color: accent.withOpacity(0.3), width: 1),
              ),
              child: Icon(icon, size: 16, color: accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: EType.label(
                    color: accent, size: 11, letterSpacing: 1.8),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 12, color: accent),
          ],
        ),
      ),
    );
  }
}

// ── Icon button ──────────────────────────────────────────────────────────
class _IconBtn extends StatelessWidget {
  const _IconBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: c.card,
          border: Border.all(color: c.hairline, width: 1),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Icon(icon, size: 16, color: c.ink),
      ),
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
          borderRadius: BorderRadius.circular(2),
        ),
        alignment: Alignment.center,
        child: Text(label.toUpperCase(),
            style: EType.label(
                color: c.ink,
                size: 11,
                letterSpacing: 1.6)),
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
          borderRadius: BorderRadius.circular(2),
        ),
        alignment: Alignment.center,
        child: Text(label.toUpperCase(),
            style: EType.label(
                color: c.pitch,
                size: 11,
                letterSpacing: 1.6)),
      ),
    );
  }
}
