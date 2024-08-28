class Users {
  final String id;
  final String displayName;
  final String email;
  final bool isAdmin;
  final Map<String, int> points;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, int> thisDayPoints;
  final Map<String, bool> snetEmail;
  final Map<String, String> groupID;
  final Map<String, String> winner;

  Users({
    required this.id,
    required this.displayName,
    required this.email,
    required this.isAdmin,
    required this.points,
    required this.createdAt,
    required this.updatedAt,
    required this.thisDayPoints,
    required this.snetEmail,
    required this.groupID,
    required this.winner,
  });

  factory Users.fromJson(Map<String, dynamic> json) {
    print('Creating Users from JSON: $json');

    // Convert points from dynamic to int
    Map<String, int> convertPoints(Map<String, dynamic>? data) {
      return data?.map((key, value) => MapEntry(key, value as int)) ?? {};
    }

    // Convert snetEmail from dynamic to bool
    Map<String, bool> convertSnetEmail(Map<String, dynamic>? data) {
      return data?.map((key, value) => MapEntry(key, value as bool)) ?? {};
    }

    // Convert groupID from dynamic to String
    Map<String, String> convertGroupID(Map<String, dynamic>? data) {
      return data?.map((key, value) => MapEntry(key, value.toString())) ?? {};
    }

    // Convert winner from dynamic to String
    Map<String, String> convertWinner(Map<String, dynamic>? data) {
      return data?.map((key, value) => MapEntry(key, value.toString())) ?? {};
    }

    Users user = Users(
      id: json['_id'] ?? '', // Note the change from 'id' to '_id'
      displayName: json['displayName'] ?? '',
      email: json['email'] ?? '',
      isAdmin: json['isAdmin'] ?? false,
      points: convertPoints(json['points'] as Map<String, dynamic>?),
      createdAt: DateTime.parse(json['createdAt'] ?? ''),
      updatedAt: DateTime.parse(json['updatedAt'] ?? ''),
      thisDayPoints:
          convertPoints(json['thisDayPoints'] as Map<String, dynamic>?),
      snetEmail: convertSnetEmail(json['snetEmail'] as Map<String, dynamic>?),
      groupID: convertGroupID(json['groupID'] as Map<String, dynamic>?),
      winner: convertWinner(json['winner'] as Map<String, dynamic>?),
    );

    print('Created Users object: $user');
    print('Users ID: ${user.id}');

    return user;
  }

  @override
  String toString() {
    return 'user(id: $id, displayName: $displayName, email: $email, isAdmin: $isAdmin, points: $points, createdAt: $createdAt, updatedAt: $updatedAt, thisDayPoints: $thisDayPoints, snetEmail: $snetEmail, groupID: $groupID, winner: $winner)';
  }
}
