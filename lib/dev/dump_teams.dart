import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:football/resources/gamesMethods.dart';

Future<void> dumpAllTeams(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger.showSnackBar(
    const SnackBar(content: Text('Fetching all games to extract teams...')),
  );

  try {
    final games = await GamesMethods().fetchAllGames(-1, false);

    final Map<int, String> teams = {};
    for (final g in games) {
      teams[g.home.id] = g.home.name;
      teams[g.away.id] = g.away.name;
    }

    final sortedEntries = teams.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final out = <String, String>{
      for (final e in sortedEntries) e.key.toString(): e.value,
    };
    final jsonStr = const JsonEncoder.withIndent('  ').convert(out);

    debugPrint('===== TEAMS DUMP (${teams.length} unique) =====');
    debugPrint(jsonStr);
    debugPrint('===== END =====');

    await Clipboard.setData(ClipboardData(text: jsonStr));

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Copied ${teams.length} teams to clipboard'),
        duration: const Duration(seconds: 4),
      ),
    );
  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text('Dump failed: $e')),
    );
  }
}
