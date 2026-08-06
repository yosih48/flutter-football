import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:football/models/season_record.dart';
import 'package:football/resources/trophyMethods.dart';
import 'package:football/widgets/trophyCabinet.dart';

class _FakeTrophyMethods extends TrophyMethods {
  const _FakeTrophyMethods(this.history);
  final List<SeasonRecord> history;
  @override
  Future<List<SeasonRecord>> fetchHistory(String userId) async => history;
}

SeasonRecord _rec({
  int leagueId = 39,
  int season = 2025,
  int rank = 1,
  int totalPlayers = 10,
}) =>
    SeasonRecord.fromJson({
      'leagueId': leagueId,
      'season': season,
      'current': false,
      'points': 100,
      'rank': rank,
      'totalPlayers': totalPlayers,
      'winnerPick': 'Man City',
      'championName': 'Man City',
      'championCorrect': true,
      'championPoints': 20,
      'topScorerPick': 'Haaland',
      'topScorerPoints': 12,
      'bracketPoints': 0,
    });

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  testWidgets('shows empty state when there is no history', (tester) async {
    await tester.pumpWidget(_wrap(TrophyCabinetTab(
      userId: 'u1',
      methods: const _FakeTrophyMethods([]),
    )));
    await tester.pumpAndSettle();
    expect(find.text('NO TROPHIES YET'), findsOneWidget);
  });

  testWidgets('renders an archived season card with rank badge',
      (tester) async {
    await tester.pumpWidget(_wrap(TrophyCabinetTab(
      userId: 'u1',
      methods:
          _FakeTrophyMethods([_rec(season: 2026, rank: 1, totalPlayers: 42)]),
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('2026'), findsWidgets);
    // Rank medallion carries the bare position; the field size sits under it.
    expect(find.text('1'), findsWidgets);
    expect(find.text('of 42'), findsOneWidget);
  });

  testWidgets('summary bar totals points, podiums and wins', (tester) async {
    await tester.pumpWidget(_wrap(TrophyCabinetTab(
      userId: 'u1',
      methods: _FakeTrophyMethods([
        _rec(leagueId: 39, season: 2026, rank: 1),
        _rec(leagueId: 140, season: 2026, rank: 4),
      ]),
    )));
    await tester.pumpAndSettle();
    // Each _rec is worth 100 points; one podium (rank 1), one win.
    expect(find.text('200'), findsOneWidget);
    expect(find.text('Total Points'), findsOneWidget);
    expect(find.text('Podiums'), findsOneWidget);
    expect(find.text('First Places'), findsOneWidget);
  });

  testWidgets('shows history for every league the user ever played',
      (tester) async {
    // Trophies are permanent: a past-season record must appear even though the
    // widget no longer knows or cares which leagues the user is enrolled in now.
    await tester.pumpWidget(_wrap(TrophyCabinetTab(
      userId: 'u1',
      methods: _FakeTrophyMethods([_rec(leagueId: 39, season: 2025)]),
    )));
    await tester.pumpAndSettle();
    expect(find.text('NO TROPHIES YET'), findsNothing);
    expect(find.textContaining('2025'), findsWidgets);
  });

  testWidgets('groups records by season, newest first', (tester) async {
    await tester.pumpWidget(_wrap(TrophyCabinetTab(
      userId: 'u1',
      methods: _FakeTrophyMethods([
        _rec(season: 2024),
        _rec(season: 2026),
      ]),
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('2024'), findsWidgets);
    expect(find.textContaining('2026'), findsWidgets);
  });
}
