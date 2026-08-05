import 'package:flutter/material.dart';
import 'package:football/screens/competitions.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:football/utils/utils.dart';
import 'package:football/widgets/googleSignIn.dart';
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
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

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

  // On any successful auth, route new users to onboarding, returning users
  // straight to the app. Same rule as the login screen's handler.
  void _routeAfterAuth() {
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
  }

  // ── Build ──────────────────────────────────────────────────────────────
  bool get _isHe => Localizations.localeOf(context).languageCode == 'he';

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final l = AppLocalizations.of(context)!;
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
              // Solid green disc with a white ball — matches the login screen.
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
                l.signupTitle,
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
                l.signupSubtitle,
                textAlign: TextAlign.center,
                style: EType.body(color: c.inkMute, size: 13, hebrew: isHe),
              ),

              const SizedBox(height: 34),

              // ── Username ───────────────────────────────────────
              _AuthField(
                icon: Icons.person_outline,
                hintText: l.username,
                controller: _usernameController,
                c: c,
                hebrew: isHe,
              ),
              const SizedBox(height: 12),
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
                hintText: l.createpassword,
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

              const SizedBox(height: 24),

              // ── Sign-up button ─────────────────────────────────
              GestureDetector(
                onTap: _isLoading ? null : _signUpUser,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 17),
                  decoration: BoxDecoration(
                    color: _isLoading ? c.hairlineHi : c.live,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: _isLoading
                        ? null
                        : [
                            BoxShadow(
                              color: c.live.withValues(alpha: 0.30),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                  ),
                  child: _isLoading
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
                              l.signup,
                              style: EType.body(
                                  color: Colors.white,
                                  size: 15,
                                  weight: FontWeight.w700,
                                  hebrew: isHe),
                            ),
                            const SizedBox(width: 8),
                            // Direction-aware "proceed" arrow.
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

              // ── Google sign-up ─────────────────────────────────
              GoogleSignInButton(
                label: l.signupWithGoogle,
                onSignInSuccess: (_) => _routeAfterAuth(),
                onSignInError: (String error) =>
                    showSnackBar(context, error, tone: SnackTone.error),
              ),

              const SizedBox(height: 40),

              // ── Login link ─────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l.allreadyhaveanaccount,
                    style: EType.body(color: c.inkMute, size: 13, hebrew: isHe),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    ),
                    child: Text(
                      l.login,
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
// Standalone rounded pill: input on the leading side, the field icon at the
// trailing edge (left in RTL), matching the login screen.
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
