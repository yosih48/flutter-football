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

  // ── Date window ──────────────────────────────────────────────────────
  late DateTime _earliestVisibleDate;
  bool _noMorePreviousGames = false;

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
    final now = DateTime.now();
    _earliestVisibleDate = DateTime(now.year, now.month, now.day);
    _bootstrap();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
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

    final lowerBound = _selectedDate ?? _earliestVisibleDate;
    final lb = DateTime(lowerBound.year, lowerBound.month, lowerBound.day);
    list = list.where((g) {
      final d = DateTime(g.date.year, g.date.month, g.date.day);
      return !d.isBefore(lb);
    });

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

  // ── Scroll-up: just expand the date window (no I/O) ──────────────────
  void _loadPreviousDay() {
    if (_noMorePreviousGames) return;

    DateTime? earliestInData;
    for (final g in _allGames) {
      final d = DateTime(g.date.year, g.date.month, g.date.day);
      if (earliestInData == null || d.isBefore(earliestInData)) {
        earliestInData = d;
      }
    }

    final newEarliest = _earliestVisibleDate.subtract(const Duration(days: 1));
    if (earliestInData != null && newEarliest.isBefore(earliestInData)) {
      setState(() => _noMorePreviousGames = true);
      return;
    }
    setState(() => _earliestVisibleDate = newEarliest);
  }

  void _jumpToToday() {
    final now = DateTime.now();
    setState(() {
      _earliestVisibleDate = DateTime(now.year, now.month, now.day);
      _noMorePreviousGames = false;
      _selectedDate = null;
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    }
  }

  bool get _isViewingPast {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _earliestVisibleDate.isBefore(today) ||
        (_selectedDate != null &&
            DateTime(_selectedDate!.year, _selectedDate!.month,
                    _selectedDate!.day)
                .isBefore(today));
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
            colorScheme: const ColorScheme.dark(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Color(0xFF303030),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF303030),
          ),
          child: child ?? Container(),
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _earliestVisibleDate = DateTime(picked.year, picked.month, picked.day);
        _noMorePreviousGames = false;
      });
    }
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
    final sortedDates = grouped.keys.toList()..sort();

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
      backgroundColor: background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: GestureDetector(
          onTap: _pickDate,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.calendar_today,
                    color: Colors.blue, size: 28),
                if (_selectedDate != null)
                  Positioned(
                    bottom: 4,
                    child: Text(
                      '${_selectedDate!.day}',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Text(
                  'Live',
                  style: TextStyle(
                    color: white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: _showOnlyLiveGames,
                    onChanged: (_) => _toggleShowOnlyLiveGames(),
                    activeColor: Colors.red,
                    activeTrackColor: Colors.red.withOpacity(0.5),
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: Colors.grey.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handlePullRefresh,
        color: Colors.blue,
        child: Column(
          children: [
            const SizedBox(height: 8),
            LeagueSelectorChips(
              options:
                  chipOptions.isEmpty ? placeholderOptions : chipOptions,
              selectedIndex: _selectedChipIndex,
              onSelectionChanged: _onChipChanged,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Stack(
                children: [
                  _buildGamesList(filteredGames, sortedDates, grouped),
                  if (_isViewingPast)
                    Positioned(
                      bottom: 16,
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _buttonLoading ? null : _submitAllGuesses,
        backgroundColor: _buttonLoading ? Colors.grey : Colors.blue,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.send),
        label: Text(
          AppLocalizations.of(context)!.send,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildJumpToTodayChip() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: _jumpToToday,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF2196F3),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context)!.backToToday,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.keyboard_arrow_down,
                  size: 20, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGamesList(List<Game> filteredGames, List<DateTime> sortedDates,
      Map<DateTime, List<Game>> groupedGames) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final effectiveGroupedGames = _isLoading
        ? {today: List.generate(3, (i) => _skeletonGame(today, i))}
        : groupedGames;
    final effectiveSortedDates = _isLoading ? [today] : sortedDates;

    if (!_isLoading && _allGames.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.scoreboard_outlined,
                size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.nogames,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (!_isLoading && groupedGames.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _showOnlyLiveGames
                  ? Icons.live_tv
                  : Icons.scoreboard_outlined,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _showOnlyLiveGames
                  ? AppLocalizations.of(context)!.nolivegames
                  : AppLocalizations.of(context)!.nogames,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Skeletonizer(
      enabled: _isLoading,
      child: NotificationListener<OverscrollNotification>(
        onNotification: (n) {
          if (n.overscroll < 0 && !_noMorePreviousGames) {
            _loadPreviousDay();
          }
          return false;
        },
        child: ListView.builder(
          controller: _scrollController,
          itemCount: effectiveSortedDates.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) return _buildTopIndicator();
            final date = effectiveSortedDates[index - 1];
            final gamesForDate = effectiveGroupedGames[date]!
              ..sort((a, b) => a.date.compareTo(b.date));
            return _buildDateSection(date, gamesForDate);
          },
        ),
      ),
    );
  }

  Widget _buildTopIndicator() {
    if (_noMorePreviousGames) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Center(
          child: Text(
            AppLocalizations.of(context)!.noOlderGames,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.blue.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.keyboard_arrow_up,
                  color: Colors.blue, size: 16),
              const SizedBox(width: 4),
              Text(
                AppLocalizations.of(context)!.pullUpForPreviousGames,
                style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          child: GameWidget(
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
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                Text(
                  formatDateInHebrew(date, context),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${gamesForDate.length} ${AppLocalizations.of(context)!.numberOfGames}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        ...widgets,
      ],
    );
  }

  Widget _buildLeagueHeader(int leagueId) {
    final leagueName = getLocalizedLeagueName(leagueId, context);
    final isFiltered = _selectedLeagueFilter == leagueId;
    return GestureDetector(
      onTap: () => _toggleLeagueHeaderFilter(leagueId),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        child: Row(
          children: [
            Text(
              leagueName,
              style: TextStyle(
                color: isFiltered ? Colors.blue : Colors.grey[300],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isFiltered)
              const Padding(
                padding: EdgeInsets.only(left: 6.0),
                child: Icon(Icons.close, size: 14, color: Colors.blue),
              ),
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
