import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:football/models/games.dart';
import 'package:football/models/guesses.dart';
import 'package:football/models/users.dart';
import 'package:football/providers/flutter%20pub%20add%20provider.dart';
import 'package:football/resources/auth.dart';
import 'package:football/resources/gamesMethods.dart';
import 'package:football/resources/guessesMethods.dart';
import 'package:football/resources/usersMethods.dart';
import 'package:football/screens/gameDetails.dart';
import 'package:football/screens/login_screen.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:football/utils/config.dart';
import 'package:football/widgets/LeagueSelectorChips.dart';
import 'package:football/widgets/gamesCard.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:skeletonizer/skeletonizer.dart';

class GamesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, UserProvider>(
      builder: (context, authProvider, userProvider, child) {
        if (authProvider.currentUser == null) {
          return LoginScreen();
        }
        return _GamesScreenContent(
          authProvider: authProvider,
          userProvider: userProvider,
        );
      },
    );
  }
}

class _GamesScreenContent extends StatefulWidget {
  final AuthProvider authProvider;
  final UserProvider userProvider;

  _GamesScreenContent({
    required this.authProvider,
    required this.userProvider,
  });

  @override
  _GamesScreenContentState createState() => _GamesScreenContentState();
}

class _GamesScreenContentState extends State<_GamesScreenContent>
    with WidgetsBindingObserver {
  // ── Identity ──────────────────────────────────────────────────────────
  late String _clientId;
  late String _email;

  // ── Data (in-memory source of truth) ──────────────────────────────────
  List<Game> _allGames = [];
  List<Guess> _guesses = [];
  List<int> _enabledLeagues = [];
  final Map<int, Map<String, TextEditingController>> _guessControllers = {};

  // ── UI filters ────────────────────────────────────────────────────────
  int _selectedChipIndex = -1;
  int _selectedChipLeagueId = -1;
  int? _selectedLeagueFilter;
  bool _showOnlyLiveGames = false;
  DateTime? _selectedDate;

  // ── Scroll anchoring ─────────────────────────────────────────────────
  // CustomScrollView center key: anchors "today + future" so prepended past
  // days extend into negative scroll offsets without ever visually jumping.
  final Key _centerKey = UniqueKey();
  final Map<DateTime, GlobalKey> _dateKeys = {};
  bool _isViewingPast = false;

  // ── Loading / refresh ────────────────────────────────────────────────
  bool _isLoading = true;
  bool _buttonLoading = false;
  Timer? _refreshTimer;
  static const Duration _liveTickInterval = Duration(seconds: 30);

  final ScrollController _scrollController = ScrollController();

  static const List<int> _supportedLeagues = [2, 383, 140, 3, 39, 78, 848];
  static const Set<String> _liveStatuses = {
    '1H', '2H', 'HT', 'ET', 'BT', 'P', 'INT'
  };

  // ── Lifecycle ────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clientId = widget.authProvider.currentUser?.id ?? '';
    _email = widget.authProvider.currentUser?.email ?? '';
    _selectedChipLeagueId = widget.userProvider.selectedLeageId ?? -1;
    _scrollController.addListener(_onScroll);
    _bootstrap();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final past = _scrollController.offset < -50;
    if (past != _isViewingPast) {
      setState(() => _isViewingPast = past);
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    for (final c in _guessControllers.values) {
      c['home']?.dispose();
      c['away']?.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startRefreshLoop();
      _tickRefresh();
    } else {
      _refreshTimer?.cancel();
      _refreshTimer = null;
    }
  }

  // ── Bootstrap: user + guesses + leagues, all parallel ────────────────
  Future<void> _bootstrap() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        UsersMethods().fetchUserById(_clientId),
        GuessesMethods().fetchThisUserGuesses(_clientId),
      ]);
      final userData = results[0] as Map<String, dynamic>;
      final guesses = results[1] as List<Guess>;

      final chosenLeagues =
          Map<String, bool>.from(userData['chosenLeagues'] ?? {});
      final enabled = _supportedLeagues
          .where((id) => chosenLeagues[id.toString()] == true)
          .toList();

      final games = await _fetchLeaguesParallel(enabled);

      if (!mounted) return;
      setState(() {
        _enabledLeagues = enabled;
        _guesses = guesses;
        _allGames = games;
        if (_selectedChipLeagueId != -1 &&
            enabled.contains(_selectedChipLeagueId)) {
          _selectedChipIndex = enabled.indexOf(_selectedChipLeagueId);
        } else {
          _selectedChipIndex = -1;
          _selectedChipLeagueId = -1;
        }
        _hydrateControllers();
        _isLoading = false;
      });

      _startRefreshLoop();
    } catch (e) {
      print('❌ bootstrap failed: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<Game>> _fetchLeaguesParallel(List<int> leagues,
      {bool forceRefresh = false}) async {
    if (leagues.isEmpty) return [];
    final results = await Future.wait(leagues.map((id) {
      return forceRefresh
          ? GamesMethods().forceRefreshGames(id)
          : GamesMethods().fetchGamesForLeague(id);
    }));
    final all = <Game>[];
    for (final r in results) all.addAll(r);
    all.sort((a, b) => a.date.compareTo(b.date));
    return all;
  }

  void _hydrateControllers() {
    for (final game in _allGames) {
      _guessControllers.putIfAbsent(
        game.fixtureId,
        () => {
          'home': TextEditingController(),
          'away': TextEditingController(),
        },
      );
    }
    for (final g in _guesses) {
      final c = _guessControllers[g.gameOriginalId];
      if (c != null) {
        c['home']!.text = g.homeTeamGoals.toString();
        c['away']!.text = g.awayTeamGoals.toString();
      }
    }
  }

  // ── Auto-refresh loop ────────────────────────────────────────────────
  static bool _isLive(Game g) => _liveStatuses.contains(g.status.short);

  void _startRefreshLoop() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_liveTickInterval, (_) => _tickRefresh());
  }

  Future<void> _tickRefresh() async {
    if (!mounted || _allGames.isEmpty) return;
    final now = DateTime.now();
    final liveLeagueIds = <int>{};
    for (final g in _allGames) {
      if (_isLive(g)) {
        liveLeagueIds.add(g.league.id);
        continue;
      }
      // Game's kickoff has passed but status hasn't updated — refresh.
      if (g.status.long == 'Not Started' && g.date.toLocal().isBefore(now)) {
        liveLeagueIds.add(g.league.id);
      }
    }
    if (liveLeagueIds.isEmpty) return;

    try {
      final results = await Future.wait(
        liveLeagueIds.map((id) => GamesMethods().forceRefreshGames(id)),
      );
      final byId = {for (final g in _allGames) g.fixtureId: g};
      for (final list in results) {
        for (final g in list) byId[g.fixtureId] = g;
      }
      if (!mounted) return;
      setState(() {
        _allGames = byId.values.toList()
          ..sort((a, b) => a.date.compareTo(b.date));
      });
    } catch (e) {
      print('❌ tickRefresh failed: $e');
    }
  }

  Future<void> _handlePullRefresh() async {
    try {
      final games =
          await _fetchLeaguesParallel(_enabledLeagues, forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _allGames = games;
        _hydrateControllers();
      });
    } catch (e) {
      print('❌ pull refresh failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refresh failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Filtering (in-memory only) ───────────────────────────────────────
  List<Game> _filteredGames() {
    Iterable<Game> list = _allGames;

    final activeLeague = _selectedLeagueFilter ??
        (_selectedChipLeagueId != -1 ? _selectedChipLeagueId : null);
    if (activeLeague != null) {
      list = list.where((g) => g.league.id == activeLeague);
    }

    if (_showOnlyLiveGames) {
      const userLive = {'1H', '2H', 'HT'};
      list = list.where((g) => userLive.contains(g.status.short));
    }

    return list.toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  Map<DateTime, List<Game>> _groupByDate(List<Game> games) {
    final m = <DateTime, List<Game>>{};
    for (final g in games) {
      final d = DateTime(g.date.year, g.date.month, g.date.day);
      m.putIfAbsent(d, () => []).add(g);
    }
    return m;
  }

  // Animate to today (offset 0 == start of the center sliver).
  void _jumpToToday() {
    setState(() => _selectedDate = null);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    }
  }

  // ── Chips / filters ──────────────────────────────────────────────────
  void _onChipChanged(int chipIndex) {
    setState(() {
      if (_selectedChipIndex == chipIndex) {
        _selectedChipIndex = -1;
        _selectedChipLeagueId = -1;
      } else {
        _selectedChipIndex = chipIndex;
        _selectedChipLeagueId = _enabledLeagues[chipIndex];
      }
    });
    Provider.of<UserProvider>(context, listen: false)
        .setselectedLeageId(_selectedChipLeagueId);
  }

  void _toggleLeagueHeaderFilter(int leagueId) {
    setState(() {
      _selectedLeagueFilter =
          _selectedLeagueFilter == leagueId ? null : leagueId;
    });
  }

  void _toggleShowOnlyLiveGames() {
    setState(() => _showOnlyLiveGames = !_showOnlyLiveGames);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(DateTime.now().year + 1),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: Editorial.live,
              onPrimary: Editorial.pitch,
              surface: Editorial.card,
              onSurface: Editorial.ink,
            ),
            dialogBackgroundColor: Editorial.card,
          ),
          child: child ?? Container(),
        );
      },
    );
    if (picked == null) return;
    final target = DateTime(picked.year, picked.month, picked.day);
    setState(() => _selectedDate = target);
    // Wait one frame so the date section is laid out before we scroll to it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _dateKeys[target]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Submit guesses ───────────────────────────────────────────────────
  Future<void> _submitAllGuesses() async {
    if (_buttonLoading) return;
    setState(() => _buttonLoading = true);

    final newGuesses = <Map<String, dynamic>>[];
    final updatedGuesses = <Map<String, dynamic>>[];

    for (final game in _allGames) {
      final controllers = _guessControllers[game.fixtureId];
      if (controllers == null) continue;
      final home = controllers['home']?.text;
      final away = controllers['away']?.text;
      if (home == null || away == null || home.isEmpty || away.isEmpty) {
        continue;
      }
      if (DateTime.now().isAfter(game.date.toLocal())) continue;

      Guess? existing;
      try {
        existing =
            _guesses.firstWhere((g) => g.gameOriginalId == game.fixtureId);
      } catch (_) {
        existing = null;
      }

      final data = <String, dynamic>{
        'userID': _clientId,
        'gameID': game.fixtureId,
        'gameOriginalID': game.fixtureId,
        'expectedPoints': 0,
        'home_team_goals': home,
        'away_team_goals': away,
        'leagueID': game.league.id,
      };

      if (existing != null && game.status.long == 'Not Started') {
        updatedGuesses.add(data);
      } else if (existing == null) {
        data['email'] = _email;
        data['sum_points'] = 0;
        newGuesses.add(data);
      }
    }

    if (newGuesses.isEmpty && updatedGuesses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.noguessesfound)),
      );
      setState(() => _buttonLoading = false);
      return;
    }

    final newUrl = Uri.parse('$backendUrl/guesses/add');
    final updateUrl = Uri.parse('$backendUrl/guesses/');
    bool ok = true;

    for (final g in newGuesses) {
      final r = await http.post(newUrl,
          headers: {'Content-Type': 'application/json'}, body: jsonEncode(g));
      if (r.statusCode != 200) ok = false;
    }
    for (final g in updatedGuesses) {
      final r = await http.put(updateUrl,
          headers: {'Content-Type': 'application/json'}, body: jsonEncode(g));
      if (r.statusCode != 200) ok = false;
    }

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(AppLocalizations.of(context)!.savedsuccessfully)),
      );
      final refreshed = await GuessesMethods().fetchThisUserGuesses(_clientId);
      if (mounted) {
        setState(() {
          _guesses = refreshed;
          _hydrateControllers();
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to submit or update some guesses')),
      );
    }
    if (mounted) setState(() => _buttonLoading = false);
  }

  // ── Localization helpers ─────────────────────────────────────────────
  String formatDateInHebrew(DateTime date, BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    const dayKeys = {
      'Monday': 'monday',
      'Tuesday': 'tuesday',
      'Wednesday': 'wednesday',
      'Thursday': 'thursday',
      'Friday': 'friday',
      'Saturday': 'saturday',
      'Sunday': 'sunday',
    };
    const monthKeys = {
      'Jan': 'january_short',
      'Feb': 'february_short',
      'Mar': 'march_short',
      'Apr': 'april_short',
      'May': 'may_short',
      'Jun': 'june_short',
      'Jul': 'july_short',
      'Aug': 'august_short',
      'Sep': 'september_short',
      'Oct': 'october_short',
      'Nov': 'november_short',
      'Dec': 'december_short',
    };

    final dayName = DateFormat('EEEE').format(date);
    final monthName = DateFormat('MMM').format(date);
    final dayNumber = date.day;

    final dayKey = dayKeys[dayName] ?? 'monday';
    final monthKey = monthKeys[monthName] ?? 'january_short';

    final localizedDay = _getLocalizedString(localizations, dayKey, dayName);
    final localizedMonth =
        _getLocalizedString(localizations, monthKey, monthName);

    return '$localizedDay,  $dayNumber $localizedMonth';
  }

  String _getLocalizedString(
      AppLocalizations l, String key, String fallback) {
    switch (key) {
      case 'monday':
        return l.monday;
      case 'tuesday':
        return l.tuesday;
      case 'wednesday':
        return l.wednesday;
      case 'thursday':
        return l.thursday;
      case 'friday':
        return l.friday;
      case 'saturday':
        return l.saturday;
      case 'sunday':
        return l.sunday;
      case 'january_short':
        return l.january_short;
      case 'february_short':
        return l.february_short;
      case 'march_short':
        return l.march_short;
      case 'april_short':
        return l.april_short;
      case 'may_short':
        return l.may_short;
      case 'june_short':
        return l.june_short;
      case 'july_short':
        return l.july_short;
      case 'august_short':
        return l.august_short;
      case 'september_short':
        return l.september_short;
      case 'october_short':
        return l.october_short;
      case 'november_short':
        return l.november_short;
      case 'december_short':
        return l.december_short;
      default:
        return fallback;
    }
  }

  String getLocalizedLeagueName(int leagueId, BuildContext context) {
    final l = AppLocalizations.of(context)!;
    switch (leagueId) {
      case 2:
        return l.championsleague;
      case 383:
        return l.ligathaal;
      case 140:
        return l.laliga;
      case 3:
        return l.europaleague;
      case 39:
        return l.premierleague;
      case 78:
        return l.bundesleague;
      case 848:
        return l.conferenceleague;
      default:
        return '';
    }
  }

  // ── Build ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final filteredGames = _filteredGames();
    final grouped = _groupByDate(filteredGames);

    final chipOptions = _enabledLeagues
        .map((id) => getLocalizedLeagueName(id, context))
        .toList();
    final placeholderOptions = const [
      'Champions League',
      'Premier League',
      'La Liga',
      'Bundesliga'
    ];

    return Scaffold(
      backgroundColor: Editorial.pitch,
      extendBodyBehindAppBar: true,
      appBar: _buildEditorialAppBar(context),
      body: RefreshIndicator(
        onRefresh: _handlePullRefresh,
        color: Editorial.live,
        backgroundColor: Editorial.card,
        child: Column(
          children: [
            const SizedBox(height: 8),
            LeagueSelectorChips(
              options:
                  chipOptions.isEmpty ? placeholderOptions : chipOptions,
              selectedIndex: _selectedChipIndex,
              onSelectionChanged: _onChipChanged,
            ),
            const SizedBox(height: 12),
            Container(height: 1, color: Editorial.hairline),
            Expanded(
              child: Stack(
                children: [
                  _buildGamesList(grouped),
                  if (_isViewingPast)
                    Positioned(
                      bottom: 20,
                      left: 0,
                      right: 0,
                      child: Center(child: _buildJumpToTodayChip()),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildSubmitFab(context),
    );
  }

  PreferredSizeWidget _buildEditorialAppBar(BuildContext context) {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Editorial.pitch,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 72,
      titleSpacing: 20,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('MATCHDAY',
              style: EType.label(
                  color: Editorial.inkDim, size: 10, letterSpacing: 3)),
          const SizedBox(height: 2),
          Text('FIXTURES',
              style: EType.display(
                  size: 28, color: Editorial.ink, letterSpacing: 1.4)),
        ],
      ),
      actions: [
        _IconBtn(
          tooltip: 'Pick date',
          icon: Icons.calendar_today_outlined,
          badge: _selectedDate?.day.toString(),
          onTap: _pickDate,
        ),
        const SizedBox(width: 4),
        _LiveToggle(
          active: _showOnlyLiveGames,
          onTap: _toggleShowOnlyLiveGames,
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildSubmitFab(BuildContext context) {
    final disabled = _buttonLoading;
    return Padding(
      padding: const EdgeInsets.only(right: 4, bottom: 4),
      child: Material(
        color: disabled ? Editorial.cardHi : Editorial.live,
        borderRadius: BorderRadius.circular(2),
        child: InkWell(
          borderRadius: BorderRadius.circular(2),
          onTap: disabled ? null : _submitAllGuesses,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              border: Border.all(
                color: disabled ? Editorial.hairline : Editorial.live,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (disabled)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor:
                          AlwaysStoppedAnimation(Editorial.inkDim),
                    ),
                  )
                else
                  Icon(Icons.bolt, size: 18, color: Editorial.pitch),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.send.toUpperCase(),
                  style: EType.label(
                    color: disabled ? Editorial.inkDim : Editorial.pitch,
                    size: 12,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJumpToTodayChip() {
    return Material(
      color: Editorial.ink,
      borderRadius: BorderRadius.circular(2),
      child: InkWell(
        borderRadius: BorderRadius.circular(2),
        onTap: _jumpToToday,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.keyboard_arrow_down,
                  size: 16, color: Editorial.pitch),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context)!.backToToday.toUpperCase(),
                style: EType.label(
                  color: Editorial.pitch,
                  size: 11,
                  letterSpacing: 1.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGamesList(Map<DateTime, List<Game>> groupedGames) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_isLoading) {
      // Simple skeleton list — no anchoring needed during initial load.
      return Skeletonizer(
        enabled: true,
        child: ListView(
          children: [
            _buildDateSection(
              today,
              List.generate(3, (i) => _skeletonGame(today, i)),
            ),
          ],
        ),
      );
    }

    if (_allGames.isEmpty) {
      return _buildEmptyState(
        icon: Icons.scoreboard_outlined,
        message: AppLocalizations.of(context)!.nogames,
      );
    }
    if (groupedGames.isEmpty) {
      return _buildEmptyState(
        icon:
            _showOnlyLiveGames ? Icons.live_tv : Icons.scoreboard_outlined,
        message: _showOnlyLiveGames
            ? AppLocalizations.of(context)!.nolivegames
            : AppLocalizations.of(context)!.nogames,
      );
    }

    final pastDates = groupedGames.keys.where((d) => d.isBefore(today)).toList()
      ..sort((a, b) => b.compareTo(a)); // newest past day closest to center
    final currentDates = groupedGames.keys
        .where((d) => !d.isBefore(today))
        .toList()
      ..sort();

    return CustomScrollView(
      controller: _scrollController,
      center: _centerKey,
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) {
              final date = pastDates[i];
              return _buildKeyedDateSection(date, groupedGames[date]!);
            },
            childCount: pastDates.length,
          ),
        ),
        SliverList(
          key: _centerKey,
          delegate: SliverChildBuilderDelegate(
            (ctx, i) {
              final date = currentDates[i];
              return _buildKeyedDateSection(date, groupedGames[date]!);
            },
            childCount: currentDates.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildKeyedDateSection(DateTime date, List<Game> games) {
    games.sort((a, b) => a.date.compareTo(b.date));
    final key = _dateKeys.putIfAbsent(date, () => GlobalKey());
    return KeyedSubtree(key: key, child: _buildDateSection(date, games));
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              border: Border.all(color: Editorial.hairline, width: 1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 26, color: Editorial.inkDim),
          ),
          const SizedBox(height: 18),
          Text(
            message.toUpperCase(),
            style: EType.label(
                color: Editorial.inkMute, size: 12, letterSpacing: 2.4),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSection(DateTime date, List<Game> gamesForDate) {
    final widgets = <Widget>[];
    for (int i = 0; i < gamesForDate.length; i++) {
      final game = gamesForDate[i];
      final showHeader =
          i == 0 || gamesForDate[i - 1].league.id != game.league.id;
      if (showHeader) widgets.add(_buildLeagueHeader(game.league.id));

      _guessControllers.putIfAbsent(
        game.fixtureId,
        () => {
          'home': TextEditingController(),
          'away': TextEditingController(),
        },
      );
      final guess = _guesses
          .where((g) => g.gameOriginalId == game.fixtureId)
          .cast<Guess?>()
          .firstWhere((_) => true, orElse: () => null);

      widgets.add(
        GameWidget(
          game: game,
          guess: guess,
          homeController: _guessControllers[game.fixtureId]?['home'],
          awayController: _guessControllers[game.fixtureId]?['away'],
          onTap: (ctx) async {
            if (game.status.long != 'Not Started') {
              await Navigator.push(
                ctx,
                MaterialPageRoute(
                  builder: (_) => GameDetails(
                    gameOriginalId: game.fixtureId,
                    game: game,
                    games: gamesForDate,
                    initialIndex: gamesForDate.indexOf(game),
                    userId: _clientId,
                  ),
                ),
              );
            }
          },
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DateHeader(
          date: date,
          dayLabel: formatDateInHebrew(date, context),
          gameCount: gamesForDate.length,
          countWord: AppLocalizations.of(context)!.numberOfGames,
        ),
        ...widgets,
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildLeagueHeader(int leagueId) {
    final leagueName = getLocalizedLeagueName(leagueId, context);
    final isFiltered = _selectedLeagueFilter == leagueId;
    return GestureDetector(
      onTap: () => _toggleLeagueHeaderFilter(leagueId),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: isFiltered ? Editorial.live : Editorial.inkDim,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              leagueName.toUpperCase(),
              style: EType.label(
                color: isFiltered ? Editorial.live : Editorial.inkMute,
                size: 11,
                letterSpacing: 2.2,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 1,
                color: isFiltered ? Editorial.live.withOpacity(0.3) : Editorial.hairline,
              ),
            ),
            if (isFiltered) ...[
              const SizedBox(width: 8),
              Icon(Icons.close, size: 12, color: Editorial.live),
            ],
          ],
        ),
      ),
    );
  }

  Game _skeletonGame(DateTime today, int index) {
    return Game(
      fixtureId: index,
      timezone: 'UTC',
      date: today,
      timestamp: today.millisecondsSinceEpoch,
      periods: {'first': null, 'second': null},
      venue: Venue(id: 0, name: 'Venue', city: 'City'),
      status: Status(long: 'Not Started', short: 'NS', elapsed: null),
      league: League(
        id: 2,
        name: 'Champions League',
        country: 'World',
        season: 2024,
        round: 'Group Stage',
        logo: 'https://media.api-sports.io/football/leagues/2.png',
      ),
      home: Team(
        id: 1,
        name: 'Home Team',
        logo: 'https://media.api-sports.io/football/teams/1.png',
      ),
      away: Team(
        id: 2,
        name: 'Away Team',
        logo: 'https://media.api-sports.io/football/teams/2.png',
      ),
      goals: Goals(home: null, away: null),
      score: Score(
        halftime: {'home': null, 'away': null},
        fulltime: {'home': null, 'away': null},
        extratime: {'home': null, 'away': null},
        penalty: {'home': null, 'away': null},
      ),
      odds: Odds(home: 1.0, draw: 1.0, away: 1.0),
    );
  }
}

// ── Editorial chrome widgets ─────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.badge,
  });
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(2),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            border: Border.all(color: Editorial.hairline, width: 1),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 18, color: Editorial.ink),
              if (badge != null)
                Positioned(
                  bottom: 4,
                  child: Text(
                    badge!,
                    style: EType.numeric(
                      color: Editorial.live,
                      size: 9,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: btn) : btn;
  }
}

class _LiveToggle extends StatelessWidget {
  const _LiveToggle({required this.active, required this.onTap});
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(2),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: active ? Editorial.live : Colors.transparent,
            border: Border.all(
              color: active ? Editorial.live : Editorial.hairline,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? Editorial.pitch : Editorial.flag,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'LIVE',
                style: EType.label(
                  color: active ? Editorial.pitch : Editorial.inkMute,
                  size: 11,
                  letterSpacing: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({
    required this.date,
    required this.dayLabel,
    required this.gameCount,
    required this.countWord,
  });
  final DateTime date;
  final String dayLabel;
  final int gameCount;
  final String countWord;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final isToday = today.year == date.year &&
        today.month == date.month &&
        today.day == date.day;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Big editorial day-number.
          Text(
            date.day.toString().padLeft(2, '0'),
            style: EType.display(
              size: 56,
              color: Editorial.ink,
              letterSpacing: 0,
              height: 0.85,
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 1,
            height: 44,
            color: Editorial.hairline,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        dayLabel.toUpperCase(),
                        style: EType.display(
                          size: 18,
                          color: Editorial.ink,
                          letterSpacing: 1,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Editorial.live,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text('TODAY',
                            style: EType.label(
                                color: Editorial.pitch,
                                size: 9,
                                letterSpacing: 1.4)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$gameCount  $countWord'.toUpperCase(),
                  style: EType.label(
                    color: Editorial.inkDim,
                    size: 10,
                    letterSpacing: 1.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
