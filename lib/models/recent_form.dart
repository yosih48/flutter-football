import 'package:football/models/games.dart';

/// Parsed response of `GET /teams/:teamId/last-matches`.
/// [matches] are full Game objects, most-recent first. [form] is the W/D/L/?
/// streak in the same order.
class RecentForm {
  final List<Game> matches;
  final List<String> form;
  final int played;
  final int wins;
  final int draws;
  final int losses;
  final int goalsFor;
  final int goalsAgainst;
  final String source;

  /// Team id the matches are oriented around. For cache-sourced data this is the
  /// API-FOOTBALL id; for the AllSport fallback it's the Sofascore id (the team
  /// ids inside [matches] are in the same namespace). Use this — not a locally
  /// resolved id — to compute per-match perspective. Null if not provided.
  final int? perspectiveTeamId;

  RecentForm({
    required this.matches,
    required this.form,
    required this.played,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.source,
    this.perspectiveTeamId,
  });

  bool get isEmpty => matches.isEmpty;

  factory RecentForm.fromJson(Map<String, dynamic> json) {
    final s = (json['summary'] as Map<String, dynamic>?) ?? const {};
    final rawMatches = (json['matches'] as List?) ?? const [];
    int asInt(dynamic v) => (v as num?)?.toInt() ?? 0;

    return RecentForm(
      matches: rawMatches
          .whereType<Map<String, dynamic>>()
          .map((m) => Game.fromJson(m))
          .toList(),
      form: ((s['form'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      played: asInt(s['played']),
      wins: asInt(s['wins']),
      draws: asInt(s['draws']),
      losses: asInt(s['losses']),
      goalsFor: asInt(s['goalsFor']),
      goalsAgainst: asInt(s['goalsAgainst']),
      source: json['source']?.toString() ?? 'cache',
      perspectiveTeamId: (json['perspectiveTeamId'] as num?)?.toInt(),
    );
  }
}
