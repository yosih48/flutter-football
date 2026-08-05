import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:football/models/games.dart';
import 'package:football/models/guesses.dart';
import 'package:football/providers/flutter%20pub%20add%20provider.dart';
import 'package:football/resources/FixtureEventsService.dart';
import 'package:football/resources/auth.dart';
import 'package:football/resources/guessesMethods.dart';
import 'package:football/resources/usersMethods.dart';
import 'package:football/screens/login_screen.dart';
import 'package:football/screens/profile.dart';
import 'package:football/screens/statistics.dart';
import 'package:football/screens/table.dart';
import 'package:football/screens/teamDetails.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:football/utils/localized_team_name.dart';
import 'package:football/utils/status_utils.dart';
import 'package:football/widgets/FixtureEventsWidget.dart';
// H2H tab is built but hidden for now — re-enable once FixtureCache has more
// historical meetings to show. See HeadToHeadWidget + the commented tab below.
// import 'package:football/widgets/HeadToHeadWidget.dart';
import 'package:football/widgets/SharedPreferences.dart';
import 'package:football/widgets/LineupsWidget.dart';
import 'package:football/widgets/StatsWidget.dart';
import 'package:football/widgets/MatchFormSection.dart';
import 'package:football/widgets/StandingsTableWidget.dart';
import 'package:football/widgets/teamLinks.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:provider/provider.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class GameDetails extends StatefulWidget {
  final gameOriginalId;
  final userId;
  final Game game;
  final List<Game> games;
  final int initialIndex;
  final List<Game>? allLeagueGames;

  const GameDetails({
    super.key,
    required this.gameOriginalId,
    required this.game,
    required this.games,
    required this.initialIndex,
    this.userId,
    this.allLeagueGames,
  });

  @override
  State<GameDetails> createState() => _GameDetailsState();
}

class _GameDetailsState extends State<GameDetails> {
  List<Guess> _guesses = [];
  List<Map<String, dynamic>> _users = [];
  late String currentUserId;
  late int league;
  List<GuessWithNames> _guessesWithNames = [];
  // Global (all-users) guesses for the current game, used by the distribution
  // bar. Independent of the selected group; shown for all game states.
  List<Guess>? _allGuesses;
  bool _distLoading = true;
  late String selectedGroupName = "";
  Map<String, String> _userGroups = {};
  bool isLoading = true;
  bool _groupsLoading = true;
  int?
      _selectedTab; // 0=Timeline, 1=Lineups, 2=Table, 3=Stats. null = collapsed (default).
  late int _currentIndex;
  late Game _currentGame;
  late int currentGameId;

  static const Set<String> _liveShort = {
    '1H',
    '2H',
    'H1',
    'H2',
    'ET',
    'BT',
    'P',
    'INT'
  };

  String _guessesCacheKey(int gameId, String group) => '$gameId|$group';

  /// The guess distribution bar is admin-only.
  bool get _isAdmin =>
      Provider.of<AuthProvider>(context, listen: false).currentUser?.admin ==
      true;

  @override
  void initState() {
    super.initState();

    _currentIndex = widget.initialIndex;
    _currentGame = widget.games[_currentIndex];
    league = _currentGame.league.id;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    currentUserId = widget.userId;
    currentGameId = widget.gameOriginalId;

    // Seed the default-group cache from prefs once. Fires in parallel with
    // the first fetch; if it lands before the user picks a group, we use it
    // as the source of truth for the active group. Cheap (SharedPreferences
    // read, no network) so it never gates the UI.
    _ensureDefaultGroupLoaded();

    // Global guess distribution — group-independent, shown for all game states.
    _fetchDistribution(currentGameId);

    final hydratedGroups = _hydrateUserGroupsFromCache();
    // Kick off groups + guesses in parallel so we don't waterfall.
    _fetchUserGroups(background: hydratedGroups);
    // If we already know which group to show, also try to hydrate + revalidate
    // the predictions for this game synchronously.
    if (hydratedGroups && selectedGroupName.isNotEmpty) {
      _hydrateGuessesFromCache(currentGameId, selectedGroupName);
      _fetchGuesses(selectedGroupName,
          background: _guessesWithNames.isNotEmpty);
    }
  }

  Future<void> _ensureDefaultGroupLoaded() async {
    if (_GuessesCache.defaultGroupName != null) return;
    try {
      final saved = await SharedPreferencesUtil.getSelectedGroupName();
      _GuessesCache.defaultGroupName = saved ?? '';
      // If groups already arrived and the resolver would now pick a different
      // group than what we settled on, re-resolve and refetch.
      if (mounted && _userGroups.isNotEmpty) {
        final better = _resolveActiveGroup(_userGroups);
        if (better.isNotEmpty && better != selectedGroupName) {
          setState(() {
            selectedGroupName = better;
            isLoading = _GuessesCache
                    .guesses[_guessesCacheKey(currentGameId, better)] ==
                null;
            final cached =
                _GuessesCache.guesses[_guessesCacheKey(currentGameId, better)];
            if (cached != null) _guessesWithNames = cached;
          });
          _fetchGuesses(better, background: _guessesWithNames.isNotEmpty);
        }
      }
    } catch (e) {
      print('Failed to read default group from prefs: $e');
      _GuessesCache.defaultGroupName = '';
    }
  }

  /// Resolution order for which group's predictions to show:
  ///   1. User's persisted default (the "starred" group in TableScreen) —
  ///      if it's a group they're still a member of.
  ///   2. UserProvider.selectedGroupName (last active group this session),
  ///      again only if it's in their group map and not 'public'.
  ///   3. First group in their groupID map.
  ///   4. Empty (no groups → show join-group callout).
  String _resolveActiveGroup(Map<String, String> groups) {
    if (groups.isEmpty) return '';
    final values = groups.values.toSet();

    final def = _GuessesCache.defaultGroupName;
    if (def != null &&
        def.isNotEmpty &&
        def != 'public' &&
        values.contains(def)) {
      return def;
    }

    final fromProvider =
        Provider.of<UserProvider>(context, listen: false).selectedGroupName;
    if (fromProvider.isNotEmpty &&
        fromProvider != 'public' &&
        values.contains(fromProvider)) {
      return fromProvider;
    }

    return groups.values.first;
  }

  bool _hydrateUserGroupsFromCache() {
    final cached = _GuessesCache.userGroups[currentUserId];
    if (cached == null) return false;
    _userGroups = cached;
    _groupsLoading = false;
    selectedGroupName = _resolveActiveGroup(cached);
    return true;
  }

  bool _hydrateGuessesFromCache(int gameId, String group) {
    final cached = _GuessesCache.guesses[_guessesCacheKey(gameId, group)];
    if (cached == null) return false;
    _guessesWithNames = cached;
    isLoading = false;
    return true;
  }

  void _navigateToGame(int newIndex) {
    if (newIndex >= 0 && newIndex < widget.games.length) {
      final newGameId = widget.games[newIndex].fixtureId;
      final cached = selectedGroupName.isNotEmpty
          ? _GuessesCache
              .guesses[_guessesCacheKey(newGameId, selectedGroupName)]
          : null;
      setState(() {
        _currentIndex = newIndex;
        _currentGame = widget.games[newIndex];
        currentGameId = newGameId;
        if (cached != null) {
          _guessesWithNames = cached;
          isLoading = false;
        } else {
          isLoading = true;
        }
      });
      // Cache hit → background revalidate. Cache miss → foreground fetch.
      _fetchGuesses(selectedGroupName, background: cached != null);
      _fetchDistribution(newGameId);
    }
  }

  bool get _notStarted => _currentGame.status.long == 'Not Started';
  bool get _isLive => _liveShort.contains(_currentGame.status.short);
  bool get _isHalftime => _currentGame.status.short == 'HT';
  bool get _isAfterPenalties => _currentGame.status.short == 'PEN';
  bool get _isAfterExtraTime => _currentGame.status.short == 'AET';
  bool get _isFinished =>
      _currentGame.status.short == 'FT' ||
      _isAfterExtraTime ||
      _isAfterPenalties;

  Color _getAccent(EditorialColors c) {
    if (_isLive) return c.live;
    if (_isHalftime) return c.amber;
    if (_isFinished) return c.inkMute;
    return c.inkDim;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Scaffold(
      backgroundColor: c.pitch,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: c.pitch,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: c.ink, size: 20),
        title: Text(
          AppLocalizations.of(context)!.matchCentre.toUpperCase(),
          style: EType.label(color: c.inkDim, size: 11, letterSpacing: 2.6),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              _buildHeroCard(),
              if (_selectedTab != null) _buildTabContent(),
              if (_notStarted) _buildFormSection(),
              _buildDistributionBlock(),
              if (_currentGame.status.long != 'Not Started')
                _buildPredictionsBlock(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Hero scoreboard ────────────────────────────────────────────────────
  Widget _buildHeroCard() {
    final c = context.col;
    final accent = _getAccent(c);
    final hasPrev = _currentIndex > 0 &&
        widget.games[_currentIndex - 1].status.long != "Not Started";
    final hasNext = _currentIndex < widget.games.length - 1 &&
        widget.games[_currentIndex + 1].status.long != "Not Started";

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v < 0 && hasPrev) {
          _navigateToGame(_currentIndex - 1);
        } else if (v > 0 && hasNext) {
          _navigateToGame(_currentIndex + 1);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: c.card,
          border: Border(
            top: BorderSide(color: accent, width: 2),
            bottom: BorderSide(color: c.hairline, width: 1),
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 14),
              child: Column(
                children: [
                  _buildHeroMeta(),
                  const SizedBox(height: 28),
                  _buildScoreboard(hasPrev: hasPrev, hasNext: hasNext),
                  const SizedBox(height: 20),
                  _buildLeagueStrip(),
                ],
              ),
            ),
            // Divider sits BELOW the league strip and ABOVE the tabs.
            Container(height: 1, color: c.hairline),
            _buildTabBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroMeta() {
    final c = context.col;
    final info = StatusUtils.getStatusInfo(_currentGame.status.short, context);
    String statusText;
    Color statusColor;
    if (_isLive) {
      final el = _currentGame.status.elapsed;
      statusText = el != null
          ? "${AppLocalizations.of(context)!.liveLabel.toUpperCase()}  ${el}'"
          : AppLocalizations.of(context)!.liveLabel.toUpperCase();
      statusColor = c.live;
    } else if (_isHalftime) {
      statusText = AppLocalizations.of(context)!.halfTimeLabel.toUpperCase();
      statusColor = c.amber;
    } else if (_isAfterPenalties) {
      statusText =
          AppLocalizations.of(context)!.afterPenaltiesLabel.toUpperCase();
      statusColor = c.inkMute;
    } else if (_isAfterExtraTime) {
      statusText =
          AppLocalizations.of(context)!.afterExtraTimeLabel.toUpperCase();
      statusColor = c.inkMute;
    } else if (_isFinished) {
      statusText = AppLocalizations.of(context)!.fullTimeLabel.toUpperCase();
      statusColor = c.inkMute;
    } else {
      statusText = (info['text']?.toString() ?? '').toUpperCase();
      statusColor = c.inkMute;
    }

    final isHe = Localizations.localeOf(context).languageCode == 'he';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Status as a soft pill with a leading dot, rather than bare tracked
        // small-caps.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: c.cardHi,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration:
                    BoxDecoration(color: statusColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
              Text(
                statusText,
                style: EType.body(
                  color: statusColor,
                  size: 11,
                  weight: FontWeight.w600,
                  hebrew: isHe,
                ),
              ),
            ],
          ),
        ),
        Text(
          DateFormat('HH:mm  •  dd.MM.yy').format(_currentGame.date.toLocal()),
          style: EType.numeric(color: c.inkDim, size: 11),
        ),
      ],
    );
  }

  Widget _buildLeagueStrip() {
    final c = context.col;
    final league = _currentGame.league;
    // Outlined green pill rather than a bare caption.
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.live.withValues(alpha: 0.45), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                league.round.isNotEmpty
                    ? '${league.name}  •  ${league.round}'.toUpperCase()
                    : league.name.toUpperCase(),
                overflow: TextOverflow.ellipsis,
                style: EType.label(
                  color: c.live,
                  size: 10,
                  letterSpacing: 1.4,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (league.logo != null && league.logo!.isNotEmpty)
              SizedBox(
                width: 15,
                height: 15,
                child: Image.network(
                  league.logo!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                      Icons.emoji_events_outlined,
                      size: 13,
                      color: c.live),
                ),
              )
            else
              Icon(Icons.emoji_events_outlined, size: 13, color: c.live),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreboard({required bool hasPrev, required bool hasNext}) {
    final c = context.col;
    final h = _currentGame.goals.home ?? 0;
    final a = _currentGame.goals.away ?? 0;
    // Reserve 2 lines for both teams only if at least one name has multiple
    // words; otherwise keep it to a single line. This keeps the two sides
    // symmetric and never splits a word mid-letter.
    // Use localized names so translated multi-word names (e.g. "ארצות הברית")
    // are detected even when the API name is a single word (e.g. "USA").
    final localHome = localizedTeamName(context, _currentGame.home.name);
    final localAway = localizedTeamName(context, _currentGame.away.name);
    final bool anyMultiWord =
        localHome.trim().contains(' ') || localAway.trim().contains(' ');
    final int nameMaxLines = anyMultiWord ? 2 : 1;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _navArrow(Icons.arrow_back_ios_new, hasPrev,
            () => _navigateToGame(_currentIndex - 1)),
        Expanded(
            child: _heroTeam(_currentGame.home,
                alignEnd: true, maxLines: nameMaxLines)),
        const SizedBox(width: 24),
        Column(
          children: [
            // Wide bold sans rather than the condensed display face, with a
            // smaller muted colon — matches the scoreboard in the design.
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '$h',
                  style: EType.body(
                    size: 44,
                    height: 1.0,
                    weight: FontWeight.w700,
                    color: _isLive ? c.live : c.ink,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    ':',
                    style: EType.body(
                      size: 30,
                      height: 1.0,
                      weight: FontWeight.w600,
                      color: c.inkDim,
                    ),
                  ),
                ),
                Text(
                  '$a',
                  style: EType.body(
                    size: 44,
                    height: 1.0,
                    weight: FontWeight.w700,
                    color: _isLive ? c.live : c.ink,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(width: 24),
        Expanded(
            child: _heroTeam(_currentGame.away,
                alignEnd: false, maxLines: nameMaxLines)),
        _navArrow(Icons.arrow_forward_ios, hasNext,
            () => _navigateToGame(_currentIndex + 1)),
      ],
    );
  }

  Widget _navArrow(IconData icon, bool enabled, VoidCallback onTap) {
    final c = context.col;
    return SizedBox(
      width: 28,
      child: enabled
          ? IconButton(
              padding: EdgeInsets.zero,
              onPressed: onTap,
              icon: Icon(icon, color: c.inkMute, size: 14),
            )
          : const SizedBox.shrink(),
    );
  }

  /// One font size for *both* team names: the largest size (capped at 18)
  /// that lets the longest single word of either name fit within [width].
  /// This guarantees word-boundary wrapping only — a word is never split
  /// mid-letter on narrow phones.
  double _heroNameFontSize(double width, String home, String away) {
    const base = 18.0;
    const minSize = 11.0;
    double widestWord(String s) {
      double maxW = 0;
      for (final w in s.toUpperCase().split(RegExp(r'\s+'))) {
        if (w.isEmpty) continue;
        final tp = TextPainter(
          text: TextSpan(
            text: w,
            style: EType.display(size: base, letterSpacing: 0.8),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();
        if (tp.width > maxW) maxW = tp.width;
      }
      return maxW;
    }

    final widest = math.max(widestWord(home), widestWord(away));
    if (widest <= 0 || widest <= width) return base;
    return (base * (width / widest)).clamp(minSize, base);
  }

  Widget _heroTeam(Team team, {required bool alignEnd, required int maxLines}) {
    final c = context.col;
    const double nameLineHeight = 1.1;
    return LayoutBuilder(
      builder: (ctx, cons) {
        final double nameFontSize = _heroNameFontSize(
          cons.maxWidth,
          _currentGame.home.name,
          _currentGame.away.name,
        );
        final double nameBlockHeight = nameFontSize * nameLineHeight * maxLines;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => _openTeamDetails(team),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: c.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.hairline, width: 1.5),
                ),
                padding: const EdgeInsets.all(9),
                child: Image.network(
                  team.logo,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      Icon(Icons.shield_outlined, color: c.inkDim),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: nameBlockHeight,
              child: GestureDetector(
                onTap: () => _openTeamDetails(team),
                child: Text(
                  // Sentence case, not tracked caps — matches the design.
                  localizedTeamName(context, team.name),
                  textAlign: TextAlign.center,
                  maxLines: maxLines,
                  softWrap: maxLines > 1,
                  overflow: TextOverflow.ellipsis,
                  style: EType.body(
                    size: nameFontSize,
                    color: c.ink,
                    weight: FontWeight.w700,
                    height: nameLineHeight,
                    hebrew: localizedTeamName(context, team.name) != team.name,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Tabbed block: Timeline / Lineups / Table / Stats ───────────────────
  /// Tab bar row – lives inside the hero card.
  Widget _buildTabBar() {
    final c = context.col;
    final l = AppLocalizations.of(context)!;

    final tabs = <String>[
      l.timeline.toUpperCase(),
      l.lineups.toUpperCase(),
      l.tableTab.toUpperCase(),
      l.statsTab.toUpperCase(),
    ];

    final isHe = Localizations.localeOf(context).languageCode == 'he';

    // Rounded segmented track: the active tab is a raised pill rather than an
    // underline.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: c.cardHi,
          // Pill radius + the 4px padding, so the inner and outer curves stay
          // concentric instead of the track looking squarer than the pill.
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: List.generate(tabs.length, (i) {
            final isActive = i == _selectedTab;
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() {
                  _selectedTab = _selectedTab == i ? null : i;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: isActive ? c.card : Colors.transparent,
                    // ~half the 33px pill height — fully rounded ends.
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isActive ? c.hairline : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    tabs[i],
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: EType.body(
                      color: isActive ? c.live : c.inkMute,
                      size: 12,
                      weight: FontWeight.w600,
                      hebrew: isHe,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  /// Tab content panel – rendered directly below the hero card.
  Widget _buildTabContent() {
    final c = context.col;
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        border: Border(
          bottom: BorderSide(color: c.hairline, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 1, color: c.hairline),
          _buildTabBody(),
        ],
      ),
    );
  }

  // Pre-match form section, shown inline below the tabbed block (for started
  // games the same content lives in the FORM tab instead).
  Widget _buildFormSection() {
    final c = context.col;
    final l = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        border: Border(bottom: BorderSide(color: c.hairline, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 1, color: c.hairline),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(
              children: [
                Container(width: 18, height: 1, color: c.live),
                const SizedBox(width: 10),
                Text(
                  l.formTab.toUpperCase(),
                  style: EType.label(
                      color: c.inkDim, size: 11, letterSpacing: 2.2),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: MatchFormSection(
              home: _currentGame.home,
              away: _currentGame.away,
              collapsible: true,
              onMatchTap: _openFormGame,
            ),
          ),
        ],
      ),
    );
  }

  // Navigate to a form match ONLY if it's one of the games already loaded in
  // the app (allLeagueGames / games). Those have full fixture detail and a valid
  // paging context. Form matches that aren't cached (e.g. AllSport-sourced or
  // other competitions) have no detail data, so tapping them does nothing.
  void _openFormGame(Game game, List<Game> contextMatches) {
    final cache = widget.allLeagueGames ?? widget.games;
    final cacheIdx = cache.indexWhere((m) => m.fixtureId == game.fixtureId);
    if (cacheIdx < 0) return; // not in app cache → no game details to show

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameDetails(
          gameOriginalId: cache[cacheIdx].fixtureId,
          game: cache[cacheIdx],
          games: cache,
          initialIndex: cacheIdx,
          allLeagueGames: widget.allLeagueGames ?? widget.games,
          userId: widget.userId,
        ),
      ),
    );
  }

  Widget _buildTabBody() {
    switch (_selectedTab) {
      case 0:
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
          child: FixtureEventsWidget(
            fixtureId: currentGameId,
            homeTeamName: _currentGame.home.name,
            awayTeamName: _currentGame.away.name,
            homeTeamLogo: _currentGame.home.logo,
            awayTeamLogo: _currentGame.away.logo,
            showHeader: false,
          ),
        );
      case 1:
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: LineupsWidget(
            fixtureId: currentGameId,
            matchDate: _currentGame.date,
            homeTeamName: _currentGame.home.name,
            awayTeamName: _currentGame.away.name,
          ),
        );
      case 2:
        return StandingsTableWidget(
          leagueId: _currentGame.league.id,
          highlightHomeId: _currentGame.home.id,
          highlightAwayId: _currentGame.away.id,
          logoSourceGames: widget.allLeagueGames ?? widget.games,
          onTeamTap: (id, name, logo) => _openTeamDetails(
            Team(id: id, name: name, logo: logo),
          ),
        );
      case 3:
      default:
        return StatsWidget(
          fixtureId: currentGameId,
          homeTeamName: _currentGame.home.name,
          awayTeamName: _currentGame.away.name,
          matchElapsed: _currentGame.status.elapsed,
          matchStatusShort: _currentGame.status.short,
        );
      // H2H tab hidden for now — re-enable once there is more historical data.
      // case 4:
      //   return Padding(
      //     padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      //     child: HeadToHeadWidget(
      //       fixtureId: currentGameId,
      //       homeTeamName: _currentGame.home.name,
      //       homeTeamLogo: _currentGame.home.logo,
      //       homeTeamId: _currentGame.home.id,
      //       awayTeamName: _currentGame.away.name,
      //       awayTeamLogo: _currentGame.away.logo,
      //     ),
      //   );
    }
  }

  // ── Distribution bar ───────────────────────────────────────────────────
  /// Global split of all users' guesses into home win / draw / away win.
  /// Group-independent and shown for every game state (incl. before kickoff).
  Widget _buildDistributionBlock() {
    final c = context.col;
    final l = AppLocalizations.of(context)!;

    // Hidden until data arrives (avoids a loading flash) and when there are no
    // guesses to show.
    final all = _allGuesses;
    if (all == null) return const SizedBox.shrink();

    int homeWins = 0, draws = 0, awayWins = 0;
    for (final g in all) {
      final h = int.tryParse(g.homeTeamGoals);
      final a = int.tryParse(g.awayTeamGoals);
      if (h == null || a == null) continue;
      if (h > a) {
        homeWins++;
      } else if (h < a) {
        awayWins++;
      } else {
        draws++;
      }
    }
    final total = homeWins + draws + awayWins;
    if (total == 0) return const SizedBox.shrink();

    final countStr = NumberFormat.decimalPattern().format(total);
    int pct(int n) => total == 0 ? 0 : (n / total * 100).round();
    final actual = _actualOutcome();

    // Always a single line now: the split bar plus an inline legend. The old
    // expand/collapse toggle and the per-outcome rows are gone.
    return Container(
      decoration: BoxDecoration(color: c.card),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionLabel(l.distributionLabel.toUpperCase()),
              const Spacer(),
              // Total guess count stays admin-only.
              if (_isAdmin)
                Text(
                  l.guessesCount(countStr),
                  style: EType.label(
                      color: c.inkDim, size: 11, letterSpacing: 1.2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _stackedBar(homeWins, draws, awayWins, _outcomeColor('home'),
              _outcomeColor('draw'), _outcomeColor('away')),
          const SizedBox(height: 10),
          Row(
            children: [
              // Equal thirds so the three labels line up under their segments
              // and a long team name truncates instead of pushing the others
              // off the row.
              Expanded(
                child: _distLegend(
                  _outcomeColor('home'),
                  localizedTeamName(context, _currentGame.home.name),
                  pct(homeWins),
                  actual == 'home',
                ),
              ),
              Expanded(
                child: _distLegend(_outcomeColor('draw'), l.drawLabel,
                    pct(draws), actual == 'draw'),
              ),
              Expanded(
                child: _distLegend(
                  _outcomeColor('away'),
                  localizedTeamName(context, _currentGame.away.name),
                  pct(awayWins),
                  actual == 'away',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // One legend entry: colour dot, who it refers to, the percentage, and a tick
  // on the outcome that actually happened.
  Widget _distLegend(Color color, String label, int pctVal, bool actual) {
    final c = context.col;
    final isHe = Localizations.localeOf(context).languageCode == 'he';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('$pctVal%',
            style:
                EType.numeric(color: color, size: 13, weight: FontWeight.w700)),
        if (actual) ...[
          const SizedBox(width: 4),
          Icon(Icons.check, size: 13, color: color),
        ],
        const SizedBox(width: 6),
        // Flexible so a long name ellipsises rather than overflowing the third.
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: EType.body(color: c.inkMute, size: 12, hebrew: isHe),
          ),
        ),
      ],
    );
  }

  // The outcome that actually happened ('home'/'draw'/'away'), for the
  // "actual result" badge — only once the game has a real score.
  String? _actualOutcome() {
    if (_notStarted) return null;
    final h = _currentGame.goals.home;
    final a = _currentGame.goals.away;
    if (h == null || a == null) return null;
    return h > a ? 'home' : (h < a ? 'away' : 'draw');
  }

  // Distribution colours: the outcome that actually happened is green, a draw
  // is gray, and the other (unfulfilled) win outcome is orange. Before the
  // result is known, both win outcomes are orange and the draw is gray.
  Color _outcomeColor(String outcome) {
    final c = context.col;
    final actual = _actualOutcome();
    if (actual != null && outcome == actual) return c.live; // actual → green
    if (outcome == 'draw') return c.inkMute; // draw → gray
    return c.amber; // other win → orange
  }

  // Segmented distribution bar: home | draw | away, rounded, small gaps,
  // zero-count segments skipped.
  Widget _stackedBar(int hf, int df, int af, Color hc, Color dc, Color ac) {
    final segs = <Widget>[];
    void add(int flex, Color color) {
      if (flex <= 0) return;
      if (segs.isNotEmpty) segs.add(const SizedBox(width: 3));
      segs.add(Expanded(
        flex: flex,
        child: Container(
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ));
    }

    add(hf, hc);
    add(df, dc);
    add(af, ac);
    return Row(children: segs);
  }

  // ── Predictions table ──────────────────────────────────────────────────
  Widget _buildPredictionsBlock() {
    final c = context.col;
    final l = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        border: Border(
          bottom: BorderSide(color: c.hairline, width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 18, height: 1, color: c.live),
              const SizedBox(width: 10),
              Text(l.groupGuesses.toUpperCase(),
                  style:
                      EType.label(color: c.ink, size: 11, letterSpacing: 2.4)),
              const Spacer(),
              if (!_groupsLoading && _userGroups.isNotEmpty)
                _compactGroupSelector(),
            ],
          ),
          const SizedBox(height: 14),
          if (_groupsLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation(c.live),
                  ),
                ),
              ),
            )
          else if (_userGroups.isEmpty)
            _joinGroupCallout(l)
          else ...[
            if (isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation(c.live),
                    ),
                  ),
                ),
              )
            else if (_guessesWithNames.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  l.noGuesses.toUpperCase(),
                  style:
                      EType.label(color: c.inkDim, size: 11, letterSpacing: 2),
                ),
              )
            else
              _buildGuessesList(l),
          ],
        ],
      ),
    );
  }

  Widget _joinGroupCallout(AppLocalizations l) {
    final c = context.col;
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TableScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
        decoration: BoxDecoration(
          border: Border.all(color: c.hairlineHi, width: 1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(Icons.groups_2_outlined, size: 18, color: c.inkMute),
            const SizedBox(width: 24),
            Expanded(
              child: Text(
                l.joingrouptoseefreinds,
                style: EType.body(color: c.inkMute, size: 13),
              ),
            ),
            Icon(Icons.arrow_forward, size: 14, color: c.inkMute),
          ],
        ),
      ),
    );
  }

  // Compact group selector shown at the end of the "Group guesses" header.
  Widget _compactGroupSelector() {
    final c = context.col;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _showGroupSwitcherSheet,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              selectedGroupName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: EType.body(color: c.ink, size: 13),
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.unfold_more, color: c.inkMute, size: 14),
          const SizedBox(width: 8),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: c.cardHi,
              shape: BoxShape.circle,
              border: Border.all(color: c.live, width: 1),
            ),
            alignment: Alignment.center,
            child: Text(
              selectedGroupName.isNotEmpty
                  ? selectedGroupName[0].toUpperCase()
                  : '?',
              style: EType.display(size: 13, color: c.live),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showGroupSwitcherSheet() async {
    if (_userGroups.isEmpty) return;
    final c = context.col;
    await showModalBottomSheet(
      context: context,
      backgroundColor: c.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) {
        final sc = sheetCtx.col;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 12),
                  width: 36,
                  height: 3,
                  decoration: BoxDecoration(
                    color: sc.hairlineHi,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Section label
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Row(
                  children: [
                    Container(width: 18, height: 1, color: sc.live),
                    const SizedBox(width: 10),
                    Text(
                      AppLocalizations.of(sheetCtx)!
                          .privategroups
                          .toUpperCase(),
                      style: EType.label(
                          color: sc.ink, size: 11, letterSpacing: 2.4),
                    ),
                  ],
                ),
              ),
              Container(height: 1, color: sc.hairline),
              // Group rows
              ..._userGroups.entries.map((entry) {
                final name = entry.value;
                final isActive = name == selectedGroupName;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    if (!isActive) {
                      setState(() {
                        selectedGroupName = name;
                        isLoading = true;
                      });
                      _fetchGuesses(name);
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isActive ? sc.liveSoft : Colors.transparent,
                      border: Border(
                        bottom: BorderSide(color: sc.hairline, width: 1),
                        left: BorderSide(
                          color: isActive ? sc.live : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: sc.cardHi,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isActive ? sc.live : sc.hairline,
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: EType.display(
                              size: 16,
                              color: isActive ? sc.live : sc.inkMute,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            name.toUpperCase(),
                            overflow: TextOverflow.ellipsis,
                            style: EType.body(
                              size: 15,
                              color: sc.ink,
                              weight: FontWeight.w700,
                              hebrew: Localizations.localeOf(sheetCtx)
                                      .languageCode ==
                                  'he',
                            ),
                          ),
                        ),
                        if (isActive)
                          Icon(Icons.check, size: 16, color: sc.live),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGuessesList(AppLocalizations l) {
    final c = context.col;
    final sorted = [..._guessesWithNames]
      ..sort((a, b) => b.guess.sumPoints.compareTo(a.guess.sumPoints));

    return Column(
      children: [
        // Header row.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Text('#',
                    style: EType.label(
                        color: c.inkDim, size: 10, letterSpacing: 1.4)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l.name.toUpperCase(),
                    style: EType.label(
                        color: c.inkDim, size: 10, letterSpacing: 1.6)),
              ),
              SizedBox(
                width: 56,
                child: Text(l.guess.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: EType.label(
                        color: c.inkDim, size: 10, letterSpacing: 1.6)),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 72,
                child: Text(l.sumpoints.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    softWrap: false,
                    style: EType.label(
                        color: c.inkDim, size: 10, letterSpacing: 1.2)),
              ),
            ],
          ),
        ),
        // Rows live in one rounded, clipped card so the tinted rows follow the
        // corners instead of running to square edges.
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.hairline, width: 1),
            ),
            child: Column(children: [
              ...sorted.asMap().entries.map((e) {
                final i = e.key;
                final g = e.value;
                final isMe = g.guess.userId == currentUserId;
                final pts = g.guess.sumPoints;
                final exact = g.guess.direct == 1; // exact score
                final partial = !exact && pts > 0; // right direction only
                final ptsColor =
                    exact ? c.live : (partial ? c.amber : c.inkMute);
                // Row tint by guess quality only — exact = green, direction = orange,
                // miss = none. The current user's row is marked by a left border and
                // the "you" badge, NOT a green fill (green means a correct guess).
                final bg = exact
                    ? c.liveSoft
                    : (partial
                        ? c.amber.withValues(alpha: 0.08)
                        : Colors.transparent);
                final isLast = i == sorted.length - 1;
                return InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => Statistics(
                          userId: g.guess.userId,
                          leagueId: _currentGame.league.id,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isLast ? Colors.transparent : c.hairline,
                          width: 1,
                        ),
                      ),
                      color: bg,
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 13),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          child: Text(
                            '${i + 1}'.padLeft(2, '0'),
                            style: EType.numeric(
                              color: i < 3 ? c.live : c.inkDim,
                              size: 11,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  g.userName,
                                  overflow: TextOverflow.ellipsis,
                                  style: EType.body(
                                    color: c.ink,
                                    size: 13,
                                    weight: isMe
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: c.live, width: 1),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: Text(l.youLabel.toUpperCase(),
                                      style: EType.label(
                                          color: c.live,
                                          size: 9,
                                          letterSpacing: 1.2)),
                                ),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 56,
                          child: Text(
                            '${g.guess.homeTeamGoals} : ${g.guess.awayTeamGoals}',
                            textAlign: TextAlign.center,
                            style: EType.numeric(
                              color: c.ink,
                              size: 13,
                              weight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 72,
                          child: Text(
                            pts % 1 == 0
                                ? pts.toInt().toString()
                                : pts.toString(),
                            textAlign: TextAlign.center,
                            style: EType.numeric(
                              color: ptsColor,
                              size: 14,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String s) {
    final c = context.col;
    return Row(
      children: [
        Container(width: 18, height: 1, color: c.live),
        const SizedBox(width: 10),
        Text(s, style: EType.label(color: c.ink, size: 11, letterSpacing: 2.4)),
      ],
    );
  }

  void _openTeamDetails(Team team) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TeamDetailsScreen(
          team: team,
          league: _currentGame.league,
          allLeagueGames: widget.allLeagueGames ?? widget.games,
          userId: widget.userId,
        ),
      ),
    );
  }

  Future<void> _fetchUserGroups({bool background = false}) async {
    try {
      Map<String, dynamic> userData =
          await UsersMethods().fetchUserById(currentUserId);
      if (!mounted) return;

      Map<String, String> tempGroups =
          Map<String, String>.from(userData['groupID'] ?? {});
      tempGroups.removeWhere((key, value) => value.toLowerCase() == 'public');
      _GuessesCache.userGroups[currentUserId] = tempGroups;

      // Single source of truth — same resolver used by the hydrate path so
      // the user's persisted default-group choice from TableScreen wins.
      final nextGroup = _resolveActiveGroup(tempGroups);
      final groupChanged = nextGroup != selectedGroupName;

      setState(() {
        _userGroups = tempGroups;
        _groupsLoading = false;
        selectedGroupName = nextGroup;
        if (tempGroups.isEmpty) {
          isLoading = false;
        }
      });

      // Only kick off a guesses fetch from here in the non-background path
      // (cold start) or when groups changed (different active group). In the
      // background revalidation path the cached _fetchGuesses call from
      // initState is already in flight.
      if (nextGroup.isNotEmpty && (!background || groupChanged)) {
        _fetchGuesses(nextGroup,
            background: background && _guessesWithNames.isNotEmpty);
      }
    } catch (e) {
      print('Failed to fetch user groups: $e');
      if (!mounted) return;
      if (!background) {
        setState(() {
          _groupsLoading = false;
          isLoading = false;
        });
      }
    }
  }

  /// Loads the all-users guesses for [gameId] that feed the distribution bar.
  /// Paints instantly from cache when available, then revalidates.
  Future<void> _fetchDistribution(int gameId) async {
    final cached = _GuessesCache.allGuesses[gameId];
    if (cached != null) {
      setState(() {
        _allGuesses = cached;
        _distLoading = false;
      });
    } else {
      setState(() {
        _allGuesses = null;
        _distLoading = true;
      });
    }
    try {
      final all = await GuessesMethods().fetchAllUsersGuesses(gameId);
      _GuessesCache.allGuesses[gameId] = all;
      if (!mounted || currentGameId != gameId) return;
      setState(() {
        _allGuesses = all;
        _distLoading = false;
      });
    } catch (e) {
      print('Failed to fetch distribution guesses: $e');
      if (!mounted || currentGameId != gameId) return;
      setState(() => _distLoading = false);
    }
  }

  Future<void> _fetchGuesses(groupName, {bool background = false}) async {
    final gameIdAtCall = currentGameId;

    // Cache hit? Paint instantly, then revalidate in background. We do this
    // even when caller passes background=false — re-entering this screen for a
    // game we've already seen should never show a spinner.
    if (!background) {
      final cached =
          _GuessesCache.guesses[_guessesCacheKey(gameIdAtCall, groupName)];
      if (cached != null) {
        setState(() {
          _guessesWithNames = cached;
          isLoading = false;
        });
        // Recurse into background revalidation.
        _fetchGuesses(groupName, background: true);
        return;
      }
    }

    try {
      // One bulk endpoint replaces:
      //   1× fetchAllUsersGuesses + N× getGuessWithNames (2 calls each)
      // The backend joins users and applies the group filter server-side.
      final filteredGuesses = await GuessesMethods()
          .fetchGuessesWithUsers(gameIdAtCall, groupName: groupName);

      _GuessesCache.guesses[_guessesCacheKey(gameIdAtCall, groupName)] =
          filteredGuesses;

      if (!mounted) return;
      // Only swap into UI if the user is still on the same game + group.
      if (currentGameId == gameIdAtCall && selectedGroupName == groupName) {
        setState(() {
          _guessesWithNames = filteredGuesses;
          isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      print('Failed to fetch guesses: $e');
      print('Stack trace: $stackTrace');
      if (!mounted) return;
      if (!background) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }
}

class _GuessesCache {
  // Per-user cache of the groupID map (already filtered: 'public' removed).
  static final Map<String, Map<String, String>> userGroups = {};
  // Per-(gameId, groupName) cache of the predictions list.
  static final Map<String, List<GuessWithNames>> guesses = {};
  // Per-gameId cache of all-users guesses, for the distribution bar.
  static final Map<int, List<Guess>> allGuesses = {};
  // Default group name picked by the user in TableScreen (the starred one).
  // Read from SharedPreferences once and shared across re-entries so the
  // initial hydrate path doesn't need an async await before it can paint.
  static String? defaultGroupName;
}
