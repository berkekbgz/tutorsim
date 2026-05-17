import 'dart:convert';

import 'package:http/http.dart' as http;

import 'forty_two_auth.dart';

class ScoreApi {
  const ScoreApi({http.Client? client}) : _client = client;

  final http.Client? _client;

  http.Client get _http => _client ?? http.Client();

  Future<void> submitScore({
    required String login,
    required int score,
    required int correctTigs,
    required int missedEvents,
    required int elapsedSeconds,
    required double peakDifficulty,
    required Map<String, int> missedNpcs,
  }) async {
    final response = await _http.post(
      Uri.parse('${FortyTwoAuth.backendBaseUrl}/api/scores'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({
        'login': login,
        'score': score,
        'correct_tigs': correctTigs,
        'missed_events': missedEvents,
        'elapsed_seconds': elapsedSeconds,
        'peak_difficulty': peakDifficulty,
        'missed_npcs': missedNpcs,
      }),
    );

    if (response.statusCode != 200) {
      throw ScoreApiException(
        'Failed to submit score (${response.statusCode}): ${response.body}',
      );
    }
  }

  Future<List<LeaderboardEntry>> fetchLeaderboard({int limit = 10}) async {
    final response = await _http.get(
      Uri.parse(
        '${FortyTwoAuth.backendBaseUrl}/api/scores',
      ).replace(queryParameters: {'limit': limit.toString()}),
    );

    if (response.statusCode != 200) {
      throw ScoreApiException(
        'Failed to fetch scores (${response.statusCode}): ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final scores = json['scores'] as List<dynamic>? ?? const [];
    return scores
        .whereType<Map<String, dynamic>>()
        .map(LeaderboardEntry.fromJson)
        .toList(growable: false);
  }

  Future<List<SneakyNpcEntry>> fetchSneakyNpcs({int limit = 10}) async {
    final response = await _http.get(
      Uri.parse(
        '${FortyTwoAuth.backendBaseUrl}/api/sneaky-npcs',
      ).replace(queryParameters: {'limit': limit.toString()}),
    );

    if (response.statusCode != 200) {
      throw ScoreApiException(
        'Failed to fetch sneaky NPCs (${response.statusCode}): ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final npcs = json['npcs'] as List<dynamic>? ?? const [];
    return npcs
        .whereType<Map<String, dynamic>>()
        .map(SneakyNpcEntry.fromJson)
        .toList(growable: false);
  }
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.login,
    required this.score,
    required this.correctTigs,
    required this.missedEvents,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      login: json['login'] as String? ?? 'unknown',
      score: _asInt(json['score']),
      correctTigs: _asInt(json['correct_tigs']),
      missedEvents: _asInt(json['missed_events']),
    );
  }

  final String login;
  final int score;
  final int correctTigs;
  final int missedEvents;
}

class SneakyNpcEntry {
  const SneakyNpcEntry({required this.login, required this.misses});

  factory SneakyNpcEntry.fromJson(Map<String, dynamic> json) {
    return SneakyNpcEntry(
      login: json['login'] as String? ?? 'unknown',
      misses: _asInt(json['misses']),
    );
  }

  final String login;
  final int misses;
}

class ScoreApiException implements Exception {
  const ScoreApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
