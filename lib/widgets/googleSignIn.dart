import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:football/resources/auth.dart';
import 'package:football/utils/config.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:football/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

String _CLIENTID = serverClientId;

class GoogleSignInButton extends StatelessWidget {
  final Function(String) onSignInSuccess;
  final Function(String) onSignInError;
  // Override the button label (e.g. "Sign up with Google" on the signup
  // screen). Falls back to the sign-in string when null.
  final String? label;

  GoogleSignInButton({
    required this.onSignInSuccess,
    required this.onSignInError,
    this.label,
  });

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    serverClientId: _CLIENTID,
  );

  Future<void> _handleSignIn(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      await _googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final String? idToken = googleAuth.idToken;

        // print(googleAuth.idToken);
        // print(idToken);
        if (idToken != null) {
          print('idToken != null');

          String? fcmToken = await FirebaseMessaging.instance.getToken();
          print('fcmToken: $fcmToken');

          await authProvider.googleLogin(idToken, fcmToken, context);
// print('googleLogin idToken: ${idToken}, fcmToken: ${fcmToken} ');
          onSignInSuccess(idToken);
        } else {
          throw ('Failed to obtain ID token from Google Sign-In');
        }
        print('idToken== null');
      }
    } catch (error) {
      print(error);
      onSignInError('Sign in failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _handleSignIn(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE4E7EC), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // The asset is a 2:1 canvas of the G inside a white app-tile with
            // grey padding, so BoxFit.contain renders the actual glyph tiny.
            // Cover-crop to the centre and zoom past the padding: the white
            // tile blends into the white button, leaving just a large G.
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 30,
                height: 30,
                child: Transform.scale(
                  scale: 1.6,
                  child: Image.asset(
                    'assets/googleimage.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label ?? AppLocalizations.of(context)!.signinwithgoogle,
              style: const TextStyle(
                color: Color(0xFF3C4043),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
