import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:football/providers/flutter pub add provider.dart';
import 'package:football/resources/auth.dart';
import 'package:football/theme/colors.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class AccountScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = authProvider.currentUser;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text(
          AppLocalizations.of(context)?.account ?? 'Account',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: user == null
          ? Center(
              child:
                  Text('No user found', style: TextStyle(color: Colors.white)))
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    AppLocalizations.of(context)?.userdetails ?? 'User Details',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 24),
                  Row(
                    children: [
                      Icon(Icons.person, color: Colors.blue),
                      SizedBox(width: 12),
                      Text(user.name ?? '-',
                          style: TextStyle(color: Colors.white, fontSize: 16)),
                    ],
                  ),
                  SizedBox(height: 24),
                  Row(
                    children: [
                      Icon(Icons.email, color: Colors.blue),
                      SizedBox(width: 12),
                      Text(user.email ?? '-',
                          style: TextStyle(color: Colors.white, fontSize: 16)),
                    ],
                  ),
                  Spacer(),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 🔁 Sign Out button as ElevatedButton
                        Container(
                          width: double.infinity,
                          margin: EdgeInsets.only(left: 16),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: Icon(Icons.exit_to_app),
                            label: Text(AppLocalizations.of(context)!.signout),
                            onPressed: () async {
                              final authProvider = Provider.of<AuthProvider>(
                                  context,
                                  listen: false);
                              bool? confirmSignOut = await showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    backgroundColor: cards,
                                    title: Text(
                                      AppLocalizations.of(context)!
                                          .confirmsignout,
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 16),
                                    ),
                                    content: Text(
                                      AppLocalizations.of(context)!.leaveapp,
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    actions: <Widget>[
                                      TextButton(
                                        child: Text(
                                          AppLocalizations.of(context)!.cancel,
                                          style: TextStyle(color: Colors.blue),
                                        ),
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                      ),
                                      TextButton(
                                        child: Text(
                                          AppLocalizations.of(context)!.yes,
                                          style: TextStyle(color: Colors.red),
                                        ),
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                      ),
                                    ],
                                  );
                                },
                              );

                              if (confirmSignOut == true) {
                                print('confirmSignOut == true');
                                Provider.of<UserProvider>(context,
                                        listen: false)
                                    .setSelectedGroupName('public');
                                await authProvider.signOut(user.id);
                                Navigator.of(context)
                                    .popUntil((route) => route.isFirst);
                              }
                            },
                          ),
                        ),

                        // 🔁 Delete button as TextButton
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                          ),
                          // icon: Icon(Icons.delete, color: Colors.red),
                         child: Text(
                            AppLocalizations.of(context)?.deleteaccount ??
                                'Delete Account',
                            style: TextStyle(color: Colors.red),
                          ),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: cards,
                                title: Text(
                                  AppLocalizations.of(context)?.deleteaccount ??
                                      'Delete Account',
                                  style: TextStyle(color: Colors.white),
                                ),
                                content: Text(
                                  AppLocalizations.of(context)
                                          ?.deleteaccountconfirm ??
                                      'Are you sure you want to delete your account? This cannot be undone.',
                                  style: TextStyle(color: Colors.white),
                                ),
                                actions: [
                                  TextButton(
                                    child: Text(
                                      AppLocalizations.of(context)?.cancel ??
                                          'Cancel',
                                      style: TextStyle(color: Colors.blue),
                                    ),
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                  ),
                                  TextButton(
                                    child: Text(
                                      AppLocalizations.of(context)?.delete ??
                                          'Delete',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              try {
                                // Show loading indicator
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (BuildContext context) {
                                    return Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  },
                                );

                                // Call your delete account logic here
                                bool deleteSuccess =
                                    await authProvider.deleteAccount(user.id);

                                if (deleteSuccess) {
                                  Navigator.of(context)
                                      .pop(); // Close loading dialog
                                  await authProvider.signOut(user.id);
                                  Navigator.of(context)
                                      .popUntil((route) => route.isFirst);

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        AppLocalizations.of(context)!
                                            .accountDeleted,
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                Navigator.of(context)
                                    .pop(); // Close loading dialog
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text('Failed to delete account: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
