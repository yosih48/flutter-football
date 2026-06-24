import 'package:flutter_test/flutter_test.dart';
import 'package:football/resources/rate_app_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = RateAppService();
  late DateTime clock;

  // Helper: seed prefs, force Android, and pin the clock.
  Future<void> setup(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    clock = DateTime(2026, 1, 1, 12, 0);
    service
      ..isAndroid = true
      ..now = () => clock;
  }

  group('shouldPrompt eligibility', () {
    test('not eligible before minimum launches', () async {
      await setup({
        'rate_app_launchCount': 4,
        'rate_app_firstLaunchEpoch':
            DateTime(2025, 12, 1).millisecondsSinceEpoch, // long ago
      });
      expect(await service.shouldPrompt(), isFalse);
    });

    test('not eligible before minimum days since install', () async {
      await setup({
        'rate_app_launchCount': 10,
        'rate_app_firstLaunchEpoch':
            clockOf(2025, 12, 31, 12).millisecondsSinceEpoch, // ~1 day ago
      });
      expect(await service.shouldPrompt(), isFalse);
    });

    test('eligible once launches and days thresholds met', () async {
      await setup({
        'rate_app_launchCount': 5,
        'rate_app_firstLaunchEpoch':
            DateTime(2025, 12, 20).millisecondsSinceEpoch, // > 3 days ago
      });
      expect(await service.shouldPrompt(), isTrue);
    });

    test('not eligible on non-Android', () async {
      await setup({
        'rate_app_launchCount': 50,
        'rate_app_firstLaunchEpoch':
            DateTime(2025, 1, 1).millisecondsSinceEpoch,
      });
      service.isAndroid = false;
      expect(await service.shouldPrompt(), isFalse);
    });
  });

  group('terminal states suppress forever', () {
    final eligible = {
      'rate_app_launchCount': 50,
      'rate_app_firstLaunchEpoch':
          DateTime(2025, 1, 1).millisecondsSinceEpoch,
    };

    test('markRated stops prompting', () async {
      await setup(Map.of(eligible));
      expect(await service.shouldPrompt(), isTrue);
      await service.markRated();
      expect(await service.shouldPrompt(), isFalse);
    });

    test('markDismissed stops prompting', () async {
      await setup(Map.of(eligible));
      await service.markDismissed();
      expect(await service.shouldPrompt(), isFalse);
    });
  });

  group('snooze re-eligibility', () {
    test('not eligible until both +launches and +days pass', () async {
      await setup({
        'rate_app_launchCount': 10,
        'rate_app_firstLaunchEpoch':
            DateTime(2025, 1, 1).millisecondsSinceEpoch,
      });
      expect(await service.shouldPrompt(), isTrue);

      await service.markSnoozed(); // needs launch>=15 and now>=+7d

      // Days passed but not enough launches.
      clock = DateTime(2026, 1, 10, 12); // +9 days
      expect(await service.shouldPrompt(), isFalse);

      // Enough launches but not enough days.
      SharedPreferences.setMockInitialValues({
        'rate_app_launchCount': 16,
        'rate_app_firstLaunchEpoch':
            DateTime(2025, 1, 1).millisecondsSinceEpoch,
        'rate_app_snoozeUntilLaunch': 15,
        'rate_app_snoozeUntilEpoch':
            DateTime(2026, 1, 8, 12).millisecondsSinceEpoch,
      });
      clock = DateTime(2026, 1, 5, 12); // before snooze epoch
      expect(await service.shouldPrompt(), isFalse);

      // Both gates passed.
      clock = DateTime(2026, 1, 9, 12); // after snooze epoch, launches 16>=15
      expect(await service.shouldPrompt(), isTrue);
    });
  });

  group('max-show cap', () {
    test('not eligible after promptShownCount reaches cap', () async {
      await setup({
        'rate_app_launchCount': 50,
        'rate_app_firstLaunchEpoch':
            DateTime(2025, 1, 1).millisecondsSinceEpoch,
        'rate_app_promptShownCount': 3,
      });
      expect(await service.shouldPrompt(), isFalse);
    });

    test('markPromptShown increments toward the cap', () async {
      await setup({'rate_app_promptShownCount': 2});
      await service.markPromptShown();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('rate_app_promptShownCount'), 3);
    });
  });

  group('recordLaunch', () {
    test('increments count and sets first-launch once', () async {
      await setup({});
      await service.recordLaunch();
      var prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('rate_app_launchCount'), 1);
      final firstEpoch = prefs.getInt('rate_app_firstLaunchEpoch');
      expect(firstEpoch, isNotNull);

      clock = clock.add(const Duration(days: 5));
      await service.recordLaunch();
      prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('rate_app_launchCount'), 2);
      // First-launch epoch must not move.
      expect(prefs.getInt('rate_app_firstLaunchEpoch'), firstEpoch);
    });
  });
}

DateTime clockOf(int y, int m, int d, int h) => DateTime(y, m, d, h);
