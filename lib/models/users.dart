import 'notif_pref.dart';

class User {
  final String id;
  final String name;
  final bool admin;
  final String email;
  final String? newToken;
  final String? fcmToken;
   final bool isFirstLogin;
  final Map<String, dynamic>? groups;
  final Map<String, dynamic>? groupID;
  final Map<String, NotifPref>? snetEmail;

  User({
    required this.id,
    required this.name,
    required this.admin,
    required this.email,
    required this.isFirstLogin,
    this.newToken,
    this.fcmToken,
    this.groups,
    this.groupID,
    this.snetEmail,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      isFirstLogin: json['isFirstLogin'] ?? false,
      name: json['name'] ?? '',
      admin: json['admin'] ?? false,
      email: json['email'] ?? '',
      fcmToken: json['fcmToken'] ?? '',
      newToken: json['newToken'],
      groups: json['groups'] != null ? Map<String, dynamic>.from(json['groups']) : null,
      groupID: json['groupID'] != null ? Map<String, dynamic>.from(json['groupID']) : null,
      snetEmail: json['snetEmail'] != null
          ? Map<String, dynamic>.from(json['snetEmail'])
              .map((k, v) => MapEntry(k, NotifPref.fromJson(v)))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'admin': admin,
      'email': email,
      'newToken': newToken,
      'fcmToken': fcmToken,
      'isFirstLogin': isFirstLogin,
      'groups': groups,
      'groupID': groupID,
      'snetEmail':
          snetEmail?.map((k, v) => MapEntry(k, v.toJson())),
    };
  }


  
}