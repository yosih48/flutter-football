import 'package:flutter/material.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:football/models/lineup.dart';
import 'package:football/resources/lineup_service.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';

class LineupsWidget extends StatefulWidget {
  final int fixtureId;
  final DateTime matchDate;
  final String homeTeamName;
  final String awayTeamName;

  const LineupsWidget({
    super.key,
    required this.fixtureId,
    required this.matchDate,
    required this.homeTeamName,
    required this.awayTeamName,
  });

  @override
  State<LineupsWidget> createState() => _LineupsWidgetState();
}

class _LineupsWidgetState extends State<LineupsWidget> {
  final LineupService _lineupService = LineupService();
  LineupResponse? _lineupResponse;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchLineups();
  }

  @override
  void didUpdateWidget(LineupsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fixtureId != widget.fixtureId) {
      _fetchLineups();
    }
  }

  Future<void> _fetchLineups() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final response = await _lineupService.getFixtureLineups(
      widget.fixtureId,
      matchDate: widget.matchDate,
    );

    if (!mounted) return;

    setState(() {
      _lineupResponse = response;
      _isLoading = false;
      _hasError = response == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation(Editorial.live),
            ),
          ),
        ),
      );
    }

    if (_hasError) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: GestureDetector(
            onTap: _fetchLineups,
            child: Text(
              l.failedToLoadEvents.toUpperCase(),
              style: EType.label(
                color: Editorial.inkDim,
                size: 11,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      );
    }

    if (_lineupResponse == null ||
        !_lineupResponse!.available ||
        _lineupResponse!.lineups == null ||
        _lineupResponse!.lineups!.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: Text(
            l.lineupsNotAvailable.toUpperCase(),
            style: EType.label(
              color: Editorial.inkDim,
              size: 11,
              letterSpacing: 2,
            ),
          ),
        ),
      );
    }

    final lineups = _lineupResponse!.lineups!;
    return Column(
      children: [
        for (int i = 0; i < lineups.length; i++) ...[
          if (i > 0) Container(height: 1, color: Editorial.hairline),
          _buildTeamLineup(lineups[i], l),
        ],
      ],
    );
  }

  Widget _buildTeamLineup(TeamLineup lineup, AppLocalizations l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTeamHeader(lineup),
        const SizedBox(height: 12),
        _buildSectionTitle(l.startingXI.toUpperCase()),
        const SizedBox(height: 8),
        ...lineup.startXI.map((player) => _buildPlayerRow(player)),
        const SizedBox(height: 16),
        _buildSectionTitle(l.substitutes.toUpperCase()),
        const SizedBox(height: 8),
        ...lineup.substitutes.map((player) => _buildPlayerRow(player)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTeamHeader(TeamLineup lineup) {
    return Row(
      children: [
        if (lineup.team.logo != null)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Image.network(
              lineup.team.logo!,
              width: 22,
              height: 22,
              errorBuilder: (_, __, ___) =>
                  Icon(Icons.shield_outlined, size: 22, color: Editorial.inkDim),
            ),
          ),
        Expanded(
          child: Text(
            lineup.team.name.toUpperCase(),
            style: EType.display(
              size: 16,
              color: Editorial.ink,
              letterSpacing: 0.8,
            ),
          ),
        ),
        if (lineup.formation.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Editorial.hairline, width: 1),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(
              lineup.formation,
              style: EType.numeric(
                color: Editorial.inkMute,
                size: 11,
                weight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: EType.label(
        color: Editorial.inkDim,
        size: 10,
        letterSpacing: 2,
      ),
    );
  }

  Widget _buildPlayerRow(LineupPlayer player) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${player.number}',
              style: EType.numeric(
                color: Editorial.live,
                size: 12,
                weight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              player.name,
              style: EType.body(
                color: Editorial.ink,
                size: 13,
              ),
            ),
          ),
          if (player.pos != null)
            Text(
              player.pos!,
              style: EType.label(
                color: Editorial.inkDim,
                size: 10,
                letterSpacing: 1.4,
              ),
            ),
        ],
      ),
    );
  }
}
