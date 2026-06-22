/// Head-to-head data for a fixture, derived by the backend from already-cached
/// fixtures (no external API call). See `head_to_head_service.dart`.
class HeadToHead {
  final H2HSummary summary;
  final List<H2HMeeting> meetings;

  HeadToHead({required this.summary, required this.meetings});

  factory HeadToHead.fromJson(Map<String, dynamic> json) {
    final rawMeetings = (json['meetings'] as List?) ?? [];
    return HeadToHead(
      summary: H2HSummary.fromJson(
        json['summary'] as Map<String, dynamic>? ?? {},
      ),
      meetings: rawMeetings
          .whereType<Map<String, dynamic>>()
          .map((m) => H2HMeeting.fromJson(m))
          .toList(),
    );
  }
}

/// Aggregate record, normalized so team A is the current fixture's home team.
class H2HSummary {
  final int teamAId;
  final int teamBId;
  final int aWins;
  final int bWins;
  final int draws;
  final int aGoals;
  final int bGoals;

  H2HSummary({
    required this.teamAId,
    required this.teamBId,
    required this.aWins,
    required this.bWins,
    required this.draws,
    required this.aGoals,
    required this.bGoals,
  });

  factory H2HSummary.fromJson(Map<String, dynamic> json) {
    return H2HSummary(
      teamAId: (json['teamAId'] as num?)?.toInt() ?? 0,
      teamBId: (json['teamBId'] as num?)?.toInt() ?? 0,
      aWins: (json['aWins'] as num?)?.toInt() ?? 0,
      bWins: (json['bWins'] as num?)?.toInt() ?? 0,
      draws: (json['draws'] as num?)?.toInt() ?? 0,
      aGoals: (json['aGoals'] as num?)?.toInt() ?? 0,
      bGoals: (json['bGoals'] as num?)?.toInt() ?? 0,
    );
  }

  int get total => aWins + bWins + draws;
}

/// A single past meeting between the two teams.
class H2HMeeting {
  final int fixtureId;
  final DateTime? date;
  final int leagueId;
  final String leagueName;
  final int homeTeamId;
  final String homeName;
  final String homeLogo;
  final int awayTeamId;
  final String awayName;
  final String awayLogo;
  final int? homeGoals;
  final int? awayGoals;

  H2HMeeting({
    required this.fixtureId,
    required this.date,
    required this.leagueId,
    required this.leagueName,
    required this.homeTeamId,
    required this.homeName,
    required this.homeLogo,
    required this.awayTeamId,
    required this.awayName,
    required this.awayLogo,
    required this.homeGoals,
    required this.awayGoals,
  });

  factory H2HMeeting.fromJson(Map<String, dynamic> json) {
    return H2HMeeting(
      fixtureId: (json['fixtureId'] as num?)?.toInt() ?? 0,
      date: DateTime.tryParse(json['date']?.toString() ?? ''),
      leagueId: (json['leagueId'] as num?)?.toInt() ?? 0,
      leagueName: json['leagueName']?.toString() ?? '',
      homeTeamId: (json['homeTeamId'] as num?)?.toInt() ?? 0,
      homeName: json['homeName']?.toString() ?? '',
      homeLogo: json['homeLogo']?.toString() ?? '',
      awayTeamId: (json['awayTeamId'] as num?)?.toInt() ?? 0,
      awayName: json['awayName']?.toString() ?? '',
      awayLogo: json['awayLogo']?.toString() ?? '',
      homeGoals: (json['homeGoals'] as num?)?.toInt(),
      awayGoals: (json['awayGoals'] as num?)?.toInt(),
    );
  }
}
