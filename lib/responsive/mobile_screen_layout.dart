import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter/src/widgets/placeholder.dart';
import 'package:football/theme/colors.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../utils/colors.dart';
import '../utils/global_variables.dart';
import 'package:google_fonts/google_fonts.dart';

class MobileScreenLayout extends StatefulWidget {
  const MobileScreenLayout({Key? key}) : super(key: key);

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
  }

  @override
  void dispose() {
    super.dispose();
    pageController.dispose();
  }

  void onPageChanged(int page) {
    setState(() {
      _page = page;
    });
  }

  void navigationTapped(int page) {
    pageController.jumpToPage(page);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        children: homeScreenItems,
        physics: const NeverScrollableScrollPhysics(),
        controller: pageController,
        onPageChanged: onPageChanged,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: CupertinoTabBar(
          backgroundColor: mobileBackgroundColor,
          activeColor: Colors.blue,
          inactiveColor: Colors.grey,
          border: Border(
            top: BorderSide(
              color: Colors.black.withOpacity(0.1),
              width: 0.5,
            ),
          ),
          items: <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(
                Icons.person_outlined,
                size: 26,
                color: (_page == 0) ? Colors.blue : Colors.grey,
              ),
              activeIcon: Icon(
                Icons.person,
                size: 26,
                color: Colors.blue,
              ),
              label: AppLocalizations.of(context)!.profile,
            ),
            BottomNavigationBarItem(
              icon: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.scoreboard_outlined,
                    size: 26,
                    color: (_page == 1) ? Colors.blue : Colors.grey,
                  ),
                  Positioned(
                    bottom: 2,
                    child: Container(
                      width: 12,
                      height: 12,
                      child: Icon(
                        Icons.sports_soccer,
                        size: 10,
                        color: (_page == 1) ? Colors.blue : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
              activeIcon: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.scoreboard,
                    size: 26,
                    color: Colors.blue,
                  ),
                  Positioned(
                    bottom: 2,
                    child: Container(
                      width: 12,
                      height: 12,
                      child: Icon(
                        Icons.sports_soccer,
                        size: 10,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
              label: AppLocalizations.of(context)!.results,
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.leaderboard_outlined,
                size: 26,
                color: (_page == 2) ? Colors.blue : Colors.grey,
              ),
              activeIcon: Icon(
                Icons.leaderboard,
                size: 26,
                color: Colors.blue,
              ),
              label: AppLocalizations.of(context)!.table,
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.settings_outlined,
                size: 26,
                color: (_page == 3) ? Colors.blue : Colors.grey,
              ),
              activeIcon: Icon(
                Icons.settings,
                size: 26,
                color: Colors.blue,
              ),
              label: AppLocalizations.of(context)!.preferences,
            ),
          ],
          onTap: navigationTapped,
          currentIndex: _page,
        ),
      ),
    );
  }
}
