class User {
  final String _id;
  final String displayName;
  final String email;
  final String password;
  final bool isAdmin;
  final Map<String, int> points;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int _v;
  final Map<String, double> thisDayPoints;
  final Map<String, bool> snetEmail;
  final Map<String, String> groupID;
  final Map<String, String> winner;
  final List<Map<String, dynamic>> test;

  User({
    required String id,
    required this.displayName,
    required this.email,
    required this.password,
    required this.isAdmin,
    required this.points,
    required DateTime createdAt,
    required DateTime updatedAt,
    required int v,
    required this.thisDayPoints,
    required this.snetEmail,
    required this.groupID,
    required this.winner,
    required this.test,
  })  : _id = id,
        createdAt = createdAt,
        updatedAt = updatedAt,
        _v = v;

  String get id => _id;
  int get _version => _v;
    factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'],
      displayName: json['displayName'],
      email: json['email'],
      password: json['password'],
      isAdmin: json['isAdmin'],
      points: Map<String, int>.from(json['points']),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      v: json['__v'],
      thisDayPoints: Map<String, double>.from(json['thisDayPoints']),
      snetEmail: Map<String, bool>.from(json['snetEmail']),
      groupID: Map<String, String>.from(json['groupID']),
      winner: Map<String, String>.from(json['winner']),
      test: List<Map<String, dynamic>>.from(json['test']),
    );
  }
}