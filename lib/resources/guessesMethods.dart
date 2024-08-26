import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:football/models/guesses.dart';

class GuessesMethods {
  Future<List<Guess>> fetchThisUserGuesses(String clientId) async {
    print('clientId ${clientId}');
    final url = Uri.parse('https://leagues.onrender.com/guesses/$clientId');

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
    print('clientId ${gameId}');
    final url =
        Uri.parse('https://leagues.onrender.com/guesses/gameOriginal/$gameId');

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

  Future<String> fetchUserName(String userId) async {
    final response = await http
        .get(Uri.parse('https://leagues.onrender.com/users/${userId}'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      // print(response.body);
      return data['displayName'];
    } else {
      throw Exception('Failed to load user name');
    }
  }
 Future<Map<String, String>>  fetchUserGroup(String userId) async {
    final response = await http
        .get(Uri.parse('https://leagues.onrender.com/users/${userId}'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      // print(response.body);
      return Map<String, String>.from(data['groupID']);
    } else {
      throw Exception('Failed to load user name');
    }
  }
}
