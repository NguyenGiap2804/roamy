import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_endpoints.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.details});

  final String message;
  final int? statusCode;
  final Object? details;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({
    http.Client? client,
    String? baseUrl,
    Future<String?> Function()? deviceIdProvider,
    FutureOr<String?> Function()? accessTokenProvider,
    Future<bool> Function()? refreshSession,
    Future<void> Function()? onSessionExpired,
  })
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? ApiEndpoints.baseUrl,
      _deviceIdProvider = deviceIdProvider,
      _accessTokenProvider = accessTokenProvider,
      _refreshSession = refreshSession,
      _onSessionExpired = onSessionExpired;

  final http.Client _client;
  final String _baseUrl;
  final Future<String?> Function()? _deviceIdProvider;
  final FutureOr<String?> Function()? _accessTokenProvider;
  final Future<bool> Function()? _refreshSession;
  final Future<void> Function()? _onSessionExpired;
  static const _timeout = Duration(seconds: 12);

  Future<dynamic> get(String endpoint, {Map<String, String>? query}) {
    return _send('GET', endpoint, query: query);
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) {
    return _send('POST', endpoint, body: body);
  }

  Future<dynamic> patch(String endpoint, Map<String, dynamic> body) {
    return _send('PATCH', endpoint, body: body);
  }

  Future<dynamic> delete(String endpoint) {
    return _send('DELETE', endpoint);
  }

  Future<dynamic> _send(
    String method,
    String endpoint, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    bool hasRetried = false,
  }) async {
    final uri = Uri.parse('$_baseUrl$endpoint').replace(queryParameters: query);

    try {
      final headers = await _headers();
      final request = switch (method) {
        'POST' => _client.post(uri, headers: headers, body: jsonEncode(body)),
        'PATCH' => _client.patch(
          uri,
          headers: headers,
          body: jsonEncode(body),
        ),
        'DELETE' => _client.delete(uri, headers: headers),
        _ => _client.get(uri, headers: headers),
      };

      final response = await request.timeout(_timeout);
      if (_shouldRefresh(response.statusCode, endpoint, hasRetried)) {
        final refreshed = await _refreshSession?.call() ?? false;
        if (refreshed) {
          return _send(
            method,
            endpoint,
            query: query,
            body: body,
            hasRetried: true,
          );
        }
        await _onSessionExpired?.call();
      }
      return _handleResponse(response);
    } on TimeoutException {
      throw const ApiException('Request timed out. Please try again.');
    } on http.ClientException catch (error) {
      throw ApiException('Network error: ${error.message}');
    } on FormatException {
      throw const ApiException('Invalid server response.');
    }
  }

  Future<Map<String, String>> _headers() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final deviceIdProvider = _deviceIdProvider;
    if (deviceIdProvider != null) {
      try {
        final deviceId = await deviceIdProvider();
        if (deviceId != null && deviceId.trim().isNotEmpty) {
          headers['x-roamy-device-id'] = deviceId.trim();
        }
      } catch (_) {}
    }

    final accessTokenProvider = _accessTokenProvider;
    if (accessTokenProvider != null) {
      final accessToken = await accessTokenProvider();
      if (accessToken != null && accessToken.trim().isNotEmpty) {
        headers['Authorization'] = 'Bearer ${accessToken.trim()}';
      }
    }

    return headers;
  }

  bool _shouldRefresh(int statusCode, String endpoint, bool hasRetried) {
    if (statusCode != 401 || hasRetried) return false;
    if (_refreshSession == null) return false;
    return !endpoint.startsWith('/auth/');
  }

  dynamic _handleResponse(http.Response response) {
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    final message = decoded is Map<String, dynamic>
        ? decoded['message'] as String?
        : null;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        message ?? 'Request failed',
        statusCode: response.statusCode,
        details: decoded is Map<String, dynamic> ? decoded['data'] : null,
      );
    }

    if (decoded is Map<String, dynamic> && decoded.containsKey('data')) {
      return decoded['data'];
    }

    return decoded;
  }
}
