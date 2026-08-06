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
    '1H',
    '2H',
    'HT',
    'ET',
    'BT',
    'P',
    'INT'
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
  // The league ids currently backing the chip rail. While bootstrapping,
  // `_enabledLeagues` is still empty and the rail shows placeholder chips
  // derived from the supported-league config (mirrors the build), so the tap
  // handler must resolve against the SAME list to avoid an empty-list index.
  List<int> _displayedLeagueIds() {
    if (_enabledLeagues.isNotEmpty) return _enabledLeagues;
    final ids = <int>[];
    for (final id in LeagueConfigService().supportedLeagues) {
      if (getLocalizedLeagueName(id, context).isNotEmpty) ids.add(id);
    }
    return ids;
  }

  void _onChipChanged(int chipIndex) {
    final ids = _displayedLeagueIds();
    if (chipIndex < 0 || chipIndex >= ids.length) return;
    setState(() {
      if (_selectedChipIndex == chipIndex) {
        _selectedChipIndex = -1;
        _selectedChipLeagueId = -1;
      } else {
        _selectedChipIndex = chipIndex;
        _selectedChipLeagueId = ids[chipIndex];
      }
    });
    Provider.of<UserProvider>(context, listen: false)
        .setselectedLeageId(_selectedChipLeagueId);
  }

  // Clears the league chip selection so every enabled league's games show.
  // No-op when nothing is selected (already showing all).
  void _selectAllLeagues() {
    if (_selectedChipIndex == -1 && _selectedChipLeagueId == -1) return;
    setState(() {
      _selectedChipIndex = -1;
      _selectedChipLeagueId = -1;
    });
    Provider.of<UserProvider>(context, listen: false).setselectedLeageId(-1);
  }

  // Small "All leagues" text at the top of the chip rail. Highlighted green
  // when no single league is selected (i.e. all games are showing); tapping it
  // cancels any chip selection.
  Widget _buildAllLeaguesToggle(BuildContext context, EditorialColors c) {
    final l = AppLocalizations.of(context)!;
    final isHe = Localizations.localeOf(context).languageCode == 'he';
    final active = _selectedChipIndex == -1;
    final fg = active ? c.live : c.inkMute;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _selectAllLeagues,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.layers_outlined, size: 15, color: fg),
              const SizedBox(width: 6),
              Text(
                l.allLeagues,
                style: EType.body(
                    color: fg, size: 12, weight: FontWeight.w600, hebrew: isHe),
              ),
            ],
          ),
        ),
      ),
    );
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

    return '$localizedDay, $dayNumber $localizedMonth';
  }

  String _getLocalizedString(AppLocalizations l, String key, String fallback) {
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
    final remote = LeagueConfigService()
        .nameFor(leagueId, Localizations.localeOf(context).languageCode);
    if (remote != null) return remote;
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
    // Ids and names are collected together, not filtered independently: a
    // league with no localized name is dropped from BOTH lists, so the chip
    // at index i always gets the crest for the league at index i.
    final placeholderIds = <int>[];
    final placeholderOptions = <String>[];
    for (final id in LeagueConfigService().supportedLeagues) {
      final name = getLocalizedLeagueName(id, context);
      if (name.isEmpty) continue;
      placeholderIds.add(id);
      placeholderOptions.add(name);
    }

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
                name: getLocalizedLeagueName(_enabledLeagues.first, context),
                imageUrl: LeagueDataProvider()
                    .getLeagueImageUrl(_enabledLeagues.first),
              )
            else ...[
              _buildAllLeaguesToggle(context, c),
              LeagueSelectorChips(
                options: chipOptions.isEmpty ? placeholderOptions : chipOptions,
                // Ids must line up with whichever option list is in use.
                leagueIds:
                    chipOptions.isEmpty ? placeholderIds : _enabledLeagues,
                selectedIndex: _selectedChipIndex,
                onSelectionChanged: _onChipChanged,
              ),
            ],
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

  PreferredSizeWidget _buildEditorialAppBar(
      BuildContext context, EditorialColors c) {
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
              style: EType.label(color: c.inkDim, size: 10, letterSpacing: 3)),
          const SizedBox(height: 2),
          Text(
            AppLocalizations.of(context)!.fixtures,
            style: EType.screenTitle(
              size: 26,
              color: c.ink,
              hebrew: Localizations.localeOf(context).languageCode == 'he',
            ),
          ),
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
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          // Matches the Material radius so the ripple stays inside the pill.
          borderRadius: BorderRadius.circular(14),
          onTap: disabled ? null : _submitAllGuesses,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
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
                      valueColor: AlwaysStoppedAnimation(c.inkDim),
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

  Widget _buildGamesList(
      Map<DateTime, List<Game>> groupedGames, EditorialColors c) {
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
        message: AppLocalizations.of(context)!.seasonWillSartSoon,
        c: c,
      );
    }
    if (groupedGames.isEmpty) {
      return _buildEmptyState(
        icon: _showOnlyLiveGames ? Icons.live_tv : Icons.scoreboard_outlined,
        message: _showOnlyLiveGames
            ? AppLocalizations.of(context)!.nolivegames
            : AppLocalizations.of(context)!.seasonWillSartSoon,
        c: c,
      );
    }

    final pastDates = groupedGames.keys.where((d) => d.isBefore(today)).toList()
      ..sort((a, b) => b.compareTo(a));
    final currentDates =
        groupedGames.keys.where((d) => !d.isBefore(today)).toList()..sort();

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

  Widget _buildEmptyState(
      {required IconData icon,
      required String message,
      required EditorialColors c}) {
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
            style: EType.label(color: c.inkMute, size: 12, letterSpacing: 2.4),
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
      if (showHeader) {
        widgets.add(_buildLeagueHeader(game.league.id));
      } else {
        // Back-to-back cards in the same league read as one block: no gap,
        // just a hairline rule between them.
        widgets.add(_cardDivider());
      }

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
        DateHeader(
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

  // Hairline between two adjacent game cards. Sits on the card surface and is
  // inset to the same horizontal margin the cards use, so it reads as a rule
  // inside one continuous block rather than a gap between two separate cards.
  Widget _cardDivider() {
    final c = context.col;
    return ColoredBox(
      color: c.card,
      child: Padding(
        // Inset to where the card content begins (3px accent stripe + 16px
        // padding) so the rule lines up with the text above and below it.
        padding: const EdgeInsetsDirectional.only(start: 19, end: 16),
        child: Container(height: 1, color: c.hairline),
      ),
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

// Shared geometry for the two app-bar buttons (calendar + live filter) so they
// stay the same height and corner radius as each other.
const double _kHeaderBtnHeight = 42;
const double _kHeaderBtnRadius = 12;

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
        borderRadius: BorderRadius.circular(_kHeaderBtnRadius),
        onTap: onTap,
        child: Container(
          width: _kHeaderBtnHeight,
          height: _kHeaderBtnHeight,
          decoration: BoxDecoration(
            color: c.card,
            border: Border.all(color: c.hairline, width: 1),
            borderRadius: BorderRadius.circular(_kHeaderBtnRadius),
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
        borderRadius: BorderRadius.circular(_kHeaderBtnRadius),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          // Fixed height (not vertical padding) so this lines up exactly with
          // the square icon button beside it.
          height: _kHeaderBtnHeight,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: active ? c.live : c.card,
            border: Border.all(
              color: active ? c.live : c.hairline,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(_kHeaderBtnRadius),
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

/// Date section header: dark day badge, day label, and the match count pinned
/// to the far end.
@visibleForTesting
class DateHeader extends StatelessWidget {
  const DateHeader({
    super.key,
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
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Dark rounded day badge — leads the row (rightmost in RTL).
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.ink,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Text(
              date.day.toString().padLeft(2, '0'),
              style: EType.numeric(
                color: c.card,
                size: 16,
                weight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Owns all the space between the badge and the count, so the count
          // is pinned to the far end (left in RTL) and a long day label
          // ellipsises instead of pushing it off-screen.
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    dayLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EType.body(
                      color: c.ink,
                      size: 14,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                if (isToday) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: c.live,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.todayLabel.toUpperCase(),
                      style: EType.label(
                          color: c.card, size: 9, letterSpacing: 1.2),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$gameCount $countWord',
            maxLines: 1,
            style: EType.body(color: c.inkDim, size: 12),
          ),
        ],
      ),
    );
  }
}
