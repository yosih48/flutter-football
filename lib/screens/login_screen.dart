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
  final TextEditingController _emailController    = TextEditingController();
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
          return AlertDialog(
            backgroundColor: dc.card,
            surfaceTintColor: Colors.transparent,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(2)),
            ),
            title: Text(
              l.emailsent.toUpperCase(),
              style: EType.display(
                  size: 18, color: dc.ink, letterSpacing: 0.8),
            ),
            content: Text(
              l.emailsentlink,
              style: EType.body(color: dc.inkMute, size: 13, height: 1.55),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(AppLocalizations.of(context)!.loginfailed)),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final l = AppLocalizations.of(context)!;
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: c.pitch,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 56),

              // ── Brand mark ─────────────────────────────────────
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: c.cardHi,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.hairline, width: 1),
                ),
                child:
                    Icon(Icons.sports_soccer, color: c.live, size: 26),
              ),
              const SizedBox(height: 20),
              Text(
                l.login.toUpperCase(),
                style: EType.display(
                    size: 28, color: c.ink, letterSpacing: 1.6),
              ),
              const SizedBox(height: 6),
              // Kit-stripe accent
              Container(
                width: 28, height: 2, color: c.live,
              ),

              const SizedBox(height: 36),

              // ── Form card ──────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: c.hairline, width: 1),
                ),
                child: Column(
                  children: [
                    // Email row
                    _AuthField(
                      icon: Icons.mail_outline,
                      hintText: l.email,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      c: c,
                    ),
                    Container(height: 1, color: c.hairline),
                    // Password row
                    _AuthField(
                      icon: Icons.lock_outline,
                      hintText: l.password,
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      c: c,
                      trailing: GestureDetector(
                        onTap: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                        child: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                          color: c.inkDim,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Forgot password ────────────────────────────────
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: authProvider.isLoading ? null : _sendResetEmail,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      l.forgotpassword.toUpperCase(),
                      style: EType.label(
                          color: c.inkMute, size: 10, letterSpacing: 1.6),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── Login button ───────────────────────────────────
              GestureDetector(
                onTap: authProvider.isLoading ? null : _loginUser,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: authProvider.isLoading
                        ? c.hairlineHi
                        : c.live,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: authProvider.isLoading
                      ? Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              valueColor:
                                  AlwaysStoppedAnimation(c.pitch),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            l.login.toUpperCase(),
                            style: EType.label(
                              color: c.pitch,
                              size: 12,
                              letterSpacing: 2.4,
                            ),
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 22),

              // ── OR divider ─────────────────────────────────────
              Row(
                children: [
                  Expanded(
                      child: Container(height: 1, color: c.hairline)),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(
                      l.or.toUpperCase(),
                      style: EType.label(
                          color: c.inkDim, size: 10, letterSpacing: 2),
                    ),
                  ),
                  Expanded(
                      child: Container(height: 1, color: c.hairline)),
                ],
              ),

              const SizedBox(height: 22),

              // ── Google sign-in ─────────────────────────────────
              GoogleSignInButton(
                onSignInSuccess: (String token) {
                  final ap =
                      Provider.of<AuthProvider>(context, listen: false);
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
                      MaterialPageRoute(
                          builder: (_) => MobileScreenLayout()),
                      (route) => false,
                    );
                  }
                },
                onSignInError: (String error) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error)),
                  );
                },
              ),

              const SizedBox(height: 48),

              // ── Sign-up link ───────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l.donthaveanaccount,
                    style: EType.body(color: c.inkMute, size: 13),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const SignupScreen()),
                    ),
                    child: Text(
                      l.signup.toUpperCase(),
                      style: EType.label(
                          color: c.live, size: 11, letterSpacing: 1.4),
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

// ── Reusable auth field row ────────────────────────────────────────────────
class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.icon,
    required this.hintText,
    required this.controller,
    required this.c,
    this.keyboardType,
    this.obscureText = false,
    this.trailing,
  });

  final IconData                icon;
  final String                  hintText;
  final TextEditingController   controller;
  final EditorialColors         c;
  final TextInputType?          keyboardType;
  final bool                    obscureText;
  final Widget?                 trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c.inkDim),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              obscureText: obscureText,
              style: EType.body(color: c.ink, size: 14),
              cursorColor: c.live,
              cursorWidth: 1.5,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: EType.body(color: c.inkFaint, size: 14),
                border: InputBorder.none,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}
