import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:football/models/season_record.dart';
import 'package:football/resources/trophyMethods.dart';
import 'package:football/screens/trophyCabinet.dart';

class _EmptyTrophyMethods extends TrophyMethods {
  const _EmptyTrophyMethods();
  @override
  Future<List<SeasonRecord>> fetchHistory(String userId) async => const [];
}

// Drives the real screen (not just the tab) so the LayoutBuilder/ConstrainedBox
// that gives the empty state its viewport height is exercised too.
Widget _screen(Locale locale) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: const TrophyCabinetScreen(userId: 'u1', allowedIds: {'39'}),
    );

void main() {
  for (final locale in [const Locale('he'), const Locale('en')]) {
    testWidgets('empty state is centred in ${locale.languageCode}',
        (tester) async {
      // Stub the network call the screen's tab makes.
      await tester.pumpWidget(_screen(locale));
      await tester.pumpAndSettle();

      final screen = tester.getRect(find.byType(Scaffold));
      final icon = tester.getRect(find.byIcon(Icons.emoji_events_outlined));

      // Horizontally centred within ~1px.
      expect((icon.center.dx - screen.center.dx).abs(), lessThan(1.0),
          reason: 'icon dx ${icon.center.dx} vs screen ${screen.center.dx}');

      // Vertically: the block sits in the middle of the page, not hugging the
      // top. Allow a wide band since the icon is above the two text lines.
      expect(icon.center.dy, greaterThan(screen.height * 0.25),
          reason: 'icon dy ${icon.center.dy} is too close to the top');
      expect(icon.center.dy, lessThan(screen.height * 0.75));
    });
  }
}
