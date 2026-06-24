# Team Recent Form (Last 5 Matches) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a team's last 5 matches (recent form + per-match stats) on the team screen, spending the absolute minimum external API quota.

**Architecture:** A new cache-only backend endpoint derives the last 5 finished matches from the existing `FixtureCache` (Mongo) — zero quota — mirroring the H2H pattern. AllSport's `matches/previous` endpoint is a fallback used only when the cache holds *nothing* for the team. Per-match stats stay cache-only but gain an opt-in `?fetch=1` that lazily fetches a single match's stats from AllSport when the user opens its stats tab. The Flutter client renders a Recent Form block (form pills + tappable rows) atop the existing Stats tab.

**Tech Stack:** Node (ESM, Express, Mongoose), `node --test`; Flutter/Dart, Provider, `flutter test`.

---

## Repos & working directories

- Backend: `C:\worldBackend` (Node). Tests run with `node --test`.
- Client: `C:\flutter-football` (Flutter). Tests run with `flutter test`.

Commit in the repo whose files the task changed. Backend tasks (1–4) commit in `worldBackend`; client tasks (5–9) commit in `flutter-football`.

## File structure

**Backend (`worldBackend`):**
- Create `src/controllers/recentForm.js` — pure `buildRecentForm()`, pure `sofaEventToFixtureRaw()`, and the HTTP handler `getTeamLastMatches()`.
- Create `tests/recentForm.test.mjs` — unit tests for the two pure functions.
- Modify `src/controllers/allsports.js` — export `teamImageUrl`, add+export `fetchTeamPreviousEvents()`.
- Modify `src/controllers/stats.js` — pure `ctxFromFixtureDoc()`, add `?fetch=1` branch to `getFixtureStats()`.
- Modify `tests/` — add `ctxFromFixtureDoc` test (in `recentForm.test.mjs` or a new file; this plan puts it in `tests/stats.ctx.test.mjs`).
- Modify `src/routes/teamsAndPlayers.js` — register the new route.

**Client (`flutter-football`):**
- Create `lib/models/recent_form.dart` — `RecentForm` model + `fromJson`.
- Create `lib/resources/recent_form_service.dart` — `RecentFormService.getLastMatches()`.
- Create `lib/widgets/RecentFormBlock.dart` — stateless render of form pills + match rows.
- Create `test/recent_form_test.dart` — model parsing test.
- Create `test/recent_form_block_test.dart` — widget test.
- Modify `lib/resources/stats_service.dart` — add `fetch` param.
- Modify `lib/widgets/StatsWidget.dart` — pass `fetch: true` for played/live games.
- Modify `lib/screens/teamDetails.dart` — fetch + render `RecentFormBlock` atop the Stats tab.
- Modify `lib/l10n/*` — new localized strings.

## Response contract (the seam between the two repos)

`GET /teams/:teamId/last-matches?name=<teamName>&limit=5` returns:

```json
{
  "success": true,
  "teamId": 541,
  "source": "cache",
  "summary": {
    "played": 5, "wins": 3, "draws": 1, "losses": 1,
    "goalsFor": 9, "goalsAgainst": 4,
    "form": ["W","W","D","L","W"]
  },
  "matches": [ /* full API-FOOTBALL fixture objects, most-recent first */ ]
}
```

- `matches` are the raw API-FOOTBALL fixture objects (the same shape `Game.fromJson` already consumes), so the client parses them with `Game.fromJson` directly.
- `form` is ordered **most-recent first**; a match with missing goals contributes `"?"` and is excluded from W/D/L and goal totals.
- `source` is `"cache"` normally, `"allsports"` only when the cache had zero matches and the fallback ran.

---

## Task 1: Backend — pure `buildRecentForm()`

**Files:**
- Create: `C:\worldBackend\src\controllers\recentForm.js`
- Test: `C:\worldBackend\tests\recentForm.test.mjs`

- [ ] **Step 1: Write the failing test**

Create `tests/recentForm.test.mjs`:

```js
import { test } from "node:test";
import assert from "node:assert";
import { buildRecentForm } from "../src/controllers/recentForm.js";

// Minimal fixture-doc factory matching FixtureCache.lean() shape.
function doc({ id, date, status, homeId, awayId, hg, ag }) {
  return {
    _id: id,
    date,
    status,
    homeTeamId: homeId,
    awayTeamId: awayId,
    raw: {
      fixture: { id },
      teams: { home: { id: homeId }, away: { id: awayId } },
      goals: { home: hg, away: ag },
    },
  };
}

test("buildRecentForm tallies W/D/L from the team's perspective, most-recent first", () => {
  const TEAM = 10;
  const fixtures = [
    doc({ id: 1, date: "2026-01-01T00:00:00Z", status: "FT", homeId: 10, awayId: 20, hg: 2, ag: 0 }), // W (home)
    doc({ id: 2, date: "2026-01-05T00:00:00Z", status: "FT", homeId: 30, awayId: 10, hg: 3, ag: 1 }), // L (away)
    doc({ id: 3, date: "2026-01-03T00:00:00Z", status: "FT", homeId: 10, awayId: 40, hg: 1, ag: 1 }), // D
  ];
  const { summary, matches } = buildRecentForm(fixtures, TEAM, 5);

  assert.deepStrictEqual(summary.form, ["L", "D", "W"]); // sorted date desc: id2,id3,id1
  assert.strictEqual(summary.played, 3);
  assert.strictEqual(summary.wins, 1);
  assert.strictEqual(summary.draws, 1);
  assert.strictEqual(summary.losses, 1);
  assert.strictEqual(summary.goalsFor, 1 + 1 + 2);   // away in id2=1, id3=1, home id1=2
  assert.strictEqual(summary.goalsAgainst, 3 + 1 + 0);
  assert.strictEqual(matches.length, 3);
  assert.strictEqual(matches[0].fixture.id, 2); // most recent first
});

test("buildRecentForm ignores non-finished, other teams, and respects limit", () => {
  const TEAM = 10;
  const fixtures = [
    doc({ id: 1, date: "2026-01-01T00:00:00Z", status: "NS", homeId: 10, awayId: 20, hg: null, ag: null }),
    doc({ id: 2, date: "2026-01-02T00:00:00Z", status: "FT", homeId: 50, awayId: 60, hg: 1, ag: 0 }), // not our team
    doc({ id: 3, date: "2026-01-03T00:00:00Z", status: "FT", homeId: 10, awayId: 20, hg: 0, ag: 0 }),
    doc({ id: 4, date: "2026-01-04T00:00:00Z", status: "FT", homeId: 10, awayId: 20, hg: 1, ag: 0 }),
  ];
  const { summary, matches } = buildRecentForm(fixtures, TEAM, 1);
  assert.strictEqual(matches.length, 1);
  assert.strictEqual(matches[0].fixture.id, 4);
  assert.deepStrictEqual(summary.form, ["W"]);
});

test("buildRecentForm marks missing goals as '?' and excludes from totals", () => {
  const TEAM = 10;
  const fixtures = [
    doc({ id: 1, date: "2026-01-01T00:00:00Z", status: "FT", homeId: 10, awayId: 20, hg: null, ag: null }),
  ];
  const { summary } = buildRecentForm(fixtures, TEAM, 5);
  assert.deepStrictEqual(summary.form, ["?"]);
  assert.strictEqual(summary.played, 0);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /c/worldBackend && node --test tests/recentForm.test.mjs`
Expected: FAIL — cannot find module `../src/controllers/recentForm.js`.

- [ ] **Step 3: Write minimal implementation**

Create `src/controllers/recentForm.js` with ONLY this for now:

```js
const FINISHED = new Set(["FT", "AET", "PEN"]);

// Pure: derive recent-form summary + ordered match list for `teamId`.
// `fixtures` are FixtureCache lean docs (with .raw, .status, .homeTeamId,
// .awayTeamId, .date). Returns matches as the raw API-FOOTBALL fixture objects,
// most-recent first. Goal-less finished games contribute "?" to the form.
export function buildRecentForm(fixtures, teamId, limit = 5) {
  const finished = (fixtures || [])
    .filter(
      (f) =>
        FINISHED.has(f.status) &&
        (f.homeTeamId === teamId || f.awayTeamId === teamId)
    )
    .sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime())
    .slice(0, limit);

  const summary = {
    played: 0,
    wins: 0,
    draws: 0,
    losses: 0,
    goalsFor: 0,
    goalsAgainst: 0,
    form: [],
  };
  const matches = [];

  for (const f of finished) {
    const raw = f.raw || {};
    matches.push(raw);

    const goals = raw.goals || {};
    const isHome = f.homeTeamId === teamId;
    const gf = isHome ? goals.home : goals.away;
    const ga = isHome ? goals.away : goals.home;

    if (gf == null || ga == null) {
      summary.form.push("?");
      continue;
    }
    summary.played += 1;
    summary.goalsFor += gf;
    summary.goalsAgainst += ga;
    if (gf > ga) {
      summary.wins += 1;
      summary.form.push("W");
    } else if (gf < ga) {
      summary.losses += 1;
      summary.form.push("L");
    } else {
      summary.draws += 1;
      summary.form.push("D");
    }
  }

  return { summary, matches };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /c/worldBackend && node --test tests/recentForm.test.mjs`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
cd /c/worldBackend && git add src/controllers/recentForm.js tests/recentForm.test.mjs && git commit -m "feat: pure buildRecentForm for team last-matches"
```

---

## Task 2: Backend — pure `sofaEventToFixtureRaw()` (AllSport fallback transform)

**Files:**
- Modify: `C:\worldBackend\src\controllers\recentForm.js`
- Test: `C:\worldBackend\tests\recentForm.test.mjs`

This transform must produce a COMPLETE API-FOOTBALL fixture object, because the client's `Game.fromJson` (and its `Status`/`League`/`Score` sub-parsers) are strict: `status.long`, `status.short`, `league.id/name/country/season/round`, and all four `score.*` maps must be present and non-null where the Dart fields are non-nullable.

- [ ] **Step 1: Add the failing test**

Append to `tests/recentForm.test.mjs`:

```js
import { sofaEventToFixtureRaw } from "../src/controllers/recentForm.js";

test("sofaEventToFixtureRaw produces a complete API-FOOTBALL fixture shape", () => {
  const event = {
    id: 999,
    startTimestamp: 1767225600, // 2026-01-01T00:00:00Z
    status: { type: "finished", description: "Ended" },
    homeTeam: { id: 1, name: "Alpha" },
    awayTeam: { id: 2, name: "Beta" },
    homeScore: { current: 2 },
    awayScore: { current: 1 },
    tournament: { name: "Cup", category: { country: { name: "Spain" } } },
  };
  const raw = sofaEventToFixtureRaw(event, { teamImageUrl: (id) => `logo/${id}` });

  assert.strictEqual(raw.fixture.id, 999);
  assert.strictEqual(raw.fixture.status.short, "FT");
  assert.strictEqual(typeof raw.fixture.status.long, "string");
  assert.strictEqual(raw.fixture.timestamp, 1767225600);
  assert.strictEqual(raw.fixture.date, "2026-01-01T00:00:00.000Z");
  assert.strictEqual(raw.league.name, "Cup");
  assert.strictEqual(raw.league.country, "Spain");
  assert.strictEqual(typeof raw.league.season, "number");
  assert.strictEqual(raw.league.round, "");
  assert.strictEqual(raw.teams.home.logo, "logo/1");
  assert.strictEqual(raw.goals.home, 2);
  assert.strictEqual(raw.goals.away, 1);
  // all four score maps present
  for (const k of ["halftime", "fulltime", "extratime", "penalty"]) {
    assert.ok(raw.score[k] && "home" in raw.score[k] && "away" in raw.score[k]);
  }
  assert.strictEqual(raw.score.fulltime.home, 2);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /c/worldBackend && node --test tests/recentForm.test.mjs`
Expected: FAIL — `sofaEventToFixtureRaw` is not exported.

- [ ] **Step 3: Implement**

Append to `src/controllers/recentForm.js`:

```js
// Pure: Sofascore event -> API-FOOTBALL fixture object (the shape the client's
// Game.fromJson expects). Used only on the AllSport fallback path. Team/league
// ids are in the Sofascore namespace (display-only here); fixture.id is the Sofa
// event id. `teamImageUrl` maps a Sofa team id to our proxied logo URL.
export function sofaEventToFixtureRaw(event, { teamImageUrl }) {
  const ts = Number(event?.startTimestamp) || 0;
  const iso = new Date(ts * 1000).toISOString();
  const hg = event?.homeScore?.current ?? null;
  const ag = event?.awayScore?.current ?? null;
  const finished = event?.status?.type === "finished";
  const decided = finished && hg != null && ag != null;

  return {
    fixture: {
      id: event?.id,
      referee: null,
      timezone: "UTC",
      date: iso,
      timestamp: ts,
      periods: { first: null, second: null },
      venue: { id: 0, name: "", city: "" },
      status: {
        long: finished ? "Match Finished" : event?.status?.description || "Not Started",
        short: finished ? "FT" : "NS",
        elapsed: null,
      },
    },
    league: {
      id: 0,
      name: event?.tournament?.name || event?.tournament?.uniqueTournament?.name || "",
      country: event?.tournament?.category?.country?.name || "",
      logo: null,
      flag: null,
      season: new Date(ts * 1000).getUTCFullYear(),
      round: "",
    },
    teams: {
      home: {
        id: event?.homeTeam?.id ?? 0,
        name: event?.homeTeam?.name ?? "",
        logo: teamImageUrl(event?.homeTeam?.id),
        winner: decided ? hg > ag : null,
      },
      away: {
        id: event?.awayTeam?.id ?? 0,
        name: event?.awayTeam?.name ?? "",
        logo: teamImageUrl(event?.awayTeam?.id),
        winner: decided ? ag > hg : null,
      },
    },
    goals: { home: hg, away: ag },
    score: {
      halftime: { home: null, away: null },
      fulltime: { home: hg, away: ag },
      extratime: { home: null, away: null },
      penalty: { home: null, away: null },
    },
  };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /c/worldBackend && node --test tests/recentForm.test.mjs`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
cd /c/worldBackend && git add src/controllers/recentForm.js tests/recentForm.test.mjs && git commit -m "feat: sofaEventToFixtureRaw fallback transform"
```

---

## Task 3: Backend — AllSport helpers (`teamImageUrl` export + `fetchTeamPreviousEvents`)

**Files:**
- Modify: `C:\worldBackend\src\controllers\allsports.js`

No new test (thin network wrappers). `fetchTeamPreviousEvents` reuses the same shape `fetchTeamPreviousFinishedEvent` already produces, generalized to a list.

- [ ] **Step 1: Export `teamImageUrl`**

In `src/controllers/allsports.js`, find:

```js
const teamImageUrl = (id) => id ? `${PUBLIC_BACKEND_URL}/api/team-image/${id}` : null;
```

Replace with:

```js
export const teamImageUrl = (id) => id ? `${PUBLIC_BACKEND_URL}/api/team-image/${id}` : null;
```

- [ ] **Step 2: Add `fetchTeamPreviousEvents`**

In `src/controllers/allsports.js`, directly AFTER the existing `fetchTeamPreviousFinishedEvent` function (ends around line 514), add:

```js
// Most recent finished events (up to `limit`) for a Sofascore team, across all
// competitions. One AllSport call. Returns [] on error/empty.
export async function fetchTeamPreviousEvents(sofaTeamId, limit, tag) {
  const { ok, data } = await asGet(
    `/api/team/${sofaTeamId}/matches/previous/0`,
    `${tag}/prev-matches`
  );
  if (!ok) return [];
  const events = Array.isArray(data?.events) ? data.events : [];
  const finished = events.filter((e) => e?.status?.type === "finished");
  const pool = finished.length ? finished : events;
  pool.sort((a, b) => (b.startTimestamp || 0) - (a.startTimestamp || 0));
  return pool.slice(0, limit);
}
```

- [ ] **Step 3: Verify the module still loads**

Run: `cd /c/worldBackend && node --check src/controllers/allsports.js`
Expected: no output (syntax OK).

- [ ] **Step 4: Commit**

```bash
cd /c/worldBackend && git add src/controllers/allsports.js && git commit -m "feat: export teamImageUrl, add fetchTeamPreviousEvents"
```

---

## Task 4: Backend — HTTP handler `getTeamLastMatches` + route

**Files:**
- Modify: `C:\worldBackend\src\controllers\recentForm.js`
- Modify: `C:\worldBackend\src\routes\teamsAndPlayers.js`

Fallback policy (refinement of the spec to keep one id-namespace per response and minimize calls): the AllSport fallback runs ONLY when the cache returns **zero** matches for the team.

- [ ] **Step 1: Add imports + handler to `recentForm.js`**

At the TOP of `src/controllers/recentForm.js`, add:

```js
import { FixtureCache } from "../models/cacheModels.js";
import {
  resolveSofaTeamId,
  fetchTeamPreviousEvents,
  teamImageUrl,
} from "./allsports.js";
```

> Note: `resolveSofaTeamId` is currently module-private in `allsports.js`. Export it: change `async function resolveSofaTeamId(` to `export async function resolveSofaTeamId(`.

At the END of `src/controllers/recentForm.js`, add the handler:

```js
const FINISHED_STATUSES = ["FT", "AET", "PEN"];

// HTTP handler. Cache-first over FixtureCache (zero quota). AllSport fallback
// runs ONLY when the cache has nothing for this team.
export async function getTeamLastMatches(req, res) {
  try {
    const teamId = Number(req.params.teamId);
    const name = (req.query.name || "").toString();
    const limit = Math.min(Number(req.query.limit) || 5, 10);

    if (!Number.isFinite(teamId) || teamId <= 0) {
      return res.status(400).json({ success: false, error: "valid teamId is required" });
    }

    const docs = await FixtureCache.find({
      status: { $in: FINISHED_STATUSES },
      $or: [{ homeTeamId: teamId }, { awayTeamId: teamId }],
    })
      .sort({ date: -1 })
      .limit(limit)
      .lean();

    if (docs.length > 0) {
      const { summary, matches } = buildRecentForm(docs, teamId, limit);
      return res.json({ success: true, teamId, source: "cache", summary, matches });
    }

    // Fallback: nothing cached for this team. Try AllSport (1 search + 1 matches call).
    if (name) {
      const sofaId = await resolveSofaTeamId(teamId, name, "recent-form");
      if (sofaId) {
        const events = await fetchTeamPreviousEvents(sofaId, limit, "recent-form");
        if (events.length > 0) {
          const sofaDocs = events.map((e) => {
            const raw = sofaEventToFixtureRaw(e, { teamImageUrl });
            return {
              raw,
              status: raw.fixture.status.short,
              homeTeamId: raw.teams.home.id,
              awayTeamId: raw.teams.away.id,
              date: raw.fixture.date,
            };
          });
          const { summary, matches } = buildRecentForm(sofaDocs, sofaId, limit);
          return res.json({ success: true, teamId, source: "allsports", summary, matches });
        }
      }
    }

    return res.json({
      success: true,
      teamId,
      source: "cache",
      summary: { played: 0, wins: 0, draws: 0, losses: 0, goalsFor: 0, goalsAgainst: 0, form: [] },
      matches: [],
    });
  } catch (error) {
    console.error("Error getting team last matches:", error);
    res.status(500).json({ success: false, error: "Failed to get team last matches" });
  }
}
```

- [ ] **Step 2: Register the route**

In `src/routes/teamsAndPlayers.js`, add the import next to the other controller imports:

```js
import { getTeamLastMatches } from "../controllers/recentForm.js";
```

And add the route next to the other `router.get(...)` lines (near the standings route):

```js
router.get("/teams/:teamId/last-matches", getTeamLastMatches);
```

- [ ] **Step 3: Verify modules load and existing tests still pass**

Run: `cd /c/worldBackend && node --check src/controllers/recentForm.js && node --check src/routes/teamsAndPlayers.js && node --test tests/recentForm.test.mjs`
Expected: no syntax errors; 4 tests PASS.

- [ ] **Step 4: Commit**

```bash
cd /c/worldBackend && git add src/controllers/recentForm.js src/controllers/allsports.js src/routes/teamsAndPlayers.js && git commit -m "feat: GET /teams/:teamId/last-matches endpoint"
```

---

## Task 5: Backend — on-demand stats via `?fetch=1`

**Files:**
- Modify: `C:\worldBackend\src\controllers\stats.js`
- Test: `C:\worldBackend\tests\stats.ctx.test.mjs`

- [ ] **Step 1: Write the failing test for the pure helper**

Create `tests/stats.ctx.test.mjs`:

```js
import { test } from "node:test";
import assert from "node:assert";
import { ctxFromFixtureDoc } from "../src/controllers/stats.js";

test("ctxFromFixtureDoc builds AllSport ctx from a fixture doc", () => {
  const doc = {
    leagueId: 140,
    raw: {
      fixture: { date: "2026-01-01T20:00:00Z" },
      league: { id: 140 },
      teams: { home: { name: "Alpha" }, away: { name: "Beta" } },
    },
  };
  const ctx = ctxFromFixtureDoc(doc);
  assert.deepStrictEqual(ctx, {
    apiFootballLeagueId: 140,
    kickoffIso: "2026-01-01T20:00:00Z",
    homeName: "Alpha",
    awayName: "Beta",
  });
});

test("ctxFromFixtureDoc returns null when raw is missing", () => {
  assert.strictEqual(ctxFromFixtureDoc({}), null);
  assert.strictEqual(ctxFromFixtureDoc(null), null);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /c/worldBackend && node --test tests/stats.ctx.test.mjs`
Expected: FAIL — `ctxFromFixtureDoc` is not exported.

- [ ] **Step 3: Implement helper + wire `?fetch=1`**

In `src/controllers/stats.js`, add the `FixtureCache` import. The file already imports `StatsCache`:

```js
import { StatsCache, FixtureCache } from "../models/cacheModels.js";
```

Add the pure helper (place it just above `getFixtureStats`):

```js
// Pure: build the AllSport fixture-resolution context from a FixtureCache doc.
export function ctxFromFixtureDoc(doc) {
  const raw = doc?.raw;
  if (!raw) return null;
  return {
    apiFootballLeagueId: raw.league?.id ?? doc.leagueId,
    kickoffIso: raw.fixture?.date,
    homeName: raw.teams?.home?.name,
    awayName: raw.teams?.away?.name,
  };
}
```

Replace the body of `getFixtureStats` so that after the cache check, an opt-in
`?fetch=1` triggers a single on-demand AllSport fetch:

```js
export async function getFixtureStats(req, res) {
  try {
    const { fixtureId } = req.params;

    if (!fixtureId) {
      return res.status(400).json({ success: false, error: "fixtureId is required" });
    }

    const cached = await loadStatsFromFile(fixtureId);
    if (cached) {
      return res.json({ success: true, fixtureId, stats: cached, source: "cache" });
    }

    // Opt-in lazy fetch: only when the client explicitly asks (user opened the
    // stats tab of a played/live match). Costs one AllSport resolve+stats call.
    if (req.query.fetch === "1") {
      const doc = await FixtureCache.findById(Number(fixtureId)).lean();
      const ctx = ctxFromFixtureDoc(doc);
      if (ctx) {
        const fetched = await fetchAndCacheStats(fixtureId, { ctx, tag: "on-demand" });
        if (Array.isArray(fetched) && fetched.length > 0) {
          return res.json({ success: true, fixtureId, stats: fetched, source: "allsports" });
        }
      }
    }

    return res.json({
      success: true,
      fixtureId,
      stats: null,
      available: false,
      message: "Stats not yet available.",
    });
  } catch (error) {
    console.error("Error getting fixture stats:", error);
    res.status(500).json({ success: false, error: "Failed to get fixture stats" });
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /c/worldBackend && node --test tests/stats.ctx.test.mjs && node --check src/controllers/stats.js`
Expected: 2 tests PASS; no syntax errors.

- [ ] **Step 5: Commit**

```bash
cd /c/worldBackend && git add src/controllers/stats.js tests/stats.ctx.test.mjs && git commit -m "feat: opt-in ?fetch=1 on-demand stats for cached fixtures"
```

---

## Task 6: Client — `RecentForm` model + parsing test

**Files:**
- Create: `C:\flutter-football\lib\models\recent_form.dart`
- Test: `C:\flutter-football\test\recent_form_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/recent_form_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:football/models/recent_form.dart';

void main() {
  test('RecentForm.fromJson parses summary and matches', () {
    final json = {
      'success': true,
      'teamId': 10,
      'source': 'cache',
      'summary': {
        'played': 1,
        'wins': 1,
        'draws': 0,
        'losses': 0,
        'goalsFor': 2,
        'goalsAgainst': 0,
        'form': ['W'],
      },
      'matches': [
        {
          'fixture': {
            'id': 123,
            'referee': null,
            'timezone': 'UTC',
            'date': '2026-01-01T20:00:00Z',
            'timestamp': 1767297600,
            'periods': {'first': null, 'second': null},
            'venue': {'id': 0, 'name': '', 'city': ''},
            'status': {'long': 'Match Finished', 'short': 'FT', 'elapsed': null},
          },
          'league': {
            'id': 140, 'name': 'La Liga', 'country': 'Spain',
            'logo': null, 'flag': null, 'season': 2025, 'round': '',
          },
          'teams': {
            'home': {'id': 10, 'name': 'Alpha', 'logo': 'a.png', 'winner': true},
            'away': {'id': 20, 'name': 'Beta', 'logo': 'b.png', 'winner': false},
          },
          'goals': {'home': 2, 'away': 0},
          'score': {
            'halftime': {'home': 1, 'away': 0},
            'fulltime': {'home': 2, 'away': 0},
            'extratime': {'home': null, 'away': null},
            'penalty': {'home': null, 'away': null},
          },
        },
      ],
    };

    final rf = RecentForm.fromJson(json);
    expect(rf.form, ['W']);
    expect(rf.wins, 1);
    expect(rf.goalsFor, 2);
    expect(rf.source, 'cache');
    expect(rf.matches.length, 1);
    expect(rf.matches.first.fixtureId, 123);
    expect(rf.matches.first.home.name, 'Alpha');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /c/flutter-football && flutter test test/recent_form_test.dart`
Expected: FAIL — target of URI doesn't exist `recent_form.dart`.

- [ ] **Step 3: Implement the model**

Create `lib/models/recent_form.dart`:

```dart
import 'package:football/models/games.dart';

/// Parsed response of `GET /teams/:teamId/last-matches`.
/// [matches] are full Game objects, most-recent first. [form] is the W/D/L/?
/// streak in the same order.
class RecentForm {
  final List<Game> matches;
  final List<String> form;
  final int played;
  final int wins;
  final int draws;
  final int losses;
  final int goalsFor;
  final int goalsAgainst;
  final String source;

  RecentForm({
    required this.matches,
    required this.form,
    required this.played,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.source,
  });

  bool get isEmpty => matches.isEmpty;

  factory RecentForm.fromJson(Map<String, dynamic> json) {
    final s = (json['summary'] as Map<String, dynamic>?) ?? const {};
    final rawMatches = (json['matches'] as List?) ?? const [];
    int asInt(dynamic v) => (v as num?)?.toInt() ?? 0;

    return RecentForm(
      matches: rawMatches
          .whereType<Map<String, dynamic>>()
          .map((m) => Game.fromJson(m))
          .toList(),
      form: ((s['form'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      played: asInt(s['played']),
      wins: asInt(s['wins']),
      draws: asInt(s['draws']),
      losses: asInt(s['losses']),
      goalsFor: asInt(s['goalsFor']),
      goalsAgainst: asInt(s['goalsAgainst']),
      source: json['source']?.toString() ?? 'cache',
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /c/flutter-football && flutter test test/recent_form_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /c/flutter-football && git add lib/models/recent_form.dart test/recent_form_test.dart && git commit -m "feat: RecentForm model + parsing"
```

---

## Task 7: Client — `RecentFormService`

**Files:**
- Create: `C:\flutter-football\lib\resources\recent_form_service.dart`

No unit test (thin HTTP wrapper, matching the existing `StatsService` which is untested). Keep the shape identical to `StatsService` for consistency.

- [ ] **Step 1: Implement the service**

Create `lib/resources/recent_form_service.dart`:

```dart
import 'dart:convert';
import 'package:football/models/recent_form.dart';
import 'package:football/utils/config.dart';
import 'package:http/http.dart' as http;

class RecentFormService {
  /// Fetches a team's last [limit] matches. [teamName] enables the backend's
  /// AllSport fallback when nothing is cached for the team.
  Future<RecentForm?> getLastMatches(
    int teamId,
    String teamName, {
    int limit = 5,
  }) async {
    try {
      final url =
          '$backendUrl/teams/$teamId/last-matches?name=${Uri.encodeQueryComponent(teamName)}&limit=$limit';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode != 200) {
        print('Failed to load recent form: ${response.statusCode}');
        return null;
      }
      final Map<String, dynamic> data = json.decode(response.body);
      if (data['success'] != true) return null;
      return RecentForm.fromJson(data);
    } catch (e) {
      print('Error fetching recent form: $e');
      return null;
    }
  }
}
```

- [ ] **Step 2: Verify it analyzes clean**

Run: `cd /c/flutter-football && flutter analyze lib/resources/recent_form_service.dart`
Expected: No issues.

- [ ] **Step 3: Commit**

```bash
cd /c/flutter-football && git add lib/resources/recent_form_service.dart && git commit -m "feat: RecentFormService HTTP client"
```

---

## Task 8: Client — localization strings

**Files:**
- Modify: `C:\flutter-football\lib\l10n\app_en.arb`
- Modify: `C:\flutter-football\lib\l10n\app_he.arb`
- Modify: `C:\flutter-football\lib\l10n\app_localizations.dart`
- Modify: `C:\flutter-football\lib\l10n\app_localizations_en.dart`
- Modify: `C:\flutter-football\lib\l10n\app_localizations_he.dart`

Two new keys: `recentFormTitle`, `recentFormEmpty`. (`statsNotAvailable` already exists and is reused.)

- [ ] **Step 1: Add to `app_en.arb`**

Add these entries (before the closing brace, matching existing comma style):

```json
  "recentFormTitle": "Recent Form",
  "recentFormEmpty": "No recent matches",
```

- [ ] **Step 2: Add to `app_he.arb`**

```json
  "recentFormTitle": "כושר אחרון",
  "recentFormEmpty": "אין משחקים אחרונים",
```

- [ ] **Step 3: Add abstract getters to `app_localizations.dart`**

Add near the other team-stat getters (e.g. after `String get statsTab;`):

```dart
  String get recentFormTitle;
  String get recentFormEmpty;
```

- [ ] **Step 4: Add overrides to `app_localizations_en.dart`**

```dart
  @override
  String get recentFormTitle => 'Recent Form';

  @override
  String get recentFormEmpty => 'No recent matches';
```

- [ ] **Step 5: Add overrides to `app_localizations_he.dart`**

```dart
  @override
  String get recentFormTitle => 'כושר אחרון';

  @override
  String get recentFormEmpty => 'אין משחקים אחרונים';
```

- [ ] **Step 6: Verify it analyzes clean**

Run: `cd /c/flutter-football && flutter analyze lib/l10n`
Expected: No issues (no missing-override errors).

- [ ] **Step 7: Commit**

```bash
cd /c/flutter-football && git add lib/l10n && git commit -m "feat: localize recent-form strings (he/en)"
```

---

## Task 9: Client — `RecentFormBlock` widget + widget test

**Files:**
- Create: `C:\flutter-football\lib\widgets\RecentFormBlock.dart`
- Test: `C:\flutter-football\test\recent_form_block_test.dart`

A stateless widget that takes a `RecentForm` and an `onMatchTap` callback, so it can be widget-tested in isolation (no network). It renders form pills + one row per match, reusing the editorial styling vocabulary from `teamDetails.dart`.

- [ ] **Step 1: Write the failing widget test**

Create `test/recent_form_block_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:football/models/games.dart';
import 'package:football/models/recent_form.dart';
import 'package:football/widgets/RecentFormBlock.dart';

Game _game(int id, String home, String away, int hg, int ag) => Game.fromJson({
      'fixture': {
        'id': id, 'referee': null, 'timezone': 'UTC',
        'date': '2026-01-0${id}T20:00:00Z', 'timestamp': 1767297600,
        'periods': {'first': null, 'second': null},
        'venue': {'id': 0, 'name': '', 'city': ''},
        'status': {'long': 'Match Finished', 'short': 'FT', 'elapsed': null},
      },
      'league': {
        'id': 140, 'name': 'La Liga', 'country': 'Spain',
        'logo': null, 'flag': null, 'season': 2025, 'round': '',
      },
      'teams': {
        'home': {'id': 10, 'name': home, 'logo': 'a.png', 'winner': hg > ag},
        'away': {'id': 20, 'name': away, 'logo': 'b.png', 'winner': ag > hg},
      },
      'goals': {'home': hg, 'away': ag},
      'score': {
        'halftime': {'home': 0, 'away': 0},
        'fulltime': {'home': hg, 'away': ag},
        'extratime': {'home': null, 'away': null},
        'penalty': {'home': null, 'away': null},
      },
    });

void main() {
  testWidgets('RecentFormBlock renders pills and a row per match, taps fire', (tester) async {
    final rf = RecentForm(
      matches: [_game(1, 'Alpha', 'Beta', 2, 0), _game(2, 'Gamma', 'Alpha', 1, 1)],
      form: ['W', 'D'],
      played: 2, wins: 1, draws: 1, losses: 0, goalsFor: 3, goalsAgainst: 1,
      source: 'cache',
    );
    int? tapped;

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      locale: const Locale('en'),
      home: Scaffold(
        body: RecentFormBlock(
          teamId: 10,
          data: rf,
          onMatchTap: (g) => tapped = g.fixtureId,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('W'), findsWidgets);
    expect(find.text('D'), findsWidgets);
    expect(find.text('Alpha'), findsWidgets);

    await tester.tap(find.text('Beta').first);
    await tester.pumpAndSettle();
    expect(tapped, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /c/flutter-football && flutter test test/recent_form_block_test.dart`
Expected: FAIL — `RecentFormBlock.dart` doesn't exist.

- [ ] **Step 3: Implement the widget**

Create `lib/widgets/RecentFormBlock.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:football/models/games.dart';
import 'package:football/models/recent_form.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:football/utils/localized_team_name.dart';

/// Recent-form block for the team screen: a W/D/L pill strip over a compact
/// list of the team's last matches. Stateless — the parent fetches the data
/// and supplies [onMatchTap].
class RecentFormBlock extends StatelessWidget {
  final int teamId;
  final RecentForm data;
  final void Function(Game game) onMatchTap;

  const RecentFormBlock({
    super.key,
    required this.teamId,
    required this.data,
    required this.onMatchTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final l = AppLocalizations.of(context)!;

    if (data.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
        child: Center(
          child: Text(
            l.recentFormEmpty.toUpperCase(),
            style: EType.label(color: c.inkDim, size: 11, letterSpacing: 2),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Row(
            children: [
              Container(width: 18, height: 1, color: c.live),
              const SizedBox(width: 10),
              Text(
                l.recentFormTitle.toUpperCase(),
                style: EType.label(color: c.inkDim, size: 11, letterSpacing: 2.2),
              ),
              const Spacer(),
              ...data.form.map((r) => _pill(c, r)),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: c.hairline, width: 1),
          ),
          child: Column(
            children: data.matches.asMap().entries.map((e) {
              final isLast = e.key == data.matches.length - 1;
              return _matchRow(context, e.value, isLast: isLast);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Color _resultColor(EditorialColors c, String r) {
    switch (r) {
      case 'W':
        return c.live;
      case 'L':
        return c.flag;
      case 'D':
        return c.inkMute;
      default:
        return c.inkDim;
    }
  }

  Widget _pill(EditorialColors c, String r) {
    final color = _resultColor(c, r);
    return Container(
      margin: const EdgeInsets.only(left: 4),
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        r,
        style: EType.label(color: color, size: 10, letterSpacing: 0.5),
      ),
    );
  }

  Widget _matchRow(BuildContext context, Game game, {required bool isLast}) {
    final c = context.col;
    final h = game.goals.home;
    final a = game.goals.away;
    final isHome = game.home.id == teamId;
    final scored = isHome ? h : a;
    final conceded = isHome ? a : h;

    String badge = 'D';
    Color badgeColor = c.inkMute;
    if (scored != null && conceded != null) {
      if (scored > conceded) {
        badge = 'W';
        badgeColor = c.live;
      } else if (scored < conceded) {
        badge = 'L';
        badgeColor = c.flag;
      }
    }

    return InkWell(
      onTap: () => onMatchTap(game),
      child: Container(
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(bottom: BorderSide(color: c.hairline, width: 1)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  _teamLine(context, game.home, h, isHome),
                  const SizedBox(height: 6),
                  _teamLine(context, game.away, a, !isHome),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: badgeColor, width: 1),
              ),
              child: Text(
                badge,
                style: EType.label(color: badgeColor, size: 11, letterSpacing: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamLine(BuildContext context, Team team, int? score, bool isViewer) {
    final c = context.col;
    return Row(
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: Image.network(
            team.logo,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.shield_outlined, size: 14, color: c.inkDim),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            localizedTeamName(context, team.name),
            overflow: TextOverflow.ellipsis,
            style: EType.body(
              color: c.ink,
              size: 13,
              weight: isViewer ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          score?.toString() ?? '-',
          style: EType.numeric(color: c.ink, size: 14, weight: FontWeight.w700),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd /c/flutter-football && flutter test test/recent_form_block_test.dart`
Expected: PASS.

> If `find.text('Beta')` resolves to multiple nodes and the tap is ambiguous, the test already uses `.first`. If the editorial color/type API names differ (`context.col`, `EType.label`, `c.live/flag/inkMute/inkDim/card/hairline`), they are copied verbatim from `teamDetails.dart` — keep them in sync with that file.

- [ ] **Step 5: Commit**

```bash
cd /c/flutter-football && git add lib/widgets/RecentFormBlock.dart test/recent_form_block_test.dart && git commit -m "feat: RecentFormBlock widget"
```

---

## Task 10: Client — wire Recent Form into the Stats tab of `teamDetails.dart`

**Files:**
- Modify: `C:\flutter-football\lib\screens\teamDetails.dart`

Render `RecentFormBlock` at the TOP of the Stats tab, with the existing season aggregate kept below it. Fetch once when the screen builds, cache the future in state.

- [ ] **Step 1: Add imports + state**

At the top of `teamDetails.dart`, add imports next to the existing ones:

```dart
import 'package:football/models/recent_form.dart';
import 'package:football/resources/recent_form_service.dart';
import 'package:football/widgets/RecentFormBlock.dart';
```

In `_TeamDetailsScreenState`, add a cached future field below `int _selectedTab = 0;`:

```dart
  Future<RecentForm?>? _recentFormFuture;

  Future<RecentForm?> _loadRecentForm() {
    final teamId = _resolveFixtureTeamId();
    return RecentFormService().getLastMatches(teamId, widget.team.name);
  }
```

- [ ] **Step 2: Build the Recent Form section into the Stats tab**

In `_buildStatsTab()`, find the line that opens the season-aggregate container:

```dart
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: c.card,
```

Replace the single `return Container(...)` (the season-aggregate container) by wrapping it in a Column that puts Recent Form first. Concretely, change the `return Container(` for the stats table into `return Column(...)` as follows — keep the existing aggregate Container as the SECOND child:

```dart
    _recentFormFuture ??= _loadRecentForm();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FutureBuilder<RecentForm?>(
            future: _recentFormFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              }
              final data = snap.data;
              if (data == null || data.isEmpty) return const SizedBox.shrink();
              return RecentFormBlock(
                teamId: _resolveFixtureTeamId(),
                data: data,
                onMatchTap: _openGameDetails,
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        // ── existing season aggregate below ──
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: c.hairline, width: 1),
          ),
          child: Column(
            children: [
              _statRow(c, l.teamStatPlayed, '${stats.played}', isFirst: true),
              _statRow(c, l.teamStatWon, '${stats.won}'),
              _statRow(c, l.teamStatDrawn, '${stats.drawn}'),
              _statRow(c, l.teamStatLost, '${stats.lost}'),
              _statRow(c, l.teamStatGoalsFor, '${stats.goalsFor}'),
              _statRow(c, l.teamStatGoalsAgainst, '${stats.goalsAgainst}'),
              _statRow(c, l.teamStatGoalDiff, diffStr, isLast: true),
            ],
          ),
        ),
      ],
    );
```

> Important: the existing `_buildStatsTab` has an early `if (stats.played == 0)` return that shows "no data". Keep that early return — but note it only fires when the in-memory league aggregate is empty. Recent Form may still have cross-competition data. To avoid hiding Recent Form, MOVE the Recent Form section ABOVE that early-return guard, or relax the guard. Simplest: change the early-return so it only suppresses the aggregate, not the whole tab. Replace the `if (stats.played == 0) { return ... }` block with a local `final hasAggregate = stats.played > 0;` and render the aggregate Container only `if (hasAggregate)`, else render the existing "no data" text in its place — while always rendering the Recent Form section above it.

`_openGameDetails(Game)` already exists in this file and matches the `onMatchTap` signature.

- [ ] **Step 3: Analyze**

Run: `cd /c/flutter-football && flutter analyze lib/screens/teamDetails.dart`
Expected: No issues.

- [ ] **Step 4: Run the full client test suite**

Run: `cd /c/flutter-football && flutter test`
Expected: all tests PASS (including the two new ones).

- [ ] **Step 5: Commit**

```bash
cd /c/flutter-football && git add lib/screens/teamDetails.dart && git commit -m "feat: show Recent Form atop the team Stats tab"
```

---

## Task 11: Client — lazy stats fetch on tap (`?fetch=1`)

**Files:**
- Modify: `C:\flutter-football\lib\resources\stats_service.dart`
- Modify: `C:\flutter-football\lib\widgets\StatsWidget.dart`

The user opening a match's Stats tab IS the "tap". Pass `fetch: true` ONLY for played/live matches so we never spend AllSport calls on not-yet-played fixtures.

- [ ] **Step 1: Add `fetch` param to the service**

In `lib/resources/stats_service.dart`, change the `getFixtureStats` signature and URL:

```dart
  Future<List<TeamStats>?> getFixtureStats(int fixtureId, {bool fetch = false}) async {
    try {
      final url = '$backendUrl/fixtures/$fixtureId/stats${fetch ? '?fetch=1' : ''}';
```

(Leave the rest of the method unchanged.)

- [ ] **Step 2: Pass `fetch` from `StatsWidget` for played/live games**

In `lib/widgets/StatsWidget.dart`, find the call to `getFixtureStats(...)` (around line 50, where `_stats = result;` is assigned). It currently looks like:

```dart
      final result = await StatsService().getFixtureStats(widget.fixtureId);
```

Replace with a guarded version that only opts into the fetch for finished/live matches:

```dart
      const playedOrLive = {'FT', 'AET', 'PEN', '1H', '2H', 'HT', 'ET', 'P', 'LIVE'};
      final shouldFetch = playedOrLive.contains(widget.matchStatusShort);
      final result = await StatsService()
          .getFixtureStats(widget.fixtureId, fetch: shouldFetch);
```

> `widget.matchStatusShort` is already a field on `StatsWidget` (passed from `GameDetails` and available in this file). If the exact call site differs, the change is: thread `fetch: <statusShort is played/live>` into the single `getFixtureStats` call.

- [ ] **Step 3: Analyze**

Run: `cd /c/flutter-football && flutter analyze lib/resources/stats_service.dart lib/widgets/StatsWidget.dart`
Expected: No issues.

- [ ] **Step 4: Commit**

```bash
cd /c/flutter-football && git add lib/resources/stats_service.dart lib/widgets/StatsWidget.dart && git commit -m "feat: opt into on-demand stats fetch for played/live matches"
```

---

## Task 12: Full verification

- [ ] **Step 1: Backend tests**

Run: `cd /c/worldBackend && node --test tests/recentForm.test.mjs tests/stats.ctx.test.mjs && npm test`
Expected: new tests PASS; existing golden test still PASS.

- [ ] **Step 2: Client analyze + tests**

Run: `cd /c/flutter-football && flutter analyze && flutter test`
Expected: no analyzer issues; all tests PASS.

- [ ] **Step 3: Manual smoke (optional, requires running backend + app)**

1. Start the backend (`cd /c/worldBackend && npm start`).
2. Open the app, navigate to a team, open the Stats tab.
3. Confirm Recent Form shows pills + last matches (network tab: one `GET /teams/:id/last-matches`, `source: "cache"`, zero API-FOOTBALL calls).
4. Tap a finished match → GameDetails → Stats tab. Confirm at most one `GET /fixtures/:id/stats?fetch=1`, and that re-opening the same match's stats serves `source: "cache"` (no second AllSport call).

- [ ] **Step 4: Final commit (if any working-tree leftovers)**

```bash
cd /c/flutter-football && git status
```

Expected: clean (everything already committed per-task).

---

## Notes / limitations (intentional, per design)

- AllSport fallback runs only when the cache has **zero** matches for a team; its rows carry Sofascore-namespace team/league ids and `fixture.id = Sofa event id`. Tapping such a fallback row opens GameDetails, but `?fetch=1` stats won't resolve (no matching `FixtureCache` doc) → stats show "not available". Acceptable: the fallback is a rare path for untracked teams.
- No auto-fetch of all 5 matches' stats (YAGNI / quota). Stats are fetched only when a specific match's Stats tab is opened.
```
