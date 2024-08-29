class User {
  final String id;
  final String name;
  final bool admin;
  final String email;
  final String? newToken;
  final Map<String, dynamic>? groups;
  final Map<String, dynamic>? groupID;

  User({
    required this.id,
    required this.name,
    required this.admin,
    required this.email,
    this.newToken,
    this.groups,
    this.groupID,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      admin: json['admin'] ?? false,
      email: json['email'] ?? '',
      newToken: json['newToken'],
      groups: json['groups'] != null ? Map<String, dynamic>.from(json['groups']) : null,
      groupID: json['groupID'] != null ? Map<String, dynamic>.from(json['groupID']) : null,
    );
  }

}