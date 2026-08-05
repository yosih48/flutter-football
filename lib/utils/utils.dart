import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:football/models/games.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:football/l10n/app_localizations.dart';

/// Tone classifies the message intent. Drives accent color + leading icon.
enum SnackTone { neutral, success, error, warning }

/// Editorial-style floating snackbar.
///
/// Matches the redesigned league header buttons: rounded 14, cardHi surface,
/// hairline border, soft shadow, Sora typography, with a left accent bar +
/// tone icon. Backwards-compatible — existing two-arg callers default to
/// `SnackTone.neutral`.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSnackBar(
  BuildContext context,
  String text, {
  SnackTone tone = SnackTone.neutral,
  Duration duration = const Duration(milliseconds: 2800),
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final c =
      Theme.of(context).extension<EditorialColors>() ?? EditorialColors.dark;

  final (Color accent, IconData icon) = switch (tone) {
    SnackTone.success => (c.live, Icons.check_rounded),
    SnackTone.error => (c.flag, Icons.error_outline_rounded),
    SnackTone.warning => (c.amber, Icons.warning_amber_rounded),
    SnackTone.neutral => (c.ink, Icons.info_outline_rounded),
  };

  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();

  return messenger.showSnackBar(
    buildEditorialSnackBar(
      text: text,
      colors: c,
      tone: tone,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction == null
          ? null
          : () {
              messenger.hideCurrentSnackBar();
              onAction();
            },
    ),
  );
}

/// Build an editorial SnackBar without a BuildContext.
///
/// Useful when the navigator has already moved on (e.g. after
/// `pushAndRemoveUntil`) and only a `ScaffoldMessengerState` reference
/// remains. Pass colors explicitly.
SnackBar buildEditorialSnackBar({
  required String text,
  required EditorialColors colors,
  SnackTone tone = SnackTone.neutral,
  Duration duration = const Duration(milliseconds: 2800),
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final (Color accent, IconData icon) = switch (tone) {
    SnackTone.success => (colors.live, Icons.check_rounded),
    SnackTone.error => (colors.flag, Icons.error_outline_rounded),
    SnackTone.warning => (colors.amber, Icons.warning_amber_rounded),
    SnackTone.neutral => (colors.ink, Icons.info_outline_rounded),
  };

  return SnackBar(
    duration: duration,
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.transparent,
    elevation: 0,
    padding: EdgeInsets.zero,
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
    dismissDirection: DismissDirection.horizontal,
    content: _EditorialSnackContent(
      text: text,
      accent: accent,
      icon: icon,
      colors: colors,
      actionLabel: actionLabel,
      onAction: onAction,
    ),
  );
}

class _EditorialSnackContent extends StatelessWidget {
  final String text;
  final Color accent;
  final IconData icon;
  final EditorialColors colors;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EditorialSnackContent({
    required this.text,
    required this.accent,
    required this.icon,
    required this.colors,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isHe = Localizations.localeOf(context).languageCode == 'he';
    return Container(
      decoration: BoxDecoration(
        color: colors.cardHi,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: colors.hairlineHi.withOpacity(0.55), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: accent.withOpacity(0.12),
            blurRadius: 20,
            spreadRadius: -4,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left accent bar — tone-colored seam.
              Container(width: 3, color: accent),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: accent, size: 18),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    text,
                    style: EType.body(
                      color: colors.ink,
                      size: 13,
                      weight: FontWeight.w500,
                      height: 1.35,
                      hebrew: isHe,
                    ),
                  ),
                ),
              ),
              if (actionLabel != null && onAction != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      foregroundColor: accent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      actionLabel!.toUpperCase(),
                      style: EType.label(
                        color: accent,
                        size: 11,
                        letterSpacing: 1.4,
                        hebrew: isHe,
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(width: 14),
            ],
          ),
        ),
      ),
    );
  }
}

/// Loads and parses fake_games.json from assets into a List<Game>.
Future<List<Game>> loadFakeGames() async {
  final String jsonString =
      await rootBundle.loadString('assets/fake_games.json');
  final List<dynamic> jsonList = json.decode(jsonString);
  return jsonList.map((e) => Game.fromJson(e)).toList();
}

void showForceUpdateDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false, // אי אפשר לסגור בלחיצה בצד
    barrierColor: Colors.black.withOpacity(0.72),
    builder: (BuildContext context) {
      final c = context.col;
      final l = AppLocalizations.of(context)!;
      // WillPopScope (או PopScope בגרסאות חדשות) מונע לחיצה על כפתור "חזור" במכשיר
      return WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          backgroundColor: c.card,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(color: c.hairline, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Accent icon badge
                Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    color: c.liveSoft,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.live, width: 1.5),
                  ),
                  child: Icon(Icons.rocket_launch_outlined,
                      size: 30, color: c.live),
                ),
                const SizedBox(height: 20),
                Text(
                  l.forceUpdateTitle,
                  textAlign: TextAlign.center,
                  style: EType.body(
                      size: 24,
                      color: c.ink,
                      weight: FontWeight.w700,
                      hebrew:
                          Localizations.localeOf(context).languageCode == 'he'),
                ),
                const SizedBox(height: 12),
                Text(
                  l.forceUpdateContent,
                  textAlign: TextAlign.center,
                  style: EType.body(color: c.inkMute, size: 14, height: 1.5),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  child: Material(
                    color: c.live,
                    borderRadius: BorderRadius.circular(2),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(2),
                      onTap: _launchStore,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.system_update, size: 18, color: c.pitch),
                            const SizedBox(width: 8),
                            Text(
                              l.forceUpdateButton.toUpperCase(),
                              style: EType.label(
                                  color: c.pitch, size: 12, letterSpacing: 1.6),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

void _launchStore() {
  // שים פה את הלינק שלך לחנות!
  const androidUrl =
      'https://play.google.com/store/apps/details?id=com.yosi.football';
  // const iosUrl = 'https://apps.apple.com/...';

  final url = Uri.parse(Platform.isAndroid
      ? androidUrl
      : androidUrl); // כרגע שמתי אנדרואיד לשניהם
  launchUrl(url, mode: LaunchMode.externalApplication);
}
