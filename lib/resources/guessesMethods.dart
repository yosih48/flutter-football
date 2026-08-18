import 'dart:convert';
import 'package:football/utils/config.dart';
import 'package:http/http.dart' as http;
import 'package:football/models/guesses.dart';

String _baseUrl = backendUrl;

class GuessesMethods {
  Future<List<Guess>> fetchThisUserGuesses(String clientId) async {
    print('clientId ${clientId}');
    final url = Uri.parse('$_baseUrl/guesses/$clientId');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        // final guessData = responseData

        if (responseData != null && responseData is List) {
          final guess = (responseData as List)
              .map((item) => Guess.fromJson(item))
              .toList();

          return guess;
        } else {
          throw Exception('Guess data is null or not a list');
        }
      } else {
        throw Exception('Failed to load guesses');
      }
    } catch (e) {
      throw Exception('Error fetching guesses: $e');
    }
  }

 Future<List<Guess>> fetchAllUsersGuesses(int gameId) async {
    print('clientId: ${gameId}');
    final url = Uri.parse('$_baseUrl/guesses/gameOriginal/$gameId');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
      

        // Handle null or empty response
        if (responseData == null) {
          print('No guesses found - returning empty list');
          return <Guess>[];
        }

        if (responseData is List) {
      

          // Handle empty list
          if (responseData.isEmpty) {
            print('Empty guesses list - returning empty list');
            return <Guess>[];
          }

          final guess = (responseData as List)
              .map((item) => Guess.fromJson(item))
              .toList();

          print('fetchAllUsersGuesses: ${guess.first.userId}');
          return guess;
        } else {
          print('Guess data is not a list - returning empty list');
          return <Guess>[];
        }
      } else {
        print('Failed to load guesses');
        throw Exception('Failed to load guesses');
      }
    } catch (e) {
      print('Error fetching guesses');
      throw Exception('Error fetching guesses: $e');
    }
  }

  /// One round-trip replacement for `fetchAllUsersGuesses` + per-user
  /// `getGuessWithNames` fan-out. Backend joins guesses with each user's
  /// displayName + groupID and (optionally) filters by group membership
  /// server-side. See `/guesses/gameOriginal/:id/with-users`.
  ///
  /// Returns an empty list on 404 / non-list responses to match the legacy
  /// flow's tolerance for missing data.
  Future<List<GuessWithNames>> fetchGuessesWithUsers(
      int gameId, {
      String? groupName,
      }) async {
    final qs = (groupName != null && groupName.isNotEmpty)
        ? '?group=${Uri.encodeQueryComponent(groupName)}'
        : '';
    final url =
        Uri.parse('$_baseUrl/guesses/gameOriginal/$gameId/with-users$qs');

    try {
      final response = await http.get(url);
      // 404 = backend doesn't have the new bulk endpoint yet. Fall back to
      // the legacy 1 + N×2 path so the client works against old deployments.
      if (response.statusCode == 404) {
        print(
            'fetchGuessesWithUsers: bulk endpoint not deployed yet, falling back');
        return _fetchGuessesWithUsersLegacy(gameId, groupName: groupName);
      }
      if (response.statusCode != 200) {
        print('fetchGuessesWithUsers: HTTP ${response.statusCode}');
        return <GuessWithNames>[];
      }
      final body = jsonDecode(response.body);
      if (body is! List) return <GuessWithNames>[];

      return body.map<GuessWithNames>((row) {
        final map = Map<String, dynamic>.from(row as Map);
        final guess = Guess.fromJson(Map<String, dynamic>.from(map['guess']));
        final userName = (map['userName'] ?? '').toString();
        final userGroups = Map<String, String>.from(
            (map['userGroups'] as Map?)?.map(
                  (k, v) => MapEntry(k.toString(), v.toString()),
                ) ??
                {});
        return GuessWithNames(guess, userName, userGroups);
      }).toList();
    } catch (e) {
      print('Error fetchGuessesWithUsers (falling back to legacy): $e');
      // Network/parse errors → try legacy path too. Worst case, that also
      // fails and we return an empty list as before.
      try {
        return await _fetchGuessesWithUsersLegacy(gameId, groupName: groupName);
      } catch (_) {
        return <GuessWithNames>[];
      }
    }
  }

  /// Legacy path: fetch the guess list, then fan out per-user name+groups.
  /// Used as a fallback when the bulk `/with-users` endpoint isn't present
  /// (older backend deployments) so the client keeps working during rollout.
  Future<List<GuessWithNames>> _fetchGuessesWithUsersLegacy(
      int gameId, {
      String? groupName,
      }) async {
    final guesses = await fetchAllUsersGuesses(gameId);
    final callService = CallService();
    final results = await Future.wait(
      guesses.map((g) async {
        try {
          return await callService.getGuessWithNames(g);
        } catch (e) {
          print('Skipping guess due to error: $e');
          return null;
        }
      }),
    );
    final list = results.whereType<GuessWithNames>().toList();
    if (groupName == null || groupName.isEmpty) return list;
    return list
        .where((g) => g.userGroups.values.contains(groupName))
        .toList();
  }

  /// One-shot bulk submit. Replaces the screen's old per-guess POST/PUT loop
  /// with a single `POST /guesses/bulk`; the backend upserts every guess in one
  /// `bulkWrite` after a single kickoff-lock check.
  ///
  /// [guesses] is a list of maps, each:
  ///   { gameID, gameOriginalID, leagueID, home_team_goals, away_team_goals }
  ///
  /// Returns the user's full guess list after the write (so the caller skips a
  /// separate refetch). Returns `null` when the bulk endpoint isn't deployed
  /// yet (404) so the caller can fall back to the legacy per-guess path —
  /// mirrors the rollout-safety pattern used by [fetchGuessesWithUsers].
  /// Throws on other non-200 responses so real failures surface to the user.
  Future<List<Guess>?> submitGuessesBulk({
    required String userID,
    required String email,
    required List<Map<String, dynamic>> guesses,
  }) async {
    final url = Uri.parse('$_baseUrl/guesses/bulk');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userID': userID,
        'email': email,
        'guesses': guesses,
      }),
    );

    // Bulk endpoint not present on this deployment — signal the caller to fall
    // back to the legacy per-guess path.
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw Exception('Bulk submit failed: HTTP ${response.statusCode}');
    }

    final body = jsonDecode(response.body);
    final list = (body is Map && body['guesses'] is List)
        ? body['guesses'] as List
        : const [];
    return list.map((item) => Guess.fromJson(item)).toList();
  }

  Future<String> fetchUserName(String userId) async {
    final response = await http.get(Uri.parse('$_baseUrl/users/${userId}'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      // print(response.body);
      return data['displayName'];
    } else {
      throw Exception('Failed to load user name');
    }
  }

  Future<Map<String, String>> fetchUserGroup(String userId) async {
    final response = await http.get(Uri.parse('$_baseUrl/users/${userId}'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      // print(response.body);
      return Map<String, String>.from(data['groupID']);
    } else {
      throw Exception('Failed to load user name');
    }
  }
}
