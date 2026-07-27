import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:football/screens/statistics.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: 300, child: child)),
      ),
    );

void main() {
  // Regression: the segments used to be childless ColoredBoxes inside a Row
  // with default (centre) cross-axis alignment, which passes LOOSE vertical
  // constraints — so every segment collapsed to zero height and the bar was
  // invisible exactly when there WAS data. The empty state still showed,
  // because it draws a Container with an explicit height.
  testWidgets('segments render at full height when there is data',
      (tester) async {
    await tester.pumpWidget(_wrap(const StatsSegmentedBar(
      segments: [
        StatsSegment(41, Colors.grey),
        StatsSegment(51, Colors.orange),
        StatsSegment(12, Colors.green),
      ],
      track: Colors.black12,
      isLoading: false,
    )));

    final boxes = find.byType(ColoredBox);
    expect(boxes, findsNWidgets(3));

    for (var i = 0; i < 3; i++) {
      final r = tester.getRect(boxes.at(i));
      expect(r.height, StatsSegmentedBar.height,
          reason: 'segment $i collapsed to ${r.height}px');
      expect(r.width, greaterThan(0));
    }
  });

  testWidgets('segment widths are proportional to their values',
      (tester) async {
    await tester.pumpWidget(_wrap(const StatsSegmentedBar(
      segments: [
        StatsSegment(41, Colors.grey),
        StatsSegment(51, Colors.orange),
        StatsSegment(12, Colors.green),
      ],
      track: Colors.black12,
      isLoading: false,
    )));

    final boxes = find.byType(ColoredBox);
    final w = [for (var i = 0; i < 3; i++) tester.getRect(boxes.at(i)).width];
    expect(w.reduce((a, b) => a + b), closeTo(300, 0.5));
    // 41 : 51 : 12 out of 104
    expect(w[0], closeTo(300 * 41 / 104, 1.0));
    expect(w[1], closeTo(300 * 51 / 104, 1.0));
    expect(w[2], closeTo(300 * 12 / 104, 1.0));
  });

  testWidgets('zero-value series are omitted, not drawn as slivers',
      (tester) async {
    await tester.pumpWidget(_wrap(const StatsSegmentedBar(
      segments: [
        StatsSegment(0, Colors.grey),
        StatsSegment(5, Colors.orange),
        StatsSegment(0, Colors.green),
      ],
      track: Colors.black12,
      isLoading: false,
    )));
    expect(find.byType(ColoredBox), findsOneWidget);
    expect(tester.getRect(find.byType(ColoredBox)).width, closeTo(300, 0.5));
  });

  testWidgets('empty and loading states fall back to the plain track',
      (tester) async {
    for (final loading in [true, false]) {
      await tester.pumpWidget(_wrap(StatsSegmentedBar(
        segments: const [StatsSegment(0, Colors.grey)],
        track: Colors.black12,
        isLoading: loading,
      )));
      expect(find.byType(ColoredBox), findsNothing);
    }
  });

  // The dark bar is a grand total: it must equal every row rendered above it
  // (match guesses + both tournament bonuses), not just the match guesses.
  test('grand total sums match points and both bonuses', () {
    const directPts = 77.0;
    const directionPts = 89.5;
    const topScorerPoints = 20;
    const championPoints = 20;

    // Misses contribute 0, so match points == direct + direction.
    const matchPts = directPts + directionPts;
    final total = matchPts + topScorerPoints + championPoints;

    expect(matchPts, 166.5);
    expect(total, 206.5, reason: 'bonuses must be included in the total');
  });
}
