import 'package:flutter/material.dart';
import 'package:football/providers/flutter%20pub%20add%20provider.dart';
import 'package:football/resources/auth.dart';
import 'package:football/resources/league_config_service.dart';
import 'package:football/resources/usersMethods.dart';
import 'package:football/screens/bracket.dart';
import 'package:football/screens/login_screen.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:football/widgets/adminChampionSettle.dart';
import 'package:football/widgets/adminBracketSettle.dart';
import 'package:football/widgets/seasonPickers.dart';
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
  // chosenLeagues[id] from the user record. Missing entries are treated as
  // opted-in (matches the bootstrap default in games.dart), so a league newly
  // added to the remote config shows up here without a manual toggle.
  Map<String, bool> _chosenLeagues = {};
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
        _chosenLeagues =
            Map<String, bool>.from(userData['chosenLeagues'] ?? {});
        _isLoading = false;
      });
      Provider.of<UserProvider>(context, listen: false)
          .setCurrentUser(currentUserId);
    } catch (e) {
      print('Failed to fetch personal data: $e');
      if (mounted) setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final filteredWinners = _filterById(_userWinners);
    final filteredTopScorers = _filterById(_userTopScorer);

    // Skeleton placeholders: shimmer one row per supported league so the
    // loading state matches the real league count from the backend config.
    final placeholderNames = <String, String>{
      for (final id in LeagueConfigService().supportedLeagues)
        id.toString(): 'Loading',
    };
    final placeholderPoints = <String, int>{
      for (final id in LeagueConfigService().supportedLeagues)
        id.toString(): 0,
    };

    return Scaffold(
      backgroundColor: c.pitch,
      body: SafeArea(
        child: Column(
          children: [
            // ── Hero (fixed at top) ──────────────────────────────────
            _buildHero(context, c),

            // ── Bracket entry (tournament leagues only) ──────────────
            _buildBracketEntry(context, c),

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
                            filteredWinners: _isLoading
                                ? placeholderNames
                                : filteredWinners,
                            leagueIds: _isLoading
                                ? placeholderNames.keys.toList()
                                : _allowedIds.toList(),
                            clientId: currentUserId,
                            email: currentUserEmail,
                            isLoading: _isLoading,
                            onChanged: _fetchPersonalData,
                          )
                        : usersTopScorers(
                            key: const ValueKey('topScorers'),
                            userTopScorerPoints: _isLoading
                                ? placeholderPoints
                                : _userTopScorerPoints,
                            filteredTopScorers: _isLoading
                                ? placeholderNames
                                : filteredTopScorers,
                            leagueIds: _isLoading
                                ? placeholderNames.keys.toList()
                                : _allowedIds.toList(),
                            clientId: currentUserId,
                            email: currentUserEmail,
                            isLoading: _isLoading,
                            onChanged: _fetchPersonalData,
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

  // Tournament leagues (hasBracket) the user has opted into get a tappable
  // entry into the bracket-prediction game. Hidden entirely for ordinary
  // leagues so the profile stays unchanged for them.
  Widget _buildBracketEntry(BuildContext context, EditorialColors c) {
    if (_isLoading) return const SizedBox.shrink();
    final l = AppLocalizations.of(context)!;
    final bracketIds = _allowedIds
        .where((id) {
          final n = int.tryParse(id);
          return n != null && LeagueConfigService().hasBracket(n);
        })
        .toList();
    if (bracketIds.isEmpty) return const SizedBox.shrink();
    final id = int.parse(bracketIds.first);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BracketScreen(
              leagueId: id,
              userId: currentUserId,
              email: currentUserEmail,
              userName: currentUserName,
            ),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.live, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(Icons.account_tree_outlined, size: 20, color: c.live),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.bracketTitle.toUpperCase(),
                        style: EType.label(
                            color: c.ink, size: 12, letterSpacing: 1.6)),
                    const SizedBox(height: 3),
                    Text(l.bracketEntrySubtitle.toUpperCase(),
                        style: EType.label(
                            color: c.inkDim, size: 9, letterSpacing: 1.2)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: c.inkDim),
            ],
          ),
        ),
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
          if (widget.authProvider.currentUser?.admin == true) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _AdminActionChip(
                  icon: Icons.admin_panel_settings_outlined,
                  label: AppLocalizations.of(context)!.settleChampionTitle,
                  onTap: () => showAdminChampionSettleDialog(context),
                ),
                _AdminActionChip(
                  icon: Icons.account_tree_outlined,
                  label: AppLocalizations.of(context)!.settleBracketTitle,
                  onTap: () => showAdminBracketSettleDialog(context),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}


// Compact admin action button used in the profile header (admins only).
class _AdminActionChip extends StatelessWidget {
  const _AdminActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: c.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: c.live),
            const SizedBox(width: 8),
            Text(
              label,
              style: EType.label(color: c.ink, size: 11, letterSpacing: 1.4),
            ),
          ],
        ),
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

// ── Winners list ────────────────────────────────────────────────────────
// Iterates every supported league so users can see and start a pick even when
// they haven't chosen yet. Each row probes the pre-season cutoff window via
// PickAvailability and renders one of: existing pick (PickedChip), empty
// state (EmptyPickChip, tappable), or closed (ClosedPickChip, not tappable).
class usersWinners extends StatelessWidget {
  const usersWinners({
    super.key,
    required this.filteredWinners,
    required this.leagueIds,
    required this.clientId,
    required this.email,
    required this.isLoading,
    required this.onChanged,
  });

  final Map<String, String> filteredWinners;
  // Pre-filtered to leagues the user has opted into; iteration order is
  // preserved so the list matches the order the parent computes.
  final List<String> leagueIds;
  final String clientId;
  final String email;
  final bool isLoading;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final ids = leagueIds;

    if (ids.isEmpty) {
      return _EmptyCard(
        icon: Icons.emoji_events_outlined,
        title: l.noWinnersYet,
        subtitle: l.noWinnersHint,
      );
    }

    return Column(
      children: ids.map((id) {
        final pick = filteredWinners[id];
        return _SeasonPickRow(
          leagueIdStr: id,
          pick: pick,
          icon: Icons.emoji_events_outlined,
          clientId: clientId,
          email: email,
          isLoading: isLoading,
          onChanged: onChanged,
          mode: _PickKind.winner,
        );
      }).toList(),
    );
  }
}

// ── Top scorers list ────────────────────────────────────────────────────
// Same shape as usersWinners: one row per supported league with availability-
// aware trailing chip. Points are only shown when the user has actually picked.
class usersTopScorers extends StatelessWidget {
  const usersTopScorers({
    super.key,
    required this.userTopScorerPoints,
    required this.filteredTopScorers,
    required this.leagueIds,
    required this.clientId,
    required this.email,
    required this.isLoading,
    required this.onChanged,
  });

  final Map<String, int> userTopScorerPoints;
  final Map<String, String> filteredTopScorers;
  // Same filtered set as usersWinners — only leagues the user opted into.
  final List<String> leagueIds;
  final String clientId;
  final String email;
  final bool isLoading;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final ids = leagueIds;

    if (ids.isEmpty) {
      return _EmptyCard(
        icon: Icons.sports_soccer_outlined,
        title: l.noTopScorersYet,
        subtitle: l.noTopScorersHint,
      );
    }

    return Column(
      children: ids.map((id) {
        final pick = filteredTopScorers[id];
        final pts = userTopScorerPoints[id] ?? 0;
        return _SeasonPickRow(
          leagueIdStr: id,
          pick: pick,
          icon: Icons.sports_soccer_outlined,
          clientId: clientId,
          email: email,
          isLoading: isLoading,
          onChanged: onChanged,
          mode: _PickKind.topScorer,
          points: pts,
        );
      }).toList(),
    );
  }
}

// ── Shared per-league row with availability-aware picker ────────────────────
enum _PickKind { winner, topScorer }

class _SeasonPickRow extends StatefulWidget {
  const _SeasonPickRow({
    required this.leagueIdStr,
    required this.pick,
    required this.icon,
    required this.clientId,
    required this.email,
    required this.isLoading,
    required this.onChanged,
    required this.mode,
    this.points,
  });

  final String leagueIdStr;
  final String? pick;
  final IconData icon;
  final String clientId;
  final String email;
  final bool isLoading;
  final VoidCallback onChanged;
  final _PickKind mode;
  final int? points;

  @override
  State<_SeasonPickRow> createState() => _SeasonPickRowState();
}

class _SeasonPickRowState extends State<_SeasonPickRow> {
  Future<PickAvailability>? _availability;

  // resolvePickWindow reads AppLocalizations for its error strings, so it
  // depends on inherited widgets and can't run in initState. Defer to
  // didChangeDependencies and guard against re-running on every dependency
  // change (theme/locale flips would otherwise re-trigger a network probe).
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _availability ??= _resolve();
  }

  @override
  void didUpdateWidget(_SeasonPickRow old) {
    super.didUpdateWidget(old);
    // Re-probe after a save so a row that flipped past the cutoff updates.
    if (old.pick != widget.pick) {
      _availability = _resolve();
    }
  }

  Future<PickAvailability> _resolve() async {
    if (widget.isLoading) return const PickAvailability(PickWindow.error);
    final id = int.tryParse(widget.leagueIdStr);
    if (id == null) return const PickAvailability(PickWindow.error);
    return resolvePickWindow(context, id);
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

    return FutureBuilder<PickAvailability>(
      future: _availability,
      builder: (ctx, snap) {
        final isOpen = snap.data?.canPick ?? false;
        final hasPick = widget.pick != null && widget.pick!.isNotEmpty;

        final Widget trailing;
        if (hasPick) {
          trailing = PickedChip(label: widget.pick!, icon: widget.icon);
        } else if (isOpen) {
          trailing = const EmptyPickChip();
        } else if (snap.connectionState == ConnectionState.waiting) {
          // Quiet placeholder while the availability probe is in-flight.
          trailing = SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation(c.inkDim),
            ),
          );
        } else {
          trailing = const ClosedPickChip();
        }

        final subtitle = _buildSubtitle(c, l, hasPick: hasPick, isOpen: isOpen);
        final tappable = isOpen; // edits allowed only inside the open window

        return _LeagueRow(
          logoUrl: _leagueLogoUrl(widget.leagueIdStr),
          leagueName: _leagueName(widget.leagueIdStr, l, context),
          trailing: trailing,
          subtitle: subtitle,
          onTap: tappable ? _openPicker : null,
        );
      },
    );
  }

  Widget _buildSubtitle(EditorialColors c, AppLocalizations l,
      {required bool hasPick, required bool isOpen}) {
    if (widget.mode == _PickKind.topScorer && hasPick) {
      final pts = widget.points ?? 0;
      return Row(
        children: [
          Text(
            (l.topScorerPoints ?? 'Goals Points').toUpperCase(),
            style:
                EType.label(color: c.inkDim, size: 10, letterSpacing: 1.6),
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
      );
    }
    final String text;
    if (hasPick) {
      text = l.yourprediction ?? 'Your prediction';
    } else if (isOpen) {
      text = widget.mode == _PickKind.winner
          ? l.taptoselectwinner
          : l.taptoselecttopscorer;
    } else {
      text = l.selectionClosed;
    }
    return Text(
      text.toUpperCase(),
      style: EType.label(color: c.inkDim, size: 10, letterSpacing: 1.6),
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
    this.onTap,
  });
  final String logoUrl;
  final String leagueName;
  final Widget trailing;
  final Widget subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final row = Container(
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
    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      child: row,
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
