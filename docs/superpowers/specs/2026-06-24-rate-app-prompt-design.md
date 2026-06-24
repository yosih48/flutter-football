# Rate-the-app prompt — design

**Date:** 2026-06-24
**Status:** Approved, ready for implementation plan

## Goal

Periodically prompt engaged users to rate the app on Google Play, via a custom
themed dialog that links to the Play Store page. The prompt must never nag:
users who already rated or explicitly declined are never asked again, and new /
lightly-engaged users are not asked at all.

## Scope

- **Android only.** On other platforms the prompt never appears.
- Custom in-app dialog (not the native `in_app_review` sheet), opening the Play
  Store page with `url_launcher`.
- No new package dependency: reuses `url_launcher`, `shared_preferences`,
  `package_info_plus` already in `pubspec.yaml`.

Play Store target: package `com.yosi.football` →
`https://play.google.com/store/apps/details?id=com.yosi.football`
(deep link `market://details?id=com.yosi.football` tried first).

## Components

### `RateAppService` — `lib/resources/rate_app_service.dart`

Singleton, no UI, owns all eligibility logic and persistence via
`SharedPreferences`. Fully unit-testable.

Persisted keys (prefixed `rate_app_`):

| key | type | meaning |
|-----|------|---------|
| `launchCount` | int | cold-start count |
| `firstLaunchEpoch` | int (ms) | first launch timestamp; set once |
| `status` | string | `pending` \| `done` \| `dismissed` |
| `snoozeUntilLaunch` | int | re-eligible only when `launchCount >= this` |
| `snoozeUntilEpoch` | int (ms) | re-eligible only when `now >= this` |
| `promptShownCount` | int | how many times the dialog has been shown |

Methods:

- `Future<void> recordLaunch()` — called once per cold start from `main()`.
  Increments `launchCount`; sets `firstLaunchEpoch` if unset.
- `Future<bool> shouldPrompt()` — returns true only when **all** hold:
  - `Platform.isAndroid`
  - `status == pending`
  - `launchCount >= 5`
  - now − `firstLaunchEpoch` >= 3 days
  - `launchCount >= snoozeUntilLaunch` (0 if unset)
  - now >= `snoozeUntilEpoch` (0 if unset)
  - `promptShownCount < 3`
- `Future<void> markPromptShown()` — increments `promptShownCount`. Called when
  the dialog is actually displayed.
- `Future<void> markRated()` — `status = done` (permanent).
- `Future<void> markDismissed()` — `status = dismissed` (permanent).
- `Future<void> markSnoozed()` — sets `snoozeUntilLaunch = launchCount + 5` and
  `snoozeUntilEpoch = now + 7 days`. Status stays `pending`.

### `RateAppDialog` — `lib/widgets/RateAppDialog.dart`

Themed dialog using existing `context.col` palette and `EType` typography,
RTL-aware via `AppLocalizations`. Three buttons:

- **Rate now** → `markRated()`, then launch Play Store (deep link first, web URL
  fallback). Dialog closes regardless of launch success.
- **Maybe later** → `markSnoozed()`, close.
- **No thanks** → `markDismissed()`, close.

Exposes a helper `Future<void> showRateAppDialog(BuildContext context)` that
calls `markPromptShown()` and shows the dialog.

### Trigger hook — `lib/responsive/mobile_screen_layout.dart`

`MobileScreenLayout` is the logged-in, non-first-login home screen. In
`initState`, schedule a `WidgetsBinding.instance.addPostFrameCallback`; if
`await RateAppService().shouldPrompt()` is true and the widget is still mounted,
call `showRateAppDialog(context)`. This guarantees the prompt never interrupts
login or onboarding and only reaches engaged logged-in users.

### Wiring in `main()` — `lib/main.dart`

After the existing startup sequence, call `await RateAppService().recordLaunch()`
(cheap, no network; safe to run on all platforms — only `shouldPrompt()` is
Android-gated).

## Data flow

1. Cold start → `main()` → `recordLaunch()` bumps counters.
2. User logs in (non-first-login) → `MobileScreenLayout` mounts → post-frame →
   `shouldPrompt()`.
3. If eligible → `markPromptShown()` + dialog.
4. User taps a button → corresponding `mark*()` → persisted → future
   eligibility follows the rules above.

## Error handling

- If both Play Store URLs fail to launch, the dialog still closes and `status`
  stays `done` (we honor the user's intent; log the failure, no crash).
- On non-Android, `shouldPrompt()` returns false, so the dialog never appears.
- All `SharedPreferences` reads default safely (missing keys → 0 / `pending`).

## Localization

New keys in `app_en.arb`, `app_he.arb`, `app_localizations.dart`,
`app_localizations_en.dart`, `app_localizations_he.dart`:

| key | en | he (natural) |
|-----|----|----|
| `rateAppTitle` | Enjoying the app? | נהנים מהאפליקציה? |
| `rateAppMessage` | If you're having fun, would you take a moment to rate us on Google Play? It really helps. | אם אתם נהנים, נשמח אם תדרגו אותנו ב‑Google Play. זה ממש עוזר לנו. |
| `rateAppRateNow` | Rate now | לדירוג עכשיו |
| `rateAppLater` | Maybe later | אולי מאוחר יותר |
| `rateAppNoThanks` | No thanks | לא תודה |

## Testing

`test/rate_app_service_test.dart`, using `SharedPreferences.setMockInitialValues`:

- Not eligible before 5 launches.
- Not eligible before 3 days since first launch.
- Eligible when all thresholds met.
- `done` and `dismissed` suppress forever.
- After `markSnoozed()`: not eligible until both +5 launches and +7 days pass;
  eligible again once both pass.
- The 3-show cap: never eligible after `promptShownCount` reaches 3.

(Platform gating is exercised only indirectly — tests target the threshold
logic; `Platform.isAndroid` is checked first in `shouldPrompt()`.)

## Out of scope (YAGNI)

- iOS / web prompts.
- Native `in_app_review` sheet.
- Remote-config-tuned thresholds (constants in `RateAppService` for now).
- Triggering off specific actions (guess submitted, game finished) — launch +
  time engagement is sufficient.
