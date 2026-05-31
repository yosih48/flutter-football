import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:football/resources/gamesMethods.dart';
import 'package:football/resources/playersMethods.dart';
import 'package:football/resources/usersMethods.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:football/utils/config.dart';
import 'package:football/utils/utils.dart';
import 'package:http/http.dart' as http;

// ── Availability ────────────────────────────────────────────────────────────
// Whether a user can still pick a season-long winner / top scorer for [leagueId].
// Cut-off is one hour before the first game of the season; once the league has
// started the row will display the existing pick but cannot be edited.
enum PickWindow { open, closed, noGames, error }

class PickAvailability {
  const PickAvailability(this.window, [this.message]);
  final PickWindow window;
  final String? message;
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
    return const PickAvailability(PickWindow.open);
  } catch (_) {
    return PickAvailability(PickWindow.error, l.selectionnotavailable);
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
      final logoByTeam = <String, String>{
        for (final t in teams)
          if (t.iconUrl != null && t.iconUrl!.isNotEmpty) t.value: t.iconUrl!,
      };

      // The persisted value is always name_english so the data shape is locale-
      // agnostic across sessions. Only the label rendered in the dropdown
      // switches to the Hebrew name/team when the app is in Hebrew (with a
      // fallback to English if the Hebrew fields are empty).
      return players.map((p) {
        final en = p['name_english'] ?? '';
        final enTeam = p['team_english'] ?? '';
        final he = (p['name'] ?? '').isNotEmpty ? p['name']! : en;
        final heTeam = (p['team'] ?? '').isNotEmpty ? p['team']! : enTeam;
        final label = isHebrew ? '$he ($heTeam)' : '$en ($enTeam)';
        return PickerOption(
          value: en,
          label: label,
          iconUrl: logoByTeam[enTeam],
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

// A picker row: the [value] is what gets saved, [label] is what's displayed,
// and [iconUrl] (when present) renders a small crest/avatar instead of the
// generic fallback icon.
class PickerOption {
  const PickerOption({
    required this.value,
    required this.label,
    this.iconUrl,
  });
  final String value;
  final String label;
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
      showSnackBar(context, l.selectionnotavailable, tone: SnackTone.warning);
    }
    return null;
  }

  if (!context.mounted) return null;

  String? selected = currentPick;
  bool saving = false;

  final result = await showDialog<String>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          final c = ctx.col;
          return Dialog(
            backgroundColor: c.card,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              leagueName.toUpperCase(),
                              style: EType.label(
                                  color: c.inkDim,
                                  size: 10,
                                  letterSpacing: 3),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              title.toUpperCase(),
                              style: EType.display(
                                  size: 22,
                                  color: c.ink,
                                  letterSpacing: 1.2),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.of(ctx).pop(null),
                        borderRadius: BorderRadius.circular(2),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.close,
                              size: 18, color: c.inkMute),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(height: 1, color: c.hairline),
                  const SizedBox(height: 14),

                  // ── Warning
                  Text(
                    AppLocalizations.of(ctx)!.teamcannotbechanged,
                    style: EType.label(
                        color: c.flag, size: 10, letterSpacing: 1.6),
                  ),
                  const SizedBox(height: 18),

                  // ── Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: c.hairline),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selected,
                        dropdownColor: c.card,
                        icon: Icon(Icons.keyboard_arrow_down,
                            color: c.inkMute),
                        hint: Text(
                          AppLocalizations.of(ctx)!.tapToPick,
                          style: EType.body(color: c.inkDim, size: 14),
                        ),
                        items: options
                            .map((opt) => DropdownMenuItem<String>(
                                  value: opt.value,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 6),
                                    child: Row(
                                      children: [
                                        _OptionLeading(
                                            iconUrl: opt.iconUrl,
                                            fallback: icon),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            opt.label,
                                            overflow: TextOverflow.ellipsis,
                                            style: EType.body(
                                                color: c.ink, size: 14),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ))
                            .toList(),
                        onChanged: saving
                            ? null
                            : (v) => setDialogState(() => selected = v),
                      ),
                    ),
                  ),

                  // ── Selected preview
                  if (selected != null) ...[
                    const SizedBox(height: 18),
                    Text(
                      l.yourprediction.toUpperCase(),
                      style: EType.label(
                          color: c.inkDim, size: 10, letterSpacing: 1.6),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: PickedChip(label: selected!, icon: icon),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ── Actions
                  Row(
                    children: [
                      Expanded(
                        child: _GhostButton(
                          label: l.cancel,
                          onTap: saving
                              ? null
                              : () => Navigator.of(ctx).pop(null),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
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

  if (result != null && context.mounted) {
    showSnackBar(context, successMessage, tone: SnackTone.success);
  }
  return result;
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
      width: 22,
      height: 22,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: c.cardHi,
        shape: BoxShape.circle,
        border: Border.all(color: c.hairline, width: 1),
      ),
      child: Image.network(
        iconUrl!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            Icon(fallback, size: 12, color: c.inkDim),
      ),
    );
  }
}

// ── Reusable visual atoms exposed for profile rows ─────────────────────────
class PickedChip extends StatelessWidget {
  const PickedChip({super.key, required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      constraints: const BoxConstraints(maxWidth: 140),
      decoration: BoxDecoration(
        color: c.liveSoft,
        border: Border.all(color: c.live.withOpacity(0.5), width: 1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c.live),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: EType.body(
                  color: c.live, size: 12, weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

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
            style: EType.label(
                color: c.inkMute, size: 10, letterSpacing: 1.6),
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
    return Material(
      color: disabled ? c.cardHi : c.live,
      borderRadius: BorderRadius.circular(2),
      child: InkWell(
        borderRadius: BorderRadius.circular(2),
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            border:
                Border.all(color: disabled ? c.hairline : c.live, width: 1),
          ),
          child: loading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation(c.pitch),
                  ),
                )
              : Text(
                  label.toUpperCase(),
                  style: EType.label(
                    color: disabled ? c.inkDim : c.pitch,
                    size: 12,
                    letterSpacing: 2,
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
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(2),
      child: InkWell(
        borderRadius: BorderRadius.circular(2),
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: c.hairline, width: 1),
          ),
          child: Text(
            label.toUpperCase(),
            style: EType.label(
                color: disabled ? c.inkDim : c.inkMute,
                size: 12,
                letterSpacing: 2),
          ),
        ),
      ),
    );
  }
}
