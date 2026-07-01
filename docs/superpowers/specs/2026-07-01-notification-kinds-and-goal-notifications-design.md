# Design: Three notification kinds + per-goal notifications

**Date:** 2026-07-01
**Repos:** `flutter-football` (Flutter client), `worldBackend` (Node backend)

## Problem

Today a single per-league flag, `snetEmail[leagueId] = true|false`, controls *all*
notifications for that league:

- **pre-game reminders** (top-scorer pick, team-winner pick, bracket reminders),
- **points rewarded after a game** (including the "your top scorer scored" bonus push),

The user wants:

1. A **new** kind of notification: one push **per goal** scored during a live game,
   carrying the scoring **team name**, **player name**, and **minute** — sent to every
   user who opted in for that league's goal notifications ("same logic" as the existing
   opt-in gate).
2. The single on/off flag split into **three independently toggleable kinds**:
   1. **goals** — goals during games (new),
   2. **reminders** — guess reminders before games (existing),
   3. **points** — points rewarded after a game, incl. top-scorer bonus (existing).

Existing users already have `snetEmail[leagueId]` as a bare bool — must not break them.

## Decisions (confirmed with user)

- **Goal-notification recipients:** ALL users who enabled `goals` for that league (not
  just users who guessed the game).
- **Storage shape:** nest under `snetEmail` per league (see below); legacy bool read via
  coercion, **no migration script**.
- **Notifications UI:** each league row shows **3 inline labeled toggles**; the master
  becomes 3 category "all on/off" toggles.
- **Top-scorer-scored during-game push** is grouped under **points** (user's framing:
  "points rewarded after game including top scorer points during games").
- **Points-after-game gating is a behavior change** (see Risks).

## Data model

`snetEmail[leagueId]` changes from `bool` to an object:

```json
"snetEmail": {
  "39": { "goals": false, "reminders": true, "points": true },
  "1":  { "goals": true,  "reminders": true, "points": true }
}
```

### Coercion (single helper, mirrored on backend + frontend)

Normalize any stored value to `{ goals, reminders, points }` (all bool):

- **object** → read each field, missing field ⇒ `false`.
- **legacy `true`** ⇒ `{ goals: false, reminders: true, points: true }`
  (existing opted-in users keep reminders+points; goals is opt-in for the new kind).
- **`false` / `null` / `undefined` / anything else** ⇒ `{ goals: false, reminders: false, points: false }`.

No migration job. Docs upgrade in place the next time the user saves settings (the
frontend always writes the full object via `$set snetEmail.<id> = {goals,reminders,points}`).

## Backend (`worldBackend`)

### New shared helper: `src/utils/notifPrefs.js`

```js
export function notifPref(user, leagueId) { /* returns {goals,reminders,points} via coercion above */ }
```

Because stored values are now mixed (legacy bool + new object), any Mongo query that
currently filters `{ ['snetEmail.'+leagueId]: true }` must change to **fetch candidates
then filter in JS** with `notifPref(...)`, so both legacy and new docs match correctly.

### Gate mapping (replace every `snetEmail[leagueId] === true` site)

| Site | New gate |
|---|---|
| `src/controllers/topScorerReminder.js` `hasNotificationsEnabled` | `reminders` |
| `src/controllers/teamWinnerReminder.js` `hasNotificationsEnabled` | `reminders` |
| `src/controllers/bracketReminder.js` `optedIn` | `reminders` |
| `src/controllers/bracketStatus.js` query `{ 'snetEmail.<id>': true }` | fetch + filter `reminders` |
| `editPoints.js` `getUsersEmails` (feeds `scheduleEmailsBeforeGame`) | `reminders` |
| `src/controllers/championSettlement.js` recipients filter | `points` |
| `src/controllers/bracketSettlement.js` recipients filter | `points` |
| `api.js` `sendGamesPointsNotification` (**newly gated**, see Risks) | `points` |
| `api.js` `sendTopScorerGoalNotification` (top-scorer bonus push) | `points` |
| **NEW** per-goal notification | `goals` |

For `sendGamesPointsNotification` / `sendTopScorerGoalNotification`, the send already
loads the user by email (`getUserFCMToken`). Extend that lookup (or add
`getUserForNotif(email)` returning `{ fcmToken, snetEmail }`) so the send can check
`notifPref(user, league).points` before dispatching, without a second query.

### New per-goal notification

**Where:** inside `calculatePoints` (`api.js`), after `fixtureEventsMap` is built and
alongside the existing top-scorer sweep. Add
`sendGoalNotificationsForFixtures(scoredFixtures, fixtureEventsMap, leagueId)`.

**Goal selection:** from each fixture's events take `type === "Goal"` excluding
`detail === "Missed Penalty"`. Include `Own Goal` and `Penalty` (they change the
scoreline); label own goals in the copy.

**Idempotency:** new mongoose model `GoalNotificationCache` with `_id` =
`` `${fixtureOriginalId}_${normalizeName(scorer)}_${ordinal}` `` (ordinal = index among
that scorer's goals in the fixture — same rationale as `createGoalAwardKey`, keyed on
ordinal not minute because the provider revises minutes). Atomic `updateOne(..., {upsert:true})`;
send only when `upsertedCount === 1`. Survives restarts; guarantees one push per goal.

**Live-only guard:** only announce goals for fixtures whose status is NOT in
`{FT, AET, PEN}` (mirrors the in-game top-scorer push). Prevents blasting historical
goals of a finished match.

**Recipients:** query users with `goals` enabled for `leagueId` **once per run** (fetch
candidates + filter via `notifPref`), collect non-null `fcmToken`s. Dispatch with
`admin.messaging().sendEachForMulticast` in batches of ≤500. Prune obviously invalid
tokens on the usual error codes (log only; token cleanup out of scope).

**Copy (Hebrew, RTL):** use `heTeamName()` for the team.
- title: `⚽ גול!`
- body (normal): `` `${teamHe} כבשה! ${player} בדקה ${minute}׳` `` + running score
  `` `(${homeHe} ${homeScore} - ${awayScore} ${awayHe})` ``
- own goal: `` `${player} כבש שער עצמי בדקה ${minute}׳` `` + running score
- minute: `time.elapsed` with `+time.extra` appended when present (e.g. `90+3`).
- `data` payload: `screen: game_details`, `gameId`, `league`, high-importance channel
  (match existing pushes).

**Cold-start edge (accepted):** if the server starts mid-match, goals scored before
tracking began get inserted fresh and may be announced late/at once — same behavior as
the existing top-scorer push. Acceptable; noted, not mitigated.

## Frontend (`flutter-football`)

### Models

Introduce a `NotifPref` value type (`{ goals, reminders, points }`) with a
`NotifPref.fromJson(dynamic)` applying the same coercion (object → fields; legacy `true`
→ reminders+points; else all false) and `toJson()`.

- `lib/models/userAll.dart` — change `snetEmail` from `Map<String, bool>` to
  `Map<String, NotifPref>`; update `convertSnetEmail`, `toString`.
- `lib/models/users.dart` — currently has **no** `snetEmail`; add the field
  (`Map<String, NotifPref>`), constructor param, `fromJson` (coercion), `toJson`.

Audit note: a `snetEmail` field-access search across the Flutter lib found the field is
only defined in the models (no screen reads `user.snetEmail` as a bool), so the type
change is low-risk. `favorits.dart` reads/writes raw JSON, not the model. Still, compile
after the change to confirm.

### `lib/screens/favorits.dart` (Notifications tab)

- Replace `Map<int, bool> notificationStates` with per-kind state — either
  `Map<int, NotifPref>` or three maps (`goalsStates`, `remindersStates`, `pointsStates`).
- `_getUserInfo`: build state from `userData['snetEmail']` via coercion.
- `updateDatabase`: write `set['snetEmail.$id'] = { 'goals':…, 'reminders':…, 'points':… }`
  for each configured league.
- Unchecking a league (chosenLeagues false) zeroes all three kinds for that league.
- UI: each league row renders 3 small labeled toggles (Goals / Reminders / Points).
  The existing single "choose all" master becomes 3 category masters (all-goals,
  all-reminders, all-points on/off across enabled leagues).

### Localization

Add keys to **both** `lib/l10n/app_en.arb` and `lib/l10n/app_he.arb`, and the
`String get`/overrides to `app_localizations.dart`, `app_localizations_en.dart`,
`app_localizations_he.dart`:

- `notifGoals` (he: "שערים"), `notifReminders` (he: "תזכורות"), `notifPoints` (he: "נקודות")
- master/section labels as needed (e.g. `notifAllGoals`, `notifAllReminders`,
  `notifAllPoints`, or reuse `chooseallcompetitions` pattern).

No app-facing goal-notification *body* strings are needed in the client — that copy is
built server-side.

## Risks / behavior changes

1. **Points-after-game notifications become gated.** They are currently sent to anyone
   with an FCM token (no `snetEmail` check). After this change they require `points:true`.
   Legacy `true` → `points:true` (unaffected); legacy `false`/absent → `points:false`
   (**will stop** getting points pushes). This is the intended, consistent behavior but
   is a live change for users who never opted in. **Confirmed acceptable by user.**
2. **Mixed-shape docs during rollout.** Coercion handles legacy bool and new object
   everywhere; Mongo `{ 'snetEmail.X': true }` queries are replaced by JS-side filtering
   so an object value doesn't silently fail the `=== true` match.
3. **Goal-notification volume.** "All opted-in league users" can be a large audience per
   goal; mitigated by once-per-run recipient query + multicast batching + per-goal
   idempotency. No per-user records are written for goals (idempotency is goal-level).

## Out of scope

- FCM token cleanup / pruning invalid tokens (log only).
- Backfilling/announcing goals scored before the server was tracking a live match.
- Any change to how leagues themselves are configured or chosen.

## Versioning

Per `pubspec.yaml` convention, bump `version:` when shipping so the client reaches users
through the forced-update gate (client-side model/UI change).
