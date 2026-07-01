/// Per-league notification preference. Three independently toggleable kinds:
/// goals (per-goal pushes during a game), reminders (pre-game guess reminders),
/// points (points rewarded after a game, incl. top-scorer bonus).
///
/// [NotifPref.fromJson] tolerates the legacy shape where `snetEmail[leagueId]`
/// was a bare bool, so existing users read correctly with no migration.
class NotifPref {
  final bool goals;
  final bool reminders;
  final bool points;

  const NotifPref({
    this.goals = false,
    this.reminders = false,
    this.points = false,
  });

  factory NotifPref.fromJson(dynamic value) {
    if (value is Map) {
      return NotifPref(
        goals: value['goals'] == true,
        reminders: value['reminders'] == true,
        points: value['points'] == true,
      );
    }
    // Legacy: a bare `true` meant reminders + points on, goals opt-in.
    if (value == true) {
      return const NotifPref(goals: false, reminders: true, points: true);
    }
    return const NotifPref();
  }

  Map<String, dynamic> toJson() =>
      {'goals': goals, 'reminders': reminders, 'points': points};

  NotifPref copyWith({bool? goals, bool? reminders, bool? points}) => NotifPref(
        goals: goals ?? this.goals,
        reminders: reminders ?? this.reminders,
        points: points ?? this.points,
      );

  bool get anyOn => goals || reminders || points;

  @override
  String toString() =>
      'NotifPref(goals: $goals, reminders: $reminders, points: $points)';
}
