class Game {
  final int fixtureId;
  final String? referee;
  final String timezone;
  final DateTime date;
  final int timestamp;
  final Map<String, int?> periods;
  final Venue venue;
  final Status status;
  final League league;
  final Team home;
  final Team away;
  final Goals goals;
  final Score score;
  final Odds odds;

  Game({
    required this.fixtureId,
   this.referee,
    required this.timezone,
    required this.date,
    required this.timestamp,
    required this.periods,
    required this.venue,
    required this.status,
    required this.league,
    required this.home,
    required this.away,
    required this.goals,
    required this.score,
    required this.odds,
  });

  factory Game.fromJson(Map<String, dynamic> json) {
    return Game(
      fixtureId: json['fixture']['id'],
      referee: json['fixture']['referee'],
      timezone: json['fixture']['timezone'],
      date: DateTime.parse(json['fixture']['date']),
      timestamp: json['fixture']['timestamp'],
      periods: {
        'first': json['fixture']['periods']['first'],
        'second': json['fixture']['periods']['second'],
      },
      venue: Venue.fromJson(json['fixture']['venue']),
      status: Status.fromJson(json['fixture']['status']),
      league: League.fromJson(json['league']),
      home: Team.fromJson(json['teams']['home']),
      away: Team.fromJson(json['teams']['away']),
      goals: Goals.fromJson(json['goals']),
      score: Score.fromJson(json['score']),
      odds: Odds.fromJson(
          json['odds'] ?? {'away': '10', 'home': '10', 'draw': '10'}),
    );
  }
}

class Odds {
  final double home;
  final double draw;
  final double away;

  Odds({
    required this.home,
    required this.draw,
    required this.away,
  });

  factory Odds.fromJson(Map<String, dynamic> json) {
    return Odds(
      home: _parseDoubleOrDefault(json['Home'], 10),
      draw: _parseDoubleOrDefault(json['Draw'], 10),
      away: _parseDoubleOrDefault(json['Away'], 10),
    );
  }

  static double _parseDoubleOrDefault(dynamic value, double defaultValue) {
    if (value == null) return defaultValue;
    try {
      return double.parse(value.toString());
    } catch (e) {
      return defaultValue;
    }
  }
}

class Venue {
  final int id;
  final String name;
  final String city;

  Venue({
    required this.id,
    required this.name,
    required this.city,
  });

  factory Venue.fromJson(Map<String, dynamic> json) {
    return Venue(
      id: json['id'],
      name: json['name'],
      city: json['city'],
    );
  }
}

class Status {
  final String long;
  final String short;
  final int? elapsed;

  Status({
    required this.long,
    required this.short,
    required this.elapsed,
  });

  factory Status.fromJson(Map<String, dynamic> json) {
    return Status(
      long: json['long'],
      short: json['short'],
      elapsed: json['elapsed'],
    );
  }
}

class League {
  final int id;
  final String name;
  final String country;
  final String? logo;
  final String? flag;
  final int season;
  final String round;

  League({
    required this.id,
    required this.name,
    required this.country,
    this.logo,
    this.flag,
    required this.season,
    required this.round,
  });

  factory League.fromJson(Map<String, dynamic> json) {
    return League(
      id: json['id'],
      name: json['name'],
      country: json['country'],
      logo: json['logo'],
      flag: json['flag'],
      season: json['season'],
      round: json['round'],
    );
  }
}

class Team {
  final int id;
  final String name;
  final String logo;
  final bool? winner;

  Team({
    required this.id,
    required this.name,
    required this.logo,
    this.winner,
  });

  factory Team.fromJson(Map<String, dynamic> json) {
    return Team(
      id: json['id'],
      name: json['name'],
      logo: json['logo'],
      winner: json['winner'],
    );
  }
}

class Goals {
  final int? home;
  final int? away;

  Goals({
    required this.home,
    required this.away,
  });

  factory Goals.fromJson(Map<String, dynamic> json) {
    return Goals(
      home: json['home'],
      away: json['away'],
    );
  }
}

class Score {
  final Map<String, int?> halftime;
  final Map<String, int?> fulltime;
  final Map<String, int?> extratime;
  final Map<String, int?> penalty;

  Score({
    required this.halftime,
    required this.fulltime,
    required this.extratime,
    required this.penalty,
  });

  factory Score.fromJson(Map<String, dynamic> json) {
    return Score(
      halftime: {
        'home': json['halftime']['home'],
        'away': json['halftime']['away'],
      },
      fulltime: {
        'home': json['fulltime']['home'],
        'away': json['fulltime']['away'],
      },
      extratime: {
        'home': json['extratime']['home'],
        'away': json['extratime']['away'],
      },
      penalty: {
        'home': json['penalty']['home'],
        'away': json['penalty']['away'],
      },
    );
  }
}
