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

  // Bracket leaderboard for a league: every user who has scored bracket points,
  // ranked high→low, each with the per-stage breakdown. Kept SEPARATE from the
  // matchday `points` leaderboard by design. Backed by the dedicated
  // GET /brackets/leaderboard/:leagueId endpoint.
  Future<List<BracketStanding>> fetchLeaderboard(int leagueId) async {
    try {
      final res = await http
          .get(Uri.parse('$_base/brackets/leaderboard/$leagueId'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return [];
      final decoded = jsonDecode(res.body);
      return _parseStandings(decoded, dropZero: true);
    } catch (e) {
      print('fetchLeaderboard failed: $e');
      return [];
    }
  }

  // Shared parser for the {name, points, stages} row shape used by both the
  // global and per-league leaderboards. [dropZero] hides 0-point rows (global
  // board); a private league keeps every member visible.
  static List<BracketStanding> _parseStandings(dynamic decoded,
      {bool dropZero = false}) {
    if (decoded is! List) return [];
    final rows = <BracketStanding>[];
    for (final u in decoded) {
      if (u is! Map) continue;
      final pts = (u['points'] is num) ? (u['points'] as num).toInt() : 0;
      if (dropZero && pts <= 0) continue;
      final stages = <String, int>{};
      final raw = u['stages'];
      if (raw is Map) {
        raw.forEach((k, v) {
          if (v is num) stages[k.toString()] = v.toInt();
        });
      }
      rows.add(BracketStanding(
        userID: u['userID']?.toString(),
        name: u['name']?.toString() ?? '—',
        points: pts,
        stages: stages,
        isOwner: u['isOwner'] == true,
      ));
    }
    rows.sort((a, b) => b.points.compareTo(a.points));
    return rows;
  }

  // ── Private bracket mini-leagues ─────────────────────────────────────────

  // GET /brackets/leagues/mine/:userId/:leagueId
  Future<List<BracketLeagueInfo>> fetchMyLeagues(
      String userId, int leagueId) async {
    try {
      final res = await http
          .get(Uri.parse('$_base/brackets/leagues/mine/$userId/$leagueId'))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return [];
      final decoded = jsonDecode(res.body);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((m) => BracketLeagueInfo.fromJson(m))
          .toList();
    } catch (e) {
      print('fetchMyLeagues failed: $e');
      return [];
    }
  }

  // POST /brackets/leagues — returns the created league, or an error string.
  Future<({BracketLeagueInfo? league, String? error})> createLeague({
    required String name,
    required int leagueId,
    required String ownerUserId,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/brackets/leagues'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(
            {'name': name, 'leagueId': leagueId, 'ownerUserId': ownerUserId}),
      );
      final body = jsonDecode(res.body);
      if (res.statusCode == 201 && body is Map && body['league'] is Map) {
        return (league: BracketLeagueInfo.fromJson(body['league']), error: null);
      }
      return (league: null, error: _errFrom(body, res.statusCode));
    } catch (e) {
      return (league: null, error: e.toString());
    }
  }

  // POST /brackets/leagues/join — join by invite code.
  Future<({BracketLeagueInfo? league, bool alreadyMember, String? error})>
      joinLeague({required String userId, required String code}) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/brackets/leagues/join'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'userId': userId, 'code': code.trim()}),
      );
      final body = jsonDecode(res.body);
      if (res.statusCode == 200 && body is Map && body['league'] is Map) {
        return (
          league: BracketLeagueInfo.fromJson(body['league']),
          alreadyMember: body['alreadyMember'] == true,
          error: null
        );
      }
      return (
        league: null,
        alreadyMember: false,
        error: _errFrom(body, res.statusCode)
      );
    } catch (e) {
      return (league: null, alreadyMember: false, error: e.toString());
    }
  }

  // GET /brackets/leagues/:id/leaderboard — members-only ranking.
  Future<({BracketLeagueInfo? league, List<BracketStanding> rows})>
      fetchLeagueLeaderboard(String id, {String? userId}) async {
    try {
      final q = userId != null ? '?userId=$userId' : '';
      final res = await http
          .get(Uri.parse('$_base/brackets/leagues/$id/leaderboard$q'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return (league: null, rows: <BracketStanding>[]);
      final body = jsonDecode(res.body);
      final league = (body is Map && body['league'] is Map)
          ? BracketLeagueInfo.fromJson(body['league'])
          : null;
      final rows = _parseStandings(
          body is Map ? body['rows'] : null,
          dropZero: false);
      return (league: league, rows: rows);
    } catch (e) {
      print('fetchLeagueLeaderboard failed: $e');
      return (league: null, rows: <BracketStanding>[]);
    }
  }

  // GET /brackets/leagues/:id/members
  Future<List<BracketLeagueMember>> fetchLeagueMembers(String id) async {
    try {
      final res = await http
          .get(Uri.parse('$_base/brackets/leagues/$id/members'))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return [];
      final body = jsonDecode(res.body);
      final rows = (body is Map) ? body['rows'] : null;
      if (rows is! List) return [];
      return rows
          .whereType<Map>()
          .map((m) => BracketLeagueMember(
                userID: m['userID']?.toString() ?? '',
                name: m['name']?.toString() ?? '—',
                isOwner: m['isOwner'] == true,
              ))
          .toList();
    } catch (e) {
      print('fetchLeagueMembers failed: $e');
      return [];
    }
  }

  // POST /brackets/leagues/leave
  Future<String?> leaveLeague(
      {required String userId, required String id}) async {
    return _simplePost('$_base/brackets/leagues/leave',
        {'userId': userId, 'id': id});
  }

  // PUT /brackets/leagues/rename (owner only)
  Future<String?> renameLeague(
      {required String id,
      required String ownerUserId,
      required String name}) async {
    try {
      final res = await http.put(
        Uri.parse('$_base/brackets/leagues/rename'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'id': id, 'ownerUserId': ownerUserId, 'name': name}),
      );
      if (res.statusCode == 200) return null;
      return _errFrom(jsonDecode(res.body), res.statusCode);
    } catch (e) {
      return e.toString();
    }
  }

  // DELETE /brackets/leagues (owner only)
  Future<String?> deleteLeague(
      {required String id, required String ownerUserId}) async {
    try {
      final res = await http.delete(
        Uri.parse('$_base/brackets/leagues'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'id': id, 'ownerUserId': ownerUserId}),
      );
      if (res.statusCode == 200) return null;
      return _errFrom(jsonDecode(res.body), res.statusCode);
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> _simplePost(String url, Map<String, dynamic> body) async {
    try {
      final res = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(body),
      );
      if (res.statusCode == 200) return null;
      return _errFrom(jsonDecode(res.body), res.statusCode);
    } catch (e) {
      return e.toString();
    }
  }

  static String _errFrom(dynamic body, int status) {
    if (body is Map) {
      if (body['error'] is String) return body['error'];
      if (body['msg'] is String) return body['msg'];
    }
    return 'request failed ($status)';
  }
}

// A private bracket mini-league summary.
class BracketLeagueInfo {
  final String id;
  final String name;
  final String code;
  final int leagueId;
  final int season;
  final String ownerUserId;
  final int memberCount;
  final bool isOwner;
  BracketLeagueInfo({
    required this.id,
    required this.name,
    required this.code,
    required this.leagueId,
    required this.season,
    required this.ownerUserId,
    required this.memberCount,
    required this.isOwner,
  });

  factory BracketLeagueInfo.fromJson(Map json) => BracketLeagueInfo(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '—',
        code: json['code']?.toString() ?? '',
        leagueId: (json['leagueId'] is num)
            ? (json['leagueId'] as num).toInt()
            : 0,
        season:
            (json['season'] is num) ? (json['season'] as num).toInt() : 0,
        ownerUserId: json['ownerUserId']?.toString() ?? '',
        memberCount: (json['memberCount'] is num)
            ? (json['memberCount'] as num).toInt()
            : 0,
        isOwner: json['isOwner'] == true,
      );
}

class BracketLeagueMember {
  final String userID;
  final String name;
  final bool isOwner;
  BracketLeagueMember({
    required this.userID,
    required this.name,
    required this.isOwner,
  });
}

class BracketStanding {
  final String? userID;
  final String name;
  final int points;
  // stage key (groups|R32|R16|QF|SF|F) -> points earned there.
  final Map<String, int> stages;
  final bool isOwner; // true for the league owner in a per-league board
  BracketStanding({
    this.userID,
    required this.name,
    required this.points,
    this.stages = const {},
    this.isOwner = false,
  });
}
