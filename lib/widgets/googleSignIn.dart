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

  GoogleSignInButton({
    required this.onSignInSuccess,
    required this.onSignInError,
  });

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    serverClientId:
        _CLIENTID, 
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
     return Padding(
      padding: const EdgeInsets.only(left: 0, right: 0, top: 10),
      child: MaterialButton(
        color: Colors.white,
        elevation: 10,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 30.0,
              width: 30.0,
              decoration: BoxDecoration(
                image: DecorationImage(
                    image: AssetImage('assets/googleimage.png'),
                    fit: BoxFit.cover),
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(
              width: 5,
            ),
            Text(AppLocalizations.of(context)!.signinwithgoogle,
                style: TextStyle(
                color: Colors.black // Change the input text color to blue
              ),
            )
          ],
        ),
        onPressed: () {
          _handleSignIn(context);
   
        },
      ),
    );
    // return ElevatedButton(
    //   child: Text('Sign in with Google'),
    //   onPressed: () => _handleSignIn(context),
    // );
  }
}
