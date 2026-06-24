import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:football/models/games.dart';
import 'package:football/models/recent_form.dart';
import 'package:football/widgets/RecentFormBlock.dart';

Game _game(int id, String home, String away, int hg, int ag) => Game.fromJson({
      'fixture': {
        'id': id, 'referee': null, 'timezone': 'UTC',
        'date': '2026-01-0$id' 'T20:00:00Z', 'timestamp': 1767297600,
        'periods': {'first': null, 'second': null},
        'venue': {'id': 0, 'name': '', 'city': ''},
        'status': {'long': 'Match Finished', 'short': 'FT', 'elapsed': null},
      },
      'league': {
        'id': 140, 'name': 'La Liga', 'country': 'Spain',
        'logo': null, 'flag': null, 'season': 2025, 'round': '',
      },
      'teams': {
        'home': {'id': 10, 'name': home, 'logo': 'a.png', 'winner': hg > ag},
        'away': {'id': 20, 'name': away, 'logo': 'b.png', 'winner': ag > hg},
      },
      'goals': {'home': hg, 'away': ag},
      'score': {
        'halftime': {'home': 0, 'away': 0},
        'fulltime': {'home': hg, 'away': ag},
        'extratime': {'home': null, 'away': null},
        'penalty': {'home': null, 'away': null},
      },
    });

void main() {
  testWidgets('RecentFormBlock renders pills and a row per match, taps fire', (tester) async {
    final rf = RecentForm(
      matches: [_game(1, 'Alpha', 'Beta', 2, 0), _game(2, 'Gamma', 'Alpha', 1, 1)],
      form: ['W', 'D'],
      played: 2, wins: 1, draws: 1, losses: 0, goalsFor: 3, goalsAgainst: 1,
      source: 'cache',
    );
    int? tapped;

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      locale: const Locale('en'),
      home: Scaffold(
        body: RecentFormBlock(
          teamId: 10,
          data: rf,
          onMatchTap: (g) => tapped = g.fixtureId,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('W'), findsWidgets);
    expect(find.text('D'), findsWidgets);
    expect(find.text('Alpha'), findsWidgets);

    await tester.tap(find.text('Beta').first);
    await tester.pumpAndSettle();
    expect(tapped, 1);
  });
}
