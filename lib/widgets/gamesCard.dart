import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:football/models/games.dart';
import 'package:football/models/guesses.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:football/utils/status_utils.dart';
import 'package:football/widgets/teamLInks.dart';

import 'package:intl/intl.dart';
import 'package:football/l10n/app_localizations.dart';

class GameWidget extends StatelessWidget {
  final Game game;
  final Guess? guess;
  final Function(BuildContext) onTap;
  final TextEditingController? homeController;
  final TextEditingController? awayController;

  GameWidget({
    required this.game,
    this.guess,
    required this.onTap,
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
  bool get _isFinished =>
      game.status.short == 'FT' || game.status.short == 'AET';
  bool get _isHalftime => game.status.short == 'HT';
  bool get _isUpcoming => game.status.long == 'Not Started';
  bool get _kickoffPassed => DateTime.now().isAfter(game.date.toLocal());
  bool get _canGuess => !_kickoffPassed;

  Color get _accent {
    if (_isLive) return Editorial.live;
    if (_isHalftime) return Editorial.amber;
    if (_isFinished) return Editorial.inkDim;
    return Editorial.hairline;
  }

  @override
  Widget build(BuildContext context) {
    final info = StatusUtils.getStatusInfo(game.status.short, context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Editorial.card,
        borderRadius: BorderRadius.circular(2),
        child: InkWell(
          borderRadius: BorderRadius.circular(2),
          onTap: () => onTap(context),
          splashColor: Editorial.live.withOpacity(0.04),
          highlightColor: Colors.transparent,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Kit-stripe accent — colors the card by match state.
                Container(width: 3, color: _accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMeta(info),
                        const SizedBox(height: 14),
                        _buildMatchRow(),
                        if (_isUpcoming) ...[
                          const SizedBox(height: 14),
                          _buildOddsRow(),
                        ],
                        if (!_isUpcoming) ...[
                          const SizedBox(height: 12),
                          _buildGuessFooter(context),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMeta(Map<String, dynamic> info) {
    return Row(
      children: [
        _buildStatusPill(info),
        const Spacer(),
        if (_isUpcoming)
          Text(
            DateFormat('HH:mm').format(game.date.toLocal()),
            style: EType.numeric(
              color: Editorial.inkMute,
              size: 13,
              letterSpacing: 0.5,
            ),
          ),
        const SizedBox(width: 12),
        Text(
          DateFormat('dd.MM').format(game.date),
          style: EType.numeric(
            color: Editorial.inkDim,
            size: 11,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusPill(Map<String, dynamic> info) {
    if (_isLive) {
      final elapsed = game.status.elapsed;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulsingDot(color: Editorial.live),
          const SizedBox(width: 6),
          Text(
            elapsed != null ? "LIVE  ${elapsed}'" : 'LIVE',
            style: EType.label(
              color: Editorial.live,
              size: 10,
              letterSpacing: 1.8,
            ),
          ),
        ],
      );
    }
    if (_isHalftime) {
      return Text('HALF TIME',
          style: EType.label(
              color: Editorial.amber, size: 10, letterSpacing: 1.8));
    }
    if (_isFinished) {
      return Text('FULL TIME',
          style: EType.label(
              color: Editorial.inkMute, size: 10, letterSpacing: 1.8));
    }
    return Text(
      (info['text']?.toString() ?? '').toUpperCase(),
      style: EType.label(color: Editorial.inkDim, size: 10, letterSpacing: 1.8),
    );
  }

  Widget _buildMatchRow() {
    return Row(
      children: [
        Expanded(child: _buildTeamSide(game.home, alignEnd: true)),
        const SizedBox(width: 14),
        _buildTeamCrest(game.home),
        const SizedBox(width: 14),
        _buildCenter(),
        const SizedBox(width: 14),
        _buildTeamCrest(game.away),
        const SizedBox(width: 14),
        Expanded(child: _buildTeamSide(game.away, alignEnd: false)),
      ],
    );
  }

  Widget _buildTeamSide(Team team, {required bool alignEnd}) {
    return GestureDetector(
      onTap: () => TeamLinkHandler.linkToTeam(team.name),
      child: Text(
        team.name.toUpperCase(),
        textAlign: alignEnd ? TextAlign.right : TextAlign.left,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: EType.display(
          size: 16,
          letterSpacing: 0.6,
          height: 1.05,
          color: Editorial.ink,
        ),
      ),
    );
  }

  Widget _buildTeamCrest(Team team) {
    return GestureDetector(
      onTap: () => TeamLinkHandler.linkToTeam(team.name),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Editorial.cardHi,
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(5),
        child: Image.network(
          team.logo,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.shield_outlined,
            size: 16,
            color: Editorial.inkDim,
          ),
        ),
      ),
    );
  }

  Widget _buildCenter() {
    if (_canGuess && _isUpcoming) {
      return _GuessInput(
        homeController: homeController,
        awayController: awayController,
      );
    }
    final h = game.goals.home ?? 0;
    final a = game.goals.away ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Editorial.cardHi,
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        '$h  :  $a',
        style: EType.display(
          size: 26,
          color: _isLive ? Editorial.live : Editorial.ink,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildOddsRow() {
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

  Widget _buildGuessFooter(BuildContext context) {
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
              style: EType.label(color: Editorial.inkDim, size: 10),
            ),
            if (hasGuess)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Editorial.liveSoft,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  '${guess!.sumPoints % 1 == 0 ? guess!.sumPoints.toInt() : guess!.sumPoints} ${l.points.toUpperCase()}',
                  style: EType.label(
                    color: Editorial.live,
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
            color: hasGuess ? Editorial.ink : Editorial.inkFaint,
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: Editorial.terrace,
        border: Border.all(color: Editorial.hairline, width: 1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: EType.label(color: Editorial.inkDim, size: 10)),
          Text(
            value.toStringAsFixed(2),
            style: EType.numeric(
              color: Editorial.ink,
              size: 12,
              weight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuessInput extends StatelessWidget {
  const _GuessInput({this.homeController, this.awayController});
  final TextEditingController? homeController;
  final TextEditingController? awayController;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _digit(homeController),
        Padding(
          padding: const EdgeInsets.only(left: 6, right: 6, bottom: 20),
          child: Text(':',
              style: EType.display(
                size: 22,
                color: Editorial.inkDim,
                letterSpacing: 0,
              )),
        ),
        _digit(awayController),
      ],
    );
  }

  Widget _digit(TextEditingController? controller) {
    return SizedBox(
      width: 38,
      height: 44,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        cursorColor: Editorial.live,
        cursorWidth: 1.5,
        style: EType.display(
          size: 22,
          color: Editorial.ink,
          letterSpacing: 0,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: Editorial.terrace,
          border: _border(Editorial.hairline),
          enabledBorder: _border(Editorial.hairline),
          focusedBorder: _border(Editorial.live),
        ),
        inputFormatters: [
          LengthLimitingTextInputFormatter(1),
          FilteringTextInputFormatter.digitsOnly,
        ],
      ),
    );
  }

  OutlineInputBorder _border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: BorderSide(color: c, width: 1),
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
