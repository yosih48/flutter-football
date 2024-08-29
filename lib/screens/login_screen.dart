// import 'package:businesses/models/employees.dart';
// import 'package:businesses/providers/flutter%20pub%20add%20provider.dart';
// import 'package:businesses/resources/Employees_methods.dart';
// import 'package:businesses/screens/employeesCalls.dart';
// import 'package:businesses/screens/signup_screen.dart';
// import 'package:businesses/utils/utils.dart';
import 'package:football/screens/signup_screen.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:football/models/users.dart';

import 'package:football/utils/utils.dart';

import '../providers/flutter pub add provider.dart';
import '../resources/auth.dart';
import '../responsive/mobile_screen_layout.dart';
import '../responsive/rsponsive_layout_screen.dart';
import '../responsive/web_screen_layout.dart';
import '../utils/colors.dart';
// import '../widgets/text_field_input.dart';
// import 'package:flutter_gen/gen_l10n/app_localizations.dart';
// import 'package:flutter_localizations/flutter_localizations.dart';

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

  void loginUsera() async {
    setState(() {
      _isLoading = true;
    });

     final authProvider = Provider.of<AuthProvider>(context, listen: false);
    authProvider.login(_usernameController.text, _passwordController.text);

    if (authProvider == 'success') {
      await Provider.of<UserProvider >(context, listen: false)
          .refreshUser(_usernameController.text);
      if (context.mounted) {
        User? currentUser =
            Provider.of<UserProvider>(context, listen: false)
                .currentUser;

        if (currentUser != null) {
     
            // Navigate to admin screen
            Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const ResponsiveLayout(
                    mobileScreenLayout: MobileScreenLayout(),
                    webScreenLayout: WebScreenLayout(),
                  ),
                ),
                (route) => false);

        }
      }

      setState(() {
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
      if (context.mounted) {
        // showSnackBar(context, res as String);
      }
    }
  }

  void loginUser() async {
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      await authProvider.login(
          _usernameController.text, _passwordController.text);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: ${e.toString()}')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
     final authProvider = Provider.of<AuthProvider>(context);
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
                    labelText: 'user name'),
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
                labelText: 'pass'),
          ),
          const SizedBox(height: 24),
         
 
          InkWell(
            onTap: authProvider.isLoading  ? null : loginUser,
            child: Container(
              child: authProvider.isLoading 
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: primaryColor,
                      ),
                    )
                  : Text('login'),
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
                child: Text('don have account'),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SignupScreen(),
                  ),
                ),
                child: Container(
                  child: Text(
                    'signup',
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
