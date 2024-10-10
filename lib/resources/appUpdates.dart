
import 'package:football/main.dart';
import 'package:football/widgets/updateDialog.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:football/utils/config.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';




Future<void> checkForUpdates() async {
print('checkForUpdates runing');
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
        showUpdateDialog( downloadUrl);
      }
    } else {
      print(response.statusCode);
      print(response.body);
    }
  } catch (e) {
    print('Error checking for updates: $e');
  }
}



void showUpdateDialog( String downloadUrl) {
    final context = navigatorKey.currentContext;
    print(context);
   if (context != null) {
    print(context != null);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return UpdateDialog(downloadUrl: downloadUrl);
      },
    );
  } else {
    print('Error: No context available to show the dialog.');
  }
}
