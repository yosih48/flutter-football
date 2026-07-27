import 'package:flutter_test/flutter_test.dart';
import 'package:football/utils/localized_team_name.dart';

void main() {
  test('real winner picks from the user record resolve to Hebrew', () {
    // Exactly the strings stored in seasonScores for this user.
    const picks = {
      'Portugal': 'פורטוגל',            // national — was already working
      'Paris Saint Germain': 'פריז סן ז׳רמן',
      'Aston Villa': 'אסטון וילה',
      'Arsenal': 'ארסנל',
      'Marseille': 'מארסיי',
      'Inter': 'אינטר',
      'valencia': 'ולנסיה',             // note: lowercase in the DB
      'Maccabi Tel Aviv': 'מכבי תל אביב',
      'Crystal Palace': 'קריסטל פאלאס',
    };
    picks.forEach((en, he) {
      expect(localizedTeamNameFor('he', en), he, reason: 'for "$en"');
    });
  });

  test('English locale is untouched', () {
    expect(localizedTeamNameFor('en', 'Arsenal'), 'Arsenal');
    expect(localizedTeamNameFor('en', 'Portugal'), 'Portugal');
  });

  test('unknown clubs fall back to the English name', () {
    expect(localizedTeamNameFor('he', 'Some FC'), 'Some FC');
  });

  test('no Hebrew value accidentally contains Latin letters', () {
    kClubNamesHe.forEach((en, he) {
      expect(RegExp(r'[A-Za-z]').hasMatch(he), isFalse,
          reason: '"$en" -> "$he" has Latin characters');
    });
  });
}
