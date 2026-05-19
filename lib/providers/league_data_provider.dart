import 'package:flutter/material.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:football/resources/league_config_service.dart';
import 'package:football/resources/usersMethods.dart';
import 'package:football/theme/colors.dart';
import 'package:football/theme/typography.dart';
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

    print('Raw chosenLeagues data: $chosenLeagues');
    print('chosenLeagues type: ${chosenLeagues.runtimeType}');

    if (chosenLeagues == null) {
      print('chosenLeagues is null');
      return LeagueData(enabledLeagues: [], options: [], imageUrls: []);
    }

    // Convert to Map<String, bool> safely
    Map<String, bool> leaguesMap = {};
    if (chosenLeagues is Map) {
      chosenLeagues.forEach((key, value) {
        leaguesMap[key.toString()] = value == true;
      });
    }

    print('Converted leaguesMap: $leaguesMap');

    final enabledLeagues = <int>[];
    final options = <String>[];
    final imageUrls = <String>[];

    // League universe comes from the backend config (LeagueConfigService) so a
    // new league appears here with no app update. The per-user chosenLeagues
    // filter below is unchanged.
    for (final leagueId in LeagueConfigService().supportedLeagues) {
      // Check if this league is chosen (true in chosenLeagues)
      final isChosen = leaguesMap[leagueId.toString()] == true;

      print('League $leagueId: $isChosen');

      if (isChosen) {
        enabledLeagues.add(leagueId);
        options.add(getLocalizedLeagueName(leagueId, context));
        imageUrls.add(getLeagueImageUrl(leagueId));
      }
    }

    print('Final enabledLeagues: $enabledLeagues');
    print('Final options: $options');

    return LeagueData(
      enabledLeagues: enabledLeagues,
      options: options,
      imageUrls: imageUrls,
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
  bool _isLoading = true;
  bool _singleNotified = false;

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
        setState(() {
          _leagueData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 50,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
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
      final name = _leagueData!.options.isNotEmpty
          ? _leagueData!.options.first
          : '';
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c.cardHi, c.card],
        ),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: c.hairline, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (imageUrl != null)
            Container(
              width: 52,
              height: 52,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: c.pitch,
                shape: BoxShape.circle,
                border: Border.all(color: c.live, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: c.live.withOpacity(0.18),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Image.network(
                imageUrl!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                    Icons.emoji_events_outlined,
                    size: 22,
                    color: c.live),
              ),
            ),
          const SizedBox(height: 14),
          Text(
            name,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
            style: EType.body(
              color: c.ink,
              size: 22,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          // Editorial signature accent — short centered rule, flanked by dots.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 4,
                height: 4,
                decoration:
                    BoxDecoration(color: c.live, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Container(width: 40, height: 2, color: c.live),
              const SizedBox(width: 8),
              Container(
                width: 4,
                height: 4,
                decoration:
                    BoxDecoration(color: c.live, shape: BoxShape.circle),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
