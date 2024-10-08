import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final String? idToken = googleAuth.idToken;

        print(googleAuth.idToken);
        print(idToken);
        if (idToken != null) {
          print('idToken != null');
          // Send the ID token to your backend
          final response = await http.post(
            Uri.parse('https://leagues.onrender.com/users/verify-google-user'),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
            },
            body: jsonEncode(<String, String>{
              'token': idToken,
            }),
          );

          if (response.statusCode == 200) {
                     print(response);
            print(response.statusCode);
            print(response.body);
            // Successfully authenticated with the backend
            final Map<String, dynamic> data = json.decode(response.body);
            final String jwtToken = data['newToken'];
            onSignInSuccess(jwtToken);
          } else {
            print('Authentication failed');
            print(response);
            print(response.statusCode);
            // Handle authentication error
            onSignInError('Authentication failed');
          }
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
    return ElevatedButton(
      child: Text('Sign in with Google'),
      onPressed: () => _handleSignIn(context),
    );
  }
}
