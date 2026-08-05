import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:football/resources/auth.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
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
                              color: c.inkMute, size: 10, letterSpacing: 3)),
                      const SizedBox(height: 2),
                      Text(
                        l.account,
                        style: EType.screenTitle(
                          size: 26,
                          color: c.ink,
                          hebrew:
                              Localizations.localeOf(context).languageCode ==
                                  'he',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            if (user == null)
              Expanded(
                child: Center(
                  child:
                      Text(l.noUserFound, style: EType.body(color: c.inkMute)),
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
                      decoration:
                          BoxDecoration(color: c.live, shape: BoxShape.circle),
                      child: Text(
                        initial,
                        style: EType.display(size: 20, color: Colors.white),
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
                            style: EType.body(color: c.inkMute, size: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Delete account moved to the bottom of settings_screen.dart.
              const Spacer(),
            ],
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
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 16, color: c.ink),
      ),
    );
  }
}
