import 'package:football/models/games.dart';

/// Season record for a single team, computed from already-loaded fixtures.
/// Pure client-side — no network call. See [TeamStatisticsService.compute].
class TeamStatistics {
  final int played;
  final int won;
  final int drawn;
  final int lost;
  final int goalsFor;
  final int goalsAgainst;

  const TeamStatistics({
    required this.played,
    required this.won,
    required this.drawn,
    required this.lost,
    required this.goalsFor,
    required this.goalsAgainst,
  });

  int get goalDiff => goalsFor - goalsAgainst;

  static const empty = TeamStatistics(
    played: 0,
    won: 0,
    drawn: 0,
    lost: 0,
    goalsFor: 0,
    goalsAgainst: 0,
  );
}

class TeamStatisticsService {
  /// Statuses that mark a fixture as finished (a counted result).
  static const Set<String> _finished = {'FT', 'AET', 'PEN'};

  /// Tallies [teamId]'s record over the finished games in [games].
  /// Games the team didn't play in, or that aren't finished, are ignored.
  static TeamStatistics compute(List<Game> games, int teamId) {
    int played = 0, won = 0, drawn = 0, lost = 0, gf = 0, ga = 0;

    for (final g in games) {
      if (!_finished.contains(g.status.short)) continue;
      final isHome = g.home.id == teamId;
      final isAway = g.away.id == teamId;
      if (!isHome && !isAway) continue;

      final myGoals = isHome ? g.goals.home : g.goals.away;
      final oppGoals = isHome ? g.goals.away : g.goals.home;
      if (myGoals == null || oppGoals == null) continue;

      played++;
      gf += myGoals;
      ga += oppGoals;
      if (myGoals > oppGoals) {
        won++;
      } else if (myGoals < oppGoals) {
        lost++;
      } else {
        drawn++;
      }
    }

    return TeamStatistics(
      played: played,
      won: won,
      drawn: drawn,
      lost: lost,
      goalsFor: gf,
      goalsAgainst: ga,
    );
  }
}
