import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:football/resources/gamesMethods.dart';
import 'package:football/resources/playersMethods.dart';
import 'package:football/resources/usersMethods.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:football/utils/config.dart';
import 'package:football/utils/localized_team_name.dart';
import 'package:football/utils/utils.dart';
import 'package:http/http.dart' as http;

// ── Availability ────────────────────────────────────────────────────────────
// Whether a user can still pick a season-long winner / top scorer for [leagueId].
// Cut-off is one hour before the first game of the season; once the league has
// started the row will display the existing pick but cannot be edited.
enum PickWindow { open, closed, noGames, error }

class PickAvailability {
  const PickAvailability(this.window, [this.message, this.cutoff]);
  final PickWindow window;
  final String? message;

  /// When the window shuts (local time), for screens that want to show a
  /// deadline. Only set for a still-open window with a scheduled first game —
  /// null when there is nothing to count down to.
  final DateTime? cutoff;

  bool get canPick => window == PickWindow.open;
}

// How long after the last fixture we still treat the league as "just ended"
// (and therefore locked for picks). Beyond this, an all-past fixture list is
// considered stale data for a future season that hasn't been published yet —
// e.g. World Cup (league=1) served with a cached 2022 schedule when the 2026
// fixtures aren't in the backend yet — and the window is opened so the user
// can still pick. Tuned generously because off-seasons for international
// tournaments can run 3+ years.
const Duration _staleScheduleThreshold = Duration(days: 180);

Future<PickAvailability> resolvePickWindow(
    BuildContext context, int leagueId) async {
  final l = AppLocalizations.of(context)!;
  try {
    final games = await GamesMethods().fetchGamesForLeague(leagueId);
    if (games.isEmpty) {
      // No schedule at all — open the window. A user picking with nothing
      // scheduled yet is the same case as a future tournament without
      // fixtures: fail-open is the safer UX than locking on no information.
      return const PickAvailability(PickWindow.open);
    }
    games.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final nowUtc = DateTime.now().toUtc();
    final firstGameUtc = games.first.date.toUtc();
    final lastGameUtc = games.last.date.toUtc();

    // Case A: every fixture is in the past. Either the season just ended
    // (legitimately closed) or the data is stale because a future season
    // hasn't been published yet (open).
    if (nowUtc.isAfter(lastGameUtc)) {
      final age = nowUtc.difference(lastGameUtc);
      if (age > _staleScheduleThreshold) {
        return const PickAvailability(PickWindow.open);
      }
      return PickAvailability(PickWindow.closed, l.selectionClosed);
    }

    // Case B: the season has already begun (some games are past, some future).
    if (nowUtc.isAfter(firstGameUtc)) {
      return PickAvailability(PickWindow.closed, l.selectionClosed);
    }

    // Case C: every fixture is in the future — gate on 1 hour before the first.
    final cutoff = firstGameUtc.subtract(const Duration(hours: 1));
    if (nowUtc.isAfter(cutoff)) {
      return PickAvailability(PickWindow.closed, l.selectiontimeexpired);
    }
    return PickAvailability(PickWindow.open, null, cutoff.toLocal());
  } catch (_) {
    return PickAvailability(PickWindow.error, l.selectionnotavailableyet);
  }
}

// ── Public openers ──────────────────────────────────────────────────────────
Future<String?> openWinnerPicker(
  BuildContext context, {
  required String clientId,
  required String email,
  required int leagueId,
  required String leagueName,
  String? currentPick,
}) {
  final l = AppLocalizations.of(context)!;
  return _openPicker(
    context,
    title: l.pickWinnerTitle,
    leagueName: leagueName,
    currentPick: currentPick,
    searchHint: l.searchTeamHint,
    icon: Icons.emoji_events_outlined,
    fetchOptions: () => _fetchTeamOptions(leagueId),
    onSave: (team) => UsersMethods().updateWinner(
      clientId: clientId,
      email: email,
      leagueId: leagueId,
      team: team,
    ),
    successMessage: l.teamSavedsuccessfully,
    failureMessage: l.failedtoSaveTeam,
    saveLabel: l.saveteam,
  );
}

// The topscorers and getTeams endpoints both come from API-Football but carry
// team names independently, so they can differ by case, punctuation, or a
// long/short form ("Newcastle United" vs "Newcastle"). Worse, some topscorer
// files (e.g. Ligat Haal) put the Hebrew team name in the english field. To
// resolve a crest across all of that we normalize aggressively and match
// loosely, and also index each team by its Hebrew name via [kClubNamesHe].
String _teamKey(String s) => s
    .trim()
    .toLowerCase()
    // Drop gershayim/geresh, quotes and dots so "בית״ר" == "ביתר" and
    // "A.F.C." == "AFC".
    .replaceAll(RegExp('[׳״\'"`.]'), '')
    .replaceAll(RegExp(r'\s+'), ' ');

// Logo lookup keyed by BOTH the team's english name and its Hebrew name (from
// kClubNamesHe), so a player whose team is stored in either language resolves.
Map<String, String> _teamLogoIndex(List<PickerOption> teams) {
  final byTeam = <String, String>{};
  for (final t in teams) {
    final url = t.iconUrl;
    if (url == null || url.isEmpty) continue;
    byTeam[_teamKey(t.value)] = url;
    final he = kClubNamesHe[t.value.trim()];
    if (he != null && he.isNotEmpty) byTeam[_teamKey(he)] = url;
  }
  return byTeam;
}

// Exact key first; then an affix-tolerant pass so a short api name matches a
// longer club name and vice versa ("Newcastle" ⊂ "Newcastle United",
// "Bournemouth" ⊂ "AFC Bournemouth"). Only whole-word leading/trailing overlaps
// count, so "Manchester City" never collides with "Manchester United".
String? _logoForTeam(Map<String, String> byTeam, String team) {
  final k = _teamKey(team);
  if (k.isEmpty) return null;
  final exact = byTeam[k];
  if (exact != null) return exact;
  for (final e in byTeam.entries) {
    final ek = e.key;
    if (k.startsWith('$ek ') ||
        k.endsWith(' $ek') ||
        ek.startsWith('$k ') ||
        ek.endsWith(' $k')) {
      return e.value;
    }
  }
  return null;
}

Future<String?> openTopScorerPicker(
  BuildContext context, {
  required String clientId,
  required String email,
  required int leagueId,
  required String leagueName,
  String? currentPick,
}) {
  final l = AppLocalizations.of(context)!;
  final isHebrew = Localizations.localeOf(context).languageCode == 'he';
  return _openPicker(
    context,
    title: l.pickTopScorerTitle,
    leagueName: leagueName,
    currentPick: currentPick,
    searchHint: l.searchPlayerHint,
    icon: Icons.sports_soccer_outlined,
    fetchOptions: () async {
      // Fetch players and teams in parallel so the team crest can be attached
      // to each row by team name. Team logos aren't in the topScorers JSON,
      // so we mine /getTeams for them. Match by english team name; missing
      // matches fall back to the generic soccer-ball icon.
      final results = await Future.wait([
        PlayersMethods().fetchPlayersListRaw({'league': leagueId}),
        _fetchAllTeamsRaw(leagueId),
      ]);
      final players = results[0] as List<Map<String, String>>;
      final teams = results[1] as List<PickerOption>;
      final logoByTeam = _teamLogoIndex(teams);

      // The persisted value is always name_english so the data shape is locale-
      // agnostic across sessions. Only the label rendered in the dropdown
      // switches to the Hebrew name/team when the app is in Hebrew (with a
      // fallback to English if the Hebrew fields are empty).
      return players.map((p) {
        final en = p['name_english'] ?? '';
        final enTeam = p['team_english'] ?? '';
        final he = (p['name'] ?? '').isNotEmpty ? p['name']! : en;
        final heTeam = (p['team'] ?? '').isNotEmpty ? p['team']! : enTeam;
        return PickerOption(
          value: en,
          label: isHebrew ? he : en,
          subtitle: isHebrew ? heTeam : enTeam,
          // Try the english team first, then the Hebrew one — some files store
          // the team only in Hebrew even in the english field.
          iconUrl: _logoForTeam(logoByTeam, enTeam) ??
              _logoForTeam(logoByTeam, heTeam),
        );
      }).toList();
    },
    onSave: (player) => UsersMethods().updateTopScorer(
      clientId: clientId,
      email: email,
      leagueId: leagueId,
      player: player,
    ),
    successMessage: l.playerSavedsuccessfully,
    failureMessage: l.failedtoSaveplayer,
    saveLabel: l.savePlayer,
  );
}

// ── Crest resolvers for revealing other users' picks ────────────────────────
// Saved picks store only the English name (team / player). To show a crest like
// the rest of the app, we re-derive the logo URL from the same backend lists the
// pickers use. Both fail soft to null (name-only) so a reveal never errors out.

// Team crest for a saved winner pick ([teamEnglish] is the persisted value).
Future<String?> resolveWinnerLogo(int leagueId, String teamEnglish) async {
  if (teamEnglish.isEmpty) return null;
  try {
    final teams = await _fetchAllTeamsRaw(leagueId);
    for (final t in teams) {
      if (t.value == teamEnglish) return t.iconUrl;
    }
  } catch (_) {}
  return null;
}

// The player's team crest for a saved top-scorer pick. Top-scorer rows carry no
// team, so we look the player up in the league list to find their team, then map
// that team to a logo — mirroring openTopScorerPicker's crest attachment.
Future<String?> resolveTopScorerLogo(int leagueId, String playerEnglish) async {
  if (playerEnglish.isEmpty) return null;
  try {
    final results = await Future.wait([
      PlayersMethods().fetchPlayersListRaw({'league': leagueId}),
      _fetchAllTeamsRaw(leagueId),
    ]);
    final players = results[0] as List<Map<String, String>>;
    final teams = results[1] as List<PickerOption>;
    var teamEnglish = '';
    var teamHebrew = '';
    for (final p in players) {
      if (p['name_english'] == playerEnglish) {
        teamEnglish = p['team_english'] ?? '';
        teamHebrew = p['team'] ?? '';
        break;
      }
    }
    if (teamEnglish.isEmpty && teamHebrew.isEmpty) return null;
    final byTeam = _teamLogoIndex(teams);
    return _logoForTeam(byTeam, teamEnglish) ?? _logoForTeam(byTeam, teamHebrew);
  } catch (_) {}
  return null;
}

// A picker row: the [value] is what gets saved, [label] is what's displayed,
// and [iconUrl] (when present) renders a small crest/avatar instead of the
// generic fallback icon.
class PickerOption {
  const PickerOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.iconUrl,
  });
  final String value;
  final String label;

  /// Secondary line under [label] — the player's club in the top-scorer
  /// picker. Null for team options, which are a single line.
  final String? subtitle;
  final String? iconUrl;
}

// European club tournaments that have a qualifying / play-off phase upstream
// of the main draw. /getTeams returns every team registered for the season —
// including teams eliminated in qualifying — so for these leagues we cross-
// reference fixtures and drop teams that never played a non-qualifying round.
// IDs: 2 = Champions League, 3 = Europa League, 848 = Conference League.
const Set<int> _europeanTournamentsWithQualifying = {2, 3, 848};

// API-Football round labels we treat as pre-main-draw:
//   • "1st/2nd/3rd Qualifying Round"   → contains "qualif"
//   • "Play-offs"                      → the pre-group play-off (exact match)
//   • "Preliminary Round"              → small competitions only
// IMPORTANT: "Knockout Round Play-offs" is a POST-group round in the new CL/EL
// format. Match "Play-offs" only as a whole-string equality, never as a substring.
bool _isPreMainDrawRound(String round) {
  final r = round.toLowerCase().trim();
  if (r.contains('qualif')) return true;
  if (r.contains('preliminary')) return true;
  if (r == 'play-offs' || r == 'play offs' || r == 'playoffs') return true;
  return false;
}

// ── Internals ───────────────────────────────────────────────────────────────
// Hits the backend's /getTeams endpoint (same shape the legacy teamSelect.dart
// used). The response wraps the team list under `games`, and each entry has a
// nested `team.name` + `team.logo`. We can't derive this from already-loaded
// fixtures because during pre-season the fixture list may be empty.
//
// For European tournaments we then filter down to teams that have at least one
// fixture in a non-qualifying round, so the winner picker doesn't suggest
// teams that never made it past the qualifiers.
Future<List<PickerOption>> _fetchTeamOptions(int leagueId) async {
  final all = await _fetchAllTeamsRaw(leagueId);
  if (!_europeanTournamentsWithQualifying.contains(leagueId)) return all;
  try {
    final games = await GamesMethods().fetchGamesForLeague(leagueId);
    final keep = <String>{};
    for (final g in games) {
      if (_isPreMainDrawRound(g.league.round)) continue;
      if (g.home.name.isNotEmpty) keep.add(g.home.name);
      if (g.away.name.isNotEmpty) keep.add(g.away.name);
    }
    // Fail-open: if we couldn't classify (no fixtures yet, all classified as
    // qualifying), return the unfiltered list rather than hiding everything.
    if (keep.isEmpty) return all;
    return all.where((t) => keep.contains(t.value)).toList();
  } catch (_) {
    return all;
  }
}

Future<List<PickerOption>> _fetchAllTeamsRaw(int leagueId) async {
  final res = await http.post(
    Uri.parse('$backendUrl/getTeams'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'data': leagueId.toString()}),
  );
  if (res.statusCode != 200) return const [];
  final decoded = jsonDecode(res.body);
  final list = decoded is Map ? decoded['games'] : null;
  if (list is! List) return const [];
  final seen = <String>{};
  final out = <PickerOption>[];
  for (final item in list) {
    if (item is! Map) continue;
    final team = item['team'];
    if (team is! Map) continue;
    final name = team['name']?.toString() ?? '';
    if (name.isEmpty || !seen.add(name)) continue;
    final logo = team['logo']?.toString();
    out.add(PickerOption(value: name, label: name, iconUrl: logo));
  }
  out.sort((a, b) => a.label.compareTo(b.label));
  return out;
}

Future<String?> _openPicker(
  BuildContext context, {
  required String title,
  required String leagueName,
  required String? currentPick,
  required String searchHint,
  required IconData icon,
  required Future<List<PickerOption>> Function() fetchOptions,
  required Future<void> Function(String) onSave,
  required String successMessage,
  required String failureMessage,
  required String saveLabel,
  String Function(String)? transformPick,
}) async {
  final l = AppLocalizations.of(context)!;
  List<PickerOption> options;
  try {
    options = await fetchOptions();
  } catch (_) {
    options = const [];
  }
  if (options.isEmpty) {
    if (context.mounted) {
      showSnackBar(context, l.selectionnotavailableyet, tone: SnackTone.warning);
    }
    return null;
  }

  if (!context.mounted) return null;

  String? selected = currentPick;
  bool saving = false;
  // Owned out here so they survive StatefulBuilder rebuilds; disposed once the
  // dialog is gone.
  final searchCtrl = TextEditingController();
  final listCtrl = ScrollController();

  final result = await showDialog<String>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          final c = ctx.col;
          final isHe = Localizations.localeOf(ctx).languageCode == 'he';
          return Dialog(
            backgroundColor: c.card,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header: league eyebrow + title, close button at the end
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              leagueName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: EType.body(
                                  color: c.inkDim, size: 11, hebrew: isHe),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              title,
                              style: EType.body(
                                  size: 20,
                                  color: c.ink,
                                  weight: FontWeight.w700,
                                  hebrew: isHe),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => Navigator.of(ctx).pop(null),
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: c.cardHi,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.close, size: 17, color: c.inkMute),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // ── Notice: informational, not an error — the window is still
                  // open, this just says when it shuts.
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: c.amber.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 16, color: c.amber),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            AppLocalizations.of(ctx)!.teamcannotbechanged,
                            style: EType.body(
                                color: c.amber,
                                size: 12,
                                height: 1.45,
                                hebrew: isHe),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ── Search
                  Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: c.cardHi,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, size: 18, color: c.inkDim),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: searchCtrl,
                            enabled: !saving,
                            cursorColor: c.live,
                            onChanged: (_) => setDialogState(() {}),
                            style: EType.body(
                                color: c.ink, size: 14, hebrew: isHe),
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: searchHint,
                              hintStyle: EType.body(
                                  color: c.inkDim, size: 14, hebrew: isHe),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Option list
                  Container(
                    clipBehavior: Clip.antiAlias,
                    constraints: const BoxConstraints(maxHeight: 300),
                    decoration: BoxDecoration(
                      border: Border.all(color: c.hairline),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Builder(builder: (_) {
                      // Match against what's actually on screen, so a Hebrew
                      // query hits the Hebrew label the user can see.
                      final q = searchCtrl.text.trim().toLowerCase();
                      final shown = q.isEmpty
                          ? options
                          : options.where((o) {
                              final name =
                                  localizedTeamName(ctx, o.label).toLowerCase();
                              final sub = o.subtitle == null
                                  ? ''
                                  : localizedTeamName(ctx, o.subtitle!)
                                      .toLowerCase();
                              return name.contains(q) ||
                                  sub.contains(q) ||
                                  o.value.toLowerCase().contains(q);
                            }).toList();

                      if (shown.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          child: Center(
                            child: Text(
                              AppLocalizations.of(ctx)!.noSearchResults,
                              style: EType.body(
                                  color: c.inkDim, size: 13, hebrew: isHe),
                            ),
                          ),
                        );
                      }

                      return Scrollbar(
                        controller: listCtrl,
                        thumbVisibility: true,
                        child: ListView.separated(
                          controller: listCtrl,
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: shown.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: c.hairline),
                          itemBuilder: (_, i) {
                            final opt = shown[i];
                            return _OptionTile(
                              option: opt,
                              fallback: icon,
                              selected: selected == opt.value,
                              onTap: saving
                                  ? null
                                  : () => setDialogState(
                                      () => selected = opt.value),
                            );
                          },
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 20),

                  // ── Actions: primary leads (right in RTL), cancel trails.
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _PrimaryButton(
                          label: saveLabel,
                          loading: saving,
                          onTap: (selected == null || saving)
                              ? null
                              : () async {
                                  setDialogState(() => saving = true);
                                  final picked = transformPick != null
                                      ? transformPick(selected!)
                                      : selected!;
                                  try {
                                    await onSave(picked);
                                    if (ctx.mounted) {
                                      Navigator.of(ctx).pop(picked);
                                    }
                                  } catch (_) {
                                    if (ctx.mounted) {
                                      setDialogState(() => saving = false);
                                      showSnackBar(ctx, failureMessage,
                                          tone: SnackTone.error);
                                    }
                                  }
                                },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: _GhostButton(
                          label: l.cancel,
                          onTap:
                              saving ? null : () => Navigator.of(ctx).pop(null),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  searchCtrl.dispose();
  listCtrl.dispose();

  if (result != null && context.mounted) {
    showSnackBar(context, successMessage, tone: SnackTone.success);
  }
  return result;
}

// One row of the picker list: crest, name over club, and a check on the
// selected row (which also tints).
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.fallback,
    required this.selected,
    required this.onTap,
  });
  final PickerOption option;
  final IconData fallback;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final isHe = Localizations.localeOf(context).languageCode == 'he';
    final sub = option.subtitle;

    return Material(
      color: selected ? c.liveSoft : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              _OptionLeading(iconUrl: option.iconUrl, fallback: fallback),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      localizedTeamName(context, option.label),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: EType.body(
                          color: c.ink,
                          size: 14,
                          weight: FontWeight.w700,
                          hebrew: isHe),
                    ),
                    if (sub != null && sub.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        localizedTeamName(context, sub),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            EType.body(color: c.inkDim, size: 12, hebrew: isHe),
                      ),
                    ],
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                Icon(Icons.check, size: 18, color: c.live),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Small leading visual in the dropdown rows. When the option carries an icon
// URL (team crest), we show it in a circular frame matching the editorial
// league-row crest. Otherwise we fall back to the generic IconData supplied by
// the caller (e.g. soccer ball for top-scorer rows).
class _OptionLeading extends StatelessWidget {
  const _OptionLeading({required this.iconUrl, required this.fallback});
  final String? iconUrl;
  final IconData fallback;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    if (iconUrl == null || iconUrl!.isEmpty) {
      return Icon(fallback, size: 16, color: c.inkMute);
    }
    return Container(
      width: 28,
      height: 28,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.cardHi,
        shape: BoxShape.circle,
        border: Border.all(color: c.hairline, width: 1),
      ),
      child: Image.network(
        iconUrl!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(fallback, size: 12, color: c.inkDim),
      ),
    );
  }
}

// ── Reusable visual atoms exposed for profile rows ─────────────────────────
class EmptyPickChip extends StatelessWidget {
  const EmptyPickChip({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final l = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: c.hairlineHi),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l.tapToPick.toUpperCase(),
            style: EType.label(color: c.inkMute, size: 10, letterSpacing: 1.6),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 14, color: c.inkMute),
        ],
      ),
    );
  }
}

class ClosedPickChip extends StatelessWidget {
  const ClosedPickChip({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final l = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: c.hairline),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        l.selectionClosed.toUpperCase(),
        style: EType.label(color: c.inkDim, size: 10, letterSpacing: 1.6),
      ),
    );
  }
}

// ── Buttons ─────────────────────────────────────────────────────────────────
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onTap,
    this.loading = false,
  });
  final String label;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final disabled = onTap == null;
    final isHe = Localizations.localeOf(context).languageCode == 'he';
    return Material(
      color: disabled ? c.cardHi : c.live,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          child: loading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EType.body(
                    color: disabled ? c.inkDim : Colors.white,
                    size: 14,
                    weight: FontWeight.w700,
                    hebrew: isHe,
                  ),
                ),
        ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final disabled = onTap == null;
    final isHe = Localizations.localeOf(context).languageCode == 'he';
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.hairlineHi, width: 1),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: EType.body(
                color: disabled ? c.inkDim : c.ink,
                size: 14,
                weight: FontWeight.w600,
                hebrew: isHe),
          ),
        ),
      ),
    );
  }
}
