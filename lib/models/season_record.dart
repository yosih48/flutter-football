// One per-league season record. The same shape is returned by both
// GET /users/:id/season-summary (current:true, computed live) and
// GET /users/:id/history (archived past seasons), so the cabinet renders both
// identically.
class SeasonRecord {
  final int leagueId;
  final int season;
  final bool current;
  final int points;
  final int? rank;
  final int totalPlayers;
  final String? winnerPick;
  final String? championName;
  final bool championCorrect;
  final int championPoints;
  final String? topScorerPick;
  final int topScorerPoints;
  final int bracketPoints;

  const SeasonRecord({
    required this.leagueId,
    required this.season,
    required this.current,
    required this.points,
    required this.rank,
    required this.totalPlayers,
    required this.winnerPick,
    required this.championName,
    required this.championCorrect,
    required this.championPoints,
    required this.topScorerPick,
    required this.topScorerPoints,
    required this.bracketPoints,
  });

  static int _int(dynamic v) => (v is num) ? v.toInt() : 0;
  static int? _intOrNull(dynamic v) => (v is num) ? v.toInt() : null;
  static String? _strOrNull(dynamic v) =>
      (v == null || (v is String && v.trim().isEmpty)) ? null : v.toString();

  factory SeasonRecord.fromJson(Map<String, dynamic> json) => SeasonRecord(
        leagueId: _int(json['leagueId']),
        season: _int(json['season']),
        current: json['current'] == true,
        points: _int(json['points']),
        rank: _intOrNull(json['rank']),
        totalPlayers: _int(json['totalPlayers']),
        winnerPick: _strOrNull(json['winnerPick']),
        championName: _strOrNull(json['championName']),
        championCorrect: json['championCorrect'] == true,
        championPoints: _int(json['championPoints']),
        topScorerPick: _strOrNull(json['topScorerPick']),
        topScorerPoints: _int(json['topScorerPoints']),
        bracketPoints: _int(json['bracketPoints']),
      );
}
