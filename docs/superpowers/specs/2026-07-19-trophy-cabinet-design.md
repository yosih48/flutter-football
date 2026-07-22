# Trophy Cabinet — Design

**Date:** 2026-07-19
**Repos touched:** `flutter-football` (Flutter client), `worldBackend` (Node/MongoDB backend)

## 1. Goal

Give each user a **Trophy Cabinet**: a per-league honours view showing their
prediction results across seasons. Requested contents:

- **Past-season final rank / points** per league.
- **Winner & Top-Scorer results** per league (pick + whether it paid off).

## 2. Key constraint discovered

The live backend stores **only current-season, in-place-mutated** values on the
user document (`usersModel.js`):

- `points.{leagueId}` — running matchday total per league
- `winner.{leagueId}` / `championPoints.{leagueId}` — champion pick + one-time 20-pt award
- `topScorer.{leagueId}` / `topScorerPoints.{leagueId}` — top-scorer pick + points
- `bracketPoints.{leagueId}` — running bracket total

There is **no season archive, no rollover snapshot, no per-user history**. The
only season-level record is `ChampionSettlementCache` (champion name per league
per season — not per-user, no rank). Rank is never stored; it is computed live
by sorting users on `points[league]` (`usersClass.js` `getGroupUsers`).

`resetUserStats()` (`usersClass.js:37`) is the existing **season-reset** routine
— it wipes `points`, `thisDayPoints`, and `winner` to empty to begin a new
season. This is the natural hook for an archive snapshot.

**Consequence / chosen direction:** build the cabinet on data that exists today
(shown as "This Season") **and** add a backend snapshot at season rollover so
past seasons accumulate going forward. The cabinet starts with only the current
season and grows over time. Past results cannot be backfilled — they were never
stored.

## 3. Decisions (locked)

| Decision | Choice |
| --- | --- |
| Data direction | Current season now + archive future seasons |
| Rank scope | **Global** (all users for that league), not group-relative |
| UI placement | Profile shows **one combined prediction card per league** (champion + top scorer, tabs removed). The **Trophy Cabinet (past seasons) lives on its own screen** (`TrophyCabinetScreen`), opened from an entry card on the profile — keeping the long per-season history off the main scroll. (Evolved through: third tab → inline section → league chips → dedicated screen.) |
| History storage | **Embedded `seasonScores` object on the user document** (revised from a separate `SeasonHistory` collection) |
| Archive trigger | Manual admin **"close season"** action, **fully decoupled from `resetUserStats`**. Hard requirement: the feature must never reset live points. |
| Read shape | Current + past records share one shape so the UI renders them identically |

## 4. Backend design (`worldBackend`)

### 4.1 Storage — embedded `seasonScores`

> **REVISED.** The original design snapshotted into a separate `SeasonHistory`
> collection triggered from `resetUserStats()`. Per an explicit requirement —
> *the feature must NEVER reset points, under any circumstances* — this was
> replaced with an **embedded `seasonScores` object on the user document**,
> written only by a manual admin **"close season"** action that is fully
> decoupled from `resetUserStats`. The description below reflects the shipped
> design.

Storage is `user.seasonScores`, an Object on the user doc (no separate
collection, no reset coupling):

```
seasonScores: {
  "<season>": {
    "<leagueId>": {
      leagueId, season, points, rank, totalPlayers, winnerPick,
      championName, championCorrect, championPoints,
      topScorerPick, topScorerPoints, bracketPoints
    }
  }
}
```

Each stored slot is exactly a `buildUserSeasonRecord(...)` output.

### 4.2 Admin "close season" action (writes seasonScores)

`archiveSeasonForLeague(leagueId, season, { dryRun })`
(`src/controllers/seasonArchive.js`), exposed as **`POST /api/archive-season`**
in `routes/reminders.js` alongside the existing settle actions:

1. Load all users; compute global rank per league via `computeLeagueRanks`
   (sort on `points[leagueId]` desc — same as the leaderboard).
2. For each participant (has points / winner / top-scorer / bracket for that
   league), build a record via `buildUserSeasonRecord` (`championName` from
   `ChampionSettlementCache[leagueId:season]`; `championCorrect` from
   `championPoints > 0`).
3. `$set` it into `seasonScores.<season>.<leagueId>` with a **dotted key**, so
   only that one slot is touched — `points`, `winner`, `topScorer`, `bracket`
   and all other seasons/leagues are left **completely unchanged**.

`season` is an **explicit** parameter (e.g. `2026` for the World Cup), not
derived from `process.env.SEASON`, so tournaments on their own season are tagged
correctly. Re-running overwrites the same slot (idempotent). `dryRun:true`
previews counts and writes nothing. **Nothing in this path ever resets or
mutates live points.**

`resetUserStats()` is left as it was originally (no snapshot hooked into it);
the Trophy Cabinet has no connection to it.

### 4.3 Read endpoint (`routes/users.js`)

- `GET /users/:id/history` — reads the user's embedded `seasonScores`, flattens
  it to the record shape (`current: false`), newest season first.

Read-only; no new auth beyond the existing `GET /users/*` pattern.

> **Note — "This Season" removed.** An earlier revision also exposed a live
> `GET /users/:id/season-summary` and rendered a "This Season" section at the
> top of the cabinet. Per a later decision the cabinet now shows **only archived
> past seasons**, so that endpoint (and its `getSeasonSummary` controller +
> `season-summary` route) were removed. A side benefit: the transient
> duplication between a live and an archived copy of the same league no longer
> exists.

## 5. Frontend design (`flutter-football`)

### 5.1 Data layer

- New model `lib/models/season_record.dart` — `SeasonRecord` with the record
  fields above + `fromJson`. A `current` bool distinguishes the live season.
- New service `lib/resources/trophyMethods.dart` (mirrors the existing
  `*Methods.dart` style): `fetchSeasonSummary(userId)` and
  `fetchHistory(userId)` returning `List<SeasonRecord>`. Both build requests as
  `'$backendUrl/...'`.

### 5.2 Profile tab wiring (`lib/screens/profile.dart`)

- Replace the `_showWinners` bool with a 3-value selector (enum or index):
  `winners`, `topScorers`, `cabinet`. Update `_buildTabStrip` to render three
  `_Tab`s and `AnimatedSwitcher` to switch among three children.
- Add a `TrophyCabinetTab` widget (in profile.dart or a new
  `lib/widgets/trophyCabinet.dart`) fed by the same `currentUserId` /
  `_allowedIds` the other tabs use.
- Fetch summary + history when the cabinet tab is first shown (lazy — avoid an
  extra round-trip on profile open for users who never open the tab).

### 5.3 Cabinet layout

- **This Season** section header, then one **trophy card per allowed league**
  from the season-summary.
- **Past seasons**: grouped by `season` (newest first), each group a header +
  its league cards, from history.
- **Trophy card** (reuses existing `_LeagueRow` visual vocabulary / editorial
  theme):
  - League crest + name (crest via `leagueLogoProviderForUrl`, name via the
    existing `_leagueName` helper).
  - **Rank badge**: `#{rank}` of `{totalPlayers}`; ranks 1/2/3 get medal accent
    (gold/silver/bronze) using theme colors.
  - **Points** (numeric, `EType.numeric`).
  - **Champion** row: pick, with a check/cross + `+championPoints` when settled.
  - **Top Scorer** row: pick + `topScorerPoints`.
  - **Bracket** row: shown only when `bracketPoints > 0`.
- **Empty state** (`_EmptyCard` pattern) when a user has no records at all.
- Skeleton loading consistent with the existing `Skeletonizer` usage on the
  profile.

### 5.4 Localization

Add keys to **both** `lib/l10n/app_en.arb` and `lib/l10n/app_he.arb`, and the
matching getters in `app_localizations.dart`, `app_localizations_en.dart`,
`app_localizations_he.dart`. New strings (final wording TBD in EN/HE):
`trophyCabinet` (tab label), `thisSeason`, `pastSeasons`, `seasonLabel`,
`rankLabel`, `championResult`, `correct`, `missed`, `bracketPointsLabel`,
`noTrophiesYet` + hint. Team names stay display-only per project rule.

## 6. Testing

- **Backend:** unit-test the snapshot — rank computation for a league, idempotent
  re-run on `{userId, leagueId, season}`, and `championCorrect` derivation.
  Shape-test both endpoints.
- **Frontend:** widget-test the cabinet against mock `SeasonRecord` lists —
  empty state, current-season-only, and multi-season grouping; verify rank badge
  and champion result rendering.

## 7. Out of scope

- Backfilling historical seasons (no source data exists).
- Group-relative rank (global only for v1).
- Sharing / exporting the cabinet.
- Any change to how points are earned or settled.
