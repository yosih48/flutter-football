import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:football/providers/flutter%20pub%20add%20provider.dart';
import 'package:football/providers/league_data_provider.dart';
import 'package:football/resources/auth.dart';
import 'package:football/resources/league_config_service.dart';
import 'package:football/resources/usersMethods.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:football/utils/config.dart';
import 'package:football/utils/league_logos.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../models/notif_pref.dart';

class FavoritsScreen extends StatefulWidget {
  const FavoritsScreen({super.key});

  @override
  State<FavoritsScreen> createState() => _FavoritsScreenState();
}

class _FavoritsScreenState extends State<FavoritsScreen> {
  late String displayName;
  late String email;
  bool isLoading = true;
  String userId = '';
  int selectedTab = 0; // 0 = choose leagues, 1 = notifications

  // Both maps are keyed by league id and driven by the backend config. The DB
  // stores snetEmail and chosenLeagues id-keyed too, so this is a 1:1 mapping
  // with no name bridge — any league added in config works with no app update.
  Map<int, NotifPref> notificationStates = {
    for (final id in LeagueConfigService().supportedLeagues)
      id: const NotifPref(),
  };

  // Which league cards are expanded in the notifications tab. The first league
  // opens by default (seeded once, after the enabled list is known).
  final Set<int> _expandedNotifLeagues = {};
  bool _notifExpandSeeded = false;

  Map<int, bool> chosenLeagues = {
    for (final id in LeagueConfigService().supportedLeagues) id: true,
  };

  // ── Static league data ─────────────────────────────────────────────────
  // League list comes from the backend config (LeagueConfigService) so leagues
  // can be added/removed by season without an app update.
  List<int> get _leagueOrder => LeagueConfigService().supportedLeagues;

  static const _leagueLogoBase =
      'https://media.api-sports.io/football/leagues/';

  // ── Lifecycle ──────────────────────────────────────────────────────────
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadUserPreferences();
  }

  Future<void> _loadUserPreferences() async {
    setState(() => isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      final user = await authProvider.ensureUserLoaded();
      if (user != null) {
        setState(() => userId = user.id);
        _getUserInfo();
      }
    } catch (e) {
      print('Error loading user preferences: $e');
    }
  }

  Future<void> _getUserInfo() async {
    try {
      final userData = await UsersMethods().fetchUserById(userId);
      final snetEmail =
          Map<String, dynamic>.from(userData['snetEmail'] ?? {});
      final chosenLeaguesData =
          Map<String, dynamic>.from(userData['chosenLeagues'] ?? {});

      setState(() {
        for (final id in LeagueConfigService().supportedLeagues) {
          chosenLeagues[id] = chosenLeaguesData[id.toString()] ?? true;
          notificationStates[id] =
              NotifPref.fromJson(snetEmail[id.toString()]);
        }
        isLoading = false;
      });
    } catch (e) {
      print('Error loading user preferences: $e');
      setState(() => isLoading = false);
    }
  }

  // Persists chosenLeagues + snetEmail by id via $set dotted keys on the
  // generic /users/ endpoint. Only the configured leagues' keys are written,
  // so nothing is wiped (unlike the old /users/profile path which $set the
  // whole snetEmail object and silently dropped leagues it didn't send).
  // No `email` is sent so the backend takes the plain-update branch, not the
  // group-join branch. name/email kept in the signature for call-site parity.
  Future<void> updateDatabase(String name, String email) async {
    try {
      // Sync: disable ALL notification kinds for leagues that are unchecked.
      for (final id in LeagueConfigService().supportedLeagues) {
        if (chosenLeagues[id] == false) {
          notificationStates[id] = const NotifPref();
        }
      }

      final set = <String, dynamic>{};
      for (final id in LeagueConfigService().supportedLeagues) {
        set['chosenLeagues.$id'] = chosenLeagues[id] ?? true;
        set['snetEmail.$id'] =
            (notificationStates[id] ?? const NotifPref()).toJson();
      }

      await http.put(
        Uri.parse('$backendUrl/users/'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'_id': userId, '\$set': set}),
      );
      LeagueDataProvider().clearCache();
    } catch (e) {
      print('Error updating database: $e');
    }
  }

  String _localizedLeagueName(int leagueId) {
    final remote = LeagueConfigService()
        .nameFor(leagueId, Localizations.localeOf(context).languageCode);
    if (remote != null) return remote;
    final l = AppLocalizations.of(context)!;
    switch (leagueId) {
      case 2:   return l.championsleague;
      case 383: return l.ligathaal;
      case 140: return l.laliga;
      case 3:   return l.europaleague;
      case 39:  return l.premierleague;
      case 848: return l.conferenceleague;
      default:  return '$leagueId';
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final authProvider = Provider.of<AuthProvider>(context);
    final name = authProvider.currentUser?.name ?? '';
    final userEmail = authProvider.currentUser?.email ?? '';
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: c.pitch,
      appBar: _buildAppBar(l, c),
      body: Skeletonizer(
        enabled: isLoading,
        child: Column(
          children: [
            _buildTabStrip(l, c),
            Container(height: 1, color: c.hairline),
            Expanded(
              child: selectedTab == 0
                  ? _buildLeaguesTab(name, userEmail, l, c)
                  : _buildNotificationsTab(name, userEmail, l, c),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppLocalizations l, EditorialColors c) {
    final title = selectedTab == 0 ? l.chooseleagues : l.notifications;
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: c.pitch,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 72,
      titleSpacing: 20,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l.preferences.toUpperCase(),
            style: EType.label(
                color: c.inkDim, size: 10, letterSpacing: 3),
          ),
          const SizedBox(height: 2),
          Text(
            title.toUpperCase(),
            style: EType.display(
                size: 26, color: c.ink, letterSpacing: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildTabStrip(AppLocalizations l, EditorialColors c) {
    return Container(
      color: c.pitch,
      child: Row(
        children: [
          _TabItem(
            label: l.chooseleagues,
            icon: Icons.shield_outlined,
            active: selectedTab == 0,
            onTap: () => setState(() => selectedTab = 0),
          ),
          _TabItem(
            label: l.notifications,
            icon: Icons.notifications_outlined,
            active: selectedTab == 1,
            onTap: () => setState(() => selectedTab = 1),
          ),
        ],
      ),
    );
  }

  // ── Choose Leagues tab ─────────────────────────────────────────────────
  Widget _buildLeaguesTab(
      String name, String userEmail, AppLocalizations l, EditorialColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              Container(width: 18, height: 1, color: c.live),
              const SizedBox(width: 10),
              Text(
                l.allCompetitions.toUpperCase(),
                style: EType.label(
                    color: c.ink, size: 11, letterSpacing: 2.4),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.85,
              ),
              itemCount: _leagueOrder.length,
              itemBuilder: (context, index) {
                final id = _leagueOrder[index];
                final isSelected = chosenLeagues[id] ?? false;
                return _LeagueCard(
                  leagueId: id,
                  leagueName: _localizedLeagueName(id),
                  logoUrl: '$_leagueLogoBase$id.png',
                  selected: isSelected,
                  onTap: () {
                    // Block unchecking the last remaining league — the user
                    // must always keep at least one league selected.
                    final selectedCount = LeagueConfigService()
                        .supportedLeagues
                        .where((lid) => chosenLeagues[lid] == true)
                        .length;
                    if (isSelected && selectedCount <= 1) {
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(SnackBar(
                          content: Text(l.atLeastOneLeague),
                          behavior: SnackBarBehavior.floating,
                        ));
                      return;
                    }
                    setState(() {
                      chosenLeagues[id] = !isSelected;
                      // Disable notification when league is unchecked.
                      if (!chosenLeagues[id]!) {
                        notificationStates[id] = const NotifPref();
                      }
                    });
                    updateDatabase(name, userEmail);
                  },
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Notifications tab ──────────────────────────────────────────────────
  Widget _buildNotificationsTab(
      String name, String userEmail, AppLocalizations l, EditorialColors c) {
    final enabledIds = LeagueConfigService()
        .supportedLeagues
        .where((id) => chosenLeagues[id] == true)
        .toList();

    if (enabledIds.isEmpty) {
      return _EmptyNotifs(l: l);
    }

    // First league opens by default (seeded once the enabled list is known).
    if (!_notifExpandSeeded) {
      _notifExpandSeeded = true;
      _expandedNotifLeagues.add(enabledIds.first);
    }

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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // ── Global settings (affect every league) ──
        _GlobalNotifCard(
          title: l.notifGlobalTitle,
          goalsLabel: l.notifAllGoals,
          remindersLabel: l.notifAllReminders,
          pointsLabel: l.notifAllPoints,
          goals: allOfKind((p) => p.goals),
          reminders: allOfKind((p) => p.reminders),
          points: allOfKind((p) => p.points),
          onChanged: setAllOfKind,
        ),
        const SizedBox(height: 20),
        // ── Per-league cards (first open by default) ──
        ...enabledIds.map((id) {
          final pref = notificationStates[id] ?? const NotifPref();
          final expanded = _expandedNotifLeagues.contains(id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _LeagueNotifCard(
              logo: Container(
                width: 40,
                height: 40,
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
                      Icon(Icons.shield_outlined, size: 18, color: c.inkDim),
                ),
              ),
              name: _localizedLeagueName(id),
              pref: pref,
              expanded: expanded,
              moreLabel: l.notifMoreSettings,
              goalsLabel: l.notifGoals,
              remindersLabel: l.notifReminders,
              pointsLabel: l.notifPoints,
              onToggleExpand: () => setState(() {
                if (expanded) {
                  _expandedNotifLeagues.remove(id);
                } else {
                  _expandedNotifLeagues.add(id);
                }
              }),
              onMasterChanged: (v) {
                setState(() => notificationStates[id] = v
                    ? const NotifPref(goals: true, reminders: true, points: true)
                    : const NotifPref());
                updateDatabase(name, userEmail);
              },
              onChanged: (next) {
                setState(() => notificationStates[id] = next);
                updateDatabase(name, userEmail);
              },
            ),
          );
        }),
      ],
    );
  }
}

// ── Tab item ────────────────────────────────────────────────────────────
class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon,
                      size: 16,
                      color: active ? c.ink : c.inkDim),
                  const SizedBox(width: 8),
                  Text(
                    label.toUpperCase(),
                    style: EType.label(
                      color: active ? c.ink : c.inkDim,
                      size: 11,
                      letterSpacing: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 2,
              width: active ? 56.0 : 0.0,
              color: c.live,
            ),
          ],
        ),
      ),
    );
  }
}

// ── League card (grid item) ─────────────────────────────────────────────
class _LeagueCard extends StatelessWidget {
  const _LeagueCard({
    required this.leagueId,
    required this.leagueName,
    required this.logoUrl,
    required this.selected,
    required this.onTap,
  });
  final int leagueId;
  final String leagueName;
  final String logoUrl;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: selected ? c.liveSoft : c.card,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
            color: selected ? c.live : c.hairline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo + check badge
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // White circle — keeps dark logos visible
                Container(
                  width: 52,
                  height: 52,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? c.live : c.hairline,
                      width: 1.5,
                    ),
                  ),
                  child: Image(
                    image: leagueLogoProvider(leagueId),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.shield_outlined,
                      size: 20,
                      color: c.inkDim,
                    ),
                  ),
                ),
                // Check badge — top-right of the circle
                Positioned(
                  top: 0,
                  right: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: selected ? c.live : c.card,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? c.live : c.hairlineHi,
                        width: 1,
                      ),
                    ),
                    child: selected
                        ? Icon(Icons.check, size: 9, color: c.pitch)
                        : null,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                leagueName.toUpperCase(),
                style: EType.label(
                  color: selected ? c.live : c.inkMute,
                  size: 9,
                  letterSpacing: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Global settings card: three category toggles for all leagues ────────
class _GlobalNotifCard extends StatelessWidget {
  const _GlobalNotifCard({
    required this.title,
    required this.goalsLabel,
    required this.remindersLabel,
    required this.pointsLabel,
    required this.goals,
    required this.reminders,
    required this.points,
    required this.onChanged,
  });
  final String title;
  final String goalsLabel;
  final String remindersLabel;
  final String pointsLabel;
  final bool goals;
  final bool reminders;
  final bool points;
  final void Function(String kind, bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.hairline, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: EType.display(size: 16, color: c.ink, height: 1.2),
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GlobalToggle(
                  label: pointsLabel,
                  value: points,
                  onChanged: (v) => onChanged('points', v)),
              _GlobalToggle(
                  label: remindersLabel,
                  value: reminders,
                  onChanged: (v) => onChanged('reminders', v)),
              _GlobalToggle(
                  label: goalsLabel,
                  value: goals,
                  onChanged: (v) => onChanged('goals', v)),
            ],
          ),
        ],
      ),
    );
  }
}

// One labeled toggle in the global card (switch above a caption).
class _GlobalToggle extends StatelessWidget {
  const _GlobalToggle({
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
    return Expanded(
      child: Column(
        children: [
          _EditorialSwitch(value: value, onChanged: onChanged),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: EType.label(color: c.inkMute, size: 11, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}

// ── One league card: collapsed summary (a master switch) that expands to
// the three per-kind toggles. ───────────────────────────────────────────
class _LeagueNotifCard extends StatelessWidget {
  const _LeagueNotifCard({
    required this.logo,
    required this.name,
    required this.pref,
    required this.expanded,
    required this.moreLabel,
    required this.goalsLabel,
    required this.remindersLabel,
    required this.pointsLabel,
    required this.onToggleExpand,
    required this.onMasterChanged,
    required this.onChanged,
  });
  final Widget logo;
  final String name;
  final NotifPref pref;
  final bool expanded;
  final String moreLabel;
  final String goalsLabel;
  final String remindersLabel;
  final String pointsLabel;
  final VoidCallback onToggleExpand;
  final ValueChanged<bool> onMasterChanged;
  final ValueChanged<NotifPref> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.col;

    Widget kindRow(String lbl, bool value, NotifPref Function(bool) apply) {
      return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                lbl,
                overflow: TextOverflow.ellipsis,
                style: EType.display(size: 15, color: c.ink, height: 1.0),
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.notifications_none, size: 18, color: c.inkMute),
            const SizedBox(width: 12),
            _EditorialSwitch(value: value, onChanged: (v) => onChanged(apply(v))),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.hairline, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          // Header — tap the logo/name/chevron to expand or collapse.
          Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggleExpand,
                child: logo,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onToggleExpand,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              overflow: TextOverflow.ellipsis,
                              style: EType.display(
                                  size: 16, color: c.ink, height: 1.0),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            expanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 20,
                            color: c.inkMute,
                          ),
                        ],
                      ),
                      if (!expanded) ...[
                        const SizedBox(height: 2),
                        Text(
                          moreLabel,
                          style: EType.label(
                              color: c.inkDim, size: 10, letterSpacing: 0.5),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (!expanded) ...[
                const SizedBox(width: 12),
                _EditorialSwitch(value: pref.anyOn, onChanged: onMasterChanged),
              ],
            ],
          ),
          if (expanded) ...[
            const SizedBox(height: 6),
            kindRow(goalsLabel, pref.goals, (v) => pref.copyWith(goals: v)),
            kindRow(remindersLabel, pref.reminders,
                (v) => pref.copyWith(reminders: v)),
            kindRow(pointsLabel, pref.points, (v) => pref.copyWith(points: v)),
          ],
        ],
      ),
    );
  }
}

// ── Editorial toggle switch ─────────────────────────────────────────────
class _EditorialSwitch extends StatelessWidget {
  const _EditorialSwitch({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 24,
        decoration: BoxDecoration(
          color: value ? c.live : c.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value ? c.live : c.hairlineHi,
            width: 1,
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment:
              value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(2),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: value ? c.pitch : c.inkMute,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty notifications state ───────────────────────────────────────────
class _EmptyNotifs extends StatelessWidget {
  const _EmptyNotifs({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
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
              child: Icon(Icons.notifications_off_outlined,
                  size: 26, color: c.inkDim),
            ),
            const SizedBox(height: 18),
            Text(
              l.noEnabledLeagues.toUpperCase(),
              style: EType.display(
                size: 22,
                color: c.ink,
                letterSpacing: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              l.enableLeaguesFirst,
              textAlign: TextAlign.center,
              style:
                  EType.body(color: c.inkMute, size: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
