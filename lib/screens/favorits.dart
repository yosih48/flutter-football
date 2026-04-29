import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:football/providers/flutter%20pub%20add%20provider.dart';
import 'package:football/providers/league_data_provider.dart';
import 'package:football/resources/auth.dart';
import 'package:football/resources/usersMethods.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:football/utils/config.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:skeletonizer/skeletonizer.dart';

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

  Map<String, bool> notificationStates = {
    'ליגת אלופות': false,
    'ליגת העל': false,
    'ליגה ספרדית': false,
    'ליגה אירופית': false,
    'ליגה אנגלית': false,
    'קונפרנס ליג': false,
    'גביע מועדונים': false,
  };

  Map<int, bool> chosenLeagues = {
    2: true,
    383: true,
    140: true,
    3: true,
    39: true,
    848: true,
  };

  // ── Static league data ─────────────────────────────────────────────────
  static const _leagueOrder = [2, 383, 140, 3, 39, 848];

  static const _leagueLogoBase =
      'https://media.api-sports.io/football/leagues/';

  static const _notifKeyToId = {
    'ליגת אלופות': 2,
    'ליגת העל': 383,
    'ליגה ספרדית': 140,
    'ליגה אירופית': 3,
    'ליגה אנגלית': 39,
    'קונפרנס ליג': 848,
  };

  static const _idToNotifKey = {
    2: 'ליגת אלופות',
    383: 'ליגת העל',
    140: 'ליגה ספרדית',
    3: 'ליגה אירופית',
    39: 'ליגה אנגלית',
    848: 'קונפרנס ליג',
  };

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
        notificationStates['ליגת אלופות'] = snetEmail['2'] ?? false;
        notificationStates['ליגה אירופית'] = snetEmail['3'] ?? false;
        notificationStates['ליגה ספרדית'] = snetEmail['140'] ?? false;
        notificationStates['ליגת העל'] = snetEmail['383'] ?? false;
        notificationStates['ליגה אנגלית'] = snetEmail['39'] ?? false;
        notificationStates['קונפרנס ליג'] = snetEmail['848'] ?? false;

        chosenLeagues[2] = chosenLeaguesData['2'] ?? true;
        chosenLeagues[3] = chosenLeaguesData['3'] ?? true;
        chosenLeagues[140] = chosenLeaguesData['140'] ?? true;
        chosenLeagues[383] = chosenLeaguesData['383'] ?? true;
        chosenLeagues[39] = chosenLeaguesData['39'] ?? true;
        chosenLeagues[848] = chosenLeaguesData['848'] ?? true;

        isLoading = false;
      });
    } catch (e) {
      print('Error loading user preferences: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> updateDatabase(String name, String email) async {
    final url = Uri.parse('$backendUrl/users/profile');
    try {
      // Sync: disable notifications for disabled leagues.
      _notifKeyToId.forEach((key, leagueId) {
        if (notificationStates[key] == true &&
            chosenLeagues[leagueId] == false) {
          notificationStates[key] = false;
        }
      });

      final encodableLeagues = chosenLeagues
          .map((k, v) => MapEntry(k.toString(), v));

      await http.put(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'email': email,
          'displayName': name,
          'leagueData': {
            'championsLeague': notificationStates['ליגת אלופות'],
            'israeliLeague': notificationStates['ליגת העל'],
            'spanishLeague': notificationStates['ליגה ספרדית'],
            'europeLeague': notificationStates['ליגה אירופית'],
            'premierLeague': notificationStates['ליגה אנגלית'],
            'conferenceLeague': notificationStates['קונפרנס ליג'],
            'africaLeague': false,
            'euroLeague': false,
            'copaLeague': false,
          },
          'chosenLeagues': encodableLeagues,
        }),
      );
      LeagueDataProvider().clearCache();
    } catch (e) {
      print('Error updating database: $e');
    }
  }

  String _localizedLeagueName(int leagueId) {
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

  String _localizedLeagueNameFromKey(String key) {
    final id = _notifKeyToId[key];
    if (id == null) return key;
    return _localizedLeagueName(id);
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
                    setState(() {
                      chosenLeagues[id] = !isSelected;
                      // Disable notification when league is unchecked.
                      if (!chosenLeagues[id]!) {
                        final key = _idToNotifKey[id];
                        if (key != null) notificationStates[key] = false;
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
    final filtered = Map.fromEntries(
      notificationStates.entries.where((e) {
        final id = _notifKeyToId[e.key];
        return id != null && chosenLeagues[id] == true;
      }),
    );

    if (filtered.isEmpty) {
      return _EmptyNotifs(l: l);
    }

    final allOn = filtered.values.every((v) => v);

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        // ── Select all ──
        _NotifRow(
          logoWidget: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.card,
              shape: BoxShape.circle,
              border: Border.all(color: c.hairline, width: 1),
            ),
            child: Icon(Icons.notifications_outlined,
                size: 16, color: c.inkMute),
          ),
          label: l.chooseallcompetitions,
          value: allOn,
          onChanged: (v) {
            setState(() {
              _notifKeyToId.forEach((key, leagueId) {
                if (chosenLeagues[leagueId] == true) {
                  notificationStates[key] = v;
                }
              });
            });
            updateDatabase(name, userEmail);
          },
          isSelectAll: true,
        ),
        Container(height: 1, color: c.hairline),
        // ── Individual leagues ──
        ...filtered.entries.map((entry) {
          final key = entry.key;
          final id = _notifKeyToId[key] ?? 0;
          return _NotifRow(
            logoWidget: Container(
              width: 36,
              height: 36,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: entry.value ? c.liveSoft : c.card,
                shape: BoxShape.circle,
                border: Border.all(
                  color: entry.value
                      ? c.live.withOpacity(0.5)
                      : c.hairline,
                  width: 1,
                ),
              ),
              child: Image.network(
                '$_leagueLogoBase$id.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.shield_outlined,
                  size: 16,
                  color: c.inkDim,
                ),
              ),
            ),
            label: _localizedLeagueNameFromKey(key),
            value: entry.value,
            onChanged: (v) {
              setState(() => notificationStates[key] = v);
              updateDatabase(name, userEmail);
            },
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
                  child: Image.network(
                    logoUrl,
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

// ── Notification row ────────────────────────────────────────────────────
class _NotifRow extends StatelessWidget {
  const _NotifRow({
    required this.logoWidget,
    required this.label,
    required this.value,
    required this.onChanged,
    this.isSelectAll = false,
  });
  final Widget logoWidget;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isSelectAll;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Container(
      decoration: BoxDecoration(
        color: isSelectAll ? c.terrace : Colors.transparent,
        border: Border(
          bottom: BorderSide(color: c.hairline, width: 1),
          left: BorderSide(
            color: value ? c.live : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          logoWidget,
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              isSelectAll
                  ? label.toUpperCase()
                  : label.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: isSelectAll
                  ? EType.label(
                      color: c.ink, size: 11, letterSpacing: 1.8)
                  : EType.display(
                      size: 16,
                      color: c.ink,
                      letterSpacing: 0.8,
                      height: 1.0,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          _EditorialSwitch(value: value, onChanged: onChanged),
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
