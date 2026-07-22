import 'package:flutter/material.dart';
import 'package:football/providers/flutter%20pub%20add%20provider.dart';
import 'package:football/resources/auth.dart';
import 'package:football/resources/league_config_service.dart';
import 'package:football/utils/league_logos.dart';
import 'package:football/utils/localized_team_name.dart';
import 'package:football/utils/he_player_name.dart';
import 'package:football/resources/usersMethods.dart';
import 'package:football/screens/bracket.dart';
import 'package:football/screens/login_screen.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:football/widgets/adminChampionSettle.dart';
import 'package:football/widgets/adminBracketSettle.dart';
import 'package:football/widgets/adminSeasonArchive.dart';
import 'package:football/widgets/seasonPickers.dart';
import 'package:football/screens/trophyCabinet.dart';
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
  // chosenLeagues[id] from the user record. Missing entries are treated as
  // opted-in (matches the bootstrap default in games.dart), so a league newly
  // added to the remote config shows up here without a manual toggle.
  Map<String, bool> _chosenLeagues = {};
  bool _isLoading = true;
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

    return Scaffold(
      backgroundColor: c.pitch,
      body: SafeArea(
        child: Column(
          children: [
            // ── Hero (fixed at top) ──────────────────────────────────
            _buildHero(context, c),

            // ── Bracket entry (tournament leagues only) ──────────────
            _buildBracketEntry(context, c),

            // ── Scrollable content ───────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: _buildBody(
                  context,
                  c,
                  placeholderNames: placeholderNames,
                  filteredWinners: filteredWinners,
                  filteredTopScorers: filteredTopScorers,
                ),
              ),
            ),
          ],
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Championship picks: one card per opted-in league ──────────
        _greenHeader(context, c, l.myChampionshipPicks),
        Skeletonizer(
          enabled: _isLoading,
          child: Column(
            children: ids
                .map((id) => _LeaguePredictionCard(
                      leagueIdStr: id,
                      winnerPick: _isLoading ? null : filteredWinners[id],
                      topScorerPick: _isLoading ? null : filteredTopScorers[id],
                      clientId: currentUserId,
                      email: currentUserEmail,
                      isLoading: _isLoading,
                      onChanged: _fetchPersonalData,
                    ))
                .toList(),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TrophyCabinetScreen(
              userId: currentUserId,
              allowedIds: _allowedIds,
            ),
          ),
        ),
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
                        style: EType.display(
                            size: 16, color: c.ink, letterSpacing: 0.4)),
                    const SizedBox(height: 3),
                    Text(l.pastSeasons,
                        style: EType.body(color: c.inkMute, size: 12)),
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

  // Green-accented section header (a short green dash + label), matching the
  // "My championship picks" / "Trophy cabinet" headers in the design.
  Widget _greenHeader(BuildContext context, EditorialColors c, String label,
      {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
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
          Text(label, style: EType.label(color: c.ink, size: 13, letterSpacing: 1)),
          const Spacer(),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Map<String, String> _filterById(Map<String, String> src) => Map.fromEntries(
      src.entries.where((e) => _allowedIds.contains(e.key)));

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
              Icon(Icons.emoji_events, size: 20, color: c.live),
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
            const _AdminManagementSection(),
          ],
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
                    style: EType.label(color: c.ink, size: 13, letterSpacing: 1)),
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
                Divider(height: 1, color: c.hairline, indent: 14, endIndent: 14),
                _AdminRow(
                  icon: Icons.workspace_premium_outlined,
                  title: l.settleChampionTitle,
                  subtitle: l.adminSettleChampionSub,
                  onTap: () => showAdminChampionSettleDialog(context),
                ),
                Divider(height: 1, color: c.hairline, indent: 14, endIndent: 14),
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
                      style: EType.display(
                          size: 14, color: c.ink, letterSpacing: 0.2)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: EType.body(color: c.inkDim, size: 11)),
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
// One white card per opted-in league showing both the champion pick and the
// top-scorer pick. Each inner row keeps its own availability-aware picker.
class _LeaguePredictionCard extends StatelessWidget {
  const _LeaguePredictionCard({
    required this.leagueIdStr,
    required this.winnerPick,
    required this.topScorerPick,
    required this.clientId,
    required this.email,
    required this.isLoading,
    required this.onChanged,
  });

  final String leagueIdStr;
  final String? winnerPick;
  final String? topScorerPick;
  final String clientId;
  final String email;
  final bool isLoading;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final l = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.hairline),
      ),
      child: Column(
        children: [
          // League header (crest + name)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: c.pitch,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.hairline, width: 1),
                  ),
                  child: Image(
                    image: leagueLogoProviderForUrl(_leagueLogoUrl(leagueIdStr)),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        Icon(Icons.shield_outlined, size: 14, color: c.inkDim),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _leagueName(leagueIdStr, l, context),
                    style: EType.display(size: 16, color: c.ink, letterSpacing: 0.4),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: c.hairline),
          _SeasonPickRow(
            leagueIdStr: leagueIdStr,
            pick: winnerPick,
            icon: Icons.emoji_events_outlined,
            label: l.trophyChampionLabel,
            clientId: clientId,
            email: email,
            isLoading: isLoading,
            onChanged: onChanged,
            mode: _PickKind.winner,
          ),
          Divider(height: 1, color: c.hairline, indent: 16, endIndent: 16),
          _SeasonPickRow(
            leagueIdStr: leagueIdStr,
            pick: topScorerPick,
            icon: Icons.sports_soccer_outlined,
            label: l.trophyTopScorerLabel,
            clientId: clientId,
            email: email,
            isLoading: isLoading,
            onChanged: onChanged,
            mode: _PickKind.topScorer,
          ),
        ],
      ),
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
    required this.isLoading,
    required this.onChanged,
    required this.mode,
  });

  final String leagueIdStr;
  final String? pick;
  final IconData icon;
  final String label;
  final String clientId;
  final String email;
  final bool isLoading;
  final VoidCallback onChanged;
  final _PickKind mode;

  @override
  State<_SeasonPickRow> createState() => _SeasonPickRowState();
}

class _SeasonPickRowState extends State<_SeasonPickRow> {
  Future<PickAvailability>? _availability;
  // Crest next to the pick. Memoised so rebuilds don't re-trigger the fetch or
  // flicker the FutureBuilder. Re-resolved when the pick changes.
  Future<String?>? _logo;

  // resolvePickWindow reads AppLocalizations for its error strings, so it
  // depends on inherited widgets and can't run in initState. Defer to
  // didChangeDependencies and guard against re-running on every dependency
  // change (theme/locale flips would otherwise re-trigger a network probe).
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _availability ??= _resolve();
    _logo ??= _resolveLogo();
  }

  @override
  void didUpdateWidget(_SeasonPickRow old) {
    super.didUpdateWidget(old);
    // Re-probe after a save so a row that flipped past the cutoff updates.
    if (old.pick != widget.pick) {
      _availability = _resolve();
      _logo = _resolveLogo();
    }
  }

  Future<PickAvailability> _resolve() async {
    if (widget.isLoading) return const PickAvailability(PickWindow.error);
    final id = int.tryParse(widget.leagueIdStr);
    if (id == null) return const PickAvailability(PickWindow.error);
    return resolvePickWindow(context, id);
  }

  Future<String?> _resolveLogo() async {
    final pick = widget.pick;
    final id = int.tryParse(widget.leagueIdStr);
    if (widget.isLoading || id == null || pick == null || pick.isEmpty) {
      return null;
    }
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

    return FutureBuilder<PickAvailability>(
      future: _availability,
      builder: (ctx, snap) {
        final isOpen = snap.data?.canPick ?? false;
        final hasPick = widget.pick != null && widget.pick!.isNotEmpty;

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
                  style: EType.label(color: c.ink, size: 12, letterSpacing: 0.4),
                ),
              ),
            ],
          );
        } else if (isOpen) {
          value = const EmptyPickChip();
        } else if (snap.connectionState == ConnectionState.waiting) {
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

        final tappable = isOpen; // edits allowed only inside the open window

        return InkWell(
          onTap: tappable ? _openPicker : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(widget.icon, size: 18, color: c.live),
                const SizedBox(width: 10),
                Text(
                  widget.label,
                  style:
                      EType.label(color: c.inkDim, size: 12, letterSpacing: 0.5),
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
        );
      },
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
          width: 22,
          height: 22,
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
