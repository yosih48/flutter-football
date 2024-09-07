import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GoogleSignInButton extends StatelessWidget {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
      clientId: '181890860612-i0jm803ej1logp1st6uaklnu0igan6qb.apps.googleusercontent.com',
  );

  Future<void> _handleSignIn(BuildContext context) async {
     print('_handleSignIn');
    try {
      await _googleSignIn.signOut(); // Sign out before signing in to ensure a fresh attempt
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser != null) {
        print('googleUser not null');
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final String? idToken = googleAuth.idToken;

        if (idToken != null) {
          // Send the ID token to your server
          final response = await http.post(
            Uri.parse('https://leagues.onrender.com/verify-token'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'token': idToken}),
          );

          if (response.statusCode == 200) {
            // Successfully verified with the server
            final userData = json.decode(response.body);
            // Handle the user data (e.g., save to local storage, update UI)
            print('Logged in: ${userData['name']}');
            // Navigate to home screen or update UI
          } else {
            // Handle error
            print('Server verification failed: ${response.body}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to verify with server')),
            );
          }
        }
      } else {
        print('Sign in aborted by user');
      }
    } catch (error) {
      print('Error during Google sign in: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign in failed: $error')),
      );
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