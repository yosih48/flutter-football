import 'package:flutter/material.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class StatusUtils {
  static Map<String, dynamic> getStatusInfo(
      String status, BuildContext context) {
    switch (status) {
      case "H1":
        return {
          "color": Colors.red,
          "text": AppLocalizations.of(context)!.firstHalf
        };
      case "H2":
        return {
          "color": Colors.red,
          "text": AppLocalizations.of(context)!.secondHalf
        };
      case "ET":
        return {
          "color": Colors.red,
          "text": AppLocalizations.of(context)!.extraTime
        };
      case "HT":
        return {
          "color": Colors.orange,
          "text": AppLocalizations.of(context)!.halftime
        };
      case "NS":
        return {
          "color": Colors.grey,
          "text": AppLocalizations.of(context)!.notStarted
        };
      case "FT":
        return {
          "color": Colors.green,
          "text": AppLocalizations.of(context)!.finished
        };
      case "Postponed":
        return {
          "color": Colors.yellow,
          "text": AppLocalizations.of(context)!.postponed
        };
      case "AET":
      case "BT":
        return {
          "color": Colors.green,
          "text": AppLocalizations.of(context)!.finishAfterExtraTime
        };
      case "PEN":
        return {
          "color": Colors.green,
          "text": AppLocalizations.of(context)!.finishAfterPenalties
        };
      case "TBD":
        return {"color": Colors.yellow, "text": "To Be Decided"};
      default:
        return {
          "color": const Color(0xFF9BA4B5).withOpacity(0.9),
          "text": "Unknown"
        };
    }
  }
}
