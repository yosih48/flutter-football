import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:football/screens/games.dart';

Widget _wrap({
  required Locale locale,
  required String dayLabel,
  double width = 380,
  DateTime? date,
}) =>
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: DateHeader(
              date: date ?? DateTime(2026, 7, 6),
              dayLabel: dayLabel,
              gameCount: 1,
              countWord: 'משחקים',
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('badge leads and count trails in Hebrew', (tester) async {
    await tester.pumpWidget(
        _wrap(locale: const Locale('he'), dayLabel: 'יום שני, 6 יולי'));

    final badge = tester.getCenter(find.text('06')).dx;
    final label = tester.getCenter(find.text('יום שני, 6 יולי')).dx;
    final count = tester.getCenter(find.text('1 משחקים')).dx;

    // RTL: badge on the right, label beside it, count at the far left.
    expect(badge, greaterThan(label), reason: 'badge $badge vs label $label');
    expect(label, greaterThan(count), reason: 'label $label vs count $count');
  });

  testWidgets('badge leads and count trails in English', (tester) async {
    await tester.pumpWidget(
        _wrap(locale: const Locale('en'), dayLabel: 'Monday, 6 Jul'));

    final badge = tester.getCenter(find.text('06')).dx;
    final count = tester.getCenter(find.text('1 משחקים')).dx;
    // Mirrored: badge left, count right.
    expect(badge, lessThan(count));
  });

  testWidgets('day number is zero-padded', (tester) async {
    await tester.pumpWidget(_wrap(
      locale: const Locale('he'),
      dayLabel: 'יום שני, 6 יולי',
      date: DateTime(2026, 7, 6),
    ));
    expect(find.text('06'), findsOneWidget);
  });

  testWidgets('a long label ellipsises instead of overflowing',
      (tester) async {
    await tester.pumpWidget(_wrap(
      locale: const Locale('he'),
      width: 240, // deliberately cramped
      dayLabel: 'יום רביעי הארוך במיוחד, 15 בספטמבר 2026',
    ));
    // A RenderFlex overflow would surface here.
    expect(tester.takeException(), isNull);
  });

  testWidgets('today pill shows only on today', (tester) async {
    await tester.pumpWidget(_wrap(
      locale: const Locale('en'),
      dayLabel: 'Some day',
      date: DateTime(2020, 1, 1),
    ));
    expect(find.text('TODAY'), findsNothing);

    final now = DateTime.now();
    await tester.pumpWidget(_wrap(
      locale: const Locale('en'),
      dayLabel: 'Today',
      date: DateTime(now.year, now.month, now.day),
    ));
    expect(find.text('TODAY'), findsOneWidget);
  });
}
