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

  Color get _accent {
    if (_isLive) return Editorial.live;
    if (_isHalftime) return Editorial.amber;
    if (_isFinished) return Editorial.inkMute;
    return Editorial.inkDim;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Editorial.pitch,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Editorial.pitch,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: Editorial.ink, size: 20),
        title: Text(
          'MATCH CENTRE',
          style: EType.label(
              color: Editorial.inkDim, size: 11, letterSpacing: 2.6),
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
                  valueColor: AlwaysStoppedAnimation(Editorial.live),
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
            color: Editorial.card,
            border: Border(
              top: BorderSide(color: _accent, width: 2),
              left: BorderSide(color: Editorial.hairline, width: 1),
              right: BorderSide(color: Editorial.hairline, width: 1),
              bottom: BorderSide(color: Editorial.hairline, width: 1),
            ),
          ),
        child: Stack(
          children: [
            // Decorative grain stripes.
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _PitchLinesPainter(
                    color: Editorial.hairline.withOpacity(0.4),
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
                  Container(height: 1, color: Editorial.hairline),
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
    final info =
        StatusUtils.getStatusInfo(_currentGame.status.short, context);
    String statusText;
    Color statusColor;
    if (_isLive) {
      final el = _currentGame.status.elapsed;
      statusText = el != null ? "LIVE  ${el}'" : 'LIVE';
      statusColor = Editorial.live;
    } else if (_isHalftime) {
      statusText = 'HALF TIME';
      statusColor = Editorial.amber;
    } else if (_isFinished) {
      statusText = 'FULL TIME';
      statusColor = Editorial.inkMute;
    } else {
      statusText = (info['text']?.toString() ?? '').toUpperCase();
      statusColor = Editorial.inkMute;
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
                  color: Editorial.live,
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
              color: Editorial.inkDim, size: 10, letterSpacing: 1.6),
        ),
      ],
    );
  }

  Widget _buildScoreboard({required bool hasPrev, required bool hasNext}) {
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
                    color: _isLive ? Editorial.live : Editorial.ink,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    ':',
                    style: EType.scoreboard(
                      size: 56,
                      color: Editorial.inkDim,
                    ),
                  ),
                ),
                Text(
                  '$a',
                  style: EType.scoreboard(
                    size: 64,
                    color: _isLive ? Editorial.live : Editorial.ink,
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
    return SizedBox(
      width: 28,
      child: enabled
          ? IconButton(
              padding: EdgeInsets.zero,
              onPressed: onTap,
              icon: Icon(icon, color: Editorial.inkMute, size: 14),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _heroTeam(Team team, {required bool alignEnd}) {
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
              color: Editorial.cardHi,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(10),
            child: Image.network(
              team.logo,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.shield_outlined, color: Editorial.inkDim),
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
              color: Editorial.ink,
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Editorial.card,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: Editorial.hairline, width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('MATCH EVENTS'),
          const SizedBox(height: 10),
          FixtureEventsWidget(
            fixtureId: currentGameId,
            homeTeamName: _currentGame.home.name,
            awayTeamName: _currentGame.away.name,
          ),
        ],
      ),
    );
  }

  // ── Predictions table ──────────────────────────────────────────────────
  Widget _buildPredictionsBlock() {
    final l = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Editorial.card,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: Editorial.hairline, width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionLabel('PREDICTIONS'),
              if (_userGroups.isNotEmpty)
                Text(
                  '${_guessesWithNames.length}',
                  style: EType.numeric(
                    color: Editorial.inkMute,
                    size: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (_userGroups.isEmpty)
            _joinGroupCallout(l)
          else ...[
            _buildGroupSelector(),
            const SizedBox(height: 14),
            if (_guessesWithNames.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  l.noGuesses.toUpperCase(),
                  style: EType.label(
                      color: Editorial.inkDim,
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
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TableScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Editorial.hairlineHi, width: 1),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Row(
          children: [
            Icon(Icons.groups_2_outlined,
                size: 18, color: Editorial.inkMute),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l.joingrouptoseefreinds,
                style: EType.body(
                    color: Editorial.inkMute, size: 13),
              ),
            ),
            Icon(Icons.arrow_forward,
                size: 14, color: Editorial.inkMute),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Editorial.terrace,
        border: Border.all(color: Editorial.hairline, width: 1),
        borderRadius: BorderRadius.circular(2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedGroupName.isEmpty ? null : selectedGroupName,
          dropdownColor: Editorial.cardHi,
          isExpanded: true,
          icon: Icon(Icons.expand_more, color: Editorial.inkMute, size: 18),
          style: EType.body(color: Editorial.ink, size: 13),
          items: _userGroups.entries.map((entry) {
            return DropdownMenuItem<String>(
              value: entry.value,
              child: Row(
                children: [
                  Icon(Icons.lock_outline,
                      color: Editorial.live, size: 14),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      entry.value.toUpperCase(),
                      style: EType.label(
                          color: Editorial.ink,
                          size: 11,
                          letterSpacing: 1.6),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (newValue) {
            if (newValue != null) {
              setState(() => selectedGroupName = newValue);
              _fetchGuesses(newValue);
            }
          },
        ),
      ),
    );
  }

  Widget _buildGuessesList(AppLocalizations l) {
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
                        color: Editorial.inkDim,
                        size: 10,
                        letterSpacing: 1.4)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l.name.toUpperCase(),
                    style: EType.label(
                        color: Editorial.inkDim,
                        size: 10,
                        letterSpacing: 1.6)),
              ),
              SizedBox(
                width: 56,
                child: Text(l.guess.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: EType.label(
                        color: Editorial.inkDim,
                        size: 10,
                        letterSpacing: 1.6)),
              ),
              SizedBox(
                width: 48,
                child: Text(l.sumpoints.toUpperCase(),
                    textAlign: TextAlign.right,
                    style: EType.label(
                        color: Editorial.inkDim,
                        size: 10,
                        letterSpacing: 1.6)),
              ),
            ],
          ),
        ),
        Container(height: 1, color: Editorial.hairline),
        ...sorted.asMap().entries.map((e) {
          final i = e.key;
          final g = e.value;
          final isMe = g.guess.userId == currentUserId;
          final pts = g.guess.sumPoints;
          return Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Editorial.hairline, width: 1),
              ),
              color: isMe ? Editorial.liveSoft : Colors.transparent,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: Text(
                    '${i + 1}'.padLeft(2, '0'),
                    style: EType.numeric(
                      color:
                          i < 3 ? Editorial.live : Editorial.inkDim,
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
                            color: Editorial.ink,
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
                                color: Editorial.live, width: 1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text('YOU',
                              style: EType.label(
                                  color: Editorial.live,
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
                      color: Editorial.ink,
                      size: 13,
                      weight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    pts % 1 == 0 ? pts.toInt().toString() : pts.toString(),
                    textAlign: TextAlign.right,
                    style: EType.numeric(
                      color: pts > 0 ? Editorial.live : Editorial.inkMute,
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
    return Row(
      children: [
        Container(width: 18, height: 1, color: Editorial.live),
        const SizedBox(width: 10),
        Text(s,
            style: EType.label(
                color: Editorial.ink, size: 11, letterSpacing: 2.4)),
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
