import 'package:flutter/material.dart';
import 'package:football/theme/colors.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class UpdateDialog extends StatelessWidget {
  final String downloadUrl;
  const UpdateDialog({Key? key, required this.downloadUrl}) : super(key: key);

  Future<void> _launchUrl(BuildContext context) async {
    final url = Uri.parse(downloadUrl);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open download link: $e')),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: cards,
      title: Text(
        AppLocalizations.of(context)!.updateavailable,
        style: TextStyle(color: Colors.white, fontSize: 16),
      ),
      content: Text(
        AppLocalizations.of(context)!.askforupdate,
        style: TextStyle(color: Colors.white, fontSize: 14),
      ),
      actions: <Widget>[
        TextButton(
          child: Text(
            AppLocalizations.of(context)!.later,
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          child: Text(
            AppLocalizations.of(context)!.update,
            style: TextStyle(color: Colors.blue, fontSize: 14),
          ),
          onPressed: () async {
            // final url = Uri.parse(downloadUrl);
            // try {
            //   print('Launching URL...');
            //   bool launched =
            //       await launchUrl(url, mode: LaunchMode.externalApplication);
            //   print('launchUrl result: $launched');
            //   if (!launched) {
            //     throw 'URL launch returned false';
            //   }
            // } catch (e) {
            //   print('Error in URL launch process: $e');
            //   ScaffoldMessenger.of(context).showSnackBar(
            //     SnackBar(content: Text('Failed to open download link: $e')),
            //   );
            // }
              _launchUrl(context);
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
