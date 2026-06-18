import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:football/models/games.dart';
import 'package:football/models/guesses.dart';
import 'package:football/models/users.dart';
import 'package:football/providers/flutter%20pub%20add%20provider.dart';
import 'package:football/providers/league_data_provider.dart';
import 'package:football/resources/auth.dart';
import 'package:football/resources/gamesMethods.dart';
import 'package:football/resources/guessesMethods.dart';
import 'package:football/resources/league_config_service.dart';
import 'package:football/resources/usersMethods.dart';
import 'package:football/screens/bracket.dart';
import 'package:football/screens/gameDetails.dart';
import 'package:football/screens/login_screen.dart';
import 'package:football/screens/teamDetails.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:football/utils/config.dart';
import 'package:football/utils/utils.dart';
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
  final Key _centerKey = UniqueKey();
  final Map<DateTime, GlobalKey> _dateKeys = {};
  bool _isViewingPast = false;
  bool _isViewingFuture = false;

  // ── Loading / refresh ────────────────────────────────────────────────
  bool _isLoading = true;
  bool _buttonLoading = false;
  Timer? _refreshTimer;
  static const Duration _liveTickInterval = Duration(seconds: 30);

  final ScrollController _scrollController = ScrollController();

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
    // The CustomScrollView is anchored at today's section (center key), so
    // negative offset means we scrolled up into past games, and positive
    // offset means we scrolled down into future games. Show the "Back to
    // today" chip in both cases. The future threshold is larger so the chip
    // doesn't pop while today's own section is still partially visible.
    final past = _scrollController.offset < -50;
    final future = _scrollController.offset > 300;
    if (past != _isViewingPast || future != _isViewingFuture) {
      setState(() {
        _isViewingPast = past;
        _isViewingFuture = future;
      });
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

      // A league newly added to the remote config has no key in this user's
      // stored chosenLeagues. Default it to ON and persist that once so it's
      // effective everywhere without the user toggling it. An EXISTING key set
      // to false is an explicit opt-out and is left untouched — this only
      // backfills absent keys; the == true filter itself is unchanged.
      final missing = LeagueConfigService()
          .supportedLeagues
          .where((id) => !chosenLeagues.containsKey(id.toString()))
          .toList();
      for (final id in missing) {
        chosenLeagues[id.toString()] = true;
      }
      if (missing.isNotEmpty) {
        _persistDefaultLeagues(missing);
      }

      final enabled = LeagueConfigService()
          .supportedLeagues
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

  // Best-effort one-time backfill of newly-added leagues. Uses $set with dotted
  // keys so only these league flags are written — notification prefs and
  // displayName are untouched. Mirrors the proven PUT /users/ + $set pattern
  // used for group join. Failure is non-fatal: the in-memory map already has
  // the defaults for this session, and the next launch retries.
  Future<void> _persistDefaultLeagues(List<int> leagueIds) async {
    try {
      await http.put(
        Uri.parse('$backendUrl/users/'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          '_id': _clientId,
          '\$set': {
            for (final id in leagueIds) 'chosenLeagues.$id': true,
          },
        }),
      );
      LeagueDataProvider().clearCache();
    } catch (e) {
      print('❌ default-league backfill failed: $e');
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
      if (g.status.long == 'Not Started' && g.date.toLocal().isBefore(now)) {
        liveLeagueIds.add(g.league.id);
      }
    }
    if (liveLeagueIds.isEmpty) return;

    try {
      final results = await Future.wait(
        liveLeagueIds.map((id) => GamesMethods().fetchLiveGamesForLeague(id)),
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
        showSnackBar(
          context,
          AppLocalizations.of(context)!.refreshFailed,
          tone: SnackTone.error,
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
        final c = context.col;
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: c.live,
              onPrimary: c.pitch,
              surface: c.card,
              onSurface: c.ink,
            ),
            dialogBackgroundColor: c.card,
          ),
          child: child ?? Container(),
        );
      },
    );
    if (picked == null) return;
    final target = DateTime(picked.year, picked.month, picked.day);
    setState(() => _selectedDate = target);
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
      // Block guesses once the match is underway. Two independent guards
      // because neither alone is sufficient:
      //  • status != 'Not Started' — server-derived, so it survives a user
      //    spoofing their device clock; but it can lag a few minutes after
      //    kickoff (status only refreshes periodically).
      //  • clock past kickoff — catches that lag window, but trusts the
      //    device clock and so is bypassable on its own.
      // The backend re-checks against server time as the real enforcement.
      if (game.status.long != 'Not Started' ||
          DateTime.now().isAfter(game.date.toLocal())) {
        continue;
      }

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
      showSnackBar(
        context,
        AppLocalizations.of(context)!.noguessesfound,
        tone: SnackTone.warning,
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
      showSnackBar(
        context,
        AppLocalizations.of(context)!.savedsuccessfully,
        tone: SnackTone.success,
      );
      final refreshed = await GuessesMethods().fetchThisUserGuesses(_clientId);
      if (mounted) {
        setState(() {
          _guesses = refreshed;
          _hydrateControllers();
        });
      }
    } else {
      showSnackBar(
        context,
        AppLocalizations.of(context)!.failedToSubmitGuesses,
        tone: SnackTone.error,
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
      case 'monday': return l.monday;
      case 'tuesday': return l.tuesday;
      case 'wednesday': return l.wednesday;
      case 'thursday': return l.thursday;
      case 'friday': return l.friday;
      case 'saturday': return l.saturday;
      case 'sunday': return l.sunday;
      case 'january_short': return l.january_short;
      case 'february_short': return l.february_short;
      case 'march_short': return l.march_short;
      case 'april_short': return l.april_short;
      case 'may_short': return l.may_short;
      case 'june_short': return l.june_short;
      case 'july_short': return l.july_short;
      case 'august_short': return l.august_short;
      case 'september_short': return l.september_short;
      case 'october_short': return l.october_short;
      case 'november_short': return l.november_short;
      case 'december_short': return l.december_short;
      default: return fallback;
    }
  }

  String getLocalizedLeagueName(int leagueId, BuildContext context) {
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
      case 78:  return l.bundesleague;
      case 848: return l.conferenceleague;
      default:  return '';
    }
  }

  // First enabled league that offers the tournament bracket game, or null.
  // Driven entirely by the backend league config (hasBracket) — when the
  // backend stops serving the tournament (or flips hasBracket to false) the
  // app-bar entry disappears on its own, no app update required.
  int? get _bracketLeagueId {
    for (final id in _enabledLeagues) {
      if (LeagueConfigService().hasBracket(id)) return id;
    }
    return null;
  }

  void _openBracket(int leagueId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BracketScreen(
          leagueId: leagueId,
          userId: _clientId,
          email: _email,
          userName: widget.authProvider.currentUser?.name ?? '',
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final filteredGames = _filteredGames();
    final grouped = _groupByDate(filteredGames);

    final chipOptions = _enabledLeagues
        .map((id) => getLocalizedLeagueName(id, context))
        .toList();
    // While bootstrapping, _enabledLeagues is still empty. Derive the
    // placeholder chips from the (synchronously available) supported-league
    // config and localize them, so they don't flash in English before the
    // real Hebrew names arrive.
    final placeholderOptions = LeagueConfigService()
        .supportedLeagues
        .map((id) => getLocalizedLeagueName(id, context))
        .where((name) => name.isNotEmpty)
        .toList();

    return Scaffold(
      backgroundColor: c.pitch,
      appBar: _buildEditorialAppBar(context, c),
      body: RefreshIndicator(
        onRefresh: _handlePullRefresh,
        color: c.live,
        backgroundColor: c.card,
        child: Column(
          children: [
            const SizedBox(height: 8),
            // Single-league mode (e.g. World Cup with no regular season):
            // no chips to toggle — show a full-width headline instead.
            if (_enabledLeagues.length == 1)
              SingleLeagueHeadline(
                name: getLocalizedLeagueName(
                    _enabledLeagues.first, context),
                imageUrl: LeagueDataProvider()
                    .getLeagueImageUrl(_enabledLeagues.first),
              )
            else
              LeagueSelectorChips(
                options:
                    chipOptions.isEmpty ? placeholderOptions : chipOptions,
                selectedIndex: _selectedChipIndex,
                onSelectionChanged: _onChipChanged,
              ),
            // Bracket-prediction entry — sits right under the tournament
            // banner. Backend-gated via hasBracket, so it self-removes when
            // the tournament ends (no app update needed).
            if (_bracketLeagueId != null)
              _BracketEntryStrip(
                title: AppLocalizations.of(context)!.bracketTitle,
                subtitle: AppLocalizations.of(context)!.bracketEntrySubtitle,
                onTap: () => _openBracket(_bracketLeagueId!),
              ),
            const SizedBox(height: 12),
            Container(height: 1, color: c.hairline),
            Expanded(
              child: Stack(
                children: [
                  _buildGamesList(grouped, c),
                  if (_isViewingPast || _isViewingFuture)
                    Positioned(
                      bottom: 20,
                      left: 0,
                      right: 0,
                      child: Center(child: _buildJumpToTodayChip(c)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildSubmitFab(context, c),
    );
  }

  PreferredSizeWidget _buildEditorialAppBar(BuildContext context, EditorialColors c) {
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
          Text(AppLocalizations.of(context)!.matchday.toUpperCase(),
              style: EType.label(
                  color: c.inkDim, size: 10, letterSpacing: 3)),
          const SizedBox(height: 2),
          Text(AppLocalizations.of(context)!.fixtures.toUpperCase(),
              style: EType.display(
                  size: 28, color: c.ink, letterSpacing: 1.4)),
        ],
      ),
      actions: [
        _IconBtn(
          tooltip: AppLocalizations.of(context)!.pickDate,
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

  Widget _buildSubmitFab(BuildContext context, EditorialColors c) {
    final disabled = _buttonLoading;
    return Padding(
      padding: const EdgeInsets.only(right: 4, bottom: 4),
      child: Material(
        color: disabled ? c.cardHi : c.live,
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
                color: disabled ? c.hairline : c.live,
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
                          AlwaysStoppedAnimation(c.inkDim),
                    ),
                  )
                else
                  Icon(Icons.bolt, size: 18, color: c.pitch),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.send.toUpperCase(),
                  style: EType.label(
                    color: disabled ? c.inkDim : c.pitch,
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

  Widget _buildJumpToTodayChip(EditorialColors c) {
    return Material(
      color: c.ink,
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
              Icon(
                  _isViewingFuture
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 16,
                  color: c.pitch),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context)!.backToToday.toUpperCase(),
                style: EType.label(
                  color: c.pitch,
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

  Widget _buildGamesList(Map<DateTime, List<Game>> groupedGames, EditorialColors c) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_isLoading) {
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
        c: c,
      );
    }
    if (groupedGames.isEmpty) {
      return _buildEmptyState(
        icon: _showOnlyLiveGames ? Icons.live_tv : Icons.scoreboard_outlined,
        message: _showOnlyLiveGames
            ? AppLocalizations.of(context)!.nolivegames
            : AppLocalizations.of(context)!.nogames,
        c: c,
      );
    }

    final pastDates = groupedGames.keys.where((d) => d.isBefore(today)).toList()
      ..sort((a, b) => b.compareTo(a));
    final currentDates = groupedGames.keys
        .where((d) => !d.isBefore(today))
        .toList()
      ..sort();

    // When there are no upcoming/today games (e.g. all games are in the past),
    // the bidirectional CustomScrollView with a center key allows infinite
    // downward scrolling into empty space.
    //
    // Replicate the "other leagues" feel: in the bidirectional scroll, the most
    // recent past game sits just above the center point (top of viewport) and
    // you scroll UP to reach older games. We mirror this with reverse: true so
    // the newest game sits at the visual bottom (the natural anchor position)
    // and older games are accessible by scrolling up — same gesture as every
    // other league. pastDates is already sorted newest-first (index 0 = newest).
    if (currentDates.isEmpty) {
      return ListView.builder(
        controller: _scrollController,
        reverse: true,
        padding: const EdgeInsets.only(bottom: 80), // FAB clearance
        itemCount: pastDates.length,
        itemBuilder: (ctx, i) {
          final date = pastDates[i];
          return _buildKeyedDateSection(date, groupedGames[date]!);
        },
      );
    }

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

  Widget _buildEmptyState({required IconData icon, required String message, required EditorialColors c}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              border: Border.all(color: c.hairline, width: 1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 26, color: c.inkDim),
          ),
          const SizedBox(height: 18),
          Text(
            message.toUpperCase(),
            style: EType.label(
                color: c.inkMute, size: 12, letterSpacing: 2.4),
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
          onTeamTap: (team) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TeamDetailsScreen(
                  team: team,
                  league: game.league,
                  allLeagueGames: _allGames,
                  userId: _clientId,
                ),
              ),
            );
          },
          onTap: (ctx) async {
            await Navigator.push(
              ctx,
              MaterialPageRoute(
                builder: (_) => GameDetails(
                  gameOriginalId: game.fixtureId,
                  game: game,
                  games: gamesForDate,
                  initialIndex: gamesForDate.indexOf(game),
                  userId: _clientId,
                  allLeagueGames: _allGames,
                ),
              ),
            );
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
    final c = context.col;
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
                color: isFiltered ? c.live : c.inkDim,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              leagueName.toUpperCase(),
              style: EType.label(
                color: isFiltered ? c.live : c.inkMute,
                size: 11,
                letterSpacing: 2.2,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 1,
                color: isFiltered ? c.live.withOpacity(0.3) : c.hairline,
              ),
            ),
            if (isFiltered) ...[
              const SizedBox(width: 8),
              Icon(Icons.close, size: 12, color: c.live),
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
    final c = context.col;
    final btn = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(2),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            border: Border.all(color: c.hairline, width: 1),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 18, color: c.ink),
              if (badge != null)
                Positioned(
                  bottom: 4,
                  child: Text(
                    badge!,
                    style: EType.numeric(
                      color: c.live,
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

// Tappable CTA strip under the World Cup banner. A slow-pulsing accent dot
// flags it as the new, time-limited tournament feature. Backend-gated by the
// caller (hasBracket) so it disappears on its own when the tournament ends.
class _BracketEntryStrip extends StatefulWidget {
  const _BracketEntryStrip({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_BracketEntryStrip> createState() => _BracketEntryStripState();
}

class _BracketEntryStripState extends State<_BracketEntryStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(2),
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: c.liveSoft,
              borderRadius: BorderRadius.circular(2),
              border: Border.all(color: c.live, width: 1),
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(Icons.emoji_events, size: 22, color: c.live),
                    Positioned(
                      top: -2,
                      right: -2,
                      child: FadeTransition(
                        opacity: Tween(begin: 0.3, end: 1.0).animate(_pulse),
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: c.live,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.pitch, width: 1),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title.toUpperCase(),
                        style: EType.label(
                            color: c.ink, size: 12, letterSpacing: 1.4),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.subtitle,
                        style: EType.label(
                            color: c.inkDim, size: 9, letterSpacing: 0.8),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 20, color: c.live),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveToggle extends StatelessWidget {
  const _LiveToggle({required this.active, required this.onTap});
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(2),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: active ? c.live : Colors.transparent,
            border: Border.all(
              color: active ? c.live : c.hairline,
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
                  color: active ? c.pitch : c.flag,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context)!.liveLabel.toUpperCase(),
                style: EType.label(
                  color: active ? c.pitch : c.inkMute,
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
    final c = context.col;
    final today = DateTime.now();
    final isToday = today.year == date.year &&
        today.month == date.month &&
        today.day == date.day;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            date.day.toString().padLeft(2, '0'),
            style: EType.display(
              size: 56,
              color: c.ink,
              letterSpacing: 0,
              height: 0.85,
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 1,
            height: 44,
            color: c.hairline,
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
                          color: c.ink,
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
                          color: c.live,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(AppLocalizations.of(context)!.todayLabel.toUpperCase(),
                            style: EType.label(
                                color: c.pitch,
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
                    color: c.inkDim,
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
