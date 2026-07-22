import 'dart:convert';
import 'package:football/models/season_record.dart';
import 'package:football/utils/config.dart';
import 'package:http/http.dart' as http;

// Reads the Trophy Cabinet data: the user's archived past-season records.
// Kept injectable so widget tests can supply a fake (see
// test/trophy_cabinet_test.dart).
class TrophyMethods {
  const TrophyMethods();

  String get _baseUrl => backendUrl;

  Future<List<SeasonRecord>> fetchHistory(String userId) async {
    final res = await http.get(Uri.parse('$_baseUrl/users/$userId/history'));
    if (res.statusCode != 200) {
      throw Exception('Failed to load history: ${res.statusCode}');
    }
    return _parse(res.body);
  }

  List<SeasonRecord> _parse(String body) {
    final data = jsonDecode(body);
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(SeasonRecord.fromJson)
        .toList();
  }
}
