# Three Notification Kinds + Per-Goal Notifications — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **⚠️ COMMIT POLICY (user standing rule):** Do **NOT** run `git commit`. Where a task ends in a "Checkpoint" step, only stage (`git add`) and pause for the user to review. The user commits.

**Goal:** Split the single per-league notification opt-in (`snetEmail[leagueId]`) into three independently toggleable kinds — goals / reminders / points — and add a new push per goal scored during a live game (team, player, minute) to all users opted into that league's goal notifications.

**Architecture:** `snetEmail[leagueId]` becomes an object `{goals,reminders,points}`; a shared coercion helper (backend `notifPrefs.js`, frontend `NotifPref`) reads legacy bools transparently so no migration runs. Backend gate sites switch to the helper; a new `GoalNotificationCache` gives per-goal idempotency; a new `sendGoalNotificationsForFixtures` in `calculatePoints` multicasts goal pushes. The Flutter settings tab renders three inline toggles per league.

**Tech Stack:** Node (ESM, mongoose, firebase-admin ^12, `node --test`); Flutter/Dart (Provider, `flutter test`, `flutter analyze`).

---

## File Structure

**Backend (`C:\worldBackend`)**
- Create `src/utils/notifPrefs.js` — coercion + `notifPref(user, leagueId)`.
- Create `tests/notifPrefs.test.mjs` — unit tests for coercion.
- Modify `src/models/cacheModels.js` — add `GoalNotificationCache`.
- Modify `api.js` — import helper + cache; gate points/top-scorer pushes; add goal-notification functions; wire into `calculatePoints`.
- Modify `src/controllers/topScorerReminder.js`, `teamWinnerReminder.js`, `bracketReminder.js`, `bracketStatus.js`, `championSettlement.js`, `bracketSettlement.js` — gate via helper.
- Modify `editPoints.js` — gate `getUsersEmails` via helper.

**Frontend (`C:\flutter-football`)**
- Create `lib/models/notif_pref.dart` — `NotifPref` value type.
- Create `test/notif_pref_test.dart` — coercion tests.
- Modify `lib/models/userAll.dart`, `lib/models/users.dart` — use `NotifPref`.
- Modify `lib/screens/favorits.dart` — per-kind state, `updateDatabase`, 3-toggle UI.
- Modify `lib/l10n/app_en.arb`, `app_he.arb`, `app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_he.dart` — new strings.
- Modify `pubspec.yaml` — version bump.

---

## PHASE A — Backend

### Task A1: `notifPref` coercion helper (TDD)

**Files:**
- Create: `C:\worldBackend\src\utils\notifPrefs.js`
- Test: `C:\worldBackend\tests\notifPrefs.test.mjs`

- [ ] **Step 1: Write the failing test**

Create `C:\worldBackend\tests\notifPrefs.test.mjs`:

```js
import { test } from "node:test";
import assert from "node:assert/strict";
import { coerceNotifPref, notifPref } from "../src/utils/notifPrefs.js";

test("legacy true → reminders+points on, goals off", () => {
  assert.deepEqual(coerceNotifPref(true), {
    goals: false, reminders: true, points: true,
  });
});

test("false / null / undefined → all off", () => {
  const off = { goals: false, reminders: false, points: false };
  assert.deepEqual(coerceNotifPref(false), off);
  assert.deepEqual(coerceNotifPref(null), off);
  assert.deepEqual(coerceNotifPref(undefined), off);
});

test("object passes through, missing fields default false", () => {
  assert.deepEqual(coerceNotifPref({ goals: true }), {
    goals: true, reminders: false, points: false,
  });
  assert.deepEqual(coerceNotifPref({ goals: true, reminders: true, points: true }), {
    goals: true, reminders: true, points: true,
  });
});

test("notifPref reads by league id (number or string key)", () => {
  const user = { snetEmail: { "39": true, "1": { goals: true } } };
  assert.deepEqual(notifPref(user, 39), { goals: false, reminders: true, points: true });
  assert.deepEqual(notifPref(user, "1"), { goals: true, reminders: false, points: false });
  assert.deepEqual(notifPref(user, 999), { goals: false, reminders: false, points: false });
  assert.deepEqual(notifPref({}, 39), { goals: false, reminders: false, points: false });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /c/worldBackend && node --test tests/notifPrefs.test.mjs`
Expected: FAIL — cannot find module `../src/utils/notifPrefs.js`.

- [ ] **Step 3: Write the helper**

Create `C:\worldBackend\src\utils\notifPrefs.js`:

```js
// Per-league notification preference, normalized to { goals, reminders, points }
// (all booleans). Tolerates the legacy shape where snetEmail[leagueId] was a
// bare boolean, so existing user docs keep working with no migration:
//   - object            → read each field (missing ⇒ false)
//   - legacy `true`     → { goals:false, reminders:true, points:true }
//   - false/null/absent → { goals:false, reminders:false, points:false }
export function coerceNotifPref(value) {
  if (value && typeof value === "object") {
    return {
      goals: value.goals === true,
      reminders: value.reminders === true,
      points: value.points === true,
    };
  }
  if (value === true) {
    return { goals: false, reminders: true, points: true };
  }
  return { goals: false, reminders: false, points: false };
}

// Convenience: pull a user's normalized pref for a league. leagueId may be a
// number or string — object property access coerces it to the string key.
export function notifPref(user, leagueId) {
  const snet = user && user.snetEmail ? user.snetEmail : {};
  return coerceNotifPref(snet[leagueId]);
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /c/worldBackend && node --test tests/notifPrefs.test.mjs`
Expected: PASS (4 tests).

- [ ] **Step 5: Checkpoint (stage only, do NOT commit)**

```bash
cd /c/worldBackend && git add src/utils/notifPrefs.js tests/notifPrefs.test.mjs
```

---

### Task A2: `GoalNotificationCache` model

**Files:**
- Modify: `C:\worldBackend\src\models\cacheModels.js`

- [ ] **Step 1: Add the schema**

In `C:\worldBackend\src\models\cacheModels.js`, after the `topScorerAwardSchema` block (ends line 92), add:

```js
// Idempotency record for per-goal push notifications. _id is a deterministic
// key (`<fixtureId>_<normalizedScorer>_<ordinal>`); presence means the goal was
// already announced, so a server restart cannot re-notify the same goal.
const goalNotificationSchema = new Schema(
  {
    _id: { type: String },
    fixtureId: { type: Number, index: true },
    leagueId: { type: Number, index: true },
    createdAt: { type: Date, default: Date.now },
  },
  { _id: false, minimize: false }
);
```

- [ ] **Step 2: Export the model**

In the same file, after the `TopScorerAwardCache` export (line 132), add:

```js
export const GoalNotificationCache = mongoose.model("GoalNotificationCache", goalNotificationSchema, "goalNotifications");
```

- [ ] **Step 3: Verify the module loads**

Run: `cd /c/worldBackend && node -e "import('./src/models/cacheModels.js').then(m => console.log(!!m.GoalNotificationCache))"`
Expected: prints `true`.

- [ ] **Step 4: Checkpoint (stage only)**

```bash
cd /c/worldBackend && git add src/models/cacheModels.js
```

---

### Task A3: Gate reminder + settlement sites via helper

**Files:**
- Modify: `src/controllers/topScorerReminder.js:80-82`, `teamWinnerReminder.js:80-82`, `bracketReminder.js:24-27`, `bracketStatus.js:47-51`, `championSettlement.js:163-166`, `bracketSettlement.js:363-366`, `editPoints.js:397-425`

- [ ] **Step 1: `topScorerReminder.js` — reminders gate**

Add import near the other imports (top of file):
```js
import { notifPref } from "../utils/notifPrefs.js";
```
Replace the body of `hasNotificationsEnabled` (lines 80-82):
```js
function hasNotificationsEnabled(user, leagueId) {
  return notifPref(user, leagueId).reminders === true;
}
```

- [ ] **Step 2: `teamWinnerReminder.js` — reminders gate**

Add `import { notifPref } from "../utils/notifPrefs.js";` and replace `hasNotificationsEnabled` (lines 80-82):
```js
function hasNotificationsEnabled(user, leagueId) {
  return notifPref(user, leagueId).reminders === true;
}
```

- [ ] **Step 3: `bracketReminder.js` — reminders gate**

Add `import { notifPref } from "../utils/notifPrefs.js";` and replace `optedIn` (lines 24-27):
```js
function optedIn(user, leagueId) {
  return notifPref(user, leagueId).reminders === true;
}
```

- [ ] **Step 4: `bracketStatus.js` — fetch + filter (reminders)**

Add `import { notifPref } from "../utils/notifPrefs.js";`. Replace the query (lines 48-51):
```js
  const candidates = await Users.find(
    { snetEmail: { $exists: true } },
    { _id: 1, displayName: 1, email: 1, snetEmail: 1 }
  ).lean();
  const allUsers = candidates.filter((u) => notifPref(u, leagueId).reminders);
```

- [ ] **Step 5: `championSettlement.js` — points gate**

Add `import { notifPref } from "../utils/notifPrefs.js";`. Replace the recipients filter (lines 164-166):
```js
    const recipients = users.filter(
      (u) => u.email && notifPref(u, leagueKey).points
    );
```

- [ ] **Step 6: `bracketSettlement.js` — points gate**

Add `import { notifPref } from "../utils/notifPrefs.js";`. Replace the filter (line 365):
```js
        .filter((u) => u.email && notifPref(u, leagueKey).points)
```

- [ ] **Step 7: `editPoints.js` `getUsersEmails` — reminders gate**

Add near the top of `editPoints.js` (with the other imports):
```js
import { notifPref } from "./src/utils/notifPrefs.js";
```
Replace the `.filter(...)` inside `getUsersEmails` (lines 410-417):
```js
      .filter((item) => notifPref(item, leagueId).reminders)
```
(Leave the `.map((item) => item.email)` that follows unchanged.)

- [ ] **Step 8: Verify all modules still parse**

Run: `cd /c/worldBackend && node -e "Promise.all(['./src/controllers/topScorerReminder.js','./src/controllers/teamWinnerReminder.js','./src/controllers/bracketReminder.js','./src/controllers/bracketStatus.js','./src/controllers/championSettlement.js','./src/controllers/bracketSettlement.js','./editPoints.js'].map(p=>import(p))).then(()=>console.log('ok')).catch(e=>{console.error(e);process.exit(1)})"`
Expected: prints `ok` (no import/syntax errors).

- [ ] **Step 9: Checkpoint (stage only)**

```bash
cd /c/worldBackend && git add src/controllers/topScorerReminder.js src/controllers/teamWinnerReminder.js src/controllers/bracketReminder.js src/controllers/bracketStatus.js src/controllers/championSettlement.js src/controllers/bracketSettlement.js editPoints.js
```

---

### Task A4: Gate points + top-scorer pushes on `points`

**Files:**
- Modify: `C:\worldBackend\api.js` (`sendGamesPointsNotification` ~957-984; `sendTopScorerGoalNotification` ~1088-1093)

- [ ] **Step 1: Add the helper import**

In `api.js`, next to the existing `import Users from "./src/models/usersModel.js";` (line 57), add:
```js
import { notifPref } from "./src/utils/notifPrefs.js";
```

- [ ] **Step 2: Gate `sendGamesPointsNotification` on `points`**

In `sendGamesPointsNotification`, replace:
```js
  const fcmToken = await getUserFCMToken(userEmail);
  try {
    if (!fcmToken) {
      console.log("No FCM token found for user:", userEmail);
      return;
    }
```
with:
```js
  const user = await Users.findOne(
    { email: userEmail },
    { fcmToken: 1, snetEmail: 1 }
  ).lean();
  const fcmToken = user && user.fcmToken;
  try {
    if (!fcmToken) {
      console.log("No FCM token found for user:", userEmail);
      return;
    }
    if (!notifPref(user, league).points) {
      console.log(`Points notifications disabled for ${userEmail} in league ${league}`);
      return;
    }
```

- [ ] **Step 3: Gate `sendTopScorerGoalNotification` on `points`**

In `sendTopScorerGoalNotification`, replace:
```js
    const fcmToken = await getUserFCMToken(userEmail);
    if (!fcmToken) {
      console.log("No FCM token found for user:", userEmail);
      return false;
    }
```
with:
```js
    const user = await Users.findOne(
      { email: userEmail },
      { fcmToken: 1, snetEmail: 1 }
    ).lean();
    const fcmToken = user && user.fcmToken;
    if (!fcmToken) {
      console.log("No FCM token found for user:", userEmail);
      return false;
    }
    if (!notifPref(user, league).points) {
      console.log(`Points notifications disabled for ${userEmail} in league ${league}`);
      return false;
    }
```

- [ ] **Step 4: Verify api.js parses**

Run: `cd /c/worldBackend && node --check api.js`
Expected: no output (syntax OK).

- [ ] **Step 5: Checkpoint (stage only)**

```bash
cd /c/worldBackend && git add api.js
```

---

### Task A5: Per-goal notification function + wiring

**Files:**
- Modify: `C:\worldBackend\api.js` (import cache; add two functions; wire into `calculatePoints` after the top-scorer sweep ~line 711)

- [ ] **Step 1: Import the cache model**

In `api.js`, extend the existing cache import (line 58):
```js
import { TopScorerAwardCache, GoalNotificationCache } from "./src/models/cacheModels.js";
```

- [ ] **Step 2: Add the goal-notification functions**

In `api.js`, immediately before `async function sendBatchNotifications(` (line 911), insert:

```js
// Multicast a single goal push to a batch of tokens. Uses sendEachForMulticast
// (firebase-admin) so one bad token doesn't fail the whole batch.
async function sendGoalMulticast(tokens, body, gameId, league) {
  const message = {
    notification: { title: "⚽ גול!", body },
    data: {
      click_action: "FLUTTER_NOTIFICATION_CLICK",
      screen: "game_details",
      gameId: String(gameId),
      league: league != null ? String(league) : "",
    },
    android: {
      notification: {
        clickAction: "FLUTTER_NOTIFICATION_CLICK",
        channelId: "high_importance_channel",
      },
    },
    apns: { payload: { aps: { sound: "default" } } },
  };
  const BATCH = 500;
  for (let i = 0; i < tokens.length; i += BATCH) {
    const batch = tokens.slice(i, i + BATCH);
    try {
      const resp = await admin
        .messaging()
        .sendEachForMulticast({ ...message, tokens: batch });
      console.log(
        `⚽ goal push: ${resp.successCount}/${batch.length} delivered (fixture ${gameId})`
      );
    } catch (err) {
      console.error(
        `Error sending goal multicast (fixture ${gameId}):`,
        err.code || err.message
      );
    }
  }
}

// Announce every goal in a LIVE game to users who opted into `goals` for this
// league. Idempotent per goal via GoalNotificationCache (survives restarts).
// Finished fixtures (FT/AET/PEN) are skipped so a just-tracked completed match
// doesn't blast its historical goals. Recipients are loaded at most once.
async function sendGoalNotificationsForFixtures(scoredFixtures, fixtureEventsMap, leagueId) {
  const FINISHED = new Set(["FT", "AET", "PEN"]);
  let tokens = null; // lazily loaded on first new goal
  const loadTokens = async () => {
    if (tokens !== null) return tokens;
    const candidates = await Users.find(
      { snetEmail: { $exists: true } },
      { fcmToken: 1, snetEmail: 1 }
    ).lean();
    tokens = candidates
      .filter((u) => u.fcmToken && notifPref(u, leagueId).goals === true)
      .map((u) => u.fcmToken);
    return tokens;
  };

  for (const game of scoredFixtures) {
    if (FINISHED.has(game.fixture?.status?.short)) continue; // live only
    const fixtureId = game.fixture.original_id;
    const events = fixtureEventsMap[fixtureId] || [];
    // Real goals only: exclude Missed Penalty. Own Goal + Penalty count.
    const goals = events.filter(
      (e) => e && e.type === "Goal" && e.detail !== "Missed Penalty"
    );
    if (goals.length === 0) continue;

    const homeHe = heTeamName(game.teams.home.name);
    const awayHe = heTeamName(game.teams.away.name);
    const homeScore = game.goals?.home ?? 0;
    const awayScore = game.goals?.away ?? 0;
    const scoreLine = `(${homeHe} ${homeScore} - ${awayScore} ${awayHe})`;

    // Ordinal per scorer keeps the idempotency key stable when the provider
    // revises a goal's minute (same rationale as createGoalAwardKey).
    const perScorer = {};
    for (const goal of goals) {
      const scorer = (goal.player && goal.player.name) || "";
      const norm = normalizeName(scorer);
      const ordinal = (perScorer[norm] = (perScorer[norm] || 0) + 1) - 1;
      const key = `${fixtureId}_${norm}_${ordinal}`;

      const claim = await GoalNotificationCache.updateOne(
        { _id: key },
        { $setOnInsert: { fixtureId, leagueId } },
        { upsert: true }
      );
      if (claim.upsertedCount !== 1) continue; // already announced

      const recipients = await loadTokens();
      if (recipients.length === 0) continue;

      const minute =
        goal.time && goal.time.elapsed != null
          ? `${goal.time.elapsed}${goal.time.extra ? "+" + goal.time.extra : ""}`
          : "";
      const isOwn = goal.detail === "Own Goal";
      const scorerTeamHe = heTeamName((goal.team && goal.team.name) || "");
      const body = isOwn
        ? `${scorer} כבש שער עצמי בדקה ${minute}׳ ${scoreLine}`
        : `${scorerTeamHe} כבשה! ${scorer} בדקה ${minute}׳ ${scoreLine}`;

      await sendGoalMulticast(recipients, body, fixtureId, leagueId);
    }
  }
}
```

- [ ] **Step 3: Wire into `calculatePoints`**

In `calculatePoints`, immediately after the top-scorer bonus sweep's closing `}` (the `catch`/`}` that ends at line 711, right before `// Batch update all point calculations`), insert:

```js
  // Fire per-goal notifications to users opted into `goals` for this league.
  // Separate from the top-scorer sweep: this notifies EVERY opted-in user, not
  // just strikers' pickers. Idempotent per goal via GoalNotificationCache.
  try {
    const goalFixtures = actualResult.filter((game) => {
      const total = (game.goals?.home || 0) + (game.goals?.away || 0);
      return (
        total > 0 && (fixtureEventsMap[game.fixture.original_id] || []).length > 0
      );
    });
    if (goalFixtures.length > 0) {
      await sendGoalNotificationsForFixtures(goalFixtures, fixtureEventsMap, leagueId);
    }
  } catch (err) {
    console.error("Error sending goal notifications:", err);
  }
```

- [ ] **Step 4: Verify api.js parses**

Run: `cd /c/worldBackend && node --check api.js`
Expected: no output (syntax OK).

- [ ] **Step 5: Run the existing points golden test (no regression)**

Run: `cd /c/worldBackend && npm test`
Expected: existing suite still PASSES (goal-notification code is not exercised by it; confirm nothing broke on import).

- [ ] **Step 6: Checkpoint (stage only)**

```bash
cd /c/worldBackend && git add api.js
```

---

## PHASE B — Frontend

### Task B1: `NotifPref` value type (TDD)

**Files:**
- Create: `C:\flutter-football\lib\models\notif_pref.dart`
- Test: `C:\flutter-football\test\notif_pref_test.dart`

- [ ] **Step 1: Write the failing test**

Create `C:\flutter-football\test\notif_pref_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:football/models/notif_pref.dart';

void main() {
  test('legacy true → reminders+points on, goals off', () {
    final p = NotifPref.fromJson(true);
    expect(p.goals, false);
    expect(p.reminders, true);
    expect(p.points, true);
  });

  test('false / null → all off', () {
    for (final v in [false, null]) {
      final p = NotifPref.fromJson(v);
      expect(p.goals, false);
      expect(p.reminders, false);
      expect(p.points, false);
    }
  });

  test('object passes through, missing fields default false', () {
    final p = NotifPref.fromJson({'goals': true});
    expect(p.goals, true);
    expect(p.reminders, false);
    expect(p.points, false);
  });

  test('toJson round-trips', () {
    const p = NotifPref(goals: true, reminders: false, points: true);
    expect(p.toJson(), {'goals': true, 'reminders': false, 'points': true});
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /c/flutter-football && flutter test test/notif_pref_test.dart`
Expected: FAIL — `notif_pref.dart` / `NotifPref` not found.

- [ ] **Step 3: Write the model**

Create `C:\flutter-football\lib\models\notif_pref.dart`:

```dart
/// Per-league notification preference. Three independently toggleable kinds:
/// goals (per-goal pushes during a game), reminders (pre-game guess reminders),
/// points (points rewarded after a game, incl. top-scorer bonus).
///
/// [NotifPref.fromJson] tolerates the legacy shape where `snetEmail[leagueId]`
/// was a bare bool, so existing users read correctly with no migration.
class NotifPref {
  final bool goals;
  final bool reminders;
  final bool points;

  const NotifPref({
    this.goals = false,
    this.reminders = false,
    this.points = false,
  });

  factory NotifPref.fromJson(dynamic value) {
    if (value is Map) {
      return NotifPref(
        goals: value['goals'] == true,
        reminders: value['reminders'] == true,
        points: value['points'] == true,
      );
    }
    // Legacy: a bare `true` meant reminders + points on, goals opt-in.
    if (value == true) {
      return const NotifPref(goals: false, reminders: true, points: true);
    }
    return const NotifPref();
  }

  Map<String, dynamic> toJson() =>
      {'goals': goals, 'reminders': reminders, 'points': points};

  NotifPref copyWith({bool? goals, bool? reminders, bool? points}) => NotifPref(
        goals: goals ?? this.goals,
        reminders: reminders ?? this.reminders,
        points: points ?? this.points,
      );

  bool get anyOn => goals || reminders || points;

  @override
  String toString() =>
      'NotifPref(goals: $goals, reminders: $reminders, points: $points)';
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /c/flutter-football && flutter test test/notif_pref_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Checkpoint (stage only)**

```bash
cd /c/flutter-football && git add lib/models/notif_pref.dart test/notif_pref_test.dart
```

---

### Task B2: Update `userAll.dart` and `users.dart` models

**Files:**
- Modify: `C:\flutter-football\lib\models\userAll.dart` (lines 10, 23, 36-39, 61, 74)
- Modify: `C:\flutter-football\lib\models\users.dart`

- [ ] **Step 1: `userAll.dart` — import + field type**

Add at top of `userAll.dart` (with other imports; if none, add above the class):
```dart
import 'notif_pref.dart';
```
Change the field (line 10) from:
```dart
  final Map<String, bool> snetEmail;
```
to:
```dart
  final Map<String, NotifPref> snetEmail;
```

- [ ] **Step 2: `userAll.dart` — coercion in fromJson**

Replace `convertSnetEmail` (lines 36-39):
```dart
    // Convert snetEmail into NotifPref, tolerating the legacy bool shape.
    Map<String, NotifPref> convertSnetEmail(Map<String, dynamic>? data) {
      return data?.map(
              (key, value) => MapEntry(key, NotifPref.fromJson(value))) ??
          {};
    }
```
(The call site at line 61 `snetEmail: convertSnetEmail(...)` stays as-is.)

- [ ] **Step 3: `users.dart` — add snetEmail field**

In `C:\flutter-football\lib\models\users.dart`, add the import at the very top:
```dart
import 'notif_pref.dart';
```
Add the field after `groupID` (line 10):
```dart
  final Map<String, NotifPref>? snetEmail;
```
Add the constructor param (in the `User({...})` block, after `this.groupID,`):
```dart
    this.snetEmail,
```
In `fromJson`, after the `groupID:` line (line 34), add:
```dart
      snetEmail: json['snetEmail'] != null
          ? Map<String, dynamic>.from(json['snetEmail'])
              .map((k, v) => MapEntry(k, NotifPref.fromJson(v)))
          : null,
```
In `toJson`, after `'groupID': groupID,` (line 48), add:
```dart
      'snetEmail':
          snetEmail?.map((k, v) => MapEntry(k, v.toJson())),
```

- [ ] **Step 4: Verify the analyzer is clean for both models**

Run: `cd /c/flutter-football && flutter analyze lib/models/notif_pref.dart lib/models/userAll.dart lib/models/users.dart`
Expected: "No issues found!"

- [ ] **Step 5: Checkpoint (stage only)**

```bash
cd /c/flutter-football && git add lib/models/userAll.dart lib/models/users.dart
```

---

### Task B3: Localization strings

**Files:**
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_he.arb`, `lib/l10n/app_localizations.dart`, `lib/l10n/app_localizations_en.dart`, `lib/l10n/app_localizations_he.dart`

Add six keys: `notifGoals`, `notifReminders`, `notifPoints`, `notifAllGoals`, `notifAllReminders`, `notifAllPoints`.

- [ ] **Step 1: `app_en.arb`**

After the `"chooseallcompetitions": ...,` line, add:
```json
    "notifGoals": "Goals",
    "notifReminders": "Reminders",
    "notifPoints": "Points",
    "notifAllGoals": "All goal alerts",
    "notifAllReminders": "All reminders",
    "notifAllPoints": "All points alerts",
```

- [ ] **Step 2: `app_he.arb`**

After **each** `"chooseallcompetitions": "בחירת כל הליגות",` occurrence (there are two in this file), add:
```json
    "notifGoals": "שערים",
    "notifReminders": "תזכורות",
    "notifPoints": "נקודות",
    "notifAllGoals": "כל התראות השערים",
    "notifAllReminders": "כל התזכורות",
    "notifAllPoints": "כל התראות הניקוד",
```
(If a locale block already contains English values, keep this Hebrew block only in the Hebrew map; match the surrounding values in each block.)

- [ ] **Step 3: `app_localizations.dart` — abstract getters**

After the `String get chooseallcompetitions;` declaration (line 474), add:
```dart
  /// No description provided for @notifGoals.
  String get notifGoals;

  /// No description provided for @notifReminders.
  String get notifReminders;

  /// No description provided for @notifPoints.
  String get notifPoints;

  /// No description provided for @notifAllGoals.
  String get notifAllGoals;

  /// No description provided for @notifAllReminders.
  String get notifAllReminders;

  /// No description provided for @notifAllPoints.
  String get notifAllPoints;
```

- [ ] **Step 4: `app_localizations_en.dart` — overrides**

Find the `String get chooseallcompetitions => '...';` override and add after it:
```dart
  @override
  String get notifGoals => 'Goals';

  @override
  String get notifReminders => 'Reminders';

  @override
  String get notifPoints => 'Points';

  @override
  String get notifAllGoals => 'All goal alerts';

  @override
  String get notifAllReminders => 'All reminders';

  @override
  String get notifAllPoints => 'All points alerts';
```

- [ ] **Step 5: `app_localizations_he.dart` — overrides**

Find the `String get chooseallcompetitions => '...';` override and add after it:
```dart
  @override
  String get notifGoals => 'שערים';

  @override
  String get notifReminders => 'תזכורות';

  @override
  String get notifPoints => 'נקודות';

  @override
  String get notifAllGoals => 'כל התראות השערים';

  @override
  String get notifAllReminders => 'כל התזכורות';

  @override
  String get notifAllPoints => 'כל התראות הניקוד';
```

- [ ] **Step 6: Verify analyzer clean for l10n**

Run: `cd /c/flutter-football && flutter analyze lib/l10n`
Expected: "No issues found!"

- [ ] **Step 7: Checkpoint (stage only)**

```bash
cd /c/flutter-football && git add lib/l10n/app_en.arb lib/l10n/app_he.arb lib/l10n/app_localizations.dart lib/l10n/app_localizations_en.dart lib/l10n/app_localizations_he.dart
```

---

### Task B4: `favorits.dart` — per-kind state + write path

**Files:**
- Modify: `C:\flutter-football\lib\screens\favorits.dart` (state map ~35-37; `_getUserInfo` ~72-91; `updateDatabase` ~99-112)

- [ ] **Step 1: Import NotifPref**

At the top of `favorits.dart` (with other imports), add:
```dart
import '../models/notif_pref.dart';
```

- [ ] **Step 2: Replace the notification state map**

Replace (lines 35-37):
```dart
  Map<int, bool> notificationStates = {
    for (final id in LeagueConfigService().supportedLeagues) id: false,
  };
```
with:
```dart
  Map<int, NotifPref> notificationStates = {
    for (final id in LeagueConfigService().supportedLeagues)
      id: const NotifPref(),
  };
```

- [ ] **Step 3: Update `_getUserInfo` to coerce**

Replace the `notificationStates[id] = snetEmail[id.toString()] == true;` line (line 83) with:
```dart
          notificationStates[id] =
              NotifPref.fromJson(snetEmail[id.toString()]);
```

- [ ] **Step 4: Update `updateDatabase` write + league-off sync**

Replace the league-off sync loop (lines 101-106):
```dart
      // Sync: disable ALL notification kinds for leagues that are unchecked.
      for (final id in LeagueConfigService().supportedLeagues) {
        if (chosenLeagues[id] == false) {
          notificationStates[id] = const NotifPref();
        }
      }
```
Replace the `set[...]` build loop (lines 108-112):
```dart
      final set = <String, dynamic>{};
      for (final id in LeagueConfigService().supportedLeagues) {
        set['chosenLeagues.$id'] = chosenLeagues[id] ?? true;
        set['snetEmail.$id'] =
            (notificationStates[id] ?? const NotifPref()).toJson();
      }
```

- [ ] **Step 5: Update the league-unchecked handler in the chooseLeagues tab**

At the `if (!chosenLeagues[id]!) { notificationStates[id] = false; }` block (~line 281-283), replace with:
```dart
                      if (!chosenLeagues[id]!) {
                        notificationStates[id] = const NotifPref();
                      }
```

- [ ] **Step 6: Verify analyzer (expected: errors ONLY in the notifications-tab builder, fixed in B5)**

Run: `cd /c/flutter-football && flutter analyze lib/screens/favorits.dart`
Expected: remaining errors are confined to the `_NotifRow`/`allOn`/`notificationStates[id] == true` usages in the notifications-tab builder (lines ~309-374) — those are rewritten in Task B5. No errors elsewhere in the file.

- [ ] **Step 7: Checkpoint (stage only)** — staged together with B5 (same file).

---

### Task B5: `favorits.dart` — three-toggle notifications UI

**Files:**
- Modify: `C:\flutter-football\lib\screens\favorits.dart` (notifications-tab builder ~300-377; `_NotifRow` widget ~546-602)

- [ ] **Step 1: Rewrite the notifications-tab builder body**

Replace the block from `final allOn =` (line 309) through the end of the `return ListView(...)` (line 376) with:

```dart
    bool allOfKind(bool Function(NotifPref) sel) =>
        enabledIds.every((id) => sel(notificationStates[id] ?? const NotifPref()));

    void setAllOfKind(String kind, bool v) {
      setState(() {
        for (final id in enabledIds) {
          final cur = notificationStates[id] ?? const NotifPref();
          notificationStates[id] = kind == 'goals'
              ? cur.copyWith(goals: v)
              : kind == 'reminders'
                  ? cur.copyWith(reminders: v)
                  : cur.copyWith(points: v);
        }
      });
      updateDatabase(name, userEmail);
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        // ── Category masters ──
        _NotifMasterRow(
          label: l.notifAllGoals,
          value: allOfKind((p) => p.goals),
          onChanged: (v) => setAllOfKind('goals', v),
        ),
        _NotifMasterRow(
          label: l.notifAllReminders,
          value: allOfKind((p) => p.reminders),
          onChanged: (v) => setAllOfKind('reminders', v),
        ),
        _NotifMasterRow(
          label: l.notifAllPoints,
          value: allOfKind((p) => p.points),
          onChanged: (v) => setAllOfKind('points', v),
        ),
        Container(height: 1, color: c.hairline),
        // ── Individual leagues: 3 toggles each ──
        ...enabledIds.map((id) {
          final pref = notificationStates[id] ?? const NotifPref();
          return _NotifLeagueRow(
            logoWidget: Container(
              width: 36,
              height: 36,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: pref.anyOn ? c.live.withOpacity(0.5) : c.hairline,
                  width: 1,
                ),
              ),
              child: Image(
                image: leagueLogoProvider(id),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.shield_outlined, size: 16, color: c.inkDim),
              ),
            ),
            label: _localizedLeagueName(id),
            pref: pref,
            goalsLabel: l.notifGoals,
            remindersLabel: l.notifReminders,
            pointsLabel: l.notifPoints,
            onChanged: (next) {
              setState(() => notificationStates[id] = next);
              updateDatabase(name, userEmail);
            },
          );
        }),
      ],
    );
  }
}
```

- [ ] **Step 2: Add the two new row widgets**

Immediately after the closing brace of the `_NotifRow` class (line 602), add:

```dart
// ── Master toggle for one notification kind across all leagues ──────────
class _NotifMasterRow extends StatelessWidget {
  const _NotifMasterRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Container(
      decoration: BoxDecoration(
        color: c.terrace,
        border: Border(bottom: BorderSide(color: c.hairline, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.notifications_outlined, size: 16, color: c.inkMute),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: EType.label(color: c.ink, size: 11, letterSpacing: 1.8),
            ),
          ),
          const SizedBox(width: 12),
          _EditorialSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

// ── One league row with three labeled toggles ──────────────────────────
class _NotifLeagueRow extends StatelessWidget {
  const _NotifLeagueRow({
    required this.logoWidget,
    required this.label,
    required this.pref,
    required this.goalsLabel,
    required this.remindersLabel,
    required this.pointsLabel,
    required this.onChanged,
  });
  final Widget logoWidget;
  final String label;
  final NotifPref pref;
  final String goalsLabel;
  final String remindersLabel;
  final String pointsLabel;
  final ValueChanged<NotifPref> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    Widget toggle(String lbl, bool value, NotifPref Function(bool) apply) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                lbl.toUpperCase(),
                overflow: TextOverflow.ellipsis,
                style: EType.label(color: c.inkMute, size: 11, letterSpacing: 1.2),
              ),
            ),
            const SizedBox(width: 12),
            _EditorialSwitch(value: value, onChanged: (v) => onChanged(apply(v))),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: c.hairline, width: 1),
          left: BorderSide(
            color: pref.anyOn ? c.live : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              logoWidget,
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: EType.display(
                      size: 16, color: c.ink, letterSpacing: 0.8, height: 1.0),
                ),
              ),
            ],
          ),
          toggle(goalsLabel, pref.goals, (v) => pref.copyWith(goals: v)),
          toggle(remindersLabel, pref.reminders, (v) => pref.copyWith(reminders: v)),
          toggle(pointsLabel, pref.points, (v) => pref.copyWith(points: v)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Analyzer clean for the whole file**

Run: `cd /c/flutter-football && flutter analyze lib/screens/favorits.dart`
Expected: "No issues found!" (the old `_NotifRow` may now be unused — if the analyzer flags it as unused, delete the `_NotifRow` class; it is no longer referenced.)

- [ ] **Step 4: Full analyze + model test**

Run: `cd /c/flutter-football && flutter analyze && flutter test test/notif_pref_test.dart`
Expected: "No issues found!" and the NotifPref tests PASS.

- [ ] **Step 5: Checkpoint (stage only)**

```bash
cd /c/flutter-football && git add lib/screens/favorits.dart
```

---

### Task B6: Version bump

**Files:**
- Modify: `C:\flutter-football\pubspec.yaml` (`version:` line)

- [ ] **Step 1: Bump the build**

In `pubspec.yaml`, increment the `version:` — bump the patch and build number (e.g. `6.33.46+85` → `6.34.46+86`). Match the existing scheme; confirm the current value first with:
Run: `cd /c/flutter-football && grep '^version:' pubspec.yaml`

- [ ] **Step 2: Checkpoint (stage only)**

```bash
cd /c/flutter-football && git add pubspec.yaml
```

---

## Verification (whole feature)

- [ ] **Backend:** `cd /c/worldBackend && npm test` (golden suite passes) and `node --test tests/notifPrefs.test.mjs` (helper passes); `node --check api.js`.
- [ ] **Frontend:** `cd /c/flutter-football && flutter analyze` ("No issues found!") and `flutter test test/notif_pref_test.dart`.
- [ ] **Manual smoke (optional, if a device/emulator is available):** open the Notifications tab, confirm each league shows Goals/Reminders/Points toggles, flip one, and confirm the PUT to `/users/` writes `snetEmail.<id> = {goals,reminders,points}` (check the backend user doc). A legacy user (bool `snetEmail`) should show Reminders+Points ON, Goals OFF on first open.

---

## Self-Review Notes (author)

- **Spec coverage:** data model (A1/B1), gate mapping table (A3/A4), new goal notification incl. own-goal/penalty/minute-extra/running-score (A5), models incl. `users.dart` (B2), 3-inline-toggle UI + masters (B4/B5), localization (B3), versioning (B6), points-gating behavior change (A4). All spec sections have a task.
- **Type/name consistency:** `notifPref`/`coerceNotifPref` (backend), `NotifPref`/`fromJson`/`toJson`/`copyWith`/`anyOn` (frontend), `GoalNotificationCache`, `sendGoalNotificationsForFixtures`/`sendGoalMulticast` used consistently across tasks.
- **No migration:** confirmed — coercion handles legacy bools on read; writes upgrade docs in place.
