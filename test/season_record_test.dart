import 'package:flutter_test/flutter_test.dart';
import 'package:football/models/season_record.dart';

void main() {
  test('SeasonRecord.fromJson parses a full record', () {
    final r = SeasonRecord.fromJson({
      'leagueId': 39,
      'season': 2025,
      'current': true,
      'points': 120,
      'rank': 3,
      'totalPlayers': 45,
      'winnerPick': 'Manchester City',
      'championName': 'Liverpool',
      'championCorrect': false,
      'championPoints': 0,
      'topScorerPick': 'Erling Haaland',
      'topScorerPoints': 18,
      'bracketPoints': 0,
    });
    expect(r.leagueId, 39);
    expect(r.season, 2025);
    expect(r.current, true);
    expect(r.points, 120);
    expect(r.rank, 3);
    expect(r.totalPlayers, 45);
    expect(r.winnerPick, 'Manchester City');
    expect(r.championName, 'Liverpool');
    expect(r.championCorrect, false);
    expect(r.topScorerPick, 'Erling Haaland');
    expect(r.topScorerPoints, 18);
    expect(r.bracketPoints, 0);
  });

  test('SeasonRecord.fromJson tolerates nulls and missing fields', () {
    final r = SeasonRecord.fromJson({'leagueId': 39, 'season': 2025});
    expect(r.leagueId, 39);
    expect(r.rank, isNull);
    expect(r.points, 0);
    expect(r.winnerPick, isNull);
    expect(r.championCorrect, false);
    expect(r.current, false);
  });
}
