import 'package:flutter/material.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:football/widgets/trophyCabinet.dart';

// Dedicated past-seasons screen, opened from the profile's cabinet entry card.
// Keeps the long per-season history off the main profile scroll.
class TrophyCabinetScreen extends StatelessWidget {
  const TrophyCabinetScreen({
    super.key,
    required this.userId,
  });

  final String userId;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: c.pitch,
      appBar: AppBar(
        backgroundColor: c.pitch,
        elevation: 0,
        iconTheme: IconThemeData(color: c.ink),
        title: Text(
          l.trophyCabinet,
          style: EType.screenTitle(
            size: 20,
            color: c.ink,
            hebrew: Localizations.localeOf(context).languageCode == 'he',
          ),
        ),
      ),
      body: SafeArea(
        // minHeight = viewport so the empty state can centre vertically in the
        // page instead of hugging the top. Content taller than the viewport
        // still scrolls normally.
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: TrophyCabinetTab(
                userId: userId,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
