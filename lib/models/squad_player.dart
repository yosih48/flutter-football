class SquadPlayer {
  final int? id;
  final String name;
  final int? age;
  final int? number;
  final String? position; // Goalkeeper | Defender | Midfielder | Attacker
  final String? photo;

  SquadPlayer({
    this.id,
    required this.name,
    this.age,
    this.number,
    this.position,
    this.photo,
  });

  factory SquadPlayer.fromJson(Map<String, dynamic> json) {
    return SquadPlayer(
      id: json['id'] as int?,
      name: (json['name'] ?? '').toString(),
      age: json['age'] as int?,
      number: json['number'] as int?,
      position: json['position'] as String?,
      photo: json['photo'] as String?,
    );
  }
}
