# Head-to-Head (H2H) Feature — Design

**Date:** 2026-06-22
**Branch context:** `brackets-same-groups`
**Status:** Approved (pending spec review)

## Goal

Add a Head-to-Head tab to the match-detail screen (`gameDetails`) showing the
historical record between the two teams in a fixture: an aggregate summary plus
a list of recent meetings. The data is derived from fixtures the backend has
**already cached** in MongoDB — **no external API-Football calls** are made, so
the feature costs nothing against the 100/day quota.

## Scope

- One new tab in `gameDetails`, labelled "H2H".
- Content: aggregate summary (Team A W–D–L Team B, total goals) + a list of the
  **last 10** finished meetings (date, competition, score).
- Lazy-loaded on first tab open, mirroring the existing Stats/Events/Lineups
  tabs.

Out of scope: guess-screen H2H summary, predictions/odds, cross-app surfaces.

## Architecture

The feature follows the existing per-fixture data pattern (`stats.js` /
`StatsService` / `StatsWidget`). The only structural difference is that the
backend derives H2H from its own `FixtureCache` collection rather than from a
scheduled external fetch.

### Backend (`worldBackend`)

**Route** — in `src/routes/teamsAndPlayers.js`:

```js
router.get("/fixtures/:fixtureId/h2h", getHeadToHead);
```

**Controller** — new `src/controllers/headToHead.js`, cache-only (never calls
the external API):

1. Look up `fixtureId` in `FixtureCache`. If absent → respond
   `{ success: true, fixtureId, h2h: null, available: false, message: "H2H not yet available." }`
   (same convention as `getFixtureStats`).
2. Read `homeTeamId` (= team A) and `awayTeamId` (= team B) from the cached
   fixture.
3. Query `FixtureCache` for **finished** fixtures where the two teams meet in
   either orientation, across all seasons and competitions:

   ```js
   {
     status: { $in: FINISHED_STATUSES }, // e.g. ["FT","AET","PEN"]
     $or: [
       { homeTeamId: a, awayTeamId: b },
       { homeTeamId: b, awayTeamId: a },
     ],
   }
   ```

   Sorted `{ date: -1 }`, `limit(10)`.
4. Build the response. The summary is normalized so **team A = the current
   fixture's home team**, regardless of each historical meeting's orientation.

**Response shape:**

```json
{
  "success": true,
  "fixtureId": 123,
  "h2h": {
    "summary": {
      "teamAId": 33, "teamBId": 40,
      "aWins": 4, "bWins": 3, "draws": 2,
      "aGoals": 14, "bGoals": 11
    },
    "meetings": [
      {
        "fixtureId": 998,
        "date": "2025-03-02T18:30:00.000Z",
        "leagueId": 39, "leagueName": "Premier League",
        "homeTeamId": 40, "homeName": "Liverpool", "homeLogo": "https://…",
        "awayTeamId": 33, "awayName": "Manchester United", "awayLogo": "https://…",
        "homeGoals": 2, "awayGoals": 1
      }
    ]
  }
}
```

Per-meeting team/league names and logos and the final score are read from each
fixture's stored `raw` object. Goals come from the raw fixture score (final).

### Frontend (`flutter-football`)

**Model** — `lib/models/head_to_head.dart`, hand-written `fromJson` (no
codegen), three classes:

- `H2HSummary { teamAId, teamBId, aWins, bWins, draws, aGoals, bGoals }`
- `H2HMeeting { fixtureId, date (DateTime), leagueId, leagueName, homeTeamId, homeName, homeLogo, awayTeamId, awayName, awayLogo, homeGoals, awayGoals }`
- `HeadToHead { summary, meetings }`

All `fromJson` use the defensive `(x as num?)?.toInt() ?? 0` / `?.toString()`
style of `StandingRow`/`TeamStats`.

**Service** — `lib/resources/head_to_head_service.dart`:

```dart
class HeadToHeadService {
  Future<HeadToHead?> getHeadToHead(int fixtureId) async { … }
}
```

GETs `'$backendUrl/fixtures/$fixtureId/h2h'`, parses `data['h2h']`, returns
`null` on non-200 / `available:false` / parse error. Mirrors `StatsService`
exactly.

**Widget** — `lib/widgets/HeadToHeadWidget.dart`:

- Summary header: `Team A  {aWins}-{draws}-{bWins}  Team B` with goal totals,
  styled like `StatsWidget`.
- Meetings list: per row — date, competition name, and `home score–away score`
  with crests.
- Loading / empty states matching the other tabs (`h2hNoData` when
  `meetings` is empty or `h2h` is null).
- Team names rendered through `localizedTeamName(context, name)`; the raw
  `team.name` from the model is preserved for any navigation/logic.

**gameDetails wiring** — `lib/screens/gameDetails.dart`:

- Add an "H2H" entry to `_buildTabBar()` and the tab body switch.
- On first open of the H2H tab, call `HeadToHeadService().getHeadToHead(...)`
  with the current fixture's id (`_currentGame`), cache the result in state so
  re-opening doesn't refetch (same lazy pattern as the other tabs).

### Localization

New keys added to **all** of `app_en.arb`, `app_he.arb`,
`app_localizations.dart`, `app_localizations_en.dart`,
`app_localizations_he.dart`:

- `h2hTab` — tab label ("H2H" / "מפגשים")
- `h2hNoData` — empty state ("No previous meetings" / "אין מפגשים קודמים")
- `h2hDraws` — summary draws label, if needed for the W-D-L caption

(Exact key set finalized during implementation; every user-visible string is
localized for both locales.)

## Data flow

```
gameDetails (H2H tab opened)
  → HeadToHeadService.getHeadToHead(fixtureId)
    → GET $backendUrl/fixtures/:fixtureId/h2h
      → headToHead.js: FixtureCache lookup (fixture) → FixtureCache query (meetings)
      ← { h2h: { summary, meetings[] } }   (pure Mongo, no API-Football)
  ← HeadToHead model
→ HeadToHeadWidget renders summary + meetings
```

## Error handling

- Backend: fixture not in cache → `available:false`, `h2h:null` (not an error).
  Unexpected exception → 500 `{ success:false }`, logged.
- Frontend: any non-200, `available:false`, or parse failure → service returns
  `null`; widget shows the `h2hNoData` empty state. No crash, no blocking
  spinner left hanging.

## Key decisions & rationale

- **Team-id consistency:** We use **fixture-side** team ids throughout. The
  current fixture's `home.id` / `away.id` are fixture ids and match
  `FixtureCache.homeTeamId/awayTeamId`, so no fuzzy name resolution (unlike the
  standings-vs-fixtures mismatch handled in `teamDetails`).
- **No external API usage:** The feature reads only already-cached fixtures, so
  it never spends API-Football quota — the explicit constraint that drove the
  design.
- **Depth caveat:** History depth is bounded by what `FixtureCache` holds. New
  pairings start thin but grow as more seasons are cached; never worse than a
  pure client-side approach.

## Testing

- Backend: unit-test `headToHead.js` against a seeded in-memory/stub
  `FixtureCache` — verify orientation normalization (team A always the current
  home team), finished-only filter, `limit 10`, and the `available:false` path
  for an unknown fixture id.
- Frontend: `fromJson` round-trip test for the three models; a widget test that
  renders summary + a meetings list and the empty state.
- Manual: open H2H tab on a fixture with known prior meetings; confirm summary
  math matches the listed rows and both locales render correctly (RTL Hebrew).
