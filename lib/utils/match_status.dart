/// Single source of truth for how the app treats API-Football status codes.
///
/// - [inPlay]: the ball is in play → LIVE badge, live colours.
/// - [interrupted]: stopped by the provider (INT = interrupted, e.g. a fan
///   protest; SUSP = suspended). NOT shown as LIVE, but still refreshed
///   because the match may resume (or later turn ABD).
/// - [voided]: never completed — postponed / cancelled / abandoned. The result
///   does not count (the backend scores every guess 0), so no score is shown.
class MatchStatus {
  MatchStatus._();

  static const Set<String> inPlay = {
    '1H',
    '2H',
    'H1',
    'H2',
    'ET',
    'BT',
    'P',
    'LIVE',
  };
  static const Set<String> interrupted = {'INT', 'SUSP'};
  static const Set<String> voided = {'PST', 'CANC', 'ABD'};

  static bool isInPlay(String short) => inPlay.contains(short);
  static bool isInterrupted(String short) => interrupted.contains(short);
  static bool isVoid(String short) => voided.contains(short);

  /// Can still change, so keep refreshing it: in play, half-time, or
  /// interrupted (may resume).
  static bool isOngoing(String short) =>
      isInPlay(short) || short == 'HT' || isInterrupted(short);
}
