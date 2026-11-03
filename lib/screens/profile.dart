import 'dart:math';

import 'package:flutter/material.dart';
import 'package:football/providers/flutter%20pub%20add%20provider.dart';
import 'package:football/resources/auth.dart';
import 'package:football/resources/league_config_service.dart';
import 'package:football/utils/league_logos.dart';
import 'package:football/utils/localized_team_name.dart';
import 'package:football/utils/he_player_name.dart';
import 'package:football/resources/usersMethods.dart';
import 'package:football/screens/login_screen.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:football/widgets/adminChampionSettle.dart';
import 'package:football/widgets/adminBracketSettle.dart';
import 'package:football/widgets/adminSeasonArchive.dart';
import 'package:football/widgets/seasonPickers.dart';
import 'package:football/screens/trophyCabinet.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:football/models/season_record.dart';
import 'package:football/resources/trophyMethods.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

// Hebrew needs a face that actually ships Hebrew glyphs (Rubik); the Latin
// display face silently falls back per-device. Every bold string on this screen
// routes through EType.body(hebrew:) / EType.screenTitle(hebrew:) for that
// reason — see the font audit.
bool _isHe(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'he';

class ProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, UserProvider>(
      builder: (context, authProvider, userProvider, child) {
        if (authProvider.currentUser == null) {
          return LoginScreen();
        }
        return ProfileScreenContent(
          authProvider: authProvider,
          userProvider: userProvider,
        );
      },
    );
  }
}

class ProfileScreenContent extends StatefulWidget {
  final AuthProvider authProvider;
  final UserProvider userProvider;

  ProfileScreenContent({
    required this.authProvider,
    required this.userProvider,
  });

  @override
  _ProfileScreenContentState createState() => _ProfileScreenContentState();
}

// Last loaded profile, per user. The screen is a PageView tab (disposed when
// swiped away), so a revisit renders the real cards at once and refreshes
// behind them instead of flashing the skeleton again.
class _ProfileCache {
  static String? userId;
  static Map<String, dynamic>? userData;
  static List<SeasonRecord>? history;
}

class _ProfileScreenContentState extends State<ProfileScreenContent> {
  Map<String, String> _userWinners = {};
  Map<String, String> _userTopScorer = {};
  // chosenLeagues[id] from the user record. Missing entries are treated as
  // opted-in (matches the bootstrap default in games.dart), so a league newly
  // added to the remote config shows up here without a manual toggle.
  Map<String, bool> _chosenLeagues = {};
  // Current-season points per league id, for the hero's stats row.
  Map<String, double> _points = {};
  // Year the account was created, for the "player since YYYY" line. Empty when
  // the backend record has no usable createdAt, in which case that half of the
  // subtitle is simply omitted.
  String _memberSinceYear = '';
  // Archived seasons. Null until loaded (or if that fails), in which case the
  // podium / first-place tiles are left out of the stats row.
  List<SeasonRecord>? _history;
  // Pick window per league, resolved here rather than inside each card so the
  // progress card can leave out picks that can no longer be made.
  final Map<String, PickAvailability> _windows = {};
  int _windowsGen = 0;
  // How many league cards the skeleton shows on a cold load — the count from
  // the last successful load, so the page doesn't shrink when data arrives.
  int? _placeholderCount;
  bool _isLoading = true;
  bool _loadFailed = false;
  late String currentUserId;
  late String currentUserEmail;
  late String currentUserName;

  String get _countPrefsKey => 'profileLeagueCount_$currentUserId';

  @override
  void initState() {
    super.initState();
    currentUserId = widget.authProvider.currentUser?.id ?? '';
    currentUserEmail = widget.authProvider.currentUser?.email ?? '';
    currentUserName = widget.authProvider.currentUser?.name ?? '';

    if (_ProfileCache.userId == currentUserId &&
        _ProfileCache.userData != null) {
      _applyUserData(_ProfileCache.userData!);
      _history = _ProfileCache.history;
      _isLoading = false;
      // resolvePickWindow reads AppLocalizations, so wait for the first frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _resolveWindows();
      });
    } else {
      _loadPlaceholderCount();
    }
    _fetchPersonalData();
    _fetchHistory();
  }

  Future<void> _loadPlaceholderCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final n = prefs.getInt(_countPrefsKey);
      if (n != null && mounted && _isLoading) {
        setState(() => _placeholderCount = n);
      }
    } catch (_) {}
  }

  void _applyUserData(Map<String, dynamic> userData) {
    _userWinners = Map<String, String>.from(userData['winner'] ?? {});
    _userTopScorer = Map<String, String>.from(userData['topScorer'] ?? {});
    _chosenLeagues = Map<String, bool>.from(userData['chosenLeagues'] ?? {});
    final rawPoints = userData['points'];
    _points = rawPoints is Map
        ? {
            for (final e in rawPoints.entries)
              e.key.toString():
                  double.tryParse(e.value?.toString() ?? '') ?? 0,
          }
        : {};
    _memberSinceYear =
        DateTime.tryParse(userData['createdAt']?.toString() ?? '')
                ?.year
                .toString() ??
            '';
  }

  Future<void> _fetchPersonalData() async {
    try {
      final userData = await UsersMethods().fetchUserById(currentUserId);
      if (!mounted) return;
      _ProfileCache.userId = currentUserId;
      _ProfileCache.userData = userData;
      setState(() {
        _applyUserData(userData);
        _isLoading = false;
        _loadFailed = false;
      });
      _resolveWindows();
      SharedPreferences.getInstance()
          .then((p) => p.setInt(_countPrefsKey, _allowedIds.length))
          .catchError((_) => false);
      Provider.of<UserProvider>(context, listen: false)
          .setCurrentUser(currentUserId);
    } catch (e) {
      print('Failed to fetch personal data: $e');
      // With cached data on screen, keep showing it; otherwise say it failed
      // rather than rendering every pick as "missing".
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (_ProfileCache.userId != currentUserId) _loadFailed = true;
        });
      }
    }
  }

  Future<void> _fetchHistory() async {
    try {
      final history = await const TrophyMethods().fetchHistory(currentUserId);
      _ProfileCache.history = history;
      if (mounted) setState(() => _history = history);
    } catch (e) {
      print('Failed to fetch trophy history: $e');
    }
  }

  Future<void> _retry() async {
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    await Future.wait([_fetchPersonalData(), _fetchHistory()]);
  }

  Future<void> _refresh() =>
      Future.wait([_fetchPersonalData(), _fetchHistory()]);

  // Re-probed after every load (incl. after a save) so a league that just
  // crossed its cutoff flips to closed. Old values stay on screen until the
  // new ones land, and a newer pass discards a slower older one.
  void _resolveWindows() {
    final gen = ++_windowsGen;
    for (final id in _allowedIds) {
      final intId = int.tryParse(id);
      if (intId == null) continue;
      resolvePickWindow(context, intId).then((av) {
        if (!mounted || gen != _windowsGen) return;
        setState(() => _windows[id] = av);
      });
    }
  }

  // League universe = (supported by backend config) ∩ (opted-in by this user).
  // Missing chosenLeagues entries default to opted-in to match games.dart
  // bootstrap behaviour. Comparing as strings because the user maps are
  // keyed by string ids.
  Set<String> get _allowedIds => LeagueConfigService()
      .supportedLeagues
      .map((id) => id.toString())
      .where((id) => _chosenLeagues[id] != false)
      .toSet();

  bool _isClosed(String id) => _windows[id]?.window == PickWindow.closed;

  void _openCabinet() => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TrophyCabinetScreen(userId: currentUserId),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final filteredWinners = _filterById(_userWinners);
    final filteredTopScorers = _filterById(_userTopScorer);

    // Skeleton placeholders: one card per league the user had last time, or
    // per supported league on a first-ever load.
    final supported = LeagueConfigService().supportedLeagues;
    final placeholderNames = <String, String>{
      for (final id in supported.take(_placeholderCount ?? supported.length))
        id.toString(): 'Loading',
    };

    return Scaffold(
      backgroundColor: c.pitch,
      body: SafeArea(
        child: RefreshIndicator(
          color: c.live,
          backgroundColor: c.card,
          onRefresh: _refresh,
          child: SingleChildScrollView(
            // AlwaysScrollable so a short page can still be pulled down.
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHero(context, c),
                if (_loadFailed)
                  _ErrorCard(onRetry: _retry)
                else
                  _buildBody(
                    context,
                    c,
                    placeholderNames: placeholderNames,
                    filteredWinners: filteredWinners,
                    filteredTopScorers: filteredTopScorers,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    EditorialColors c, {
    required Map<String, String> placeholderNames,
    required Map<String, String> filteredWinners,
    required Map<String, String> filteredTopScorers,
  }) {
    final l = AppLocalizations.of(context)!;
    final ids =
        _isLoading ? placeholderNames.keys.toList() : _allowedIds.toList();

    if (!_isLoading && ids.isEmpty) {
      return _EmptyCard(
        icon: Icons.emoji_events_outlined,
        title: l.noWinnersYet,
        subtitle: l.noWinnersHint,
      );
    }

    int filled(Map<String, String> src, String id) {
      final v = src[id];
      return (v != null && v.isNotEmpty) ? 1 : 0;
    }

    // Two picks per league — champion and top scorer. A league whose window
    // has closed only counts the picks actually made: the rest can't be made
    // any more, so they'd keep the bar from ever reaching 100%.
    var done = 0;
    var total = 0;
    if (!_isLoading) {
      for (final id in ids) {
        final made = filled(filteredWinners, id) + filled(filteredTopScorers, id);
        done += made;
        total += _isClosed(id) ? made : 2;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(context, c, l.myChampionshipPicks),
        Skeletonizer(
          enabled: _isLoading,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isLoading || total > 0)
                _ProgressCard(done: done, total: _isLoading ? 2 : total),
              ...ids.map((id) => _LeaguePredictionCard(
                    leagueIdStr: id,
                    winnerPick: _isLoading ? null : filteredWinners[id],
                    topScorerPick: _isLoading ? null : filteredTopScorers[id],
                    availability: _isLoading ? null : _windows[id],
                    clientId: currentUserId,
                    email: currentUserEmail,
                    isLoading: _isLoading,
                    onChanged: _fetchPersonalData,
                  )),
            ],
          ),
        ),

        // ── Trophy cabinet entry → dedicated past-seasons screen ──────
        if (!_isLoading) _buildCabinetEntry(context, c),
        const SizedBox(height: 24),
      ],
    );
  }

  // Tappable card that opens the dedicated Trophy Cabinet screen (past
  // seasons). Keeps the long, per-season history off the main profile scroll.
  Widget _buildCabinetEntry(BuildContext context, EditorialColors c) {
    final l = AppLocalizations.of(context)!;
    final isHe = _isHe(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: GestureDetector(
        onTap: _openCabinet,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.hairline),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c.ink,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.emoji_events,
                    size: 20, color: Color(0xFFD4AF37)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.trophyCabinet,
                        style: EType.body(
                            color: c.ink,
                            size: 15,
                            weight: FontWeight.w700,
                            hebrew: isHe)),
                    const SizedBox(height: 3),
                    Text(l.pastSeasons,
                        style: EType.body(
                            color: c.inkMute, size: 12, hebrew: isHe)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 22, color: c.inkDim),
            ],
          ),
        ),
      ),
    );
  }

  // Large bold section title, the anchor of the picks list.
  Widget _sectionTitle(BuildContext context, EditorialColors c, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Text(
        label,
        style:
            EType.screenTitle(size: 20, color: c.ink, hebrew: _isHe(context)),
      ),
    );
  }

  Map<String, String> _filterById(Map<String, String> src) {
    final allowed = _allowedIds;
    return Map.fromEntries(src.entries.where((e) => allowed.contains(e.key)));
  }

  String _fmtPoints(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);

  Widget _buildHero(BuildContext context, EditorialColors c) {
    final l = AppLocalizations.of(context)!;
    final isHe = _isHe(context);
    final initial =
        currentUserName.isNotEmpty ? currentUserName[0].toUpperCase() : '?';
    final loaded = !_isLoading && !_loadFailed;

    // "Player since 2023 • 5 leagues" — each half is dropped when its data
    // isn't available, so the separator never dangles.
    final parts = <String>[
      if (_memberSinceYear.isNotEmpty)
        '${l.profilePlayerSince} $_memberSinceYear',
      if (loaded) '${_allowedIds.length} ${l.profileLeaguesWord}',
    ];

    final history = _history;
    final seasonPoints = _allowedIds.fold<double>(
        0, (sum, id) => sum + (_points[id] ?? 0));

    return Container(
      color: c.pitch,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Solid green monogram — the profile's anchor.
          Center(
            child: Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.live, shape: BoxShape.circle),
              child: Text(
                initial,
                style: EType.display(size: 32, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Text(
            currentUserName.isNotEmpty ? currentUserName : '—',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: EType.body(
                color: c.ink, size: 20, weight: FontWeight.w700, hebrew: isHe),
          ),

          if (parts.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_outline, size: 14, color: c.inkDim),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    parts.join('  •  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EType.body(color: c.inkDim, size: 12, hebrew: isHe),
                  ),
                ),
              ],
            ),
          ],

          // Stats row — the season at a glance; tapping opens the cabinet.
          if (loaded) ...[
            const SizedBox(height: 16),
            _StatsRow(
              onTap: _openCabinet,
              stats: [
                _Stat(_fmtPoints(seasonPoints), l.profileSeasonPoints),
                if (history != null) ...[
                  _Stat(
                      '${history.where((r) => r.rank != null && r.rank! <= 3).length}',
                      l.trophyPodiums),
                  _Stat('${history.where((r) => r.rank == 1).length}',
                      l.trophyFirstPlaces),
                ],
              ],
            ),
          ],

          if (widget.authProvider.currentUser?.admin == true) ...[
            const SizedBox(height: 20),
            const _AdminManagementSection(),
          ],
        ],
      ),
    );
  }
}

// ── Hero stats row ──────────────────────────────────────────────────────────
class _Stat {
  const _Stat(this.value, this.label);
  final String value;
  final String label;
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats, required this.onTap});
  final List<_Stat> stats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final isHe = _isHe(context);
    final cells = <Widget>[];
    for (var i = 0; i < stats.length; i++) {
      if (i > 0) {
        cells.add(Container(width: 1, height: 30, color: c.hairline));
      }
      cells.add(Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(stats[i].value,
                style: EType.numeric(
                    color: c.ink, size: 20, weight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(
              stats[i].label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: EType.body(color: c.inkMute, size: 11, hebrew: isHe),
            ),
          ],
        ),
      ));
    }
    return Material(
      color: c.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.hairline),
          ),
          child: Row(children: cells),
        ),
      ),
    );
  }
}

// ── Load-failure card ───────────────────────────────────────────────────────
// Shown instead of the picks list when the user record couldn't be fetched,
// so an outage doesn't read as "every pick is missing".
class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final l = AppLocalizations.of(context)!;
    final isHe = _isHe(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
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
            child: Icon(Icons.wifi_off_rounded, size: 26, color: c.inkDim),
          ),
          const SizedBox(height: 18),
          Text(
            l.profileLoadFailed,
            textAlign: TextAlign.center,
            style:
                EType.body(color: c.inkMute, size: 13, height: 1.5, hebrew: isHe),
          ),
          const SizedBox(height: 20),
          Material(
            color: c.live,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onRetry,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.refresh, size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      l.retry,
                      style: EType.body(
                          color: Colors.white,
                          size: 13,
                          weight: FontWeight.w700,
                          hebrew: isHe),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Progress card ───────────────────────────────────────────────────────────
// "3/6 picks completed" with a bar. LinearProgressIndicator is direction-aware,
// so the fill grows from the right in Hebrew without extra work.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.done, required this.total});
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final l = AppLocalizations.of(context)!;
    final isHe = _isHe(context);
    final value = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);

    // Once everything is picked the bar carries no information — collapse to
    // a one-line confirmation.
    if (total > 0 && done >= total) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: c.liveSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.live.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, size: 18, color: c.live),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l.picksAllDone,
                style: EType.body(
                    color: c.ink,
                    size: 13,
                    weight: FontWeight.w600,
                    hebrew: isHe),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.picksCompleted,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: EType.body(color: c.inkMute, size: 12, hebrew: isHe),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$done/$total',
                style: EType.numeric(
                    color: c.ink, size: 20, weight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: c.cardHi,
              valueColor: AlwaysStoppedAnimation(c.live),
            ),
          ),
        ],
      ),
    );
  }
}

// Admin-only "league management" section. Collapsed to a single line; tapping
// expands a card with the three admin actions (settle bracket / champion /
// close season).
class _AdminManagementSection extends StatefulWidget {
  const _AdminManagementSection();

  @override
  State<_AdminManagementSection> createState() =>
      _AdminManagementSectionState();
}

class _AdminManagementSectionState extends State<_AdminManagementSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final l = AppLocalizations.of(context)!;
    final isHe = _isHe(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Toggle line: green dash + "League management" + chevron.
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 3,
                  decoration: BoxDecoration(
                    color: c.live,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(l.leagueManagement,
                    style: EType.body(
                        color: c.ink,
                        size: 13,
                        weight: FontWeight.w700,
                        hebrew: isHe)),
                const Spacer(),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(Icons.expand_more, size: 22, color: c.inkDim),
                ),
              ],
            ),
          ),
        ),
        if (_open) ...[
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.hairline),
            ),
            child: Column(
              children: [
                _AdminRow(
                  icon: Icons.fact_check_outlined,
                  title: l.settleBracketTitle,
                  subtitle: l.adminSettleBracketSub,
                  onTap: () => showAdminBracketSettleDialog(context),
                ),
                Divider(
                    height: 1, color: c.hairline, indent: 14, endIndent: 14),
                _AdminRow(
                  icon: Icons.workspace_premium_outlined,
                  title: l.settleChampionTitle,
                  subtitle: l.adminSettleChampionSub,
                  onTap: () => showAdminChampionSettleDialog(context),
                ),
                Divider(
                    height: 1, color: c.hairline, indent: 14, endIndent: 14),
                _AdminRow(
                  icon: Icons.event_available_outlined,
                  title: l.closeSeasonTitle,
                  subtitle: l.adminCloseSeasonSub,
                  onTap: () => showAdminSeasonArchiveDialog(context),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// A single admin action row: soft-green icon tile + title + subtitle + chevron.
class _AdminRow extends StatelessWidget {
  const _AdminRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final isHe = _isHe(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: c.live.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 19, color: c.live),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: EType.body(
                          color: c.ink,
                          size: 14,
                          weight: FontWeight.w700,
                          hebrew: isHe)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style:
                          EType.body(color: c.inkDim, size: 11, hebrew: isHe)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: c.inkDim),
          ],
        ),
      ),
    );
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────
// Resolve the display name via the backend league config first; fall back to
// the bundled localizations for the historically-known ids so we still show a
// translated name if the remote config hasn't loaded yet.
String _leagueName(String id, AppLocalizations l, BuildContext context) {
  final intId = int.tryParse(id);
  if (intId != null) {
    final remote = LeagueConfigService()
        .nameFor(intId, Localizations.localeOf(context).languageCode);
    if (remote != null) return remote;
  }
  switch (id) {
    case '2':
      return l.championsleague;
    case '383':
      return l.ligathaal;
    case '140':
      return l.laliga;
    case '3':
      return l.europaleague;
    case '39':
      return l.premierleague;
    case '848':
      return l.conferenceleague;
    default:
      return id;
  }
}

String _leagueLogoUrl(String id) =>
    'https://media.api-sports.io/football/leagues/$id.png';

// ── Combined per-league prediction card ─────────────────────────────────
// One card per opted-in league: crest + name + status, then the champion and
// top-scorer rows. The pick window is resolved by the screen (it also feeds
// the progress card) and handed in; null means it's still being probed.
class _LeaguePredictionCard extends StatelessWidget {
  const _LeaguePredictionCard({
    required this.leagueIdStr,
    required this.winnerPick,
    required this.topScorerPick,
    required this.availability,
    required this.clientId,
    required this.email,
    required this.isLoading,
    required this.onChanged,
  });

  final String leagueIdStr;
  final String? winnerPick;
  final String? topScorerPick;
  final PickAvailability? availability;
  final String clientId;
  final String email;
  final bool isLoading;
  final VoidCallback onChanged;

  bool get _hasWinner => winnerPick != null && winnerPick!.isNotEmpty;
  bool get _hasTopScorer => topScorerPick != null && topScorerPick!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final l = AppLocalizations.of(context)!;
    final av = availability;
    final waiting = av == null && !isLoading;
    final isOpen = av?.canPick ?? false;
    final closed = av?.window == PickWindow.closed;
    final missing = (_hasWinner ? 0 : 1) + (_hasTopScorer ? 0 : 1);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context, c, l,
              missing: missing, closed: closed, cutoff: av?.cutoff),
          Divider(height: 1, color: c.hairline),
          _SeasonPickRow(
            leagueIdStr: leagueIdStr,
            pick: winnerPick,
            icon: Icons.emoji_events_outlined,
            label: l.trophyChampionLabel,
            clientId: clientId,
            email: email,
            isOpen: isOpen,
            waiting: waiting,
            onChanged: onChanged,
            mode: _PickKind.winner,
          ),
          Divider(height: 1, color: c.hairline),
          _SeasonPickRow(
            leagueIdStr: leagueIdStr,
            pick: topScorerPick,
            icon: Icons.sports_soccer_outlined,
            label: l.trophyTopScorerLabel,
            clientId: clientId,
            email: email,
            isOpen: isOpen,
            waiting: waiting,
            onChanged: onChanged,
            mode: _PickKind.topScorer,
          ),
        ],
      ),
    );
  }

  Widget _header(
    BuildContext context,
    EditorialColors c,
    AppLocalizations l, {
    required int missing,
    required bool closed,
    required DateTime? cutoff,
  }) {
    final isHe = _isHe(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              // White circle — keeps dark crests legible in dark theme, same
              // treatment as the league chips and favourites grid.
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: c.hairline, width: 1),
            ),
            child: Image(
              image: leagueLogoProviderForUrl(_leagueLogoUrl(leagueIdStr)),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.shield_outlined, size: 16, color: c.inkDim),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _leagueName(leagueIdStr, l, context),
                  style: EType.body(
                      color: c.ink,
                      size: 17,
                      weight: FontWeight.w700,
                      hebrew: isHe),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _statusChip(c, l, isHe, missing, closed),
                    if (cutoff != null) _deadline(context, c, l, isHe, cutoff),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(EditorialColors c, AppLocalizations l, bool isHe,
      int missing, bool closed) {
    // Green when done; amber while picks can still be made; grey once the
    // window has closed with picks missing — nothing left to act on.
    final String text;
    final Color fg;
    if (missing == 0) {
      text = l.picksComplete;
      fg = c.live;
    } else if (closed) {
      text = l.selectionClosed;
      fg = c.inkMute;
    } else {
      text = l.picksMissing('$missing');
      fg = c.amber;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: EType.body(
            color: fg, size: 11, weight: FontWeight.w600, hebrew: isHe),
      ),
    );
  }

  // Countdown once the cutoff is within a week (red in the last 24h), plain
  // date before that.
  Widget _deadline(BuildContext context, EditorialColors c, AppLocalizations l,
      bool isHe, DateTime cutoff) {
    final left = cutoff.difference(DateTime.now());
    final String text;
    final Color color;
    if (left.inHours < 1) {
      text = l.picksClosesInMinutes(max(1, left.inMinutes));
      color = c.flag;
    } else if (left.inHours < 24) {
      text = l.picksClosesInHours(left.inHours);
      color = c.flag;
    } else if (left.inDays <= 7) {
      text = l.picksClosesInDays(left.inDays);
      color = c.amber;
    } else {
      final locale = Localizations.localeOf(context).toString();
      text = '${l.picksDeadline}: ${DateFormat.MMMMd(locale).format(cutoff)}';
      color = c.inkDim;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.schedule, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: EType.body(
              color: color,
              size: 11,
              weight: color == c.inkDim ? FontWeight.w400 : FontWeight.w600,
              hebrew: isHe),
        ),
      ],
    );
  }
}

// ── Shared per-league pick row with availability-aware picker ───────────────
enum _PickKind { winner, topScorer }

class _SeasonPickRow extends StatefulWidget {
  const _SeasonPickRow({
    required this.leagueIdStr,
    required this.pick,
    required this.icon,
    required this.label,
    required this.clientId,
    required this.email,
    required this.isOpen,
    required this.waiting,
    required this.onChanged,
    required this.mode,
  });

  final String leagueIdStr;
  final String? pick;
  final IconData icon;
  final String label;
  final String clientId;
  final String email;
  // Resolved once by the parent card — the window is a per-league fact.
  final bool isOpen;
  final bool waiting;
  final VoidCallback onChanged;
  final _PickKind mode;

  @override
  State<_SeasonPickRow> createState() => _SeasonPickRowState();
}

class _SeasonPickRowState extends State<_SeasonPickRow> {
  // Crest next to the pick. Memoised so rebuilds don't re-trigger the fetch or
  // flicker the FutureBuilder. Re-resolved when the pick changes.
  Future<String?>? _logo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _logo ??= _resolveLogo();
  }

  @override
  void didUpdateWidget(_SeasonPickRow old) {
    super.didUpdateWidget(old);
    if (old.pick != widget.pick) _logo = _resolveLogo();
  }

  Future<String?> _resolveLogo() async {
    final pick = widget.pick;
    final id = int.tryParse(widget.leagueIdStr);
    if (id == null || pick == null || pick.isEmpty) return null;
    // Same resolvers the statistics screen uses, so crests come from one source.
    return widget.mode == _PickKind.winner
        ? resolveWinnerLogo(id, pick)
        : resolveTopScorerLogo(id, pick);
  }

  Future<void> _openPicker() async {
    final id = int.tryParse(widget.leagueIdStr);
    if (id == null) return;
    final l = AppLocalizations.of(context)!;
    final leagueName = _leagueName(widget.leagueIdStr, l, context);
    final result = widget.mode == _PickKind.winner
        ? await openWinnerPicker(
            context,
            clientId: widget.clientId,
            email: widget.email,
            leagueId: id,
            leagueName: leagueName,
            currentPick: widget.pick,
          )
        : await openTopScorerPicker(
            context,
            clientId: widget.clientId,
            email: widget.email,
            leagueId: id,
            leagueName: leagueName,
            currentPick: widget.pick,
          );
    if (result != null) widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final l = AppLocalizations.of(context)!;
    final isHe = _isHe(context);
    final hasPick = widget.pick != null && widget.pick!.isNotEmpty;
    // An actionable row — open window, nothing picked — is tinted so the work
    // still outstanding is visible at a glance down the list.
    final needsAction = !hasPick && widget.isOpen;

    final Widget value;
    if (hasPick) {
      final name = widget.mode == _PickKind.winner
          ? localizedTeamName(context, widget.pick!)
          : localizedPlayerName(context, widget.pick!);
      value = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PickCrest(
            future: _logo,
            fallback: widget.mode == _PickKind.winner
                ? Icons.emoji_events_outlined
                : Icons.sports_soccer_outlined,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              name,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: EType.body(
                  color: c.ink,
                  size: 13,
                  weight: FontWeight.w700,
                  hebrew: isHe),
            ),
          ),
          if (widget.isOpen) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_left, size: 18, color: c.inkDim),
          ],
        ],
      );
    } else if (needsAction) {
      value = _ChooseButton(label: l.pickChoose);
    } else if (widget.waiting) {
      // Quiet placeholder while the availability probe is in-flight.
      value = SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          valueColor: AlwaysStoppedAnimation(c.inkDim),
        ),
      );
    } else {
      value = const ClosedPickChip();
    }

    return Material(
      color: needsAction ? c.liveSoft : Colors.transparent,
      child: InkWell(
        onTap: widget.isOpen ? _openPicker : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(widget.icon, size: 17, color: hasPick ? c.live : c.inkDim),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: EType.body(
                    color: hasPick ? c.ink : c.inkMute, size: 12, hebrew: isHe),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: value,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Solid green call-to-action shown in place of an unmade pick.
class _ChooseButton extends StatelessWidget {
  const _ChooseButton({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: c.live,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: EType.body(
                color: Colors.white,
                size: 13,
                weight: FontWeight.w700,
                hebrew: _isHe(context)),
          ),
          const SizedBox(width: 2),
          const Icon(Icons.chevron_left, size: 17, color: Colors.white),
        ],
      ),
    );
  }
}

// Crest next to a champion / top-scorer pick, styled identically to the
// statistics screen's crest (circular frame; a generic fallback icon while the
// logo resolves or when none is available).
class _PickCrest extends StatelessWidget {
  const _PickCrest({required this.future, required this.fallback});
  final Future<String?>? future;
  final IconData fallback;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return FutureBuilder<String?>(
      future: future,
      builder: (_, snap) {
        final url = snap.data;
        if (url == null || url.isEmpty) {
          return Icon(fallback, size: 16, color: c.inkMute);
        }
        return Container(
          width: 24,
          height: 24,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: c.cardHi,
            shape: BoxShape.circle,
            border: Border.all(color: c.hairline, width: 1),
          ),
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) =>
                Icon(fallback, size: 12, color: c.inkDim),
          ),
        );
      },
    );
  }
}

// ── Empty state card ────────────────────────────────────────────────────
class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final isHe = _isHe(context);
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
            child: Icon(icon, size: 26, color: c.inkDim),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: EType.body(
                color: c.ink, size: 20, weight: FontWeight.w700, hebrew: isHe),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: EType.body(
                color: c.inkMute, size: 13, height: 1.5, hebrew: isHe),
          ),
        ],
      ),
    );
  }
}
