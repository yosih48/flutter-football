import 'dart:convert';

import 'package:flutter/material.dart';
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
  const FavoritsScreen({super.key, this.initialTab = 0});

  // 0 = choose leagues, 1 = notifications. Lets other screens deep-link.
  final int initialTab;

  @override
  State<FavoritsScreen> createState() => _FavoritsScreenState();
}

class _FavoritsScreenState extends State<FavoritsScreen> {
  late String displayName;
  late String email;
  bool isLoading = true;
  String userId = '';
  late int selectedTab; // 0 = choose leagues, 1 = notifications

  @override
  void initState() {
    super.initState();
    selectedTab = widget.initialTab;
  }

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
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 10,
                // Fixed pixel height rather than a width-derived ratio: the
                // card content is a constant 122px tall, so a ratio would
                // under-size (and overflow) the cards on narrow screens.
                mainAxisExtent: 138,
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

    final anyOn = enabledIds
        .any((id) => (notificationStates[id] ?? const NotifPref()).anyOn);

    void setAllNotifs(bool v) {
      setState(() {
        for (final id in enabledIds) {
          notificationStates[id] = v
              ? const NotifPref(goals: true, reminders: true, points: true)
              : const NotifPref();
        }
      });
      updateDatabase(name, userEmail);
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // ── Master switch — turns every alert on or off ──
        _MasterNotifCard(
          title: l.notifMasterTitle,
          subtitle: l.notifMasterSub,
          value: anyOn,
          onChanged: setAllNotifs,
        ),
        const SizedBox(height: 24),

        // ── Defaults (apply to all leagues) ──
        _NotifSectionHeader(label: l.notifDefaults, trailing: l.notifApplyAll),
        const SizedBox(height: 10),
        _NotifRowCard(
          kind: _NotifKind.goals,
          title: l.notifAllGoals,
          subtitle: l.notifGoalsSub,
          value: allOfKind((p) => p.goals),
          onChanged: (v) => setAllOfKind('goals', v),
        ),
        const SizedBox(height: 10),
        _NotifRowCard(
          kind: _NotifKind.reminders,
          title: l.notifAllReminders,
          subtitle: l.notifRemindersSub,
          value: allOfKind((p) => p.reminders),
          onChanged: (v) => setAllOfKind('reminders', v),
        ),
        const SizedBox(height: 10),
        _NotifRowCard(
          kind: _NotifKind.points,
          title: l.notifAllPoints,
          subtitle: l.notifPointsSub,
          value: allOfKind((p) => p.points),
          onChanged: (v) => setAllOfKind('points', v),
        ),
        const SizedBox(height: 28),

        // ── Per-league cards (first open by default) ──
        _NotifSectionHeader(label: l.notifPerLeague),
        const SizedBox(height: 10),
        ...enabledIds.map((id) {
          final pref = notificationStates[id] ?? const NotifPref();
          final expanded = _expandedNotifLeagues.contains(id);
          final onCount = (pref.goals ? 1 : 0) +
              (pref.reminders ? 1 : 0) +
              (pref.points ? 1 : 0);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _LeagueNotifGroup(
              leagueId: id,
              name: _localizedLeagueName(id),
              pref: pref,
              expanded: expanded,
              subtitle: '$onCount ${l.notifAlertsOnSuffix}',
              goalsTitle: l.notifAllGoals,
              remindersTitle: l.notifAllReminders,
              pointsTitle: l.notifAllPoints,
              goalsSub: l.notifGoalsSub,
              remindersSub: l.notifRemindersSub,
              pointsSub: l.notifPointsSub,
              onToggleExpand: () => setState(() {
                if (expanded) {
                  _expandedNotifLeagues.remove(id);
                } else {
                  _expandedNotifLeagues.add(id);
                }
              }),
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
      child: Stack(
        clipBehavior: Clip.none,
        // Fill the whole grid cell so every card is the same height and the
        // check badge anchors to a consistent corner.
        fit: StackFit.expand,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
            decoration: BoxDecoration(
              color: selected ? c.liveSoft : c.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? c.live : c.hairline,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // White circle — keeps dark logos visible (unchanged).
                Container(
                  width: 54,
                  height: 54,
                  padding: const EdgeInsets.all(10),
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
                const SizedBox(height: 10),
                // Fixed two-line box: one- and two-line names occupy the same
                // space, so logos sit on a shared baseline across the grid.
                SizedBox(
                  height: 32,
                  child: Text(
                    leagueName,
                    style: EType.body(
                      size: 13,
                      color: c.ink,
                      weight: FontWeight.w600,
                      height: 1.15,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Selected check badge — card's top-right corner.
          if (selected)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.live,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.card, width: 2),
                ),
                child: const Icon(Icons.check, size: 12, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

// The three notification categories, each with its own tinted icon tile.
enum _NotifKind { goals, reminders, points }

class _NotifIconTile extends StatelessWidget {
  const _NotifIconTile({required this.kind});
  final _NotifKind kind;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final IconData icon;
    final Color bg;
    final Color fg;
    switch (kind) {
      case _NotifKind.goals:
        icon = Icons.adjust;
        bg = c.live.withValues(alpha: 0.12);
        fg = c.live;
        break;
      case _NotifKind.reminders:
        icon = Icons.schedule_outlined;
        bg = c.amber.withValues(alpha: 0.16);
        fg = c.amber;
        break;
      case _NotifKind.points:
        icon = Icons.emoji_events_outlined;
        bg = c.inkMute.withValues(alpha: 0.14);
        fg = c.ink;
        break;
    }
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: fg),
    );
  }
}

// Master card: one switch that turns every alert on or off.
class _MasterNotifCard extends StatelessWidget {
  const _MasterNotifCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.hairline, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.live.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.notifications_none, size: 20, color: c.live),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: EType.display(size: 16, color: c.ink, height: 1.1)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: EType.body(color: c.inkMute, size: 12, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _EditorialSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

// Small section label (e.g. DEFAULTS) with an optional trailing hint.
class _NotifSectionHeader extends StatelessWidget {
  const _NotifSectionHeader({required this.label, this.trailing});
  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Text(label.toUpperCase(),
              style:
                  EType.label(color: c.inkDim, size: 11, letterSpacing: 1.8)),
          const Spacer(),
          if (trailing != null)
            Text(trailing!, style: EType.body(color: c.inkMute, size: 12)),
        ],
      ),
    );
  }
}

// A single notification row card: tinted icon + title/subtitle + switch.
// Used both in "Defaults" and inside an expanded per-league card.
class _NotifRowCard extends StatelessWidget {
  const _NotifRowCard({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final _NotifKind kind;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.hairline, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          _NotifIconTile(kind: kind),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: EType.display(size: 15, color: c.ink, height: 1.1)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style:
                        EType.body(color: c.inkMute, size: 12, height: 1.25)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _EditorialSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

// One league group: a header card (logo + name + "N of 3 alerts on" + chevron)
// that expands to three notification row cards for that league.
class _LeagueNotifGroup extends StatelessWidget {
  const _LeagueNotifGroup({
    required this.leagueId,
    required this.name,
    required this.pref,
    required this.expanded,
    required this.subtitle,
    required this.goalsTitle,
    required this.remindersTitle,
    required this.pointsTitle,
    required this.goalsSub,
    required this.remindersSub,
    required this.pointsSub,
    required this.onToggleExpand,
    required this.onChanged,
  });
  final int leagueId;
  final String name;
  final NotifPref pref;
  final bool expanded;
  final String subtitle;
  final String goalsTitle;
  final String remindersTitle;
  final String pointsTitle;
  final String goalsSub;
  final String remindersSub;
  final String pointsSub;
  final VoidCallback onToggleExpand;
  final ValueChanged<NotifPref> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.col;

    return Column(
      children: [
        // Header card — tap anywhere to expand/collapse.
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onToggleExpand,
          child: Container(
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: pref.anyOn ? c.live.withValues(alpha: 0.5) : c.hairline,
                width: 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: pref.anyOn ? c.live : c.hairline,
                      width: 1.5,
                    ),
                  ),
                  child: Image(
                    image: leagueLogoProvider(leagueId),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        Icon(Icons.shield_outlined, size: 18, color: c.inkDim),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            EType.display(size: 16, color: c.ink, height: 1.1),
                      ),
                      const SizedBox(height: 3),
                      Text(subtitle,
                          style: EType.body(color: c.inkMute, size: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 22,
                  color: c.inkMute,
                ),
              ],
            ),
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: 10),
          _NotifRowCard(
            kind: _NotifKind.goals,
            title: goalsTitle,
            subtitle: goalsSub,
            value: pref.goals,
            onChanged: (v) => onChanged(pref.copyWith(goals: v)),
          ),
          const SizedBox(height: 10),
          _NotifRowCard(
            kind: _NotifKind.reminders,
            title: remindersTitle,
            subtitle: remindersSub,
            value: pref.reminders,
            onChanged: (v) => onChanged(pref.copyWith(reminders: v)),
          ),
          const SizedBox(height: 10),
          _NotifRowCard(
            kind: _NotifKind.points,
            title: pointsTitle,
            subtitle: pointsSub,
            value: pref.points,
            onChanged: (v) => onChanged(pref.copyWith(points: v)),
          ),
        ],
      ],
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
