import 'package:football/resources/guessesMethods.dart';

class Guess {
  final String id;
  final String awayTeamGoals;
  final String homeTeamGoals;
  final int gameId;
  final int gameOriginalId;
  final String userId;
  final String email;
  final double expectedPoints;
  final double sumPoints;
  final int leagueId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int? direct;
  final int? direction;

  Guess({
    required this.id,
    required this.awayTeamGoals,
    required this.homeTeamGoals,
    required this.gameId,
    required this.gameOriginalId,
    required this.userId,
    required this.email,
    required this.expectedPoints,
    required this.sumPoints,
    required this.leagueId,
    required this.createdAt,
    required this.updatedAt,
    this.direct,
    this.direction,
  });

  factory Guess.fromJson(Map<String, dynamic> json) {
    return Guess(
      id: json['_id'],
      awayTeamGoals: json['away_team_goals'],
      homeTeamGoals: json['home_team_goals'],
      gameId: int.parse(json['gameID'].toString()),
      gameOriginalId: int.parse(json['gameOriginalID'].toString()),
      userId: json['userID'],
      email: json['email'],
      expectedPoints: double.parse(json['expectedPoints'].toString()),
      sumPoints: double.parse(json['sum_points'].toString()),
      leagueId: int.parse(json['leagueID'].toString()),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      direct: json['direct'] != null ? int.parse(json['direct'].toString()) : null,
      direction: json['direction'] != null ? int.parse(json['direction'].toString()) : null,
    );
  }
}

class GuessWithNames {
  final Guess guess;
  final String userName;


  GuessWithNames(this.guess, this.userName);
}
class CallService {
  final Map<String, String> _userNameCache = {};


  Future<GuessWithNames> getGuessWithNames(Guess guess) async {
    // print("Call details: ${guess.details}");
 

    String userName = await _getUserName(guess.userId);



    return GuessWithNames(guess, userName);
  }

  Future<String> _getUserName(String userId) async {
    if (_userNameCache.containsKey(userId)) {
      return _userNameCache[userId]!;
    }
    // Fetch from Firestore
    String name = await GuessesMethods()
        .fetchUserName(userId);
    _userNameCache[userId] = name;
    return name;
  }


}

