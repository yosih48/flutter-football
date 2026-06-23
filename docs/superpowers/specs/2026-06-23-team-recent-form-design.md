# Team Recent Form (Last 5 Matches) — Design

**Date:** 2026-06-23
**Repos:** `flutter-football` (client), `worldBackend` (Node backend)

## Goal

Let a user view a team's last 5 matches — recent form plus per-match statistics —
triggered on demand from the team screen, while spending the **absolute minimum**
of external API quota.

## Background / constraints

- API-FOOTBALL quota is 100/day and frequently exhausted; AllSport (Sofascore
  wrapper, RapidAPI) has a **separate** 100/day quota. Both are scarce.
- The backend already has the building blocks:
  - `FixtureCache` (Mongo) holds every tracked fixture, queryable by
    `homeTeamId` / `awayTeamId`. The H2H endpoint
    (`src/controllers/headToHead.js`) already does a "last N finished matches"
    query against it at **zero** quota cost.
  - `StatsCache` (Mongo) + `/data/{fixtureId}-stats.json` hold per-fixture stats
    populated by the proactive kickoff+50 job.
  - AllSport integration (`src/controllers/allsports.js`) already calls
    `/api/team/{sofaTeamId}/matches/previous/0` and has `resolveSofaTeamId()`
    (API-FOOTBALL team id + name → Sofascore team id, disk + negative cached).
  - `fetchAndCacheStats(fixtureId, { ctx })` (`src/controllers/stats.js`) fetches
    stats via AllSport when given fixture context, cache-first.
- The frontend `teamDetails.dart` already lists a team's matches from
  `allLeagueGames` (single league, in memory) and resolves a fixture-side team id
  via `_resolveFixtureTeamId()`. Tapping a match opens `GameDetails`.

## Decisions (from brainstorming)

1. **Scope:** last 5 across **all tracked competitions**, with AllSport fallback
   when the cache is thin.
2. **Detail:** results/form **plus** per-match stats.
3. **Stats fetch policy:** cache-only by default; **lazy on tap** — a single
   AllSport call only for a match the user actually opens.

## Data-source decision tree (core of the design)

| Need | Source | API cost |
|------|--------|----------|
| List of last 5 (results/form) | `FixtureCache` query, finished, `date desc`, limit 5 | 0 |
| List, cache has < 5 for this team | Fallback: AllSport `/api/team/{sofaId}/matches/previous/0` (1 call), transformed to fixture shape | 1 AllSport |
| Per-match stats, already cached | `StatsCache` | 0 |
| Per-match stats, on tap, not cached | Build ctx from `FixtureCache.raw` → `fetchAndCacheStats(fixtureId, {ctx})` → AllSport | 1 AllSport per opened match |

## Backend changes (`worldBackend`)

### 1. New `GET /teams/:teamId/last-matches`

- Query params: `name` (team name, for the AllSport fallback search), `limit`
  (default 5).
- New controller `src/controllers/recentForm.js`, modeled on `headToHead.js`.
- Primary: query `FixtureCache` for finished fixtures
  (`status ∈ {FT, AET, PEN}`) where `homeTeamId == teamId || awayTeamId ==
  teamId`, sorted `date: -1`, limited to `limit`.
- Build response: a `summary` (form streak from team's perspective, W/D/L counts,
  goals for/against) + a `meetings` list (fixtureId, date, league, both teams,
  goals, logos) — shaped consistently with the H2H response.
- Fallback: if the cache returns fewer than `limit` (or zero), call AllSport
  `fetchTeamPreviousFinishedEvent`-style `/api/team/{sofaId}/matches/previous/0`
  via `resolveSofaTeamId(teamId, name)`; transform Sofascore events into the same
  meeting shape. Mark the response `source: "cache" | "allsports" | "mixed"`.
- Register the route in `src/routes/teamsAndPlayers.js`.

### 2. Opt-in on-demand stats: `getFixtureStats` `?fetch=1`

- Default behavior (no flag) unchanged: cache-only, never calls the API.
- When `?fetch=1` and cache misses: load the fixture from `FixtureCache`, build
  `ctx = { apiFootballLeagueId, kickoffIso, homeName, awayName }` from
  `raw`, and call `fetchAndCacheStats(fixtureId, { ctx, tag: "on-demand" })`.
  Return the freshly fetched stats (or `available: false` if AllSport has none).
- This is what makes lazy stats work for old / cup matches the proactive job
  never touched.

## Frontend changes (`flutter-football`)

### 3. Data layer

- Add a method (extend `team_statistics_service.dart` or a `teamMethods` class)
  that calls `$backendUrl/teams/{teamId}/last-matches?name=...&limit=5` and parses
  the `meetings` into `Game` models (from the API-FOOTBALL `raw` shape) plus a
  parsed form summary.

### 4. `teamDetails.dart` — Recent Form block

- Pass the resolved fixture-side team id (`_resolveFixtureTeamId()`) and
  `team.name` to the new method.
- Render a **Recent Form** block at the **top of the existing Stats tab**, with
  the season aggregate kept below it:
  - form pills (e.g. W-W-D-L-W) coloured like the existing W/D/L badges,
  - the 5 matches reusing the existing `_matchRow` styling,
  - each row tappable → existing `GameDetails`.

### 5. `GameDetails` — lazy stats on tap

- When the user opens a match's stats and the cache-only call returns "not
  available", call the stats endpoint with `?fetch=1` to trigger the single
  on-demand AllSport fetch. (Exact current call site to be confirmed during
  planning.)

### 6. Localization

- Add new he/en strings (Recent Form header, form labels, "stats not available",
  etc.) per CLAUDE.md: `app_en.arb`, `app_he.arb`, `app_localizations.dart`,
  `app_localizations_en.dart`, `app_localizations_he.dart`.

## Out of scope (YAGNI)

- Auto-fetching stats for all 5 matches on open (rejected — burns quota).
- A standalone full-screen "recent form" page (the Stats-tab block is enough).
- Caching/storage changes beyond reusing the existing `FixtureCache` / `StatsCache`.

## Testing

- Backend: unit-test `recentForm.js` summary/meeting derivation against fixture
  fixtures (cache-only path); verify fallback triggers only when cache < limit;
  verify `?fetch=1` builds ctx and calls `fetchAndCacheStats` once.
- Frontend: widget test the Recent Form block rendering (form pills, rows) from a
  mocked response; verify tap navigates to `GameDetails`.
