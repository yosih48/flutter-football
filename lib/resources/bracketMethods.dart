import 'dart:convert';

import 'package:football/models/bracket.dart';
import 'package:football/utils/config.dart';
import 'package:http/http.dart' as http;

// API client for the bracket-prediction game. Talks to the /brackets routes on
// the backend plus the shared /users list for the bracket leaderboard.
class BracketMethods {
  final String _base = backendUrl;

  // GET /brackets/structure/:leagueId — static tournament structure.
  Future<BracketStructure?> fetchStructure(int leagueId) async {
    try {
      final res = await http
          .get(Uri.parse('$_base/brackets/structure/$leagueId'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      return BracketStructure.fromJson(jsonDecode(res.body));
    } catch (e) {
      print('fetchStructure failed: $e');
      return null;
    }
  }

  // GET /brackets/:userId/:leagueId?season= — this user's picks (empty shell if
  // none yet).
  Future<UserBracket?> fetchUserBracket(
    String userId,
    int leagueId, {
    int? season,
  }) async {
    try {
      final q = season != null ? '?season=$season' : '';
      final res = await http
          .get(Uri.parse('$_base/brackets/$userId/$leagueId$q'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      return UserBracket.fromJson(jsonDecode(res.body));
    } catch (e) {
      print('fetchUserBracket failed: $e');
      return null;
    }
  }

  // PUT /brackets — saves one slice of the bracket selected by [stage]. The
  // [picks] shape depends on the stage kind:
  //   groups   -> Map<String, List<String>> { "A": ["t1","t2"] }
  //   knockout -> List<String>
  //   champion -> String
  // Returns null on success or a server error message on failure (e.g. a
  // 409 when the stage is locked).
  Future<String?> saveStage({
    required String userId,
    required String email,
    required int leagueId,
    required int season,
    required String stage,
    required Object picks,
  }) async {
    try {
      final res = await http.put(
        Uri.parse('$_base/brackets'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'userID': userId,
          'email': email,
          'leagueID': leagueId,
          'season': season,
          'stage': stage,
          'picks': picks,
        }),
      );
      if (res.statusCode == 200) return null;
      try {
        final body = jsonDecode(res.body);
        if (body is Map && body['error'] is String) return body['error'];
      } catch (_) {}
      return 'save failed (${res.statusCode})';
    } catch (e) {
      return e.toString();
    }
  }

  // Bracket leaderboard for a league: every user with a bracketPoints entry,
  // ranked by their points for this league. Reads the shared users list and
  // projects the bracketPoints.{leagueId} field. Kept SEPARATE from the
  // matchday `points` leaderboard by design.
  Future<List<BracketStanding>> fetchLeaderboard(int leagueId) async {
    final key = leagueId.toString();
    try {
      final res = await http
          .get(Uri.parse('$_base/users/register'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return [];
      final decoded = jsonDecode(res.body);
      if (decoded is! List) return [];
      final rows = <BracketStanding>[];
      for (final u in decoded) {
        if (u is! Map) continue;
        final bp = u['bracketPoints'];
        final pts = (bp is Map && bp[key] is num)
            ? (bp[key] as num).toInt()
            : 0;
        if (pts <= 0) continue; // only show users who have scored
        rows.add(BracketStanding(
          name: u['displayName']?.toString() ?? '—',
          points: pts,
        ));
      }
      rows.sort((a, b) => b.points.compareTo(a.points));
      return rows;
    } catch (e) {
      print('fetchLeaderboard failed: $e');
      return [];
    }
  }
}

class BracketStanding {
  final String name;
  final int points;
  BracketStanding({required this.name, required this.points});
}
