
import 'package:flutter/material.dart';
import 'package:football/theme/colors.dart';
import 'package:football/widgets/text_field_input.dart';
import 'package:provider/provider.dart';

import '../resources/auth.dart';
import '../responsive/mobile_screen_layout.dart';
import '../responsive/rsponsive_layout_screen.dart';
import '../responsive/web_screen_layout.dart';
import '../utils/colors.dart';
import '../utils/utils.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final TextEditingController _usernameController = TextEditingController();

  // final _image = null;
  bool _isLoading = false;

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    _emailController.dispose();
    _passwordController.dispose();

    _usernameController.dispose();
  }

  void selectImage() async {}

 void signUpUser() async {
  setState(() {
    _isLoading = true;
  });

  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  
  try {
    await authProvider.register(
      _usernameController.text,
      _emailController.text,
      _passwordController.text
    );
    
    // If we reach here, registration was successful
    print('Registration successful');
    navigateToLogin();
    // Navigator.of(context).pushReplacement(
    //   MaterialPageRoute(
    //     builder: (context) => const ResponsiveLayout(
    //       mobileScreenLayout: MobileScreenLayout(),
    //       webScreenLayout: WebScreenLayout(),
    //     ),
    //   ),
    // );
  } catch (e) {
    print('Registration failed: $e');
    // Show error message to user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Registration failed: $e')),
    );
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

  void navigateToLogin() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
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
//cicular widget to accept and show our selected file

          const SizedBox(
            height: 24,
          ),
          //test fiels input for username
          
          TextField(
        
              controller: _usernameController,
              //  labelText: 'enter your username',
                               decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.username,
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
            onChanged: (value) {
              _usernameController.text = value;
            },
              ),
          const SizedBox(height: 24),
          //test fiels input for email
           TextField(
        
              controller: _emailController,
              //  labelText: 'enter your username',
                               decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.email,
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
            onChanged: (value) {
              _emailController.text = value;
            },
              ),
          const SizedBox(height: 24),
          //test fiels input for password
                 TextField(
            controller: _passwordController,
            //  labelText: 'enter your username',
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.createpassword,
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
            onChanged: (value) {
              _passwordController.text = value;
            },
          ),
          const SizedBox(height: 24),

          //button login

          InkWell(
            onTap: signUpUser,
            child: Container(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: primaryColor,
                      ),
                    )
                  :  Text(AppLocalizations.of(context)!.signup),
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
          const SizedBox(height: 12),
          Flexible(
            child: Container(),
            flex: 2,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                child: Text(AppLocalizations.of(context)!.allreadyhaveanaccount,
                      style: TextStyle(
                    color: Colors.white, // Change the input text color to blue
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              GestureDetector(
                onTap: navigateToLogin,
                child: Container(
                  child: Text(
                    AppLocalizations.of(context)!.login,
                    style: TextStyle(fontWeight: FontWeight.bold,
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
