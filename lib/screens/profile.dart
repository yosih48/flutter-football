import 'package:flutter/material.dart';
import 'package:football/providers/flutter%20pub%20add%20provider.dart';
import 'package:football/resources/auth.dart';
import 'package:football/resources/usersMethods.dart';
import 'package:football/screens/login_screen.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

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

class _ProfileScreenContentState extends State<ProfileScreenContent> {
  Map<String, String> _userWinners = {};
  Map<String, String> _userTopScorer = {};
  Map<String, int> _userTopScorerPoints = {};
  bool _isLoading = true;
  bool _showWinners = true;
  late String currentUserId;
  late String currentUserEmail;
  late String currentUserName;

  @override
  void initState() {
    super.initState();
    currentUserId = widget.authProvider.currentUser?.id ?? '';
    currentUserEmail = widget.authProvider.currentUser?.email ?? '';
    currentUserName = widget.authProvider.currentUser?.name ?? '';
    _fetchPersonalData();
  }

  Future<void> _fetchPersonalData() async {
    try {
      final userData = await UsersMethods().fetchUserById(currentUserId);
      if (!mounted) return;
      setState(() {
        _userWinners = Map<String, String>.from(userData['winner'] ?? {});
        _userTopScorer =
            Map<String, String>.from(userData['topScorer'] ?? {});
        _userTopScorerPoints =
            Map<String, int>.from(userData['topScorerPoints'] ?? {});
        _isLoading = false;
      });
      Provider.of<UserProvider>(context, listen: false)
          .setCurrentUser(currentUserId);
    } catch (e) {
      print('Failed to fetch personal data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static const Set<String> _allowedIds = {'383', '2', '140', '3', '39', '848'};

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final filteredWinners = _filterById(_userWinners);
    final filteredTopScorers = _filterById(_userTopScorer);

    return Scaffold(
      backgroundColor: c.pitch,
      body: SafeArea(
        child: Column(
          children: [
            // ── Hero (fixed at top) ──────────────────────────────────
            _buildHero(context, c),

            // ── Tab strip (pinned) ───────────────────────────────────
            _buildTabStrip(context, c),

            // ── Scrollable content ───────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Skeletonizer(
                  enabled: _isLoading,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _showWinners
                        ? usersWinners(
                            key: const ValueKey('winners'),
                            userWinners: _isLoading
                                ? {'2': 'Loading', '39': 'Loading'}
                                : _userWinners,
                            filteredWinners: _isLoading
                                ? {'2': 'Loading', '39': 'Loading'}
                                : filteredWinners,
                          )
                        : usersTopScorers(
                            key: const ValueKey('topScorers'),
                            userTopScorers: _isLoading
                                ? {'2': 'Loading', '39': 'Loading'}
                                : _userTopScorer,
                            userTopScorerPoints: _isLoading
                                ? {'2': 10, '39': 20}
                                : _userTopScorerPoints,
                            filteredTopScorers: _isLoading
                                ? {'2': 'Loading', '39': 'Loading'}
                                : filteredTopScorers,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, String> _filterById(Map<String, String> src) => Map.fromEntries(
      src.entries.where((e) => _allowedIds.contains(e.key)));

  Widget _buildTabStrip(BuildContext context, EditorialColors c) {
    final l = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: c.pitch,
        border: Border(
          bottom: BorderSide(color: c.hairline, width: 1),
        ),
      ),
      child: Row(
        children: [
          _Tab(
            label: l.yourwinners,
            icon: Icons.emoji_events_outlined,
            active: _showWinners,
            onTap: () => setState(() => _showWinners = true),
          ),
          _Tab(
            label: l.topScorers ?? 'Top Scorers',
            icon: Icons.sports_soccer_outlined,
            active: !_showWinners,
            onTap: () => setState(() => _showWinners = false),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context, EditorialColors c) {
    final initial =
        currentUserName.isNotEmpty ? currentUserName[0].toUpperCase() : '?';

    return Container(
      color: c.pitch,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overline
          Text(AppLocalizations.of(context)!.playerProfile.toUpperCase(),
              style: EType.label(
                  color: c.inkDim, size: 10, letterSpacing: 3)),
          const SizedBox(height: 20),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Large monogram with pitch-line texture
              Stack(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: c.card,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.live, width: 1.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: CustomPaint(
                      painter: _MonogramBgPainter(color: c.hairline),
                      child: Center(
                        child: Text(
                          initial,
                          style: EType.display(
                            size: 42,
                            color: c.ink,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Live green dot — "online" indicator
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: c.live,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.pitch, width: 2),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 20),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentUserName.isNotEmpty
                          ? currentUserName.toUpperCase()
                          : '—',
                      style: EType.display(
                        size: 28,
                        color: c.ink,
                        letterSpacing: 1.2,
                        height: 0.95,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currentUserEmail,
                      style: EType.body(
                          color: c.inkMute, size: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


class _Tab extends StatelessWidget {
  const _Tab({
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
                  Icon(
                    icon,
                    size: 16,
                    color: active ? c.ink : c.inkDim,
                  ),
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
            // Active underline indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 2,
              width: active ? 60.0 : 0.0,
              color: c.live,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────
String _leagueName(String id, AppLocalizations l) {
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

// ── Winners list ────────────────────────────────────────────────────────
class usersWinners extends StatelessWidget {
  const usersWinners({
    super.key,
    required Map<String, String> userWinners,
    required this.filteredWinners,
  }) : _userWinners = userWinners;

  final Map<String, String> _userWinners;
  final Map<String, String> filteredWinners;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final l = AppLocalizations.of(context)!;

    if (_userWinners.isEmpty) {
      return _EmptyCard(
        icon: Icons.emoji_events_outlined,
        title: l.noWinnersYet,
        subtitle: l.noWinnersHint,
      );
    }

    return Column(
      children: filteredWinners.entries.map((entry) {
        final id = entry.key;
        final teamName = entry.value;
        return _LeagueRow(
          logoUrl: _leagueLogoUrl(id),
          leagueName: _leagueName(id, l),
          trailing: _BadgeChip(
            icon: Icons.emoji_events_outlined,
            label: teamName,
          ),
          subtitle: Text(
            (l.yourprediction ?? 'Your prediction').toUpperCase(),
            style: EType.label(
                color: c.inkDim, size: 10, letterSpacing: 1.6),
          ),
        );
      }).toList(),
    );
  }
}

// ── Top scorers list ────────────────────────────────────────────────────
class usersTopScorers extends StatelessWidget {
  const usersTopScorers({
    super.key,
    required Map<String, String> userTopScorers,
    required this.userTopScorerPoints,
    required this.filteredTopScorers,
  }) : _userTopScorers = userTopScorers;

  final Map<String, String> _userTopScorers;
  final Map<String, int> userTopScorerPoints;
  final Map<String, String> filteredTopScorers;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final l = AppLocalizations.of(context)!;

    if (filteredTopScorers.isEmpty) {
      return _EmptyCard(
        icon: Icons.sports_soccer_outlined,
        title: l.noTopScorersYet,
        subtitle: l.noTopScorersHint,
      );
    }

    return Column(
      children: filteredTopScorers.entries.map((entry) {
        final id = entry.key;
        final scorerName = entry.value;
        final pts = userTopScorerPoints[id] ?? 0;
        return _LeagueRow(
          logoUrl: _leagueLogoUrl(id),
          leagueName: _leagueName(id, l),
          trailing: _BadgeChip(
            icon: Icons.sports_soccer_outlined,
            label: scorerName,
          ),
          subtitle: Row(
            children: [
              Text(
                (l.topScorerPoints ?? 'Goals Points').toUpperCase(),
                style: EType.label(
                    color: c.inkDim, size: 10, letterSpacing: 1.6),
              ),
              const SizedBox(width: 6),
              Text(
                '$pts ${l.pst}',
                style: EType.numeric(
                  color: pts > 0 ? c.live : c.inkDim,
                  size: 11,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Shared row widget ───────────────────────────────────────────────────
class _LeagueRow extends StatelessWidget {
  const _LeagueRow({
    required this.logoUrl,
    required this.leagueName,
    required this.trailing,
    required this.subtitle,
  });
  final String logoUrl;
  final String leagueName;
  final Widget trailing;
  final Widget subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: c.hairline, width: 1),
        ),
      ),
      child: Row(
        children: [
          // League crest
          Container(
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: c.card,
              shape: BoxShape.circle,
              border: Border.all(color: c.hairline, width: 1),
            ),
            child: Image.network(
              logoUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.shield_outlined, size: 16, color: c.inkDim),
            ),
          ),
          const SizedBox(width: 14),
          // League name + sub-label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  leagueName.toUpperCase(),
                  style: EType.display(
                    size: 16,
                    color: c.ink,
                    letterSpacing: 0.8,
                    height: 1.0,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                subtitle,
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );
  }
}

// ── Pill / badge chip ───────────────────────────────────────────────────
class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      constraints: const BoxConstraints(maxWidth: 130),
      decoration: BoxDecoration(
        color: c.liveSoft,
        border: Border.all(color: c.live.withOpacity(0.5), width: 1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c.live),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: EType.body(
                color: c.live,
                size: 12,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
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
            title.toUpperCase(),
            style: EType.display(
              size: 22,
              color: c.ink,
              letterSpacing: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: EType.body(color: c.inkMute, size: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}

// ── Decorative monogram background painter ──────────────────────────────
class _MonogramBgPainter extends CustomPainter {
  _MonogramBgPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..strokeWidth = 1;
    for (double x = 0; x <= size.width; x += 14) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_MonogramBgPainter old) => old.color != color;
}
