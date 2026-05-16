import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'browser_oauth.dart';

class FortyTwoAuth {
  static const clientId = String.fromEnvironment(
    'FT_CLIENT_ID',
    defaultValue:
        'u-s4t2ud-1f50105112418289f15e037bcb906147ebf3545a1feb15084f34347003cf0755',
  );
  static const configuredRedirectUri = String.fromEnvironment(
    'FT_REDIRECT_URI',
  );
  static const backendBaseUrl = String.fromEnvironment(
    'FT_BACKEND_URL',
    defaultValue: 'http://127.0.0.1:8787',
  );

  const FortyTwoAuth({http.Client? client}) : _client = client;

  final http.Client? _client;

  http.Client get _http => _client ?? http.Client();

  Uri get redirectUri {
    if (configuredRedirectUri.isNotEmpty) {
      return Uri.parse(configuredRedirectUri);
    }
    return Uri.base.replace(query: '', fragment: '');
  }

  void startLogin() {
    final state = _randomState();
    writeOAuthState(state);
    openOAuthUrl(
      Uri.https('api.intra.42.fr', '/oauth/authorize', {
        'client_id': clientId,
        'redirect_uri': redirectUri.toString(),
        'response_type': 'code',
        'scope': 'public',
        'state': state,
      }).toString(),
    );
  }

  Future<FortyTwoSession?> completeLoginFromCallback() async {
    final query = Uri.base.queryParameters;
    final error = query['error'];
    if (error != null) {
      throw FortyTwoAuthException('42 OAuth error: $error');
    }

    final code = query['code'];
    if (code == null || code.isEmpty) return null;

    final returnedState = query['state'];
    final expectedState = readOAuthState();
    if (expectedState == null || returnedState != expectedState) {
      throw FortyTwoAuthException('42 OAuth state mismatch. Login aborted.');
    }

    final token = await _exchangeCode(code);
    final user = await _fetchMe(token.accessToken);

    clearOAuthState();
    replaceBrowserUrl(redirectUri.toString());

    return FortyTwoSession(token: token, user: user);
  }

  Future<FortyTwoToken> _exchangeCode(String code) async {
    final response = await _http.post(
      Uri.parse('$backendBaseUrl/oauth/42/token'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'code': code, 'redirect_uri': redirectUri.toString()}),
    );

    if (response.statusCode != 200) {
      throw FortyTwoAuthException(
        'Failed to exchange 42 OAuth code (${response.statusCode}): ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return FortyTwoToken(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String? ?? 'bearer',
      expiresIn: json['expires_in'] as int? ?? 0,
    );
  }

  Future<FortyTwoUser> _fetchMe(String accessToken) async {
    final response = await _http.get(
      Uri.parse('$backendBaseUrl/api/42/me'),
      headers: {'authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw FortyTwoAuthException(
        'Failed to fetch 42 profile (${response.statusCode}): ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return FortyTwoUser(
      id: json['id'] as int,
      login: json['login'] as String,
      displayName: json['displayname'] as String? ?? json['login'] as String,
      imageUrl: _extractImageUrl(json),
      campusId: _extractCampusId(json),
    );
  }

  Future<List<String>> fetchStudentLogins(
    String accessToken, {
    int? campusId,
    int limit = 32,
  }) async {
    final response = await _http.get(
      Uri.parse('$backendBaseUrl/api/42/users').replace(
        queryParameters: {
          'limit': limit.toString(),
          'pages': '10',
          if (campusId != null) 'campus_id': campusId.toString(),
        },
      ),
      headers: {'authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode != 200) {
      throw FortyTwoAuthException(
        'Failed to fetch 42 users (${response.statusCode}): ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final logins = json['logins'] as List<dynamic>;
    return logins.whereType<String>().toList(growable: false);
  }

  String _randomState() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static String? _extractImageUrl(Map<String, dynamic> json) {
    final image = json['image'];
    if (image is Map<String, dynamic>) {
      final link = image['link'];
      if (link is String && link.isNotEmpty) return link;
    }
    final legacy = json['image_url'];
    return legacy is String && legacy.isNotEmpty ? legacy : null;
  }

  static int? _extractCampusId(Map<String, dynamic> json) {
    final campuses = json['campus'];
    if (campuses is List && campuses.isNotEmpty) {
      final campus = campuses.first;
      if (campus is Map<String, dynamic>) {
        final id = campus['id'];
        if (id is int) return id;
      }
    }
    return null;
  }
}

class FortyTwoSession {
  const FortyTwoSession({required this.token, required this.user});

  final FortyTwoToken token;
  final FortyTwoUser user;
}

class FortyTwoToken {
  const FortyTwoToken({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
  });

  final String accessToken;
  final String tokenType;
  final int expiresIn;
}

class FortyTwoUser {
  const FortyTwoUser({
    required this.id,
    required this.login,
    required this.displayName,
    this.imageUrl,
    this.campusId,
  });

  final int id;
  final String login;
  final String displayName;
  final String? imageUrl;
  final int? campusId;
}

class FortyTwoAuthException implements Exception {
  const FortyTwoAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
