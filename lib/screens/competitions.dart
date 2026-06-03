import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:football/resources/auth.dart';
import 'package:football/utils/league_logos.dart';
import 'package:football/resources/league_config_service.dart';
import 'package:football/responsive/mobile_screen_layout.dart';
import 'package:football/responsive/rsponsive_layout_screen.dart';
import 'package:football/responsive/web_screen_layout.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:football/utils/config.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

class Competitions extends StatefulWidget {
  final String userEmail;
  final String userName;

  const Competitions({
    super.key,
    required this.userEmail,
    required this.userName,
  });

  @override
  State<Competitions> createState() => _CompetitionsState();
}

class _CompetitionsState extends State<Competitions> {
  // League list comes from the backend config (LeagueConfigService) so leagues
  // can be added/removed by season without an app update.
  Map<int, bool> chosenLeagues = {
    for (final id in LeagueConfigService().supportedLeagues) id: false,
  };

  static const _leagueLogoBase =
      'https://media.api-sports.io/football/leagues/';

  Future<void> updateDatabase(String name, String email) async {
    final url = Uri.parse('$backendUrl/users/profile');
    try {
      final Map<String, bool> encodableLeagues = {};
      chosenLeagues.forEach((k, v) => encodableLeagues[k.toString()] = v);

      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'email': email,
          'displayName': name,
          'leagueData': {
            'championsLeague': false,
            'israeliLeague': false,
            'spanishLeague': false,
            'europeLeague': false,
            'premierLeague': false,
            'conferenceLeague': false,
            'clubworldcup': false,
            'africaLeague': false,
            'euroLeague': false,
            'copaLeague': false,
          },
          'chosenLeagues': encodableLeagues,
        }),
      );

      if (response.statusCode == 200) {
        final authProvider =
            Provider.of<AuthProvider>(context, listen: false);
        final nav = Navigator.of(context);
        await markFirstLoginComplete();
        await authProvider.markCurrentUserAsReturning();

        if (!mounted) return;
        nav.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const ResponsiveLayout(
              mobileScreenLayout: MobileScreenLayout(),
              webScreenLayout: WebScreenLayout(),
            ),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Error updating database: $e');
    }
  }

  Future<void> markFirstLoginComplete() async {
    try {
      await http.post(
        Uri.parse('$backendUrl/users/mark-first-login-complete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.userEmail}),
      );
    } catch (e) {
      debugPrint('Error marking first login complete: $e');
    }
  }

  // Backend-configured name wins (so a brand-new league shows a real name with
  // no app update); the localized map is the fallback for known leagues.
  String _leagueName(
      int id, BuildContext context, Map<int, String> fallback) {
    final remote = LeagueConfigService()
        .nameFor(id, Localizations.localeOf(context).languageCode);
    return remote ?? fallback[id] ?? '$id';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final l = AppLocalizations.of(context)!;
    final leagueNames = {
      2: l.championsleague,
      383: l.ligathaal,
      140: l.laliga,
      3: l.europaleague,
      39: l.premierleague,
      848: l.conferenceleague,
    };

    final anySelected = chosenLeagues.values.any((v) => v);

    return Scaffold(
      backgroundColor: c.pitch,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: c.pitch,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SETUP',
                    style: EType.label(
                        color: c.inkDim,
                        size: 10,
                        letterSpacing: 3)),
                const SizedBox(height: 2),
                Text(
                  l.chooseCompetitions.toUpperCase(),
                  style: EType.display(
                      size: 28,
                      color: c.ink,
                      letterSpacing: 1.4),
                ),
              ],
            ),
          ),

          // ── Section label ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Row(
              children: [
                Container(width: 18, height: 1, color: c.live),
                const SizedBox(width: 10),
                Text(
                  l.allCompetitions.toUpperCase(),
                  style: EType.label(
                      color: c.ink,
                      size: 11,
                      letterSpacing: 2.4),
                ),
              ],
            ),
          ),

          // ── League grid ──────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                physics: const BouncingScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.85,
                ),
                itemCount: chosenLeagues.length,
                itemBuilder: (context, index) {
                  final id =
                      chosenLeagues.keys.elementAt(index);
                  final isSelected = chosenLeagues[id]!;
                  return _LeagueCard(
                    leagueName: _leagueName(id, context, leagueNames),
                    logoUrl: '$_leagueLogoBase$id.png',
                    selected: isSelected,
                    onTap: () => setState(
                        () => chosenLeagues[id] = !isSelected),
                  );
                },
              ),
            ),
          ),
        ],
      ),

      // ── Continue button ─────────────────────────────────────────
      // SafeArea here pushes the button up above the system gesture/nav bar
      // on phones whose OS reserves space at the bottom of the screen.
      bottomNavigationBar: SafeArea(
        top: false,
        left: false,
        right: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: GestureDetector(
          onTap: anySelected
              ? () => updateDatabase(widget.userName, widget.userEmail)
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 52,
            decoration: BoxDecoration(
              color: anySelected ? c.live : c.card,
              border: Border.all(
                color: anySelected ? c.live : c.hairline,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
            alignment: Alignment.center,
            child: Text(
              l.continueButton.toUpperCase(),
              style: EType.label(
                color: anySelected ? c.pitch : c.inkDim,
                size: 12,
                letterSpacing: 2.4,
              ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}

// ── League card — identical pattern to favorits.dart ─────────────────────
class _LeagueCard extends StatelessWidget {
  const _LeagueCard({
    required this.leagueName,
    required this.logoUrl,
    required this.selected,
    required this.onTap,
  });
  final String leagueName;
  final String logoUrl;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: selected ? c.liveSoft : c.card,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
            color: selected ? c.live : c.hairline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo + check badge
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // White circle
                Container(
                  width: 52,
                  height: 52,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? c.live : c.hairline,
                      width: 1.5,
                    ),
                  ),
                  child: Image(
                    image: leagueLogoProviderForUrl(logoUrl),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.shield_outlined,
                      size: 20,
                      color: c.inkDim,
                    ),
                  ),
                ),
                // Check badge
                Positioned(
                  top: 0,
                  right: 0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: selected ? c.live : c.card,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? c.live : c.hairlineHi,
                        width: 1,
                      ),
                    ),
                    child: selected
                        ? Icon(Icons.check, size: 9, color: c.pitch)
                        : null,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                leagueName.toUpperCase(),
                style: EType.label(
                  color: selected ? c.live : c.inkMute,
                  size: 9,
                  letterSpacing: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
