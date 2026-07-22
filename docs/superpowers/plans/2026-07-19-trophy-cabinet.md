# Trophy Cabinet Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a per-league "Trophy Cabinet" as a third Profile tab showing the user's current-season results (points, global rank, champion & top-scorer outcomes, bracket points), plus a backend season-history archive so past seasons accumulate over time.

**Architecture:** A pure, unit-tested helper in `worldBackend` builds per-league season records and ranks users. `resetUserStats()` (the existing season-reset routine) snapshots those records into a new `SeasonHistory` collection before wiping. Two read endpoints expose the current-season summary (computed live) and past history in one shared shape. The Flutter client adds a `SeasonRecord` model, a `TrophyMethods` service, and a presentational cabinet tab.

**Tech Stack:** Node ESM + Mongoose 8 + `node --test`/esmock (backend); Flutter + Provider + `flutter test` (frontend).

**Two repos:** backend paths are under `C:\worldBackend`; frontend paths under `C:\flutter-football`. Backend commands run from `C:\worldBackend`; frontend commands from `C:\flutter-football`.

**Shared record shape** (JSON, used by both endpoints and the Dart model):

```json
{
  "leagueId": 39,
  "season": 2025,
  "current": true,
  "points": 120,
  "rank": 3,
  "totalPlayers": 45,
  "winnerPick": "Manchester City",
  "championName": "Liverpool",
  "championCorrect": false,
  "championPoints": 0,
  "topScorerPick": "Erling Haaland",
  "topScorerPoints": 18,
  "bracketPoints": 0
}
```

---

## File Structure

**Backend (`C:\worldBackend`):**
- Create `src/utils/seasonHistory.js` — pure helpers: `computeLeagueRanks`, `buildUserSeasonRecord`. No DB, no I/O.
- Create `src/models/seasonHistoryModel.js` — `SeasonHistory` Mongoose model.
- Create `tests/seasonHistory.test.mjs` — unit tests for the pure helpers.
- Modify `src/controllers/usersClass.js` — snapshot inside `resetUserStats()`; add `getSeasonSummary` + `getHistory` controller methods.
- Modify `src/routes/users.js` — register the two GET routes.

**Frontend (`C:\flutter-football`):**
- Create `lib/models/season_record.dart` — `SeasonRecord` + `fromJson`.
- Create `lib/resources/trophyMethods.dart` — `TrophyMethods.fetchSeasonSummary` / `fetchHistory`.
- Create `lib/widgets/trophyCabinet.dart` — `TrophyCabinetTab` (fetches + renders).
- Create `test/season_record_test.dart` — model unit test.
- Create `test/trophy_cabinet_test.dart` — cabinet widget test.
- Modify `lib/screens/profile.dart` — three-way tab selector + cabinet child.
- Modify `lib/l10n/app_en.arb`, `lib/l10n/app_he.arb`, `lib/l10n/app_localizations.dart`, `lib/l10n/app_localizations_en.dart`, `lib/l10n/app_localizations_he.dart` — new strings.

---

## Task 1: Backend pure helpers (`seasonHistory.js`)

**Files:**
- Create: `C:\worldBackend\src\utils\seasonHistory.js`
- Test: `C:\worldBackend\tests\seasonHistory.test.mjs`

- [ ] **Step 1: Write the failing test**

Create `C:\worldBackend\tests\seasonHistory.test.mjs`:

```javascript
import { test } from "node:test";
import assert from "node:assert/strict";
import { computeLeagueRanks, buildUserSeasonRecord } from "../src/utils/seasonHistory.js";

const users = [
  { _id: "a", points: { "39": 120 }, winner: { "39": "Man City" }, topScorer: { "39": "Haaland" }, topScorerPoints: { "39": 18 }, championPoints: { "39": 0 }, bracketPoints: {} },
  { _id: "b", points: { "39": 200 }, winner: {}, topScorer: {}, topScorerPoints: {}, championPoints: {}, bracketPoints: {} },
  { _id: "c", points: { "39": 50 }, winner: {}, topScorer: {}, topScorerPoints: {}, championPoints: {}, bracketPoints: {} },
  { _id: "d", points: {}, winner: {}, topScorer: {}, topScorerPoints: {}, championPoints: {}, bracketPoints: {} },
];

test("computeLeagueRanks ranks participants by points desc, ignores non-participants", () => {
  const { ranks, totalPlayers } = computeLeagueRanks(users, "39");
  assert.equal(totalPlayers, 3); // a, b, c have a points entry; d does not
  assert.equal(ranks["b"], 1);
  assert.equal(ranks["a"], 2);
  assert.equal(ranks["c"], 3);
  assert.equal(ranks["d"], undefined);
});

test("buildUserSeasonRecord returns a full record for a participant", () => {
  const { ranks, totalPlayers } = computeLeagueRanks(users, "39");
  const rec = buildUserSeasonRecord(users[0], "39", {
    season: 2025,
    current: true,
    rank: ranks["a"],
    totalPlayers,
    championName: "Liverpool",
  });
  assert.deepEqual(rec, {
    leagueId: 39,
    season: 2025,
    current: true,
    points: 120,
    rank: 2,
    totalPlayers: 3,
    winnerPick: "Man City",
    championName: "Liverpool",
    championCorrect: false,
    championPoints: 0,
    topScorerPick: "Haaland",
    topScorerPoints: 18,
    bracketPoints: 0,
  });
});

test("buildUserSeasonRecord derives championCorrect from championPoints > 0", () => {
  const u = { _id: "x", points: { "39": 10 }, winner: { "39": "Liverpool" }, championPoints: { "39": 20 }, topScorer: {}, topScorerPoints: {}, bracketPoints: {} };
  const rec = buildUserSeasonRecord(u, "39", { season: 2025, current: false, rank: 1, totalPlayers: 1, championName: "Liverpool" });
  assert.equal(rec.championCorrect, true);
  assert.equal(rec.championPoints, 20);
});

test("buildUserSeasonRecord returns null when the user never participated in the league", () => {
  const rec = buildUserSeasonRecord(users[3], "39", { season: 2025, current: true, rank: undefined, totalPlayers: 3, championName: null });
  assert.equal(rec, null);
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd /c/worldBackend && node --test tests/seasonHistory.test.mjs`
Expected: FAIL — `Cannot find module '../src/utils/seasonHistory.js'`.

- [ ] **Step 3: Write the implementation**

Create `C:\worldBackend\src\utils\seasonHistory.js`:

```javascript
// Pure helpers for building per-league season-history records and ranking
// users. No DB access — callers pass in already-loaded user docs so this stays
// unit-testable (see tests/seasonHistory.test.mjs). Shared by the season
// snapshot in resetUserStats() and the live GET /users/:id/season-summary.

function num(v) {
  return typeof v === "number" && Number.isFinite(v) ? v : 0;
}

// Participation = the user has any signal for this league. Non-participants are
// excluded from ranking and produce a null record (nothing to archive/show).
function participated(user, key) {
  const p = user.points && user.points[key];
  const w = user.winner && user.winner[key];
  const t = user.topScorer && user.topScorer[key];
  const b = user.bracketPoints && user.bracketPoints[key];
  return (
    typeof p === "number" ||
    (w !== undefined && w !== null && String(w).trim() !== "") ||
    (t !== undefined && t !== null && String(t).trim() !== "") ||
    typeof b === "number"
  );
}

// { ranks: { userId: rank(1-based) }, totalPlayers }. Only users with a numeric
// points entry for the league are ranked; ties keep input order (matches the
// existing leaderboard's plain points-desc sort in usersClass.getGroupUsers).
export function computeLeagueRanks(users, leagueId) {
  const key = String(leagueId);
  const ranked = users
    .filter((u) => typeof (u.points && u.points[key]) === "number")
    .map((u) => ({ id: String(u._id), pts: num(u.points[key]) }))
    .sort((a, b) => b.pts - a.pts);
  const ranks = {};
  ranked.forEach((r, i) => {
    ranks[r.id] = i + 1;
  });
  return { ranks, totalPlayers: ranked.length };
}

// Build one league record for one user, or null if they never participated.
export function buildUserSeasonRecord(user, leagueId, opts) {
  const key = String(leagueId);
  if (!participated(user, key)) return null;
  const { season, current, rank, totalPlayers, championName } = opts;
  const championPoints = num(user.championPoints && user.championPoints[key]);
  const winnerPick =
    (user.winner && user.winner[key] != null && String(user.winner[key])) || null;
  const topScorerPick =
    (user.topScorer && user.topScorer[key] != null && String(user.topScorer[key])) || null;
  return {
    leagueId: Number(leagueId),
    season,
    current: Boolean(current),
    points: num(user.points && user.points[key]),
    rank: rank ?? null,
    totalPlayers: totalPlayers ?? 0,
    winnerPick,
    championName: championName ?? null,
    championCorrect: championPoints > 0,
    championPoints,
    topScorerPick,
    topScorerPoints: num(user.topScorerPoints && user.topScorerPoints[key]),
    bracketPoints: num(user.bracketPoints && user.bracketPoints[key]),
  };
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd /c/worldBackend && node --test tests/seasonHistory.test.mjs`
Expected: PASS — 4 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
cd /c/worldBackend && git add src/utils/seasonHistory.js tests/seasonHistory.test.mjs && git commit -m "feat: pure helpers for season-history records and ranking"
```

---

## Task 2: `SeasonHistory` model

**Files:**
- Create: `C:\worldBackend\src\models\seasonHistoryModel.js`

- [ ] **Step 1: Write the model**

Create `C:\worldBackend\src\models\seasonHistoryModel.js`:

```javascript
import mongoose from "mongoose";

const { Schema } = mongoose;

// One archived record per {userId, leagueId, season}. Written by the season
// snapshot in usersClass.resetUserStats() before points/winner are wiped.
// Kept in its own collection (not embedded on the user doc) so it can grow
// season over season without bloating the hot user document.
const seasonHistorySchema = new Schema(
  {
    userId: { type: String, index: true },
    leagueId: { type: Number, index: true },
    season: { type: Number, index: true },
    points: { type: Number, default: 0 },
    rank: { type: Number, default: null },
    totalPlayers: { type: Number, default: 0 },
    winnerPick: { type: String, default: null },
    championName: { type: String, default: null },
    championCorrect: { type: Boolean, default: false },
    championPoints: { type: Number, default: 0 },
    topScorerPick: { type: String, default: null },
    topScorerPoints: { type: Number, default: 0 },
    bracketPoints: { type: Number, default: 0 },
    settledAt: { type: Date, default: Date.now },
  },
  { minimize: false }
);

// Idempotency key: a re-run of the snapshot upserts the same doc rather than
// creating a duplicate.
seasonHistorySchema.index({ userId: 1, leagueId: 1, season: 1 }, { unique: true });

const SeasonHistory = mongoose.model("SeasonHistory", seasonHistorySchema, "seasonHistory");

export default SeasonHistory;
```

- [ ] **Step 2: Verify it imports cleanly**

Run: `cd /c/worldBackend && node -e "import('./src/models/seasonHistoryModel.js').then(m => console.log('ok:', m.default.modelName)).catch(e => { console.error(e); process.exit(1); })"`
Expected: prints `ok: SeasonHistory`.

- [ ] **Step 3: Commit**

```bash
cd /c/worldBackend && git add src/models/seasonHistoryModel.js && git commit -m "feat: SeasonHistory model for archived per-league season records"
```

---

## Task 3: Snapshot on season reset

**Files:**
- Modify: `C:\worldBackend\src\controllers\usersClass.js` (imports near top; `resetUserStats` at ~line 37)

- [ ] **Step 1: Add imports**

At the top of `usersClass.js`, after the existing `import Users from "../models/usersModel.js";` (line 17), add:

```javascript
import SeasonHistory from "../models/seasonHistoryModel.js";
import { ChampionSettlementCache } from "../models/cacheModels.js";
import { getLeagueIds } from "../config/leaguesConfig.js";
import { computeLeagueRanks, buildUserSeasonRecord } from "../utils/seasonHistory.js";
```

- [ ] **Step 2: Snapshot before the wipe**

In `resetUserStats()`, replace the body from `const users = await Users.find({});` down to the `for (const user of users) {` loop start so the snapshot runs first. Insert this block immediately after `const users = await Users.find({});`:

```javascript
      // ── Archive the finished season before wiping ────────────────────────
      // Snapshot each user's per-league results into SeasonHistory so the
      // Trophy Cabinet can show past seasons. Idempotent on
      // {userId, leagueId, season}. Runs BEFORE the reset below.
      const season = process.env.SEASON ? Number(process.env.SEASON) : null;
      const leagueIds = getLeagueIds();

      // Champion names per league from the settlement audit records, so an
      // archived record can show the actual champion, not just correct/missed.
      const championNames = {};
      for (const lid of leagueIds) {
        const settlement = await ChampionSettlementCache.findById(
          `${lid}:${season}`
        ).lean();
        if (settlement && settlement.championName) {
          championNames[lid] = settlement.championName;
        }
      }

      for (const lid of leagueIds) {
        const { ranks, totalPlayers } = computeLeagueRanks(users, lid);
        for (const user of users) {
          const record = buildUserSeasonRecord(user, lid, {
            season,
            current: false,
            rank: ranks[String(user._id)],
            totalPlayers,
            championName: championNames[lid] ?? null,
          });
          if (!record) continue;
          await SeasonHistory.updateOne(
            { userId: String(user._id), leagueId: record.leagueId, season },
            { $set: { ...record, userId: String(user._id), settledAt: new Date() } },
            { upsert: true }
          );
        }
      }
      console.log(`[SeasonHistory] archived season ${season} for ${users.length} users`);
```

Leave the existing reset loop (`for (const user of users) { ... }`) unchanged below this block.

- [ ] **Step 3: Verify the file parses**

Run: `cd /c/worldBackend && node -e "import('./src/controllers/usersClass.js').then(() => console.log('ok')).catch(e => { console.error(e); process.exit(1); })"`
Expected: prints `ok` (module loads without syntax/import errors).

- [ ] **Step 4: Run the existing test suite (no regressions)**

Run: `cd /c/worldBackend && node --test tests/seasonHistory.test.mjs`
Expected: PASS — Task 1 tests still green.

- [ ] **Step 5: Commit**

```bash
cd /c/worldBackend && git add src/controllers/usersClass.js && git commit -m "feat: archive season results into SeasonHistory on season reset"
```

---

## Task 4: Read endpoints (`getSeasonSummary`, `getHistory`)

**Files:**
- Modify: `C:\worldBackend\src\controllers\usersClass.js` (add two methods to the class)
- Modify: `C:\worldBackend\src\routes\users.js`

- [ ] **Step 1: Add controller methods**

In `usersClass.js`, add these two methods inside the `User` class (e.g. right after `resetUserStats()`):

```javascript
  // GET /users/:id/season-summary — current-season per-league records computed
  // live (rank derived by ranking all users on points[league]). Same shape as
  // an archived SeasonHistory doc, marked current:true.
  async getSeasonSummary(req, res) {
    try {
      const { id } = req.params;
      const season = process.env.SEASON ? Number(process.env.SEASON) : null;
      const users = await Users.find({}).lean();
      const me = users.find((u) => String(u._id) === String(id));
      if (!me) return res.status(404).json({ error: "User not found" });

      const championNames = {};
      const leagueIds = getLeagueIds();
      for (const lid of leagueIds) {
        const settlement = await ChampionSettlementCache.findById(
          `${lid}:${season}`
        ).lean();
        if (settlement && settlement.championName) {
          championNames[lid] = settlement.championName;
        }
      }

      const records = [];
      for (const lid of leagueIds) {
        const { ranks, totalPlayers } = computeLeagueRanks(users, lid);
        const record = buildUserSeasonRecord(me, lid, {
          season,
          current: true,
          rank: ranks[String(me._id)],
          totalPlayers,
          championName: championNames[lid] ?? null,
        });
        if (record) records.push(record);
      }
      res.json(records);
    } catch (error) {
      console.error("getSeasonSummary error:", error);
      res.status(500).json({ error: "Internal server error" });
    }
  }

  // GET /users/:id/history — archived past-season records, newest season first.
  async getHistory(req, res) {
    try {
      const { id } = req.params;
      const rows = await SeasonHistory.find({ userId: String(id) })
        .sort({ season: -1, leagueId: 1 })
        .lean();
      const records = rows.map((r) => ({
        leagueId: r.leagueId,
        season: r.season,
        current: false,
        points: r.points ?? 0,
        rank: r.rank ?? null,
        totalPlayers: r.totalPlayers ?? 0,
        winnerPick: r.winnerPick ?? null,
        championName: r.championName ?? null,
        championCorrect: Boolean(r.championCorrect),
        championPoints: r.championPoints ?? 0,
        topScorerPick: r.topScorerPick ?? null,
        topScorerPoints: r.topScorerPoints ?? 0,
        bracketPoints: r.bracketPoints ?? 0,
      }));
      res.json(records);
    } catch (error) {
      console.error("getHistory error:", error);
      res.status(500).json({ error: "Internal server error" });
    }
  }
```

- [ ] **Step 2: Register the routes**

In `src/routes/users.js`, add these two lines immediately after line 56 (`router.get("/user-groups/:userId", user.getUsersGroups);`), before the 404 middleware:

```javascript
router.get("/:id/season-summary", user.getSeasonSummary);
router.get("/:id/history", user.getHistory);
```

Note: these are two-segment paths, so they do not collide with the single-segment `router.get("/:id", ...)` at line 29.

- [ ] **Step 3: Verify both files parse**

Run: `cd /c/worldBackend && node -e "Promise.all([import('./src/controllers/usersClass.js'), import('./src/routes/users.js')]).then(() => console.log('ok')).catch(e => { console.error(e); process.exit(1); })"`
Expected: prints `ok`.

- [ ] **Step 4: Commit**

```bash
cd /c/worldBackend && git add src/controllers/usersClass.js src/routes/users.js && git commit -m "feat: season-summary and history read endpoints"
```

---

## Task 5: Frontend `SeasonRecord` model

**Files:**
- Create: `C:\flutter-football\lib\models\season_record.dart`
- Test: `C:\flutter-football\test\season_record_test.dart`

- [ ] **Step 1: Write the failing test**

Create `C:\flutter-football\test\season_record_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:football/models/season_record.dart';

void main() {
  test('SeasonRecord.fromJson parses a full record', () {
    final r = SeasonRecord.fromJson({
      'leagueId': 39,
      'season': 2025,
      'current': true,
      'points': 120,
      'rank': 3,
      'totalPlayers': 45,
      'winnerPick': 'Manchester City',
      'championName': 'Liverpool',
      'championCorrect': false,
      'championPoints': 0,
      'topScorerPick': 'Erling Haaland',
      'topScorerPoints': 18,
      'bracketPoints': 0,
    });
    expect(r.leagueId, 39);
    expect(r.season, 2025);
    expect(r.current, true);
    expect(r.points, 120);
    expect(r.rank, 3);
    expect(r.totalPlayers, 45);
    expect(r.winnerPick, 'Manchester City');
    expect(r.championName, 'Liverpool');
    expect(r.championCorrect, false);
    expect(r.topScorerPick, 'Erling Haaland');
    expect(r.topScorerPoints, 18);
    expect(r.bracketPoints, 0);
  });

  test('SeasonRecord.fromJson tolerates nulls and missing fields', () {
    final r = SeasonRecord.fromJson({'leagueId': 39, 'season': 2025});
    expect(r.leagueId, 39);
    expect(r.rank, isNull);
    expect(r.points, 0);
    expect(r.winnerPick, isNull);
    expect(r.championCorrect, false);
    expect(r.current, false);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd /c/flutter-football && flutter test test/season_record_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:football/models/season_record.dart'`.

- [ ] **Step 3: Write the model**

Create `C:\flutter-football\lib\models\season_record.dart`:

```dart
// One per-league season record. The same shape is returned by both
// GET /users/:id/season-summary (current:true, computed live) and
// GET /users/:id/history (archived past seasons), so the cabinet renders both
// identically.
class SeasonRecord {
  final int leagueId;
  final int season;
  final bool current;
  final int points;
  final int? rank;
  final int totalPlayers;
  final String? winnerPick;
  final String? championName;
  final bool championCorrect;
  final int championPoints;
  final String? topScorerPick;
  final int topScorerPoints;
  final int bracketPoints;

  const SeasonRecord({
    required this.leagueId,
    required this.season,
    required this.current,
    required this.points,
    required this.rank,
    required this.totalPlayers,
    required this.winnerPick,
    required this.championName,
    required this.championCorrect,
    required this.championPoints,
    required this.topScorerPick,
    required this.topScorerPoints,
    required this.bracketPoints,
  });

  static int _int(dynamic v) => (v is num) ? v.toInt() : 0;
  static int? _intOrNull(dynamic v) => (v is num) ? v.toInt() : null;
  static String? _strOrNull(dynamic v) =>
      (v == null || (v is String && v.trim().isEmpty)) ? null : v.toString();

  factory SeasonRecord.fromJson(Map<String, dynamic> json) => SeasonRecord(
        leagueId: _int(json['leagueId']),
        season: _int(json['season']),
        current: json['current'] == true,
        points: _int(json['points']),
        rank: _intOrNull(json['rank']),
        totalPlayers: _int(json['totalPlayers']),
        winnerPick: _strOrNull(json['winnerPick']),
        championName: _strOrNull(json['championName']),
        championCorrect: json['championCorrect'] == true,
        championPoints: _int(json['championPoints']),
        topScorerPick: _strOrNull(json['topScorerPick']),
        topScorerPoints: _int(json['topScorerPoints']),
        bracketPoints: _int(json['bracketPoints']),
      );
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd /c/flutter-football && flutter test test/season_record_test.dart`
Expected: PASS — 2 tests.

- [ ] **Step 5: Commit**

```bash
cd /c/flutter-football && git add lib/models/season_record.dart test/season_record_test.dart && git commit -m "feat: SeasonRecord model"
```

---

## Task 6: Frontend `TrophyMethods` service

**Files:**
- Create: `C:\flutter-football\lib\resources\trophyMethods.dart`

- [ ] **Step 1: Write the service**

Create `C:\flutter-football\lib\resources\trophyMethods.dart`:

```dart
import 'dart:convert';
import 'package:football/models/season_record.dart';
import 'package:football/utils/config.dart';
import 'package:http/http.dart' as http;

// Reads the Trophy Cabinet data. Both calls return List<SeasonRecord>; the
// cabinet renders the current-season summary and past-season history the same
// way. Kept injectable so widget tests can supply a fake (see
// test/trophy_cabinet_test.dart).
class TrophyMethods {
  const TrophyMethods();

  String get _baseUrl => backendUrl;

  Future<List<SeasonRecord>> fetchSeasonSummary(String userId) async {
    final res = await http.get(Uri.parse('$_baseUrl/users/$userId/season-summary'));
    if (res.statusCode != 200) {
      throw Exception('Failed to load season summary: ${res.statusCode}');
    }
    return _parse(res.body);
  }

  Future<List<SeasonRecord>> fetchHistory(String userId) async {
    final res = await http.get(Uri.parse('$_baseUrl/users/$userId/history'));
    if (res.statusCode != 200) {
      throw Exception('Failed to load history: ${res.statusCode}');
    }
    return _parse(res.body);
  }

  List<SeasonRecord> _parse(String body) {
    final data = jsonDecode(body);
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(SeasonRecord.fromJson)
        .toList();
  }
}
```

- [ ] **Step 2: Verify it analyzes clean**

Run: `cd /c/flutter-football && flutter analyze lib/resources/trophyMethods.dart lib/models/season_record.dart`
Expected: "No issues found!"

- [ ] **Step 3: Commit**

```bash
cd /c/flutter-football && git add lib/resources/trophyMethods.dart && git commit -m "feat: TrophyMethods service"
```

---

## Task 7: Localization strings

**Files:**
- Modify: `C:\flutter-football\lib\l10n\app_en.arb`
- Modify: `C:\flutter-football\lib\l10n\app_he.arb`
- Modify: `C:\flutter-football\lib\l10n\app_localizations.dart`
- Modify: `C:\flutter-football\lib\l10n\app_localizations_en.dart`
- Modify: `C:\flutter-football\lib\l10n\app_localizations_he.dart`

New keys: `trophyCabinet`, `thisSeason`, `pastSeasons`, `trophySeason`, `trophyRank`, `trophyOf`, `trophyChampionLabel`, `trophyTopScorerLabel`, `trophyBracketLabel`, `trophyCorrect`, `trophyMissed`, `noTrophiesYet`, `noTrophiesHint`.

- [ ] **Step 1: Add to `app_en.arb`**

Add these entries (before the closing `}` of the JSON object; ensure the preceding entry ends with a comma):

```json
  "trophyCabinet": "Trophy Cabinet",
  "thisSeason": "This Season",
  "pastSeasons": "Past Seasons",
  "trophySeason": "Season",
  "trophyRank": "Rank",
  "trophyOf": "of",
  "trophyChampionLabel": "Champion",
  "trophyTopScorerLabel": "Top Scorer",
  "trophyBracketLabel": "Bracket",
  "trophyCorrect": "Correct",
  "trophyMissed": "Missed",
  "noTrophiesYet": "No trophies yet",
  "noTrophiesHint": "Your season results will appear here."
```

- [ ] **Step 2: Add to `app_he.arb`**

Add the matching entries:

```json
  "trophyCabinet": "ארון גביעים",
  "thisSeason": "העונה",
  "pastSeasons": "עונות קודמות",
  "trophySeason": "עונה",
  "trophyRank": "דירוג",
  "trophyOf": "מתוך",
  "trophyChampionLabel": "אלופה",
  "trophyTopScorerLabel": "מלך שערים",
  "trophyBracketLabel": "נוקאאוט",
  "trophyCorrect": "פגעת",
  "trophyMissed": "לא פגעת",
  "noTrophiesYet": "אין גביעים עדיין",
  "noTrophiesHint": "תוצאות העונה שלך יופיעו כאן."
```

- [ ] **Step 3: Add abstract getters to `app_localizations.dart`**

Add these getters to the abstract `AppLocalizations` class (place them together, e.g. right after `String get topScorers;` at line 744):

```dart
  String get trophyCabinet;
  String get thisSeason;
  String get pastSeasons;
  String get trophySeason;
  String get trophyRank;
  String get trophyOf;
  String get trophyChampionLabel;
  String get trophyTopScorerLabel;
  String get trophyBracketLabel;
  String get trophyCorrect;
  String get trophyMissed;
  String get noTrophiesYet;
  String get noTrophiesHint;
```

Note: `noTrophiesYet`/`noTrophiesHint` are new — confirm they are not already declared (they are not; only `noWinnersYet` exists).

- [ ] **Step 4: Add overrides to `app_localizations_en.dart`**

Add to the `AppLocalizationsEn` class:

```dart
  @override
  String get trophyCabinet => 'Trophy Cabinet';
  @override
  String get thisSeason => 'This Season';
  @override
  String get pastSeasons => 'Past Seasons';
  @override
  String get trophySeason => 'Season';
  @override
  String get trophyRank => 'Rank';
  @override
  String get trophyOf => 'of';
  @override
  String get trophyChampionLabel => 'Champion';
  @override
  String get trophyTopScorerLabel => 'Top Scorer';
  @override
  String get trophyBracketLabel => 'Bracket';
  @override
  String get trophyCorrect => 'Correct';
  @override
  String get trophyMissed => 'Missed';
  @override
  String get noTrophiesYet => 'No trophies yet';
  @override
  String get noTrophiesHint => 'Your season results will appear here.';
```

- [ ] **Step 5: Add overrides to `app_localizations_he.dart`**

Add to the `AppLocalizationsHe` class:

```dart
  @override
  String get trophyCabinet => 'ארון גביעים';
  @override
  String get thisSeason => 'העונה';
  @override
  String get pastSeasons => 'עונות קודמות';
  @override
  String get trophySeason => 'עונה';
  @override
  String get trophyRank => 'דירוג';
  @override
  String get trophyOf => 'מתוך';
  @override
  String get trophyChampionLabel => 'אלופה';
  @override
  String get trophyTopScorerLabel => 'מלך שערים';
  @override
  String get trophyBracketLabel => 'נוקאאוט';
  @override
  String get trophyCorrect => 'פגעת';
  @override
  String get trophyMissed => 'לא פגעת';
  @override
  String get noTrophiesYet => 'אין גביעים עדיין';
  @override
  String get noTrophiesHint => 'תוצאות העונה שלך יופיעו כאן.';
```

- [ ] **Step 6: Verify localization compiles**

Run: `cd /c/flutter-football && flutter analyze lib/l10n`
Expected: "No issues found!" (an abstract getter with no override in either locale class would surface here).

- [ ] **Step 7: Commit**

```bash
cd /c/flutter-football && git add lib/l10n && git commit -m "feat: Trophy Cabinet localization strings"
```

---

## Task 8: Cabinet tab widget

**Files:**
- Create: `C:\flutter-football\lib\widgets\trophyCabinet.dart`

This widget fetches summary + history on mount (lazy — it is only mounted when the cabinet tab is selected) and renders sections. It accepts an injectable `TrophyMethods` for testing.

- [ ] **Step 1: Write the widget**

Create `C:\flutter-football\lib\widgets\trophyCabinet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:football/models/season_record.dart';
import 'package:football/resources/league_config_service.dart';
import 'package:football/resources/trophyMethods.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:football/utils/league_logos.dart';

// Third Profile tab. Shows the user's current-season records ("This Season")
// plus archived past seasons. Only mounted while the tab is active, so its
// initState fetch doubles as lazy loading.
class TrophyCabinetTab extends StatefulWidget {
  const TrophyCabinetTab({
    super.key,
    required this.userId,
    required this.allowedIds,
    this.methods = const TrophyMethods(),
  });

  final String userId;
  // Supported ∩ opted-in league ids (string), same set the other tabs use.
  final Set<String> allowedIds;
  final TrophyMethods methods;

  @override
  State<TrophyCabinetTab> createState() => _TrophyCabinetTabState();
}

class _TrophyCabinetTabState extends State<TrophyCabinetTab> {
  List<SeasonRecord> _summary = const [];
  List<SeasonRecord> _history = const [];
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        widget.methods.fetchSeasonSummary(widget.userId),
        widget.methods.fetchHistory(widget.userId),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = _filter(results[0]);
        _history = _filter(results[1]);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  List<SeasonRecord> _filter(List<SeasonRecord> src) =>
      src.where((r) => widget.allowedIds.contains(r.leagueId.toString())).toList();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_summary.isEmpty && _history.isEmpty) {
      return _CabinetEmpty(title: l.noTrophiesYet, subtitle: l.noTrophiesHint);
    }

    // Group past history by season, newest first.
    final seasons = <int>{for (final r in _history) r.season}.toList()
      ..sort((a, b) => b.compareTo(a));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_summary.isNotEmpty) ...[
          _SectionHeader(label: l.thisSeason),
          ..._summary.map((r) => _TrophyCard(record: r)),
        ],
        if (seasons.isNotEmpty) _SectionHeader(label: l.pastSeasons),
        for (final s in seasons) ...[
          _SectionHeader(label: '${l.trophySeason} $s', dim: true),
          ..._history.where((r) => r.season == s).map((r) => _TrophyCard(record: r)),
        ],
      ],
    );
  }
}

String _leagueName(BuildContext context, int leagueId) {
  final remote = LeagueConfigService()
      .nameFor(leagueId, Localizations.localeOf(context).languageCode);
  return remote ?? leagueId.toString();
}

String _leagueLogoUrl(int leagueId) =>
    'https://media.api-sports.io/football/leagues/$leagueId.png';

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, this.dim = false});
  final String label;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Text(
        label.toUpperCase(),
        style: EType.label(
          color: dim ? c.inkDim : c.ink,
          size: dim ? 11 : 13,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

class _TrophyCard extends StatelessWidget {
  const _TrophyCard({required this.record});
  final SeasonRecord record;

  Color _rankColor(EditorialColors c) {
    switch (record.rank) {
      case 1:
        return const Color(0xFFD4AF37); // gold
      case 2:
        return const Color(0xFFAAB2BD); // silver
      case 3:
        return const Color(0xFFCD7F32); // bronze
      default:
        return c.inkDim;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final l = AppLocalizations.of(context)!;
    final rankColor = _rankColor(c);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.hairline, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: c.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.hairline, width: 1),
                ),
                child: Image(
                  image: leagueLogoProviderForUrl(_leagueLogoUrl(record.leagueId)),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      Icon(Icons.shield_outlined, size: 16, color: c.inkDim),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _leagueName(context, record.leagueId).toUpperCase(),
                  style: EType.display(size: 16, color: c.ink, letterSpacing: 0.8),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Rank badge
              if (record.rank != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border.all(color: rankColor, width: 1.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '#${record.rank} ${l.trophyOf} ${record.totalPlayers}',
                    style: EType.numeric(
                        color: rankColor, size: 11, weight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _StatLine(
            label: l.pst,
            value: '${record.points}',
            valueColor: c.ink,
          ),
          if (record.winnerPick != null)
            _StatLine(
              label: l.trophyChampionLabel,
              value: record.winnerPick!,
              badge: record.championCorrect ? l.trophyCorrect : l.trophyMissed,
              badgeColor: record.championCorrect ? c.live : c.inkDim,
            ),
          if (record.topScorerPick != null)
            _StatLine(
              label: l.trophyTopScorerLabel,
              value: '${record.topScorerPick} · ${record.topScorerPoints} ${l.pst}',
            ),
          if (record.bracketPoints > 0)
            _StatLine(
              label: l.trophyBracketLabel,
              value: '${record.bracketPoints} ${l.pst}',
            ),
        ],
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  const _StatLine({
    required this.label,
    required this.value,
    this.badge,
    this.badgeColor,
    this.valueColor,
  });
  final String label;
  final String value;
  final String? badge;
  final Color? badgeColor;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label.toUpperCase(),
              style: EType.label(color: c.inkDim, size: 10, letterSpacing: 1.4),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: EType.body(color: valueColor ?? c.inkMute, size: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (badge != null)
            Text(
              badge!.toUpperCase(),
              style: EType.label(
                  color: badgeColor ?? c.inkDim, size: 10, letterSpacing: 1.4),
            ),
        ],
      ),
    );
  }
}

class _CabinetEmpty extends StatelessWidget {
  const _CabinetEmpty({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: c.hairline, width: 1),
            ),
            child: Icon(Icons.emoji_events_outlined, size: 26, color: c.inkDim),
          ),
          const SizedBox(height: 18),
          Text(
            title.toUpperCase(),
            style: EType.display(size: 22, color: c.ink, letterSpacing: 1.2),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: EType.body(color: c.inkMute, size: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}
```

The widget uses `const TrophyMethods()` as its default `methods` value — the const constructor for `TrophyMethods` was added in Task 6, so no service change is needed here.

- [ ] **Step 2: Verify it analyzes clean**

Run: `cd /c/flutter-football && flutter analyze lib/widgets/trophyCabinet.dart lib/resources/trophyMethods.dart`
Expected: "No issues found!"

Note: confirm `EditorialColors`, `context.col`, `EType.label/display/body/numeric`, `leagueLogoProviderForUrl`, and `LeagueConfigService().nameFor` exist with these signatures (they are used identically in `lib/screens/profile.dart`). If a name differs, match profile.dart.

- [ ] **Step 3: Commit**

```bash
cd /c/flutter-football && git add lib/widgets/trophyCabinet.dart && git commit -m "feat: Trophy Cabinet tab widget"
```

---

## Task 9: Cabinet widget test

**Files:**
- Test: `C:\flutter-football\test\trophy_cabinet_test.dart`

- [ ] **Step 1: Write the test**

Create `C:\flutter-football\test\trophy_cabinet_test.dart`. It injects a fake `TrophyMethods` that returns canned records, pumps the widget inside a localized `MaterialApp`, and verifies rendering.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:football/models/season_record.dart';
import 'package:football/resources/trophyMethods.dart';
import 'package:football/widgets/trophyCabinet.dart';

class _FakeTrophyMethods extends TrophyMethods {
  const _FakeTrophyMethods(this.summary, this.history);
  final List<SeasonRecord> summary;
  final List<SeasonRecord> history;
  @override
  Future<List<SeasonRecord>> fetchSeasonSummary(String userId) async => summary;
  @override
  Future<List<SeasonRecord>> fetchHistory(String userId) async => history;
}

SeasonRecord _rec({
  int leagueId = 39,
  int season = 2025,
  bool current = true,
  int rank = 1,
  int totalPlayers = 10,
}) =>
    SeasonRecord.fromJson({
      'leagueId': leagueId,
      'season': season,
      'current': current,
      'points': 100,
      'rank': rank,
      'totalPlayers': totalPlayers,
      'winnerPick': 'Man City',
      'championName': 'Man City',
      'championCorrect': true,
      'championPoints': 20,
      'topScorerPick': 'Haaland',
      'topScorerPoints': 12,
      'bracketPoints': 0,
    });

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  testWidgets('shows empty state when there are no records', (tester) async {
    await tester.pumpWidget(_wrap(TrophyCabinetTab(
      userId: 'u1',
      allowedIds: const {'39'},
      methods: const _FakeTrophyMethods([], []),
    )));
    await tester.pumpAndSettle();
    expect(find.text('NO TROPHIES YET'), findsOneWidget);
  });

  testWidgets('renders this-season card with rank badge', (tester) async {
    await tester.pumpWidget(_wrap(TrophyCabinetTab(
      userId: 'u1',
      allowedIds: const {'39'},
      methods: _FakeTrophyMethods([_rec(rank: 1, totalPlayers: 42)], const []),
    )));
    await tester.pumpAndSettle();
    expect(find.text('THIS SEASON'), findsOneWidget);
    expect(find.textContaining('#1'), findsOneWidget);
    expect(find.textContaining('42'), findsOneWidget);
  });

  testWidgets('filters out leagues not in allowedIds', (tester) async {
    await tester.pumpWidget(_wrap(TrophyCabinetTab(
      userId: 'u1',
      allowedIds: const {'140'}, // record is league 39 → filtered out
      methods: _FakeTrophyMethods([_rec(leagueId: 39)], const []),
    )));
    await tester.pumpAndSettle();
    expect(find.text('NO TROPHIES YET'), findsOneWidget);
  });

  testWidgets('groups past seasons under a Past Seasons header', (tester) async {
    await tester.pumpWidget(_wrap(TrophyCabinetTab(
      userId: 'u1',
      allowedIds: const {'39'},
      methods: _FakeTrophyMethods(
        const [],
        [_rec(current: false, season: 2024)],
      ),
    )));
    await tester.pumpAndSettle();
    expect(find.text('PAST SEASONS'), findsOneWidget);
    expect(find.textContaining('2024'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run the test to verify it passes**

Run: `cd /c/flutter-football && flutter test test/trophy_cabinet_test.dart`
Expected: PASS — 4 tests.

If a text assertion fails on casing, adjust the assertion to the actual rendered text (the widget upper-cases section headers and the empty title). Do not change the widget to satisfy a casing mismatch.

- [ ] **Step 3: Commit**

```bash
cd /c/flutter-football && git add test/trophy_cabinet_test.dart && git commit -m "test: Trophy Cabinet widget rendering"
```

---

## Task 10: Wire the third tab into the Profile

**Files:**
- Modify: `C:\flutter-football\lib\screens\profile.dart`

The profile currently switches on a `bool _showWinners`. Replace it with a three-value selector and add the cabinet child.

- [ ] **Step 1: Add the import**

At the top of `profile.dart`, with the other imports, add:

```dart
import 'package:football/widgets/trophyCabinet.dart';
```

- [ ] **Step 2: Replace the tab state field**

In `_ProfileScreenContentState`, replace:

```dart
  bool _showWinners = true;
```

with:

```dart
  // 0 = winners, 1 = top scorers, 2 = trophy cabinet
  int _activeTab = 0;
```

- [ ] **Step 3: Update the tab strip**

Replace the `_buildTabStrip` `Row` children (the two `_Tab(...)` entries) with three:

```dart
      child: Row(
        children: [
          _Tab(
            label: l.yourwinners,
            icon: Icons.emoji_events_outlined,
            active: _activeTab == 0,
            onTap: () => setState(() => _activeTab = 0),
          ),
          _Tab(
            label: l.topScorers,
            icon: Icons.sports_soccer_outlined,
            active: _activeTab == 1,
            onTap: () => setState(() => _activeTab = 1),
          ),
          _Tab(
            label: l.trophyCabinet,
            icon: Icons.workspace_premium_outlined,
            active: _activeTab == 2,
            onTap: () => setState(() => _activeTab = 2),
          ),
        ],
      ),
```

(Note: `l.topScorers` is non-nullable, so drop the `?? 'Top Scorers'` fallback.)

- [ ] **Step 4: Update the switched content**

Replace the `AnimatedSwitcher`'s `child:` expression (currently `_showWinners ? usersWinners(...) : usersTopScorers(...)`) with a helper call:

```dart
                  child: _buildActiveTab(
                    placeholderNames: placeholderNames,
                    placeholderPoints: placeholderPoints,
                    filteredWinners: filteredWinners,
                    filteredTopScorers: filteredTopScorers,
                  ),
```

Then add this method to `_ProfileScreenContentState`:

```dart
  Widget _buildActiveTab({
    required Map<String, String> placeholderNames,
    required Map<String, int> placeholderPoints,
    required Map<String, String> filteredWinners,
    required Map<String, String> filteredTopScorers,
  }) {
    switch (_activeTab) {
      case 1:
        return usersTopScorers(
          key: const ValueKey('topScorers'),
          userTopScorerPoints: _isLoading ? placeholderPoints : _userTopScorerPoints,
          filteredTopScorers: _isLoading ? placeholderNames : filteredTopScorers,
          leagueIds: _isLoading ? placeholderNames.keys.toList() : _allowedIds.toList(),
          clientId: currentUserId,
          email: currentUserEmail,
          isLoading: _isLoading,
          onChanged: _fetchPersonalData,
        );
      case 2:
        return TrophyCabinetTab(
          key: const ValueKey('cabinet'),
          userId: currentUserId,
          allowedIds: _allowedIds,
        );
      case 0:
      default:
        return usersWinners(
          key: const ValueKey('winners'),
          filteredWinners: _isLoading ? placeholderNames : filteredWinners,
          leagueIds: _isLoading ? placeholderNames.keys.toList() : _allowedIds.toList(),
          clientId: currentUserId,
          email: currentUserEmail,
          isLoading: _isLoading,
          onChanged: _fetchPersonalData,
        );
    }
  }
```

Note: the cabinet manages its own loading, so it is not wrapped by the parent `Skeletonizer` state — the `Skeletonizer(enabled: _isLoading, ...)` wrapper stays, but on the cabinet tab `_isLoading` refers to the profile's user fetch (already complete once the user taps in), so it will be disabled and the cabinet's own spinner shows.

- [ ] **Step 5: Analyze the screen**

Run: `cd /c/flutter-football && flutter analyze lib/screens/profile.dart`
Expected: "No issues found!" (Watch for: unused `_showWinners`, missing `topScorers` fallback removal, and the switch returning on all paths.)

- [ ] **Step 6: Full analyze + test run**

Run: `cd /c/flutter-football && flutter analyze && flutter test`
Expected: "No issues found!" and all tests pass (season_record, trophy_cabinet, plus the existing suite).

- [ ] **Step 7: Commit**

```bash
cd /c/flutter-football && git add lib/screens/profile.dart && git commit -m "feat: add Trophy Cabinet as third Profile tab"
```

---

## Task 11: Manual verification

- [ ] **Step 1: Backend endpoints respond**

With the backend running against a dev DB, hit both endpoints for a known user id and confirm JSON arrays come back in the shared shape:

Run: `cd /c/worldBackend && node -e "console.log('manual: GET /users/<id>/season-summary and /users/<id>/history')"`
Then verify with a real request (curl/Postman) that `season-summary` returns `current:true` records and `history` returns `[]` until a season reset has run.

- [ ] **Step 2: App shows the tab**

Launch the app (`cd /c/flutter-football && flutter run`), open Profile, tap the **Trophy Cabinet** tab. Confirm: spinner → either the empty state (no history yet) or "This Season" cards with rank badges, champion/top-scorer/bracket lines, in both `he` (RTL) and `en`.

- [ ] **Step 3: No commit** (verification only).

---

## Notes / Out of scope

- **Backfill:** past seasons cannot be reconstructed (never stored); history fills only from the next season reset onward.
- **Rank is global**, not group-relative.
- **Cabinet re-fetches** each time the tab is opened (mounted). In-memory caching is a possible later optimization, not part of this plan.
- **Versioning:** per repo convention, bump `pubspec.yaml` `version:` as part of shipping (not a code task here) so the change reaches users through the forced-update gate.
- Team names remain display-only (rendered via `_leagueName`/localized helpers); raw values are not used for matching in the cabinet.
```
