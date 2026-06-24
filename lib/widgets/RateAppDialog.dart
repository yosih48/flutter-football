import 'package:flutter/material.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:football/resources/rate_app_service.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:url_launcher/url_launcher.dart';

/// Play Store page for this app. The `market://` deep link opens the native
/// Play Store app directly; the https URL is the web fallback.
const String _kPlayMarketUrl = 'market://details?id=com.yosi.football';
const String _kPlayWebUrl =
    'https://play.google.com/store/apps/details?id=com.yosi.football';

/// Records that the prompt is being shown, then displays the rate-app dialog.
/// Eligibility must already have been checked via [RateAppService.shouldPrompt].
Future<void> showRateAppDialog(BuildContext context) async {
  await RateAppService().markPromptShown();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const RateAppDialog(),
  );
}

class RateAppDialog extends StatelessWidget {
  const RateAppDialog({super.key});

  Future<void> _openStore() async {
    // Try the native Play Store app first, then fall back to the web URL.
    try {
      final market = Uri.parse(_kPlayMarketUrl);
      if (await canLaunchUrl(market)) {
        await launchUrl(market, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {
      // fall through to web URL
    }
    try {
      await launchUrl(Uri.parse(_kPlayWebUrl),
          mode: LaunchMode.externalApplication);
    } catch (_) {
      // Honor the user's "Rate now" intent regardless — dialog already closed
      // and status marked done; swallow launch failures (logged by the OS).
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    final l = AppLocalizations.of(context)!;
    final service = RateAppService();

    return AlertDialog(
      backgroundColor: c.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: c.hairline, width: 1),
      ),
      title: Row(
        children: [
          Icon(Icons.star_rounded, color: c.live, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l.rateAppTitle,
              style: EType.body(color: c.ink, size: 17, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
      content: Text(
        l.rateAppMessage,
        style: EType.body(color: c.inkDim, size: 14),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: [
        TextButton(
          onPressed: () async {
            await service.markDismissed();
            if (context.mounted) Navigator.of(context).pop();
          },
          child: Text(
            l.rateAppNoThanks,
            style: EType.body(color: c.inkDim, size: 13),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () async {
                await service.markSnoozed();
                if (context.mounted) Navigator.of(context).pop();
              },
              child: Text(
                l.rateAppLater,
                style: EType.body(color: c.ink, size: 13),
              ),
            ),
            const SizedBox(width: 4),
            TextButton(
              onPressed: () async {
                await service.markRated();
                if (context.mounted) Navigator.of(context).pop();
                await _openStore();
              },
              child: Text(
                l.rateAppRateNow,
                style: EType.body(
                    color: c.live, size: 13, weight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
