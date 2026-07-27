import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:football/models/games.dart';
import 'package:football/models/guesses.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:football/utils/localized_team_name.dart';
import 'package:football/utils/status_utils.dart';
import 'package:football/widgets/teamLInks.dart';

import 'package:intl/intl.dart';
import 'package:football/l10n/app_localizations.dart';

class GameWidget extends StatelessWidget {
  final Game game;
  final Guess? guess;
  final Function(BuildContext) onTap;
  final void Function(Team team)? onTeamTap;
  final TextEditingController? homeController;
  final TextEditingController? awayController;

  GameWidget({
    required this.game,
    this.guess,
    required this.onTap,
    this.onTeamTap,
    this.homeController,
    this.awayController,
  }) {
    if (guess != null) {
      homeController!.text = guess!.homeTeamGoals.toString();
      awayController!.text = guess!.awayTeamGoals.toString();
    }
  }

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

  bool get _isLive => _liveShort.contains(game.status.short);
  bool get _isAfterPenalties => game.status.short == 'PEN';
  bool get _isAfterExtraTime => game.status.short == 'AET';
  bool get _isFinished =>
      game.status.short == 'FT' || _isAfterExtraTime || _isAfterPenalties;
  bool get _isHalftime => game.status.short == 'HT';
  bool get _isUpcoming => game.status.long == 'Not Started';
  bool get _kickoffPassed => DateTime.now().isAfter(game.date.toLocal());
  bool get _canGuess => !_kickoffPassed;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final l = AppLocalizations.of(context)!;
    final info = StatusUtils.getStatusInfo(game.status.short, context);

    // Compute accent locally so it can use the theme colors.
    final Color accent;
    if (_isLive) {
      accent = c.live;
    } else if (_isHalftime) {
      accent = c.amber;
    } else if (_isFinished) {
      accent = c.inkDim;
    } else {
      accent = c.hairline;
    }

    // Edge-to-edge: no outer margin and no corner radius, so consecutive cards
    // form one continuous surface separated only by the hairline the caller
    // inserts between them (see _buildDateSection in games.dart).
    return Material(
      color: c.card,
      child: InkWell(
        onTap: () => onTap(context),
        splashColor: c.live.withOpacity(0.04),
        highlightColor: Colors.transparent,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Kit-stripe accent — colors the card by match state.
              Container(width: 3, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMeta(info, c, l),
                      const SizedBox(height: 14),
                      _buildMatchRow(context, c),
                      if (_isUpcoming) ...[
                        const SizedBox(height: 14),
                        _buildOddsRow(c),
                      ],
                      if (!_isUpcoming) ...[
                        const SizedBox(height: 12),
                        _buildGuessFooter(context, c),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMeta(
      Map<String, dynamic> info, EditorialColors c, AppLocalizations l) {
    return Row(
      children: [
        _buildStatusPill(info, c, l),
        const Spacer(),
        if (_isUpcoming)
          Text(
            DateFormat('HH:mm').format(game.date.toLocal()),
            style: EType.numeric(
              color: c.inkMute,
              size: 13,
              letterSpacing: 0.5,
            ),
          ),
        const SizedBox(width: 12),
        Text(
          DateFormat('dd.MM').format(game.date),
          style: EType.numeric(
            color: c.inkDim,
            size: 11,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusPill(
      Map<String, dynamic> info, EditorialColors c, AppLocalizations l) {
    if (_isLive) {
      final elapsed = game.status.elapsed;
      final live = l.liveLabel.toUpperCase();
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulsingDot(color: c.live),
          const SizedBox(width: 6),
          Text(
            elapsed != null ? "$live  ${elapsed}'" : live,
            style: EType.label(
              color: c.live,
              size: 10,
              letterSpacing: 1.8,
            ),
          ),
        ],
      );
    }
    if (_isHalftime) {
      return Text(l.halfTimeLabel.toUpperCase(),
          style: EType.label(color: c.amber, size: 10, letterSpacing: 1.8));
    }
    if (_isAfterPenalties) {
      return Text(l.afterPenaltiesLabel.toUpperCase(),
          style: EType.label(color: c.inkMute, size: 10, letterSpacing: 1.8));
    }
    if (_isAfterExtraTime) {
      return Text(l.afterExtraTimeLabel.toUpperCase(),
          style: EType.label(color: c.inkMute, size: 10, letterSpacing: 1.8));
    }
    if (_isFinished) {
      return Text(l.fullTimeLabel.toUpperCase(),
          style: EType.label(color: c.inkMute, size: 10, letterSpacing: 1.8));
    }
    return Text(
      (info['text']?.toString() ?? '').toUpperCase(),
      style: EType.label(color: c.inkDim, size: 10, letterSpacing: 1.8),
    );
  }

  Widget _buildMatchRow(BuildContext context, EditorialColors c) {
    // Keep both team labels on a single line by default; only wrap to two
    // lines when at least one name is multi-word (and never mid-word). Use the
    // localized (display) name for the wrap heuristic too, so Hebrew names size
    // consistently.
    final homeDisplay = localizedTeamName(context, game.home.name);
    final awayDisplay = localizedTeamName(context, game.away.name);
    final bool anyMultiWord =
        homeDisplay.trim().contains(' ') || awayDisplay.trim().contains(' ');
    final int nameMaxLines = anyMultiWord ? 2 : 1;
    return Row(
      children: [
        Expanded(
            child: _buildTeamSide(context, game.home,
                alignEnd: true, c: c, maxLines: nameMaxLines)),
        const SizedBox(width: 10),
        _buildTeamCrest(game.home, c),
        const SizedBox(width: 10),
        _buildCenter(c),
        const SizedBox(width: 10),
        _buildTeamCrest(game.away, c),
        const SizedBox(width: 10),
        Expanded(
            child: _buildTeamSide(context, game.away,
                alignEnd: false, c: c, maxLines: nameMaxLines)),
      ],
    );
  }

  Widget _buildTeamSide(BuildContext context, Team team,
      {required bool alignEnd,
      required EditorialColors c,
      required int maxLines}) {
    final display = localizedTeamName(context, team.name);
    final heName = display != team.name;
    return GestureDetector(
      onTap: () => onTeamTap != null
          ? onTeamTap!(team)
          : TeamLinkHandler.linkToTeam(team.name),
      child: Text(
        display.toUpperCase(),
        textAlign: alignEnd ? TextAlign.right : TextAlign.left,
        maxLines: maxLines,
        softWrap: maxLines > 1,
        overflow: TextOverflow.ellipsis,
        style: EType.teamNameDisplay(
          size: 16,
          letterSpacing: 0.6,
          height: 1.05,
          color: c.ink,
          hebrew: heName,
        ),
      ),
    );
  }

  Widget _buildTeamCrest(Team team, EditorialColors c) {
    return GestureDetector(
      onTap: () => onTeamTap != null
          ? onTeamTap!(team)
          : TeamLinkHandler.linkToTeam(team.name),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: c.cardHi,
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(5),
        child: Image.network(
          team.logo,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.shield_outlined,
            size: 16,
            color: c.inkDim,
          ),
        ),
      ),
    );
  }

  Widget _buildCenter(EditorialColors c) {
    if (_canGuess && _isUpcoming) {
      return _GuessInput(
        homeController: homeController,
        awayController: awayController,
      );
    }
    final h = game.goals.home ?? 0;
    final a = game.goals.away ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.cardHi,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        '$h : $a',
        style: EType.display(
          size: 22,
          color: _isLive ? c.live : c.ink,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildOddsRow(EditorialColors c) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(child: _OddsCell(label: '1', value: game.odds.home)),
          const SizedBox(width: 6),
          Expanded(child: _OddsCell(label: 'X', value: game.odds.draw)),
          const SizedBox(width: 6),
          Expanded(child: _OddsCell(label: '2', value: game.odds.away)),
        ],
      ),
    );
  }

  Widget _buildGuessFooter(BuildContext context, EditorialColors c) {
    final l = AppLocalizations.of(context)!;
    final hasGuess = guess != null;
    return Stack(
      alignment: Alignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l.yourguess.toUpperCase(),
              style: EType.label(color: c.inkDim, size: 10),
            ),
            if (hasGuess)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: c.liveSoft,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  '${guess!.sumPoints % 1 == 0 ? guess!.sumPoints.toInt() : guess!.sumPoints} ${l.points.toUpperCase()}',
                  style: EType.label(
                    color: c.live,
                    size: 10,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
          ],
        ),
        Text(
          hasGuess
              ? '${guess!.homeTeamGoals} : ${guess!.awayTeamGoals}'
              : '— : —',
          style: EType.numeric(
            color: hasGuess ? c.ink : c.inkFaint,
            size: 13,
            weight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _OddsCell extends StatelessWidget {
  const _OddsCell({required this.label, required this.value});
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: c.terrace,
        border: Border.all(color: c.hairline, width: 1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: EType.label(color: c.inkDim, size: 10)),
          const SizedBox(width: 8),
          Text(
            value.toStringAsFixed(2),
            style: EType.numeric(
              color: c.ink,
              size: 12,
              weight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuessInput extends StatefulWidget {
  const _GuessInput({this.homeController, this.awayController});
  final TextEditingController? homeController;
  final TextEditingController? awayController;

  @override
  State<_GuessInput> createState() => _GuessInputState();
}

class _GuessInputState extends State<_GuessInput> {
  final FocusNode _homeFocus = FocusNode();
  final FocusNode _awayFocus = FocusNode();

  @override
  void dispose() {
    _homeFocus.dispose();
    _awayFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _digit(
          widget.homeController,
          c,
          focusNode: _homeFocus,
          onChanged: (v) {
            // Auto-advance to the away field once a digit is entered.
            if (v.length == 1) _awayFocus.requestFocus();
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(':',
              style: EType.display(
                size: 18,
                color: c.inkDim,
                letterSpacing: 0,
              )),
        ),
        _digit(
          widget.awayController,
          c,
          focusNode: _awayFocus,
          onChanged: (v) {
            // Dismiss the keyboard once both digits are filled.
            if (v.length == 1) _awayFocus.unfocus();
          },
        ),
      ],
    );
  }

  Widget _digit(
    TextEditingController? controller,
    EditorialColors c, {
    FocusNode? focusNode,
    ValueChanged<String>? onChanged,
  }) {
    return SizedBox(
      width: 32,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        cursorColor: c.live,
        cursorWidth: 1.5,
        style: EType.display(
          size: 18,
          color: c.ink,
          letterSpacing: 0,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          filled: true,
          fillColor: c.terrace,
          border: _border(c.hairline),
          enabledBorder: _border(c.hairline),
          focusedBorder: _border(c.live),
        ),
        inputFormatters: [
          LengthLimitingTextInputFormatter(1),
          FilteringTextInputFormatter.digitsOnly,
        ],
      ),
    );
  }

  OutlineInputBorder _border(Color col) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: BorderSide(color: col, width: 1),
      );
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});
  final Color color;
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = Curves.easeInOut.transform(_c.value);
        return Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.25 + 0.45 * t),
                blurRadius: 4 + 6 * t,
                spreadRadius: 0.5 + 1.5 * t,
              ),
            ],
          ),
        );
      },
    );
  }
}
