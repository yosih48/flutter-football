import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:football/models/games.dart';
import 'package:football/models/guesses.dart';
import 'package:football/theme/colors.dart';
import 'package:football/utils/status_utils.dart';
import 'package:football/widgets/teamLInks.dart';

import 'package:intl/intl.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

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
    // Set initial values for controllers if a guess exists
    if (guess != null) {
      homeController!.text = guess!.homeTeamGoals.toString();
      awayController!.text = guess!.awayTeamGoals.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isValid = homeController?.text.isNotEmpty ?? false;
    final info = StatusUtils.getStatusInfo(game.status.short, context);
    
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: cards,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(context),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildHeader(context, info),
                SizedBox(height: 20),
                _buildTeamsRow(context, isValid),
                if (game.status.long == "Not Started") ...[
                   SizedBox(height: 16),
                   _buildOdds(),
                ],
                SizedBox(height: 16),
                 _buildFooter(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Map<String, dynamic> info) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Status/Time
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: (game.status.long == "First Half" || 
                   game.status.long == "Second Half" || 
                   info['text'] == 'LIVE') 
                   ? Colors.red.withOpacity(0.2) 
                   : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              if (game.status.long == "First Half" || 
                  game.status.long == "Second Half" ||
                   info['text'] == 'LIVE')
                Container(
                  width: 6,
                  height: 6,
                  margin: EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              Text(
                 (game.status.long == "First Half" || game.status.long == "Second Half")
                  ? "${game.status.elapsed}'"
                  : info['text'],
                style: TextStyle(
                  color: (game.status.long == "First Half" || 
                          game.status.long == "Second Half" ||
                          info['text'] == 'LIVE')
                      ? Colors.red
                      : Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        
        // Date/Time if not live
        if (game.status.long == 'Not Started')
        Row(
          children: [
             Icon(Icons.access_time, size: 14, color: Colors.white54),
            SizedBox(width: 4),
            Text(
              DateFormat('HH:mm').format(game.date.toLocal()),
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTeamsRow(BuildContext context, bool isValid) {
    final bool isUpcoming = DateTime.now().isBefore(game.date.toLocal()) || 
                          game.status.long == "Not Started";

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Home Team
        Expanded(child: _buildTeamItem(game.home.name, game.home.logo, CrossAxisAlignment.start)),
        
        // Score or Input
        Container(
          width: 80,
          margin: EdgeInsets.symmetric(horizontal: 8),
          child: isUpcoming 
              ? _buildScoreInputs(isValid)
              : _buildFinalScore(),
        ),

        // Away Team
        Expanded(child: _buildTeamItem(game.away.name, game.away.logo, CrossAxisAlignment.end)),
      ],
    );
  }

  Widget _buildTeamItem(String name, String logoUrl, CrossAxisAlignment alignment) {
    return GestureDetector(
       onTap: () => TeamLinkHandler.linkToTeam(name),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Image.network(
            logoUrl,
            width: 40,
            height: 40,
            errorBuilder: (context, error, stackTrace) => 
               Container(
                  width: 40,
                  height: 40,
                   decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(8),
                   ),
                  child: Icon(Icons.shield, color: Colors.white30, size: 20),
               ),
          ),
          SizedBox(height: 8),
          Text(
            name,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
             textAlign: alignment == CrossAxisAlignment.start ? TextAlign.left : TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildScoreInputs(bool isValid) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildInputBox(homeController, isValid),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(":", style: TextStyle(color: Colors.white30, fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        _buildInputBox(awayController, isValid),
      ],
    );
  }

  Widget _buildInputBox(TextEditingController? controller, bool isValid) {
    return Container(
      width: 32,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF2A3238),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isValid ? Colors.transparent : Colors.red.withOpacity(0.5),
        ),
      ),
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
          inputFormatters: [
            LengthLimitingTextInputFormatter(1),
            FilteringTextInputFormatter.digitsOnly,
        ],
      ),
    );
  }

  Widget _buildFinalScore() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
       decoration: BoxDecoration(
        color: const Color(0xFF2A3238),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${game.goals.home} - ${game.goals.away}',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
         textAlign: TextAlign.center,
      ),
    );
  }
    Widget _buildOdds() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
         color: Colors.white.withOpacity(0.03),
         borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
            _buildOddItem("1", game.odds.home.toString()),
            _buildOddItem("X", game.odds.draw.toString()),
            _buildOddItem("2", game.odds.away.toString()),
        ],
      ),
    );
  }

  Widget _buildOddItem(String label, String value) {
     return Row(
       children: [
         Text(
           label,
           style: TextStyle(color: Colors.white38, fontSize: 12),
         ),
          SizedBox(width: 4),
          Text(
           value,
           style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
         ),
       ],
     );
  }


  Widget _buildFooter(BuildContext context) {
      if (guess == null && game.status.long != 'Not Started') return SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primary.withOpacity(0.2), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (guess != null) ...[
             Text(
            AppLocalizations.of(context)!.yourguess,
            style: TextStyle(color: primary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          Text(
            '${guess!.homeTeamGoals} - ${guess!.awayTeamGoals}',
            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
           Text(
             '${guess!.sumPoints % 1 == 0 ? guess!.sumPoints.toInt() : guess!.sumPoints} pts',
             style: TextStyle(color: primary, fontSize: 12, fontWeight: FontWeight.w600),
           ),
          ] else ...[
             Text(
                "Prediction missing",
                style: TextStyle(color: Colors.white54, fontSize: 12),
             ),
             Text('-- : --', style: TextStyle(color: Colors.white54)),
          ]
        ],
      ),
    );
  }
}
