import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:football/models/memoryToken.dart';
import 'package:football/resources/appUpdates.dart';
import 'package:football/resources/usersMethods.dart';
import 'package:football/screens/competitions.dart';
import 'package:football/screens/signup_screen.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:football/widgets/googleSignIn.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:football/models/users.dart';
import 'package:football/utils/utils.dart';
import 'package:http/http.dart' as http;
import '../providers/flutter pub add provider.dart';
import '../resources/auth.dart';
import '../responsive/mobile_screen_layout.dart';
import '../responsive/rsponsive_layout_screen.dart';
import '../responsive/web_screen_layout.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Forgot password ────────────────────────────────────────────────────
  Future<void> _sendResetEmail() async {
    try {
      final resetToken =
          await UsersMethods().sendEmail(_emailController.text, context);
      TokenManager.setToken(resetToken);

      if (!context.mounted) return;
      final c = context.col;
      final l = AppLocalizations.of(context)!;

      showDialog(
        context: context,
        builder: (dialogCtx) {
          final dc = dialogCtx.col;
          final isHe = Localizations.localeOf(dialogCtx).languageCode == 'he';
          return AlertDialog(
            backgroundColor: dc.card,
            surfaceTintColor: Colors.transparent,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            title: Text(
              l.emailsent,
              style: EType.body(
                  size: 18,
                  color: dc.ink,
                  weight: FontWeight.w700,
                  hebrew: isHe),
            ),
            content: Text(
              l.emailsentlink,
              style: EType.body(
                  color: dc.inkMute, size: 13, height: 1.55, hebrew: isHe),
            ),
            actions: [
              GestureDetector(
                onTap: () => Navigator.of(dialogCtx).pop(),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    'OK',
                    style: EType.label(
                        color: dc.live, size: 11, letterSpacing: 1.6),
                  ),
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!context.mounted) return;
      showSnackBar(context, e.toString(), tone: SnackTone.error);
    }
  }

  // ── Login ──────────────────────────────────────────────────────────────
  Future<void> _loginUser() async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      await authProvider.login(
          _emailController.text, _passwordController.text, fcmToken);
      if (!mounted) return;

      if (authProvider.currentUser?.isFirstLogin == true) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => Competitions(
              userEmail: authProvider.currentUser!.email,
              userName: authProvider.currentUser!.name,
            ),
          ),
          (route) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => MobileScreenLayout()),
          (route) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showSnackBar(
        context,
        AppLocalizations.of(context)!.loginfailed,
        tone: SnackTone.error,
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────
  bool get _isHe => Localizations.localeOf(context).languageCode == 'he';

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final l = AppLocalizations.of(context)!;
    final authProvider = Provider.of<AuthProvider>(context);
    final isHe = _isHe;

    return Scaffold(
      backgroundColor: c.pitch,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 48),

              // ── Brand mark ─────────────────────────────────────
              // Solid green disc with a white ball — the login's anchor.
              Container(
                width: 84,
                height: 84,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.live,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: c.live.withValues(alpha: 0.30),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.sports_soccer,
                    color: Colors.white, size: 40),
              ),
              const SizedBox(height: 20),
              Text(
                l.loginWelcomeBack,
                textAlign: TextAlign.center,
                style: EType.screenTitle(size: 28, color: c.ink, hebrew: isHe),
              ),
              const SizedBox(height: 10),
              // Kit-stripe accent
              Container(
                width: 40,
                height: 3,
                decoration: BoxDecoration(
                  color: c.live,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l.loginSubtitle,
                textAlign: TextAlign.center,
                style: EType.body(color: c.inkMute, size: 13, hebrew: isHe),
              ),

              const SizedBox(height: 34),

              // ── Email ──────────────────────────────────────────
              _AuthField(
                icon: Icons.mail_outline,
                hintText: l.email,
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                c: c,
                hebrew: isHe,
              ),
              const SizedBox(height: 12),
              // ── Password ───────────────────────────────────────
              _AuthField(
                icon: Icons.lock_outline,
                hintText: l.password,
                controller: _passwordController,
                obscureText: _obscurePassword,
                c: c,
                hebrew: isHe,
                trailing: GestureDetector(
                  onTap: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  child: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: c.inkDim,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ── Forgot password ────────────────────────────────
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: GestureDetector(
                  onTap: authProvider.isLoading ? null : _sendResetEmail,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      l.forgotpassword,
                      style: EType.body(
                          color: c.live,
                          size: 13,
                          weight: FontWeight.w600,
                          hebrew: isHe),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Login button ───────────────────────────────────
              GestureDetector(
                onTap: authProvider.isLoading ? null : _loginUser,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 17),
                  decoration: BoxDecoration(
                    color: authProvider.isLoading ? c.hairlineHi : c.live,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: authProvider.isLoading
                        ? null
                        : [
                            BoxShadow(
                              color: c.live.withValues(alpha: 0.30),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                  ),
                  child: authProvider.isLoading
                      ? Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              l.login,
                              style: EType.body(
                                  color: Colors.white,
                                  size: 15,
                                  weight: FontWeight.w700,
                                  hebrew: isHe),
                            ),
                            const SizedBox(width: 8),
                            // Direction-aware "proceed" arrow: points along the
                            // reading direction (left in Hebrew, right in en).
                            Icon(
                              isHe ? Icons.arrow_back : Icons.arrow_forward,
                              color: Colors.white,
                              size: 18,
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 22),

              // ── OR divider ─────────────────────────────────────
              Row(
                children: [
                  Expanded(child: Container(height: 1, color: c.hairline)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      l.or,
                      style:
                          EType.body(color: c.inkDim, size: 12, hebrew: isHe),
                    ),
                  ),
                  Expanded(child: Container(height: 1, color: c.hairline)),
                ],
              ),

              const SizedBox(height: 22),

              // ── Google sign-in ─────────────────────────────────
              GoogleSignInButton(
                onSignInSuccess: (String token) {
                  final ap = Provider.of<AuthProvider>(context, listen: false);
                  if (ap.currentUser?.isFirstLogin == true) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => Competitions(
                          userEmail: ap.currentUser!.email,
                          userName: ap.currentUser!.name,
                        ),
                      ),
                      (route) => false,
                    );
                  } else {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => MobileScreenLayout()),
                      (route) => false,
                    );
                  }
                },
                onSignInError: (String error) {
                  showSnackBar(context, error, tone: SnackTone.error);
                },
              ),

              const SizedBox(height: 40),

              // ── Sign-up link ───────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l.donthaveanaccount,
                    style: EType.body(color: c.inkMute, size: 13, hebrew: isHe),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SignupScreen()),
                    ),
                    child: Text(
                      l.signup,
                      style: EType.body(
                          color: c.live,
                          size: 13,
                          weight: FontWeight.w700,
                          hebrew: isHe),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Reusable auth field ─────────────────────────────────────────────────────
// A standalone rounded pill: input on the leading side, the field's icon at the
// trailing edge (left in RTL), with an optional inner control (e.g. the
// password eye) sitting just inside it.
class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.icon,
    required this.hintText,
    required this.controller,
    required this.c,
    required this.hebrew,
    this.keyboardType,
    this.obscureText = false,
    this.trailing,
  });

  final IconData icon;
  final String hintText;
  final TextEditingController controller;
  final EditorialColors c;
  final bool hebrew;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.hairline, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              obscureText: obscureText,
              style: EType.body(color: c.ink, size: 14, hebrew: hebrew),
              cursorColor: c.live,
              cursorWidth: 1.5,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle:
                    EType.body(color: c.inkFaint, size: 14, hebrew: hebrew),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
          const SizedBox(width: 12),
          Icon(icon, size: 20, color: c.inkDim),
        ],
      ),
    );
  }
}
