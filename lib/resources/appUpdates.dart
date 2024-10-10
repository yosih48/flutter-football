
import 'package:package_info_plus/package_info_plus.dart';
import 'package:football/utils/config.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';




Future<void> checkForUpdates(BuildContext context) async {

PackageInfo packageInfo = await PackageInfo.fromPlatform();


String version = packageInfo.version;
String _baseUrl = '$backendUrl';
String CURRENT_VERSION = version; 

  try {
    // Make API call to check for updates
    final response = await http.get(Uri.parse('$_baseUrl/check-update'));

    if (response.statusCode == 200) {
        // print(response.body);
      final data = json.decode(response.body);
      String latestVersion = data['version'];
      String downloadUrl = data['downloadUrl'];
print('CURRENT_VERSION: ${CURRENT_VERSION}');
      if (latestVersion != CURRENT_VERSION) {
        // Show update dialog
        showUpdateDialog(context, downloadUrl);
      }
    } else {
      print(response.statusCode);
      print(response.body);
    }
  } catch (e) {
    print('Error checking for updates: $e');
  }
}



void showUpdateDialog(BuildContext context, String downloadUrl) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('Update Available'),
        content: Text(
            'A new version of the app is available. Would you like to update?'),
        actions: <Widget>[
          TextButton(
            child: Text('Later'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: Text('Update'),
              onPressed: () async {
              // final url = Uri.parse(downloadUrl);
              final url = Uri.parse(downloadUrl);

        
              try {
                print('Launching URL without check...');
                bool launched =
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                print('launchUrl result: $launched');

                if (!launched) {
                  throw 'URL launch returned false';
                }
              } catch (e) {
                print('Error in URL launch process: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to open download link: $e')),
                );
              }

              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}
