class LineupResponse {
  final bool success;
  final String fixtureId;
  final List<TeamLineup>? lineups;
  final bool available;
  final bool predicted;
  final String? message;

  LineupResponse({
    required this.success,
    required this.fixtureId,
    this.lineups,
    this.available = true,
    this.predicted = false,
    this.message,
  });

  factory LineupResponse.fromJson(Map<String, dynamic> json) {
    List<TeamLineup>? lineups;
    if (json['lineups'] != null && json['lineups'] is List) {
      lineups = (json['lineups'] as List)
          .map((e) => TeamLineup.fromJson(e))
          .toList();
    }

    return LineupResponse(
      success: json['success'] ?? false,
      fixtureId: (json['fixtureId'] ?? '').toString(),
      lineups: lineups,
      available: json['available'] ?? (lineups != null && lineups.isNotEmpty),
      predicted: json['predicted'] == true,
      message: json['message'],
    );
  }
}

class TeamLineup {
  final LineupTeam team;
  final String formation;
  final List<LineupPlayer> startXI;
  final List<LineupPlayer> substitutes;
  final LineupCoach? coach;

  TeamLineup({
    required this.team,
    required this.formation,
    required this.startXI,
    required this.substitutes,
    this.coach,
  });

  factory TeamLineup.fromJson(Map<String, dynamic> json) {
    final startXIList = (json['startXI'] as List? ?? [])
        .map((e) => LineupPlayer.fromJson(e['player'] ?? e))
        .toList();
    final subsList = (json['substitutes'] as List? ?? [])
        .map((e) => LineupPlayer.fromJson(e['player'] ?? e))
        .toList();

    return TeamLineup(
      team: LineupTeam.fromJson(json['team'] ?? {}),
      formation: json['formation'] ?? '',
      startXI: startXIList,
      substitutes: subsList,
      coach: json['coach'] != null ? LineupCoach.fromJson(json['coach']) : null,
    );
  }
}

class LineupTeam {
  final int id;
  final String name;
  final String? logo;

  LineupTeam({required this.id, required this.name, this.logo});

  factory LineupTeam.fromJson(Map<String, dynamic> json) {
    return LineupTeam(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      logo: json['logo'],
    );
  }
}

class LineupPlayer {
  final int id;
  final String name;
  final int number;
  final String? pos;
  final String? grid;
  final double? rating;
  final bool captain;
  final String? photo;

  LineupPlayer({
    required this.id,
    required this.name,
    required this.number,
    this.pos,
    this.grid,
    this.rating,
    this.captain = false,
    this.photo,
  });

  factory LineupPlayer.fromJson(Map<String, dynamic> json) {
    return LineupPlayer(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      number: json['number'] ?? 0,
      pos: json['pos'],
      grid: json['grid'],
      rating: (json['rating'] as num?)?.toDouble(),
      captain: json['captain'] == true,
      photo: json['photo'],
    );
  }
}

class LineupCoach {
  final int id;
  final String name;
  final String? photo;

  LineupCoach({required this.id, required this.name, this.photo});

  factory LineupCoach.fromJson(Map<String, dynamic> json) {
    return LineupCoach(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      photo: json['photo'],
    );
  }
}
