import 'package:flutter/material.dart';
import 'package:football/screens/login_screen.dart';
import 'package:provider/provider.dart';
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.hairline, width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: c.live, shape: BoxShape.circle),
                      child: Text(
                        initial,
                        style:
                            EType.display(size: 20, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName.isNotEmpty ? userName : '—',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: EType.body(
                                color: c.ink,
                                size: 16,
                                weight: FontWeight.w600),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            userEmail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                EType.body(color: c.inkMute, size: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
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
          borderRadius: BorderRadius.circular(12),
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
          borderRadius: BorderRadius.circular(10),
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
          borderRadius: BorderRadius.circular(10),
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
