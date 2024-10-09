import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:football/resources/auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

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
        '319642473794-269lu0hmmfsig13b52p9a127mjbdbrpb.apps.googleusercontent.com', // Add this line
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
          // Send the ID token to your backend

          // final response = await http.post(
          //   Uri.parse('https://leagues.onrender.com/users/verify-google-user'),
          //   headers: <String, String>{
          //     'Content-Type': 'application/json; charset=UTF-8',
          //   },
          //   body: jsonEncode(<String, String>{
          //     'token': idToken,
          //   }),
          // );

          // if (response.statusCode == 200) {
          //            print(response);
          //   print(response.statusCode);
          //   print(response.body);
          //   // Successfully authenticated with the backend
          //   final Map<String, dynamic> data = json.decode(response.body);
          //   final String jwtToken = data['newToken'];
          //   onSignInSuccess(jwtToken);
          // } else {
          //   print('Authentication failed');
          //   print(response);
          //   print(response.statusCode);
          //   // Handle authentication error
          //   onSignInError('Authentication failed');
          // }

          await authProvider.googleLogin(idToken, fcmToken, context);

        } else {
          throw Exception('Failed to obtain ID token from Google Sign-In');
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
            Text(AppLocalizations.of(context)!.signinwithgoogle)
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
