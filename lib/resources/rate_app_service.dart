import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:shared_preferences/shared_preferences.dart';

/// Decides whether to show the "rate the app on Google Play" prompt, and
/// persists the user's response. Pure logic + SharedPreferences — no UI.
///
/// Eligibility (all must hold) is evaluated by [shouldPrompt]:
///   • running on Android
///   • status is still `pending` (never rated / dismissed)
///   • at least [_minLaunches] cold starts
///   • at least [_minDaysSinceInstall] days since first launch
///   • past both snooze gates (launch count + wall clock)
///   • shown fewer than [_maxPrompts] times
///
/// Thresholds are constants for now (see spec — remote tuning is out of scope).
class RateAppService {
  RateAppService._internal();
  static final RateAppService _instance = RateAppService._internal();
  factory RateAppService() => _instance;

  // ── Tunable thresholds ──────────────────────────────────────────────────
  static const int _minLaunches = 5;
  static const int _minDaysSinceInstall = 3;
  static const int _snoozeLaunches = 5;
  static const int _snoozeDays = 7;
  static const int _maxPrompts = 3;

  // ── Persistence keys ────────────────────────────────────────────────────
  static const String _kLaunchCount = 'rate_app_launchCount';
  static const String _kFirstLaunchEpoch = 'rate_app_firstLaunchEpoch';
  static const String _kStatus = 'rate_app_status';
  static const String _kSnoozeUntilLaunch = 'rate_app_snoozeUntilLaunch';
  static const String _kSnoozeUntilEpoch = 'rate_app_snoozeUntilEpoch';
  static const String _kPromptShownCount = 'rate_app_promptShownCount';

  static const String _statusPending = 'pending';
  static const String _statusDone = 'done';
  static const String _statusDismissed = 'dismissed';

  /// Injectable clock — overridden in tests. Defaults to the real clock.
  DateTime Function() now = DateTime.now;

  /// Overridable so non-Android logic can be unit-tested. Production reads the
  /// real platform; tests can force `true`.
  bool isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Call once per cold start (from `main()`). Bumps the launch counter and
  /// records the install time on first ever launch.
  Future<void> recordLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_kLaunchCount) ?? 0;
    await prefs.setInt(_kLaunchCount, count + 1);
    if (prefs.getInt(_kFirstLaunchEpoch) == null) {
      await prefs.setInt(
          _kFirstLaunchEpoch, now().millisecondsSinceEpoch);
    }
  }

  /// True only when every eligibility rule passes.
  Future<bool> shouldPrompt() async {
    if (!isAndroid) return false;

    final prefs = await SharedPreferences.getInstance();
    final status = prefs.getString(_kStatus) ?? _statusPending;
    if (status != _statusPending) return false;

    final shown = prefs.getInt(_kPromptShownCount) ?? 0;
    if (shown >= _maxPrompts) return false;

    final launches = prefs.getInt(_kLaunchCount) ?? 0;
    if (launches < _minLaunches) return false;

    final firstEpoch = prefs.getInt(_kFirstLaunchEpoch);
    if (firstEpoch == null) return false;
    final daysSinceInstall =
        now().difference(DateTime.fromMillisecondsSinceEpoch(firstEpoch)).inDays;
    if (daysSinceInstall < _minDaysSinceInstall) return false;

    final snoozeLaunch = prefs.getInt(_kSnoozeUntilLaunch) ?? 0;
    if (launches < snoozeLaunch) return false;

    final snoozeEpoch = prefs.getInt(_kSnoozeUntilEpoch) ?? 0;
    if (now().millisecondsSinceEpoch < snoozeEpoch) return false;

    return true;
  }

  /// The dialog is being displayed — count it toward the [_maxPrompts] cap.
  Future<void> markPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getInt(_kPromptShownCount) ?? 0;
    await prefs.setInt(_kPromptShownCount, shown + 1);
  }

  /// User chose "Rate now" — never ask again.
  Future<void> markRated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStatus, _statusDone);
  }

  /// User chose "No thanks" — never ask again.
  Future<void> markDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStatus, _statusDismissed);
  }

  /// User chose "Maybe later" — re-eligible only after both gates pass.
  Future<void> markSnoozed() async {
    final prefs = await SharedPreferences.getInstance();
    final launches = prefs.getInt(_kLaunchCount) ?? 0;
    await prefs.setInt(_kSnoozeUntilLaunch, launches + _snoozeLaunches);
    final until = now().add(const Duration(days: _snoozeDays));
    await prefs.setInt(_kSnoozeUntilEpoch, until.millisecondsSinceEpoch);
  }
}
