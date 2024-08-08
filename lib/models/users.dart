class User {
  final String email;
  final String displayName;
  // final String isAdmin;

  User({
    required this.email,
    required this.displayName,
    //  required this.isAdmin
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      email: json['email'],
      displayName: json['displayName'],
      // isAdmin: json['isAdmin'],
    );
  }
}
