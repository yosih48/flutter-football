
import 'package:flutter/material.dart';
import 'package:football/widgets/text_field_input.dart';

import '../resources/auth.dart';
import '../responsive/mobile_screen_layout.dart';
import '../responsive/rsponsive_layout_screen.dart';
import '../responsive/web_screen_layout.dart';
import '../utils/colors.dart';
import '../utils/utils.dart';

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

  // void signUpUser() async {
  //   setState(() {
  //     _isLoading = true;
  //   });
  //   String res = await AuthMethods().signUpUser(
  //     email: _emailController.text,
  //     password: _passwordController.text,
  //     username: _usernameController.text,
  //   );
  //   setState(() {
  //     _isLoading = false;
  //   });
  //   if (res != 'success') {
  //     showSnackBar(context, res);
  //   } else {
  //     print('error signup');
  //     Navigator.of(context).pushReplacement(
  //       MaterialPageRoute(
  //         builder: (context) => const ResponsiveLayout(
  //           mobileScreenLayout: MobileScreenLayout(),
  //           webScreenLayout: WebScreenLayout(),
  //         ),
  //       ),
  //     );
  //   }
  // }

  void navigateToLogin() {
    // Navigator.of(context)
    //     .push(MaterialPageRoute(builder: (context) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          TextFieldInput(
              hintText: 'enter your username',
              textEditingController: _usernameController,
              textInputType: TextInputType.text),
          const SizedBox(height: 24),
          //test fiels input for email
          TextFieldInput(
              textEditingController: _emailController,
              hintText: 'enter your email',
              textInputType: TextInputType.emailAddress),
          const SizedBox(height: 24),
          //test fiels input for password
          TextFieldInput(
            textEditingController: _passwordController,
            hintText: 'enter your password',
            textInputType: TextInputType.text,
            isPass: true,
          ),
          const SizedBox(height: 24),

          //button login

          InkWell(
            // onTap: signUpUser,
            child: Container(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: primaryColor,
                      ),
                    )
                  : const Text('sign up'),
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
                child: Text('allready have an account?'),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              GestureDetector(
                onTap: navigateToLogin,
                child: Container(
                  child: Text(
                    'login',
                    style: TextStyle(fontWeight: FontWeight.bold),
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
