import 'dart:convert';
import 'dart:io';
import 'dart:math';

Future<void> main() async {
  final clientId = _requiredEnv('FT_CLIENT_ID');
  final clientSecret = _requiredEnv('FT_CLIENT_SECRET');
  final defaultRedirectUri = Platform.environment['FT_REDIRECT_URI'];
  final port = int.parse(Platform.environment['PORT'] ?? '8787');

  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  stdout.writeln('42 OAuth proxy listening on http://127.0.0.1:$port');

  await for (final request in server) {
    stdout.writeln(
      '${DateTime.now().toIso8601String()} ${request.method} ${request.uri.path}',
    );
    _writeCorsHeaders(request);

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      request.response.headers.contentLength = 0;
      await request.response.close();
      continue;
    }

    try {
      if (request.method == 'POST' && request.uri.path == '/oauth/42/token') {
        await _exchangeCode(
          request,
          clientId: clientId,
          clientSecret: clientSecret,
          defaultRedirectUri: defaultRedirectUri,
        );
      } else if (request.method == 'GET' && request.uri.path == '/api/42/me') {
        await _proxyMe(request);
      } else if (request.method == 'GET' &&
          request.uri.path == '/api/42/users') {
        await _proxyUsers(request);
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write(jsonEncode({'error': 'not_found'}));
        await request.response.close();
      }
    } catch (error, stackTrace) {
      stderr.writeln(error);
      stderr.writeln(stackTrace);
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'error': error.toString()}));
      await request.response.close();
    }
  }
}

Future<void> _exchangeCode(
  HttpRequest request, {
  required String clientId,
  required String clientSecret,
  required String? defaultRedirectUri,
}) async {
  final body = await utf8.decoder.bind(request).join();
  final json = jsonDecode(body) as Map<String, dynamic>;
  final code = json['code'] as String?;
  final redirectUri = json['redirect_uri'] as String? ?? defaultRedirectUri;

  if (code == null || code.isEmpty) {
    await _json(request.response, HttpStatus.badRequest, {
      'error': 'missing_code',
    });
    return;
  }
  if (redirectUri == null || redirectUri.isEmpty) {
    await _json(request.response, HttpStatus.badRequest, {
      'error': 'missing_redirect_uri',
    });
    return;
  }

  final client = HttpClient();
  try {
    final tokenRequest = await client.postUrl(
      Uri.https('api.intra.42.fr', '/oauth/token'),
    );
    tokenRequest.headers.contentType = ContentType(
      'application',
      'x-www-form-urlencoded',
      charset: 'utf-8',
    );
    tokenRequest.write(
      Uri(
        queryParameters: {
          'grant_type': 'authorization_code',
          'client_id': clientId,
          'client_secret': clientSecret,
          'code': code,
          'redirect_uri': redirectUri,
        },
      ).query,
    );

    final tokenResponse = await tokenRequest.close();
    final responseBody = await utf8.decoder.bind(tokenResponse).join();
    request.response.statusCode = tokenResponse.statusCode;
    request.response.headers.contentType = ContentType.json;
    request.response.write(responseBody);
    await request.response.close();
  } finally {
    client.close(force: true);
  }
}

Future<void> _proxyMe(HttpRequest request) async {
  final authorization = request.headers.value(HttpHeaders.authorizationHeader);
  if (authorization == null || authorization.isEmpty) {
    await _json(request.response, HttpStatus.unauthorized, {
      'error': 'missing_authorization',
    });
    return;
  }

  final client = HttpClient();
  try {
    final meRequest = await client.getUrl(
      Uri.https('api.intra.42.fr', '/v2/me'),
    );
    meRequest.headers.set(HttpHeaders.authorizationHeader, authorization);

    final meResponse = await meRequest.close();
    final responseBody = await utf8.decoder.bind(meResponse).join();
    request.response.statusCode = meResponse.statusCode;
    request.response.headers.contentType = ContentType.json;
    request.response.write(responseBody);
    await request.response.close();
  } finally {
    client.close(force: true);
  }
}

Future<void> _proxyUsers(HttpRequest request) async {
  final authorization = request.headers.value(HttpHeaders.authorizationHeader);
  if (authorization == null || authorization.isEmpty) {
    await _json(request.response, HttpStatus.unauthorized, {
      'error': 'missing_authorization',
    });
    return;
  }

  final limit = int.tryParse(request.uri.queryParameters['limit'] ?? '') ?? 32;
  final pages = int.tryParse(request.uri.queryParameters['pages'] ?? '') ?? 10;
  final campusId = request.uri.queryParameters['campus_id'];
  final path = campusId == null || campusId.isEmpty
      ? '/v2/users'
      : '/v2/campus/$campusId/users';

  final client = HttpClient();
  try {
    final logins = <String>{};
    final pageSize = limit.clamp(1, 100);
    final pageCount = pages.clamp(1, 20);
    final random = Random.secure();
    final candidatePages = List<int>.generate(80, (index) => index + 1)
      ..shuffle(random);

    for (
      int offset = 0;
      offset < pageCount &&
          offset < candidatePages.length &&
          logins.length < limit;
      offset++
    ) {
      final page = campusId == null || campusId.isEmpty
          ? offset + 1
          : candidatePages[offset];
      final usersRequest = await client.getUrl(
        Uri.https('api.intra.42.fr', path, {
          'page[number]': page.toString(),
          'page[size]': pageSize.toString(),
        }),
      );
      usersRequest.headers.set(HttpHeaders.authorizationHeader, authorization);

      final usersResponse = await usersRequest.close();
      final responseBody = await utf8.decoder.bind(usersResponse).join();
      if (usersResponse.statusCode != HttpStatus.ok) {
        request.response.statusCode = usersResponse.statusCode;
        request.response.headers.contentType = ContentType.json;
        request.response.write(responseBody);
        await request.response.close();
        return;
      }

      final records = jsonDecode(responseBody) as List<dynamic>;
      if (records.isEmpty) continue;
      logins.addAll(
        records
            .whereType<Map<String, dynamic>>()
            .where(_isActiveUserRecord)
            .map(_loginFromRecord)
            .where(_hasNoDigits)
            .whereType<String>(),
      );
    }

    final shuffledLogins = logins.toList(growable: false);
    shuffledLogins.shuffle(Random.secure());
    await _json(request.response, HttpStatus.ok, {
      'logins': shuffledLogins.take(limit).toList(growable: false),
    });
  } finally {
    client.close(force: true);
  }
}

bool _isActiveUserRecord(Map<String, dynamic> record) {
  final active = record['active?'] ?? record['active'] ?? record['is_active'];
  if (active is bool) return active;

  // Some 42 user payloads don't include an explicit active flag. In that case
  // keep the record instead of accidentally filtering the whole roster to zero.
  return true;
}

bool _hasNoDigits(String? login) {
  if (login == null) return false;
  return !login.contains(RegExp(r'\d'));
}

String? _loginFromRecord(Map<String, dynamic> record) {
  final directLogin = record['login'];
  if (directLogin is String && directLogin.isNotEmpty) return directLogin;

  final userLogin = record['user_login'];
  if (userLogin is String && userLogin.isNotEmpty) return userLogin;

  final user = record['user'];
  if (user is Map<String, dynamic>) {
    final nestedLogin = user['login'];
    if (nestedLogin is String && nestedLogin.isNotEmpty) return nestedLogin;
  }

  return null;
}

Future<void> _json(
  HttpResponse response,
  int statusCode,
  Map<String, Object?> body,
) async {
  response.statusCode = statusCode;
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(body));
  await response.close();
}

void _writeCorsHeaders(HttpRequest request) {
  final response = request.response;
  final origin = request.headers.value('origin');
  response.headers.set(
    HttpHeaders.accessControlAllowOriginHeader,
    origin ?? '*',
  );
  response.headers.set(
    HttpHeaders.accessControlAllowMethodsHeader,
    'GET, POST, OPTIONS',
  );
  response.headers.set(
    HttpHeaders.accessControlAllowHeadersHeader,
    'authorization, content-type, x-requested-with, access-control-request-private-network',
  );
  response.headers.set('Access-Control-Allow-Private-Network', 'true');
  response.headers.set(HttpHeaders.accessControlMaxAgeHeader, '600');
  response.headers.set(HttpHeaders.varyHeader, 'Origin');
}

String _requiredEnv(String name) {
  final value = Platform.environment[name];
  if (value == null || value.isEmpty) {
    stderr.writeln('Missing required environment variable: $name');
    exitCode = 64;
    throw StateError('Missing required environment variable: $name');
  }
  return value;
}
