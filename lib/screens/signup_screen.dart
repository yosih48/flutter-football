import 'package:flutter/material.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:football/utils/utils.dart';
import 'package:provider/provider.dart';
import '../resources/auth.dart';
import '../responsive/mobile_screen_layout.dart';
import '../responsive/rsponsive_layout_screen.dart';
import '../responsive/web_screen_layout.dart';
import 'package:football/l10n/app_localizations.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController    = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading        = false;
  bool _obscurePassword  = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Sign up ────────────────────────────────────────────────────────────
  Future<void> _signUpUser() async {
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      await authProvider.register(
        _usernameController.text,
        _emailController.text,
        _passwordController.text,
      );
      if (!mounted) return;
      showSnackBar(
        context,
        AppLocalizations.of(context)!.registrationsuccessful,
        tone: SnackTone.success,
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const ResponsiveLayout(
            mobileScreenLayout: MobileScreenLayout(),
            webScreenLayout: WebScreenLayout(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showSnackBar(
        context,
        AppLocalizations.of(context)!.registrationfailed,
        tone: SnackTone.error,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final l = AppLocalizations.of(context)!;

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
                l.signup.toUpperCase(),
                style: EType.display(
                    size: 28, color: c.ink, letterSpacing: 1.6),
              ),
              const SizedBox(height: 6),
              // Kit-stripe accent
              Container(width: 28, height: 2, color: c.live),

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
                    // Username
                    _AuthField(
                      icon: Icons.person_outline,
                      hintText: l.username,
                      controller: _usernameController,
                      c: c,
                    ),
                    Container(height: 1, color: c.hairline),
                    // Email
                    _AuthField(
                      icon: Icons.mail_outline,
                      hintText: l.email,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      c: c,
                    ),
                    Container(height: 1, color: c.hairline),
                    // Password
                    _AuthField(
                      icon: Icons.lock_outline,
                      hintText: l.createpassword,
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

              const SizedBox(height: 28),

              // ── Sign-up button ─────────────────────────────────
              GestureDetector(
                onTap: _isLoading ? null : _signUpUser,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: _isLoading ? c.hairlineHi : c.live,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: _isLoading
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
                            l.signup.toUpperCase(),
                            style: EType.label(
                              color: c.pitch,
                              size: 12,
                              letterSpacing: 2.4,
                            ),
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 48),

              // ── Login link ─────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l.allreadyhaveanaccount,
                    style: EType.body(color: c.inkMute, size: 13),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const LoginScreen()),
                    ),
                    child: Text(
                      l.login.toUpperCase(),
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
