import 'package:flutter_test/flutter_test.dart';
import 'package:football/models/recent_form.dart';

void main() {
  test('RecentForm.fromJson parses summary and matches', () {
    final json = {
      'success': true,
      'teamId': 10,
      'source': 'cache',
      'summary': {
        'played': 1,
        'wins': 1,
        'draws': 0,
        'losses': 0,
        'goalsFor': 2,
        'goalsAgainst': 0,
        'form': ['W'],
      },
      'matches': [
        {
          'fixture': {
            'id': 123,
            'referee': null,
            'timezone': 'UTC',
            'date': '2026-01-01T20:00:00Z',
            'timestamp': 1767297600,
            'periods': {'first': null, 'second': null},
            'venue': {'id': 0, 'name': '', 'city': ''},
            'status': {'long': 'Match Finished', 'short': 'FT', 'elapsed': null},
          },
          'league': {
            'id': 140, 'name': 'La Liga', 'country': 'Spain',
            'logo': null, 'flag': null, 'season': 2025, 'round': '',
          },
          'teams': {
            'home': {'id': 10, 'name': 'Alpha', 'logo': 'a.png', 'winner': true},
            'away': {'id': 20, 'name': 'Beta', 'logo': 'b.png', 'winner': false},
          },
          'goals': {'home': 2, 'away': 0},
          'score': {
            'halftime': {'home': 1, 'away': 0},
            'fulltime': {'home': 2, 'away': 0},
            'extratime': {'home': null, 'away': null},
            'penalty': {'home': null, 'away': null},
          },
        },
      ],
    };

    final rf = RecentForm.fromJson(json);
    expect(rf.form, ['W']);
    expect(rf.wins, 1);
    expect(rf.goalsFor, 2);
    expect(rf.source, 'cache');
    expect(rf.matches.length, 1);
    expect(rf.matches.first.fixtureId, 123);
    expect(rf.matches.first.home.name, 'Alpha');
  });
}
