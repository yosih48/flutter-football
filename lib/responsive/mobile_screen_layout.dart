import 'package:flutter/material.dart';
import 'package:football/resources/rate_app_service.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:football/widgets/RateAppDialog.dart';
import '../utils/global_variables.dart';

class MobileScreenLayout extends StatefulWidget {
  const MobileScreenLayout({super.key});

  @override
  State<MobileScreenLayout> createState() => _MobileScreenLayoutState();
}

class _MobileScreenLayoutState extends State<MobileScreenLayout> {
  int _page = 1;
  late PageController pageController;

  @override
  void initState() {
    super.initState();
    pageController = PageController(initialPage: _page);
    _maybeShowRatePrompt();
  }

  // After the first frame, ask the user to rate the app if they've used it
  // enough and haven't already rated or declined. Never interrupts login or
  // onboarding because this screen only mounts for logged-in returning users.
  void _maybeShowRatePrompt() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (await RateAppService().shouldPrompt() && mounted) {
        await showRateAppDialog(context);
      }
    });
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  void onPageChanged(int page) => setState(() => _page = page);
  void navigationTapped(int page) => pageController.jumpToPage(page);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    final tabs = [
      _TabDef(
        label: l.profile,
        icon: Icons.person_outline,
        activeIcon: Icons.person,
      ),
      _TabDef(
        label: l.results,
        icon: Icons.sports_soccer_outlined,
        activeIcon: Icons.sports_soccer,
      ),
      _TabDef(
        label: l.table,
        icon: Icons.leaderboard_outlined,
        activeIcon: Icons.leaderboard,
      ),
      _TabDef(
        label: l.preferences,
        icon: Icons.favorite_border,
        activeIcon: Icons.favorite,
      ),
      _TabDef(
        label: l.settings,
        icon: Icons.tune_outlined,
        activeIcon: Icons.tune,
      ),
    ];

    return Scaffold(
      body: PageView(
        physics: const NeverScrollableScrollPhysics(),
        controller: pageController,
        onPageChanged: onPageChanged,
        children: homeScreenItems,
      ),
      bottomNavigationBar: _EditorialNavBar(
        tabs: tabs,
        currentIndex: _page,
        onTap: navigationTapped,
      ),
    );
  }
}

// ── Tab definition ────────────────────────────────────────────────────────
class _TabDef {
  const _TabDef({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

// ── Editorial nav bar ─────────────────────────────────────────────────────
class _EditorialNavBar extends StatelessWidget {
  const _EditorialNavBar({
    required this.tabs,
    required this.currentIndex,
    required this.onTap,
  });
  final List<_TabDef> tabs;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Container(
      decoration: BoxDecoration(
        color: c.terrace,
        border: Border(
          top: BorderSide(color: c.hairline, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(tabs.length, (i) {
              final active = i == currentIndex;
              final tab = tabs[i];
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      // Active green stripe
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 2,
                        color: active ? c.live : Colors.transparent,
                      ),

                      // Icon
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: Icon(
                                active ? tab.activeIcon : tab.icon,
                                key: ValueKey(active),
                                size: 22,
                                color: active ? c.live : c.inkDim,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              tab.label.toUpperCase(),
                              style: EType.label(
                                color: active ? c.live : c.inkFaint,
                                size: 8,
                                letterSpacing: 1.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
