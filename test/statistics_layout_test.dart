import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:football/screens/statistics.dart';

Widget _screen(Locale locale) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: const Statistics(userId: 'u1', leagueId: 39),
    );

void main() {
  // Skeletonizer's shimmer animates forever, so pumpAndSettle would time out —
  // pump a fixed number of frames instead. Network is stubbed out by
  // flutter_test, so the screen lands in its empty/zero state, which is enough
  // to prove the new layout builds and lays out in both directions.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
  }

  for (final locale in [const Locale('he'), const Locale('en')]) {
    testWidgets('statistics builds with no overflow in ${locale.languageCode}',
        (tester) async {
      await tester.pumpWidget(_screen(locale));
      await settle(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('renders the three overview cards and the total bar',
      (tester) async {
    await tester.pumpWidget(_screen(const Locale('en')));
    await settle(tester);

    // One card per section.
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Accuracy'), findsOneWidget);
    expect(find.text('Points'), findsOneWidget);

    // Points sub-groups + dark total row.
    expect(find.text('Match guesses'), findsOneWidget);
    expect(find.text('Tournament bonus'), findsOneWidget);
    expect(find.text('Total points'), findsOneWidget);

    // Legend keeps all three counts, including the new derived misses figure.
    expect(find.text('Misses'), findsOneWidget);
    expect(find.text('Total Guesses'), findsOneWidget);
  });

  // The split bar and legend are a chart pinned LTR (grey → amber → green),
  // so they must read the same way round regardless of app language.
  testWidgets('legend order is grey, amber, green left-to-right in Hebrew',
      (tester) async {
    await tester.pumpWidget(_screen(const Locale('he')));
    await settle(tester);

    // These labels also appear in the accuracy and points cards; the legend
    // is built first, so take the first match.
    double xOf(String label) => tester.getCenter(find.text(label).first).dx;

    final misses = xOf('החטאות');
    final direction = xOf('ניחושי כיוון');
    final direct = xOf('ניחושים מדוייקים');

    expect(misses, lessThan(direction),
        reason: 'misses ($misses) must sit left of direction ($direction)');
    expect(direction, lessThan(direct),
        reason: 'direction ($direction) must sit left of exact ($direct)');
  });

  testWidgets('headline number sits at the start edge (right) in Hebrew',
      (tester) async {
    await tester.pumpWidget(_screen(const Locale('he')));
    await settle(tester);

    // Value-agnostic: under test the fetch never resolves so the figure is a
    // placeholder — position is what matters here.
    final number = tester.getCenter(find.byKey(const Key('stats-total'))).dx;
    final label = tester.getCenter(find.text('סה"כ ניחושים')).dx;
    expect(number, greaterThan(label),
        reason: 'total ($number) should be right of its label ($label)');
  });
}
