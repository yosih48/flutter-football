import 'package:football/models/FixtureEvent.dart';
import 'package:football/models/lineup.dart';

/// Goal/card/substitution marks for a single player, distilled from the
/// API-Football fixture events so they can be overlaid on the lineup pitch.
class PlayerMarks {
  int goals;
  int ownGoals;
  int yellow;
  int red;
  int? subOffMin; // minute the player was taken OFF (red down-arrow)
  int? subOnMin; // minute the player came ON (green up-arrow)

  PlayerMarks({
    this.goals = 0,
    this.ownGoals = 0,
    this.yellow = 0,
    this.red = 0,
    this.subOffMin,
    this.subOnMin,
  });

  bool get isEmpty =>
      goals == 0 &&
      ownGoals == 0 &&
      yellow == 0 &&
      red == 0 &&
      subOffMin == null &&
      subOnMin == null;
}

/// Lineups come from AllSports (Sofascore ids) while events come from
/// API-Football (different ids), so the two can only be joined by name — and
/// the spellings differ by accents ("F. Kessié" vs "F. Kessie") and by how much
/// of the first name is shown ("Franck Kessié" vs "F. Kessie"). Key on
/// first-initial + accent-stripped surname, which is stable across both.
String playerMatchKey(String name) {
  final cleaned = _stripDiacritics(name.toLowerCase()).replaceAll('.', ' ');
  final tokens = cleaned.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  if (tokens.isEmpty) return '';
  final surname = tokens.last;
  final initial = tokens.first.isNotEmpty ? tokens.first[0] : '';
  return '$initial|$surname';
}

/// Builds a player-key → marks map from the events belonging to one team.
/// Pass the events already filtered/checked against [teamName] so a surname
/// shared across both teams can't collide.
Map<String, PlayerMarks> buildPlayerMarks(
  List<FixtureEvent> events,
  String teamName,
) {
  final marks = <String, PlayerMarks>{};
  PlayerMarks at(String name) =>
      marks.putIfAbsent(playerMatchKey(name), () => PlayerMarks());

  for (final e in events) {
    if (e.team != teamName) continue;
    final type = e.type.toLowerCase();
    final detail = e.detail?.toLowerCase() ?? '';

    if (type == 'goal') {
      if (detail.contains('missed')) continue; // missed penalty — not a goal
      if (detail.contains('own')) {
        at(e.player).ownGoals++;
      } else {
        at(e.player).goals++;
      }
    } else if (type == 'card') {
      if (detail.contains('red')) {
        at(e.player).red++; // covers "Red Card" and "Second Yellow card"→red
      } else if (detail.contains('yellow')) {
        at(e.player).yellow++;
      }
    } else if (type == 'subst') {
      // API-Football: `player` = went OFF, `assist` = came ON.
      at(e.player).subOffMin = e.time;
      final inName = e.assist;
      if (inName != null && inName.isNotEmpty) {
        at(inName).subOnMin = e.time;
      }
    }
  }
  return marks;
}

extension PlayerMarksLookup on Map<String, PlayerMarks> {
  PlayerMarks? forPlayer(LineupPlayer p) => this[playerMatchKey(p.name)];
}

// Latin-1 + common football diacritics → ASCII. Keeps the matcher independent
// of locale data so it works the same on every device.
String _stripDiacritics(String input) {
  const from = 'àáâãäåāăąçćčďèéêëēėęěìíîïĩīįñńňòóôõöøōŏőùúûüũūŭůűýÿžźż';
  const to = 'aaaaaaaaacccdeeeeeeeeiiiiiiinnnoooooooooouuuuuuuuuyyzzz';
  final buf = StringBuffer();
  for (final ch in input.split('')) {
    final idx = from.indexOf(ch);
    buf.write(idx >= 0 ? to[idx] : ch);
  }
  return buf.toString();
}
