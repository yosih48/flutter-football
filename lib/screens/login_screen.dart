// import 'package:businesses/models/employees.dart';
// import 'package:businesses/providers/flutter%20pub%20add%20provider.dart';
// import 'package:businesses/resources/Employees_methods.dart';
// import 'package:businesses/screens/employeesCalls.dart';
// import 'package:businesses/screens/signup_screen.dart';
// import 'package:businesses/utils/utils.dart';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:football/models/memoryToken.dart';
import 'package:football/resources/usersMethods.dart';
import 'package:football/screens/games.dart';
import 'package:football/screens/signup_screen.dart';
import 'package:football/theme/colors.dart';
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
import '../utils/colors.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  List<String> _employeeUsernames = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

Future<void> sendResetEmail() async {
    try {
      final resetToken =
          await UsersMethods().sendEmail(_usernameController.text,  context);
      print('Reset token received: $resetToken');

      // Store token in memory
      TokenManager.setToken(resetToken);
      print('Token stored in memory');

      // Show dialog
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              backgroundColor: cards,
              title: Text(AppLocalizations.of(context)!.emailsent,
                      style: TextStyle(
                 
                      color: Colors.white,
                    ),
              ),
              content: Text(
                 AppLocalizations.of(context)!.emailsentlink,
                         style: TextStyle(
                
                      color: Colors.white,
                    ),
                 ),
              actions: <Widget>[
                TextButton(
                  child: Text('OK'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      print('Exception in sendResetEmail: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  void loginUser() async {
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      print('fcmToken: $fcmToken');

      await authProvider.login(
          _usernameController.text, _passwordController.text, fcmToken);

// String? fcmToken = await FirebaseMessaging.instance.getToken();
// print('fcmToken: ${fcmToken}');
//  await sendFCMTokenToServer(fcmToken);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.loginfailed)),
      );
    }
  }

  Future<void> sendFCMTokenToServer(String? fcmToken) async {
    if (fcmToken == null) {
      print('FCM token is null. Unable to send to server.');
      return;
    }

    final String userId =
        '6584aceb503733cfc6418e98'; // Replace with actual user ID from your auth system
    final String email = _usernameController
        .text; // Replace with actual user ID from your auth system
    final String serverUrl =
        'https://leagues.onrender.com/users/store-fcm-token'; // Replace with your actual server URL

    try {
      final response = await http.post(
        Uri.parse(serverUrl),
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'userId': userId,
          'fcmToken': fcmToken,
          'email': email,
        }),
      );

      if (response.statusCode == 200) {
        print('FCM token sent to server successfully');
      } else {
        print(
            'Failed to send FCM token to server. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending FCM token to server: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    return Scaffold(
        backgroundColor: background,
        body: SafeArea(
            child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Container(),
                flex: 2,
              ),
              //svg image
              // SvgPicture.asset('assets/ic_instegram.svg', color: primaryColor,height:64),
              const SizedBox(height: 64),
              //test fiels input for email
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text == '') {
                    return const Iterable<String>.empty();
                  }
                  return _employeeUsernames.where((String option) {
                    return option
                        .toLowerCase()
                        .contains(textEditingValue.text.toLowerCase());
                  });
                },
                onSelected: (String selection) {
                  setState(() {
                    _usernameController.text = selection;
                  });
                },
                fieldViewBuilder: (BuildContext context,
                    TextEditingController fieldTextEditingController,
                    FocusNode fieldFocusNode,
                    VoidCallback onFieldSubmitted) {
                  return TextField(
                    controller: fieldTextEditingController,
                    focusNode: fieldFocusNode,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.username,
                      labelStyle: TextStyle(
                        color: Colors.blue, // Change this to your desired color
                      ),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                            color: Colors
                                .blue), // Bottom border color when enabled
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                            color: Colors.blue,
                            width:
                                2.0), // Bottom border color when focused, with thicker border
                      ),
                    ),
                    style: TextStyle(
                      color:
                          Colors.white, // Change the input text color to blue
                    ),
                    cursorColor: Colors.blue,
                    onChanged: (value) {
                      _usernameController.text = value;
                    },
                  );
                },
                optionsViewBuilder: (BuildContext context,
                    AutocompleteOnSelected<String> onSelected,
                    Iterable<String> options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4.0,
                      child: Container(
                        width: 330,
                        height: 60, // Adjust this width as needed
                        child: ListView.builder(
                          padding: EdgeInsets.all(8.0),
                          itemCount: options.length,
                          itemBuilder: (BuildContext context, int index) {
                            final String option = options.elementAt(index);
                            return GestureDetector(
                              onTap: () {
                                onSelected(option);
                              },
                              child: ListTile(
                                title: Text(option),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),
              //old test fiels input for password
              // TextFieldInput(
              //   textEditingController: _passwordController,
              //   hintText: AppLocalizations.of(context)!.enteryourpassword,
              //   textInputType: TextInputType.text,
              //   isPass: true,
              // ),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.password,
                  labelStyle: TextStyle(
                    color: Colors.blue, // Change this to your desired color
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                        color: Colors.blue), // Bottom border color when enabled
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                        color: Colors.blue,
                        width:
                            2.0), // Bottom border color when focused, with thicker border
                  ),
                ),
                style: TextStyle(
                  color: Colors.white, // Change the input text color to blue
                ),
                cursorColor: Colors.blue,
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: authProvider.isLoading ? null : sendResetEmail,
                child: Container(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      AppLocalizations.of(context)!.forgotpassword,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              InkWell(
                onTap: authProvider.isLoading ? null : loginUser,
                child: Container(
                  child: authProvider.isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: primaryColor,
                          ),
                        )
                      : Text(
                          AppLocalizations.of(context)!.login,
                          style: TextStyle(
                            color: Colors
                                .white, // Change the input text color to blue
                          ),
                        ),
                  width: double.infinity,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const ShapeDecoration(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                      ),
                      color: blueColor),
                ),
              ),

              GoogleSignInButton(
                onSignInSuccess: (String token) {
                  // Handle successful sign-in
                  print('Successfully signed in with Google. JWT: ');
                  // TODO: Store the token securely and navigate to the home screen
                  Navigator.push(context,MaterialPageRoute(builder:(context) => GamesScreen(
             
                  ), 
               
                  ));
                },
                onSignInError: (String error) {
                  // Handle sign-in error
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error)),
                  );
                },
              ),
              
              const SizedBox(height: 12),
              Flexible(
                child: Container(),
                flex: 2,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    child: Text(
                      AppLocalizations.of(context)!.donthaveanaccount,
                      style: TextStyle(
                        color:
                            Colors.white, // Change the input text color to blue
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SignupScreen(),
                      ),
                    ),
                    child: Container(
                      child: Text(
                        AppLocalizations.of(context)!.signup,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  )
                ],
              )
              //transition to sign up
            ],
          ),
        )));
  }
}
