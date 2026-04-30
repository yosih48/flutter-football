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
import 'package:football/screens/table.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:football/utils/status_utils.dart';
import 'package:football/widgets/FixtureEventsWidget.dart';
import 'package:football/widgets/SharedPreferences.dart';
import 'package:football/widgets/LineupsWidget.dart';
import 'package:football/widgets/teamLinks.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class GameDetails extends StatefulWidget {
  final gameOriginalId;
  final userId;
  final Game game;
  final List<Game> games;
  final int initialIndex;

  const GameDetails({
    super.key,
    required this.gameOriginalId,
    required this.game,
    required this.games,
    required this.initialIndex,
    this.userId,
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
  late String selectedGroupName = "";
  Map<String, String> _userGroups = {};
  bool isLoading = true;
  bool _eventsExpanded = false;
  bool _lineupsExpanded = false;
  late int _currentIndex;
  late Game _currentGame;
  late int currentGameId;

  static const Set<String> _liveShort = {'1H', '2H', 'H1', 'H2', 'ET', 'BT', 'P', 'INT'};

  @override
  void initState() {
    super.initState();

    _currentIndex = widget.initialIndex;
    _currentGame = widget.games[_currentIndex];
    league = _currentGame.league.id;
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    currentUserId = widget.userId;
    currentGameId = widget.gameOriginalId;

    _fetchUserGroups();
    _fetchGuesses(selectedGroupName);
  }

  void _navigateToGame(int newIndex) {
    if (newIndex >= 0 && newIndex < widget.games.length) {
      setState(() {
        _currentIndex = newIndex;
        _currentGame = widget.games[newIndex];
        isLoading = true;
        currentGameId = widget.games[newIndex].fixtureId;
      });
      _fetchGuesses(selectedGroupName);
    }
  }

  bool get _isLive => _liveShort.contains(_currentGame.status.short);
  bool get _isHalftime => _currentGame.status.short == 'HT';
  bool get _isFinished =>
      _currentGame.status.short == 'FT' || _currentGame.status.short == 'AET';

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
          style: EType.label(
              color: c.inkDim, size: 11, letterSpacing: 2.6),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation(c.live),
                ),
              ),
            )
          : SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    _buildHeroCard(),
                    const SizedBox(height: 8),
                    _buildEventsBlock(),
                    const SizedBox(height: 8),
                    _buildLineupsBlock(),
                    const SizedBox(height: 8),
                    if (_currentGame.status.long != 'Not Started') ...[
                      _buildPredictionsBlock(),
                      const SizedBox(height: 8),
                    ],
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          decoration: BoxDecoration(
            color: c.card,
            border: Border(
              top: BorderSide(color: accent, width: 2),
              left: BorderSide(color: c.hairline, width: 1),
              right: BorderSide(color: c.hairline, width: 1),
              bottom: BorderSide(color: c.hairline, width: 1),
            ),
          ),
        child: Stack(
          children: [
            // Decorative grain stripes.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _PitchLinesPainter(
                    color: c.hairline.withOpacity(0.4),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
              child: Column(
                children: [
                  _buildHeroMeta(),
                  const SizedBox(height: 28),
                  _buildScoreboard(hasPrev: hasPrev, hasNext: hasNext),
                  const SizedBox(height: 24),
                  Container(height: 1, color: c.hairline),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildHeroMeta() {
    final c = context.col;
    final info =
        StatusUtils.getStatusInfo(_currentGame.status.short, context);
    String statusText;
    Color statusColor;
    if (_isLive) {
      final el = _currentGame.status.elapsed;
      statusText = el != null ? "${AppLocalizations.of(context)!.liveLabel.toUpperCase()}  ${el}'" : AppLocalizations.of(context)!.liveLabel.toUpperCase();
      statusColor = c.live;
    } else if (_isHalftime) {
      statusText = AppLocalizations.of(context)!.halfTimeLabel.toUpperCase();
      statusColor = c.amber;
    } else if (_isFinished) {
      statusText = AppLocalizations.of(context)!.fullTimeLabel.toUpperCase();
      statusColor = c.inkMute;
    } else {
      statusText = (info['text']?.toString() ?? '').toUpperCase();
      statusColor = c.inkMute;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (_isLive) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: c.live,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              statusText,
              style: EType.label(
                  color: statusColor, size: 11, letterSpacing: 2.2),
            ),
          ],
        ),
        Text(
          DateFormat('EEE  dd.MM.yy  •  HH:mm')
              .format(_currentGame.date.toLocal())
              .toUpperCase(),
          style: EType.label(
              color: c.inkDim, size: 10, letterSpacing: 1.6),
        ),
      ],
    );
  }

  Widget _buildScoreboard({required bool hasPrev, required bool hasNext}) {
    final c = context.col;
    final h = _currentGame.goals.home ?? 0;
    final a = _currentGame.goals.away ?? 0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _navArrow(Icons.arrow_back_ios_new, hasPrev,
            () => _navigateToGame(_currentIndex - 1)),
        Expanded(child: _heroTeam(_currentGame.home, alignEnd: true)),
        const SizedBox(width: 12),
        Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '$h',
                  style: EType.scoreboard(
                    size: 64,
                    color: _isLive ? c.live : c.ink,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    ':',
                    style: EType.scoreboard(
                      size: 56,
                      color: c.inkDim,
                    ),
                  ),
                ),
                Text(
                  '$a',
                  style: EType.scoreboard(
                    size: 64,
                    color: _isLive ? c.live : c.ink,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(child: _heroTeam(_currentGame.away, alignEnd: false)),
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

  Widget _heroTeam(Team team, {required bool alignEnd}) {
    final c = context.col;
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => TeamLinkHandler.linkToTeam(team.name),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: c.cardHi,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(10),
            child: Image.network(
              team.logo,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.shield_outlined, color: c.inkDim),
            ),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => TeamLinkHandler.linkToTeam(team.name),
          child: Text(
            team.name.toUpperCase(),
            textAlign: alignEnd ? TextAlign.right : TextAlign.left,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: EType.display(
              size: 18,
              color: c.ink,
              letterSpacing: 0.8,
              height: 1.0,
            ),
          ),
        ),
      ],
    );
  }

  // ── Match events ───────────────────────────────────────────────────────
  Widget _buildEventsBlock() {
    final c = context.col;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: c.hairline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _eventsExpanded = !_eventsExpanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _sectionLabel(AppLocalizations.of(context)!.matchEvents.toUpperCase()),
                  AnimatedRotation(
                    turns: _eventsExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      size: 20,
                      color: c.inkMute,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: FixtureEventsWidget(
                fixtureId: currentGameId,
                homeTeamName: _currentGame.home.name,
                awayTeamName: _currentGame.away.name,
                showHeader: false,
              ),
            ),
            crossFadeState: _eventsExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  // ── Lineups ─────────────────────────────────────────────────────────────
  Widget _buildLineupsBlock() {
    final c = context.col;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: c.hairline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _lineupsExpanded = !_lineupsExpanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _sectionLabel(AppLocalizations.of(context)!.lineups.toUpperCase()),
                  AnimatedRotation(
                    turns: _lineupsExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      size: 20,
                      color: c.inkMute,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                // Pitch — full card width, no horizontal padding
                LineupsWidget(
                  fixtureId: currentGameId,
                  matchDate: _currentGame.date,
                  homeTeamName: _currentGame.home.name,
                  awayTeamName: _currentGame.away.name,
                ),
                const SizedBox(height: 14),
              ],
            ),
            crossFadeState: _lineupsExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }

  // ── Predictions table ──────────────────────────────────────────────────
  Widget _buildPredictionsBlock() {
    final c = context.col;
    final l = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: c.hairline, width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionLabel(l.predictionsLabel.toUpperCase()),
              if (_userGroups.isNotEmpty)
                Text(
                  '${_guessesWithNames.length}',
                  style: EType.numeric(
                    color: c.inkMute,
                    size: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_userGroups.isEmpty)
            _joinGroupCallout(l)
          else ...[
            _buildGroupHeader(),
            const SizedBox(height: 14),
            if (_guessesWithNames.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  l.noGuesses.toUpperCase(),
                  style: EType.label(
                      color: c.inkDim,
                      size: 11,
                      letterSpacing: 2),
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
          borderRadius: BorderRadius.circular(2),
        ),
        child: Row(
          children: [
            Icon(Icons.groups_2_outlined,
                size: 18, color: c.inkMute),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l.joingrouptoseefreinds,
                style: EType.body(
                    color: c.inkMute, size: 13),
              ),
            ),
            Icon(Icons.arrow_forward,
                size: 14, color: c.inkMute),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupHeader() {
    final c = context.col;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _showGroupSwitcherSheet,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: c.terrace,
          border: Border.all(color: c.hairline, width: 1),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Row(
          children: [
            // Monogram circle
            Container(
              width: 36,
              height: 36,
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
                style: EType.display(
                    size: 16, color: c.live, letterSpacing: 0),
              ),
            ),
            const SizedBox(width: 12),
            // Group name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(AppLocalizations.of(context)!.group.toUpperCase(),
                      style: EType.label(
                          color: c.inkDim,
                          size: 9,
                          letterSpacing: 2)),
                  const SizedBox(height: 3),
                  Text(
                    selectedGroupName.toUpperCase(),
                    overflow: TextOverflow.ellipsis,
                    style: EType.display(
                        size: 18, color: c.ink, letterSpacing: 1),
                  ),
                ],
              ),
            ),
            // SWITCH pill
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: c.hairline, width: 1),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Row(
                children: [
                  Text(AppLocalizations.of(context)!.switchGroup.toUpperCase(),
                      style: EType.label(
                          color: c.inkMute,
                          size: 10,
                          letterSpacing: 1.6)),
                  const SizedBox(width: 4),
                  Icon(Icons.expand_more,
                      color: c.inkMute, size: 14),
                ],
              ),
            ),
          ],
        ),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
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
                    Container(
                        width: 18, height: 1, color: sc.live),
                    const SizedBox(width: 10),
                    Text(
                      AppLocalizations.of(sheetCtx)!.privategroups
                          .toUpperCase(),
                      style: EType.label(
                          color: sc.ink,
                          size: 11,
                          letterSpacing: 2.4),
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
                      color: isActive
                          ? sc.liveSoft
                          : Colors.transparent,
                      border: Border(
                        bottom: BorderSide(
                            color: sc.hairline, width: 1),
                        left: BorderSide(
                          color: isActive
                              ? sc.live
                              : Colors.transparent,
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
                              color: isActive
                                  ? sc.live
                                  : sc.hairline,
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            name.isNotEmpty
                                ? name[0].toUpperCase()
                                : '?',
                            style: EType.display(
                              size: 16,
                              color: isActive
                                  ? sc.live
                                  : sc.inkMute,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            name.toUpperCase(),
                            overflow: TextOverflow.ellipsis,
                            style: EType.display(
                              size: 16,
                              color: sc.ink,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        if (isActive)
                          Icon(Icons.check,
                              size: 16, color: sc.live),
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
    final sorted = [..._guessesWithNames]..sort((a, b) =>
        b.guess.sumPoints.compareTo(a.guess.sumPoints));

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
                        color: c.inkDim,
                        size: 10,
                        letterSpacing: 1.4)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l.name.toUpperCase(),
                    style: EType.label(
                        color: c.inkDim,
                        size: 10,
                        letterSpacing: 1.6)),
              ),
              SizedBox(
                width: 56,
                child: Text(l.guess.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: EType.label(
                        color: c.inkDim,
                        size: 10,
                        letterSpacing: 1.6)),
              ),
              const SizedBox(width: 24),
              SizedBox(
                width: 48,
                child: Text(l.sumpoints.toUpperCase(),
                    textAlign: TextAlign.right,
                    style: EType.label(
                        color: c.inkDim,
                        size: 10,
                        letterSpacing: 1.6)),
              ),
            ],
          ),
        ),
        Container(height: 1, color: c.hairline),
        ...sorted.asMap().entries.map((e) {
          final i = e.key;
          final g = e.value;
          final isMe = g.guess.userId == currentUserId;
          final pts = g.guess.sumPoints;
          return Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: c.hairline, width: 1),
              ),
              color: isMe ? c.liveSoft : Colors.transparent,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
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
                            border: Border.all(
                                color: c.live, width: 1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text(AppLocalizations.of(context)!.youLabel.toUpperCase(),
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
                const SizedBox(width: 24),
                SizedBox(
                  width: 48,
                  child: Text(
                    pts % 1 == 0 ? pts.toInt().toString() : pts.toString(),
                    textAlign: TextAlign.right,
                    style: EType.numeric(
                      color: pts > 0 ? c.live : c.inkMute,
                      size: 14,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _sectionLabel(String s) {
    final c = context.col;
    return Row(
      children: [
        Container(width: 18, height: 1, color: c.live),
        const SizedBox(width: 10),
        Text(s,
            style: EType.label(
                color: c.ink, size: 11, letterSpacing: 2.4)),
      ],
    );
  }

  Future<void> _fetchUserGroups() async {
    try {
      Map<String, dynamic> userData =
          await UsersMethods().fetchUserById(currentUserId);
      setState(() {
        Map<String, String> tempGroups =
            Map<String, String>.from(userData['groupID'] ?? {});

        tempGroups.removeWhere((key, value) => value.toLowerCase() == 'public');
        _userGroups = tempGroups;

        final userProvider = Provider.of<UserProvider>(context, listen: false);
        if (_userGroups.isNotEmpty &&
            userProvider.selectedGroupName != 'public') {
          selectedGroupName = userProvider.selectedGroupName;
          _fetchGuesses(selectedGroupName);
        } else if (_userGroups.isNotEmpty) {
          selectedGroupName = _userGroups.values.first;
          _fetchGuesses(selectedGroupName);
        }
      });
    } catch (e) {
      print('Failed to fetch user groups: $e');
    }
  }

  Future<void> _fetchGuesses(groupName) async {
    try {
      final guesses =
          await GuessesMethods().fetchAllUsersGuesses(currentGameId);
      final callService = CallService();
      final guessesWithNames = <GuessWithNames>[];

      for (var guess in guesses) {
        try {
          final guessWithName = await callService.getGuessWithNames(guess);
          guessesWithNames.add(guessWithName);
        } catch (e) {
          print('Skipping guess due to error: $e');
        }
      }

      final filteredGuesses = guessesWithNames.where((guessWithName) {
        return guessWithName.userGroups != null &&
            guessWithName.userGroups.values.contains(groupName);
      }).toList();

      setState(() {
        _guessesWithNames = filteredGuesses;
        isLoading = false;
      });
    } catch (e, stackTrace) {
      print('Failed to fetch guesses: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        isLoading = false;
      });
    }
  }
}

// ── Decorative pitch-line painter (very subtle background texture) ──────
class _PitchLinesPainter extends CustomPainter {
  _PitchLinesPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    // Faint vertical hairlines reminiscent of pitch markings.
    for (double x = 0; x <= size.width; x += 24) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PitchLinesPainter old) => old.color != color;
}
