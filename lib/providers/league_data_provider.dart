import 'package:flutter/material.dart';
import 'package:football/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:football/resources/usersMethods.dart';
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

  // League configuration - maps league ID to its string key
  static const Map<int, String> _leagueKeys = {
    2: '2',
    383: '383',
    140: '140',
    3: '3',
    39: '39',
    78: '78',
    848: '848',
    // 15: '15',
  };

  // Check if cache is valid
  bool _isCacheValid() {
    return _lastCacheUpdate != null &&
        DateTime.now().difference(_lastCacheUpdate!) < _cacheExpiry;
  }

  // Get localized league name
  String getLocalizedLeagueName(int id, BuildContext context) {
    try {
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

    // Check each league ID to see if it's enabled
    for (final entry in _leagueKeys.entries) {
      final leagueId = entry.key;
      final leagueKey = entry.value;

      // Check if this league is chosen (true in chosenLeagues)
      final isChosen = leaguesMap[leagueKey] == true;

      print('League $leagueId (key: $leagueKey): $isChosen');

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
