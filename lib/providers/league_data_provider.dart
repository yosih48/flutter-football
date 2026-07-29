import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:football/resources/league_config_service.dart';
import 'package:football/resources/usersMethods.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
import 'package:football/utils/league_logos.dart';
import 'package:football/widgets/LeagueSelectorChips.dart';
import 'package:football/widgets/toggleButton.dart';

class LeagueDataProvider extends ChangeNotifier {
  static final LeagueDataProvider _instance = LeagueDataProvider._internal();
  factory LeagueDataProvider() => _instance;
  LeagueDataProvider._internal();

  // Cache for user league data
  Map<String, Map<String, dynamic>> _userLeagueCache = {};
  DateTime? _lastCacheUpdate;
  static const Duration _cacheExpiry = Duration(minutes: 5);

  // Check if cache is valid
  bool _isCacheValid() {
    return _lastCacheUpdate != null &&
        DateTime.now().difference(_lastCacheUpdate!) < _cacheExpiry;
  }

  // Get localized league name
  String getLocalizedLeagueName(int id, BuildContext context) {
    try {
      final remote = LeagueConfigService()
          .nameFor(id, Localizations.localeOf(context).languageCode);
      if (remote != null) return remote;
      final localizations = AppLocalizations.of(context);
      if (localizations == null) {
        print('AppLocalizations is null, using fallback names');
        return _getFallbackLeagueName(id, context);
      }

      switch (id) {
        case 2:
          return AppLocalizations.of(context)!.championsleague;
        case 383:
          return AppLocalizations.of(context)!.ligathaal;
        case 140:
          return AppLocalizations.of(context)!.laliga;
        case 3:
          return AppLocalizations.of(context)!.europaleague;
        case 39:
          return AppLocalizations.of(context)!.premierleague;
        case 78:
          return AppLocalizations.of(context)!.bundesleague;
        case 848:
          return AppLocalizations.of(context)!.conferenceleague;
        // case 15:
        //   return AppLocalizations.of(context)!.clubworldcup;
        default:
          return _getFallbackLeagueName(id, context);
      }
    } catch (e) {
      print('Error getting localized name for league $id: $e');
      return _getFallbackLeagueName(id, context);
    }
  }

  // Fallback names when localization fails
  String _getFallbackLeagueName(int id, context) {
    switch (id) {
      case 2:
        return AppLocalizations.of(context)!.championsleague;
      case 383:
        return AppLocalizations.of(context)!.ligathaal;
      case 140:
        return AppLocalizations.of(context)!.laliga;
      case 3:
        return AppLocalizations.of(context)!.europaleague;
      case 39:
        return AppLocalizations.of(context)!.premierleague;
      case 78:
        return AppLocalizations.of(context)!.bundesleague;
      case 848:
        return AppLocalizations.of(context)!.conferenceleague;
      // case 15:
      //   return AppLocalizations.of(context)!.clubworldcup;
      default:
        return 'League $id';
    }
  }

  // Get league image URL
  String getLeagueImageUrl(int id) {
    return 'https://media.api-sports.io/football/leagues/$id.png';
  }

  // Fetch and cache user league data
  Future<LeagueData> getUserLeagueData(
      String userId, BuildContext context) async {
    // Return cached data if valid
    if (_isCacheValid() && _userLeagueCache.containsKey(userId)) {
      return _createLeagueDataFromCache(userId, context);
    }

    try {
      // Fetch fresh data
      final userData = await UsersMethods().fetchUserById(userId);

      // Cache the raw user data
      _userLeagueCache[userId] = userData;
      _lastCacheUpdate = DateTime.now();

      return _createLeagueDataFromUserData(userData, context);
    } catch (e) {
      print('Error fetching user league data: $e');
      // Return empty data on error
      return LeagueData(
        enabledLeagues: [],
        options: [],
        imageUrls: [],
      );
    }
  }

  LeagueData _createLeagueDataFromCache(String userId, BuildContext context) {
    final userData = _userLeagueCache[userId]!;
    return _createLeagueDataFromUserData(userData, context);
  }

  LeagueData _createLeagueDataFromUserData(
      Map<String, dynamic> userData, BuildContext context) {
    final chosenLeagues = userData['chosenLeagues'];

    if (chosenLeagues == null) {
      return LeagueData(enabledLeagues: [], options: [], imageUrls: []);
    }

    Map<String, bool> leaguesMap = {};
    if (chosenLeagues is Map) {
      chosenLeagues.forEach((key, value) {
        leaguesMap[key.toString()] = value == true;
      });
    }

    final enabledLeagues = <int>[];
    final options = <String>[];
    final imageUrls = <String>[];

    for (final leagueId in LeagueConfigService().supportedLeagues) {
      final isChosen = leaguesMap[leagueId.toString()] == true;
      if (isChosen) {
        enabledLeagues.add(leagueId);
        options.add(getLocalizedLeagueName(leagueId, context));
        imageUrls.add(getLeagueImageUrl(leagueId));
      }
    }

    return LeagueData(
      enabledLeagues: enabledLeagues,
      options: options,
      imageUrls: imageUrls,
    );
  }

  // Synchronous placeholder built from the (already-loaded) supported-leagues
  // config so a screen can render real-looking chips on the first frame
  // instead of a spinner while the per-user chosenLeagues fetch is in flight.
  // Replaced as soon as the real data lands.
  LeagueData buildPlaceholderLeagueData(BuildContext context) {
    final ids = LeagueConfigService().supportedLeagues;
    return LeagueData(
      enabledLeagues: List<int>.from(ids),
      options: ids.map((id) => getLocalizedLeagueName(id, context)).toList(),
      imageUrls: ids.map((id) => getLeagueImageUrl(id)).toList(),
    );
  }

  // Clear cache when needed
  void clearCache() {
    _userLeagueCache.clear();
    _lastCacheUpdate = null;
    notifyListeners();
  }

  // Update cache for specific user
  void updateUserCache(String userId, Map<String, dynamic> userData) {
    _userLeagueCache[userId] = userData;
    _lastCacheUpdate = DateTime.now();
    notifyListeners();
  }
}

// Data class to hold league information
class LeagueData {
  final List<int> enabledLeagues;
  final List<String> options;
  final List<String> imageUrls;

  LeagueData({
    required this.enabledLeagues,
    required this.options,
    required this.imageUrls,
  });

  bool get isEmpty => enabledLeagues.isEmpty;

  int getInitialIndex(int currentLeague) {
    final index = enabledLeagues.indexOf(currentLeague);
    return index >= 0 ? index : 0;
  }
}

// Generic League Selector Widget
class LeagueSelector extends StatefulWidget {
  final String userId;
  final int currentLeague;
  final Function(int leagueId, int index) onSelectionChanged;
  final bool
      useToggleButtons; // true for ToggleButtonsSample, false for LeagueSelectorChips

  const LeagueSelector({
    Key? key,
    required this.userId,
    required this.currentLeague,
    required this.onSelectionChanged,
    this.useToggleButtons = false,
  }) : super(key: key);

  @override
  _LeagueSelectorState createState() => _LeagueSelectorState();
}

class _LeagueSelectorState extends State<LeagueSelector> {
  final LeagueDataProvider _provider = LeagueDataProvider();
  LeagueData? _leagueData;
  bool _singleNotified = false;
  bool _placeholderBuilt = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLeagueData();
    });
  }

  Future<void> _loadLeagueData() async {
    if (!mounted) return;

    try {
      final data = await _provider.getUserLeagueData(widget.userId, context);
      if (mounted) {
        setState(() => _leagueData = data);
      }
    } catch (e) {
      // Keep the placeholder visible on failure — better than a "no leagues"
      // wall while the next bootstrap retries.
    }
  }

  @override
  Widget build(BuildContext context) {
    // First frame: render placeholder chips (all supported leagues, localized
    // from the synchronous config) so the selector appears instantly. The
    // real per-user list swaps in once the fetch completes.
    if (_leagueData == null) {
      if (!_placeholderBuilt) {
        _leagueData = _provider.buildPlaceholderLeagueData(context);
        _placeholderBuilt = true;
      }
    }

    if (_leagueData == null || _leagueData!.isEmpty) {
      return Container(
        height: 50,
        child: Center(
          child: Text(
            'No leagues available',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    // Single-league mode (e.g. summer tournament like the World Cup with no
    // regular season running): drop the selector entirely and show a
    // full-width headline instead of one lonely toggle button.
    if (_leagueData!.enabledLeagues.length == 1) {
      final singleId = _leagueData!.enabledLeagues.first;
      final name =
          _leagueData!.options.isNotEmpty ? _leagueData!.options.first : '';
      final imageUrl = _leagueData!.imageUrls.isNotEmpty
          ? _leagueData!.imageUrls.first
          : null;

      // The selector is gone, so there's no tap to propagate the choice —
      // notify the parent once so the screen loads this league instead of
      // its default (e.g. table.dart defaults to league 2).
      if (!_singleNotified && widget.currentLeague != singleId) {
        _singleNotified = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onSelectionChanged(singleId, 0);
        });
      }

      return SingleLeagueHeadline(name: name, imageUrl: imageUrl);
    }

    final initialIndex = _leagueData!.getInitialIndex(widget.currentLeague);

    if (widget.useToggleButtons) {
      return ToggleButtonsSample(
        options: _leagueData!.options,
        imageUrls: _leagueData!.imageUrls,
        onSelectionChanged: (index) {
          final selectedLeagueId = _leagueData!.enabledLeagues[index];
          widget.onSelectionChanged(selectedLeagueId, index);
        },
        initialSelection: initialIndex,
      );
    } else {
      return LeagueSelectorChips(
        options: _leagueData!.options,
        leagueIds: _leagueData!.enabledLeagues,
        selectedIndex: initialIndex,
        onSelectionChanged: (index) {
          final selectedLeagueId = _leagueData!.enabledLeagues[index];
          widget.onSelectionChanged(selectedLeagueId, index);
        },
      );
    }
  }
}

// Full-width headline shown in place of the league selector when the
// backend exposes exactly one league. Logo + name, centered, no tap target.
class SingleLeagueHeadline extends StatelessWidget {
  const SingleLeagueHeadline({super.key, required this.name, this.imageUrl});

  final String name;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final c = context.col;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [c.cardHi, c.card],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.hairline, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (imageUrl != null) ...[
            // Light rounded backplate so any logo (dark or transparent) stays
            // legible against the dark card background.
            Container(
              width: 46,
              height: 46,
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Image(
                image: leagueLogoProviderForUrl(imageUrl!),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    Icon(Icons.emoji_events_outlined, size: 22, color: c.live),
              ),
            ),
            const SizedBox(width: 11),
          ],
          Flexible(
            child: Text(
              name,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: GoogleFonts.rubik(
                color: c.ink,
                fontSize: 19,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
