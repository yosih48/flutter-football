import 'package:flutter_test/flutter_test.dart';
import 'package:football/models/notif_pref.dart';

void main() {
  test('legacy true → reminders+points on, goals off', () {
    final p = NotifPref.fromJson(true);
    expect(p.goals, false);
    expect(p.reminders, true);
    expect(p.points, true);
  });

  test('false / null → all off', () {
    for (final v in [false, null]) {
      final p = NotifPref.fromJson(v);
      expect(p.goals, false);
      expect(p.reminders, false);
      expect(p.points, false);
    }
  });

  test('object passes through, missing fields default false', () {
    final p = NotifPref.fromJson({'goals': true});
    expect(p.goals, true);
    expect(p.reminders, false);
    expect(p.points, false);
  });

  test('toJson round-trips', () {
    const p = NotifPref(goals: true, reminders: false, points: true);
    expect(p.toJson(), {'goals': true, 'reminders': false, 'points': true});
  });
}
