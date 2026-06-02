// Data models for the World Cup bracket-prediction game. Mirror the backend
// shapes: GET /brackets/structure/:leagueId (static config from
// worldCupBracket.json) and GET /brackets/:userId/:leagueId (a user's picks).

// One stage of the tournament (group stage or a knockout round).
class BracketStage {
  final String key; // groups | R32 | R16 | QF | SF | F
  final String labelEn;
  final String labelHe;
  final String kind; // groups | knockout
  final String? advanceTo; // groups -> "R32"
  final int? advancers; // knockout: teams that reach the next round
  final int qualifierPoints; // groups
  final int orderBonus; // groups
  final int points; // knockout flat award
  final DateTime? lockAt; // null = not locked

  BracketStage({
    required this.key,
    required this.labelEn,
    required this.labelHe,
    required this.kind,
    this.advanceTo,
    this.advancers,
    this.qualifierPoints = 0,
    this.orderBonus = 0,
    this.points = 0,
    this.lockAt,
  });

  factory BracketStage.fromJson(Map<String, dynamic> j) {
    final label = j['label'] as Map<String, dynamic>? ?? {};
    final pts = j['points'];
    return BracketStage(
      key: j['key']?.toString() ?? '',
      labelEn: label['en']?.toString() ?? j['key']?.toString() ?? '',
      labelHe: label['he']?.toString() ?? j['key']?.toString() ?? '',
      kind: j['kind']?.toString() ?? '',
      advanceTo: j['advanceTo']?.toString(),
      advancers: (j['advancers'] as num?)?.toInt(),
      qualifierPoints: pts is Map ? (pts['qualifier'] as num?)?.toInt() ?? 0 : 0,
      orderBonus: pts is Map ? (pts['orderBonus'] as num?)?.toInt() ?? 0 : 0,
      points: pts is num ? pts.toInt() : 0,
      lockAt: _parseDate(j['lockAt']),
    );
  }

  String label(String langCode) => langCode == 'he' ? labelHe : labelEn;

  // A stage is locked once its lockAt has passed. null lockAt = never locked
  // by time (knockout rounds gate on team availability, handled in the UI).
  bool isLocked(DateTime now) => lockAt != null && now.isAfter(lockAt!);

  static DateTime? _parseDate(dynamic v) {
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v)?.toUtc();
    return null;
  }
}

// Static tournament structure: format + ordered stages.
class BracketStructure {
  final int leagueId;
  final int season;
  final int groupCount;
  final List<String> groupIds;
  final int qualifiersPerGroup;
  final int bestThirds;
  final List<BracketStage> stages;

  BracketStructure({
    required this.leagueId,
    required this.season,
    required this.groupCount,
    required this.groupIds,
    required this.qualifiersPerGroup,
    required this.bestThirds,
    required this.stages,
  });

  factory BracketStructure.fromJson(Map<String, dynamic> j) {
    final format = j['format'] as Map<String, dynamic>? ?? {};
    final rawStages = j['stages'] as List<dynamic>? ?? [];
    return BracketStructure(
      leagueId: (j['leagueId'] as num?)?.toInt() ?? 0,
      season: (j['season'] as num?)?.toInt() ?? 0,
      groupCount: (format['groupCount'] as num?)?.toInt() ?? 0,
      groupIds: (format['groupIds'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      qualifiersPerGroup: (format['qualifiersPerGroup'] as num?)?.toInt() ?? 2,
      bestThirds: (format['bestThirds'] as num?)?.toInt() ?? 0,
      stages: rawStages
          .whereType<Map<String, dynamic>>()
          .map(BracketStage.fromJson)
          .toList(),
    );
  }

  BracketStage? stage(String key) {
    for (final s in stages) {
      if (s.key == key) return s;
    }
    return null;
  }

  // The ordered knockout stages (excludes groups).
  List<BracketStage> get knockoutStages =>
      stages.where((s) => s.kind == 'knockout').toList();
}

// A user's saved picks. The backend returns an empty shell when the user has
// not started, so every field is defaulted.
class UserBracket {
  final String userId;
  final int leagueId;
  final int season;

  // group id -> [1st, 2nd] predicted finish order.
  final Map<String, List<String>> groupPicks;

  // stage key -> teams predicted to advance to the next round.
  final Map<String, List<String>> advancePicks;

  // stage key -> points awarded (settlement-filled, display only).
  final Map<String, int> stagePoints;

  UserBracket({
    required this.userId,
    required this.leagueId,
    required this.season,
    required this.groupPicks,
    required this.advancePicks,
    required this.stagePoints,
  });

  factory UserBracket.fromJson(Map<String, dynamic> j) {
    return UserBracket(
      userId: j['userID']?.toString() ?? '',
      leagueId: (j['leagueID'] as num?)?.toInt() ?? 0,
      season: (j['season'] as num?)?.toInt() ?? 0,
      groupPicks: _strListMap(j['groupPicks']),
      advancePicks: _strListMap(j['advancePicks']),
      stagePoints: _intMap(j['stagePoints']),
    );
  }

  int get totalPoints =>
      stagePoints.values.fold(0, (a, b) => a + b);

  static Map<String, List<String>> _strListMap(dynamic v) {
    final out = <String, List<String>>{};
    if (v is Map) {
      v.forEach((k, val) {
        if (val is List) {
          out[k.toString()] =
              val.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
        }
      });
    }
    return out;
  }

  static Map<String, int> _intMap(dynamic v) {
    final out = <String, int>{};
    if (v is Map) {
      v.forEach((k, val) {
        if (val is num) out[k.toString()] = val.toInt();
      });
    }
    return out;
  }
}
