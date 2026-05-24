import 'dart:async';
import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../models/auth_user.dart';
import 'auth_token_store.dart';

class AuthService {
  AuthService({
    required AuthTokenStore tokenStore,
    http.Client? client,
    Future<String?> Function()? deviceIdProvider,
    GoogleSignIn? googleSignIn,
  }) : _tokenStore = tokenStore,
       _client = client ?? http.Client(),
       _deviceIdProvider = deviceIdProvider,
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final AuthTokenStore _tokenStore;
  final http.Client _client;
  final Future<String?> Function()? _deviceIdProvider;
  final GoogleSignIn _googleSignIn;

  bool _googleInitialized = false;
  static const _timeout = Duration(seconds: 12);

  Future<AuthSession> login({
    required String email,
    required String password,
  }) {
    return _postSession(
      ApiEndpoints.authLogin,
      {'email': email, 'password': password},
    );
  }

  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
  }) {
    return _postSession(
      ApiEndpoints.authRegister,
      {'name': name, 'email': email, 'password': password},
    );
  }

  Future<AuthSession> verifyEmail({
    required String email,
    required String code,
  }) {
    return _postSession(
      ApiEndpoints.authVerifyEmail,
      {'email': email, 'code': code},
    );
  }

  Future<void> resendVerification(String email) async {
    await _post(ApiEndpoints.authResendEmail, {'email': email});
  }

  Future<void> forgotPassword(String email) async {
    await _post(ApiEndpoints.authForgotPassword, {'email': email});
  }

  Future<AuthSession> resetPassword({
    required String email,
    required String code,
    required String password,
  }) {
    return _postSession(
      ApiEndpoints.authResetPassword,
      {'email': email, 'code': code, 'password': password},
    );
  }

  Future<AuthSession> refresh(String refreshToken) {
    return _postSession(
      ApiEndpoints.authRefresh,
      {'refreshToken': refreshToken},
      persist: false,
    );
  }

  Future<void> logout(String? refreshToken) async {
    try {
      await _post(ApiEndpoints.authLogout, {'refreshToken': refreshToken});
    } catch (_) {
      // Local logout must still complete if the server is unavailable.
    }
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _tokenStore.clear();
  }

  Future<AuthUser> me(String accessToken) async {
    final data = await _request(
      'GET',
      ApiEndpoints.me,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    return AuthUser.fromJson(data as Map<String, dynamic>);
  }

  Future<AuthUser> updateMe(String accessToken, {required String name}) async {
    final data = await _request(
      'PATCH',
      ApiEndpoints.me,
      body: {'name': name},
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    return AuthUser.fromJson(data as Map<String, dynamic>);
  }

  Future<AuthSession> loginWithGoogle() async {
    try {
      await _ensureGoogleInitialized();
      if (!_googleSignIn.supportsAuthenticate()) {
        throw const ApiException('Google sign-in is not supported here.');
      }

      final account = await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const ApiException('Google did not return an ID token.');
      }
      return _postSession(ApiEndpoints.authGoogle, {'idToken': idToken});
    } on GoogleSignInException catch (error) {
      throw ApiException(_googleSignInMessage(error));
    }
  }

  Future<AuthSession> _postSession(
    String endpoint,
    Map<String, dynamic> body, {
    bool persist = true,
  }) async {
    final data = await _post(endpoint, body);
    final session = AuthSession.fromJson(data);
    if (persist) {
      await _tokenStore.saveTokens(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
      );
    }
    return session;
  }

  Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final data = await _request('POST', endpoint, body: body);
    return data as Map<String, dynamic>;
  }

  Future<dynamic> _request(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse('${ApiEndpoints.baseUrl}$endpoint');
    try {
      final requestHeaders = await _headers(headers);
      final response = switch (method) {
        'PATCH' => await _client
            .patch(uri, headers: requestHeaders, body: jsonEncode(body))
            .timeout(_timeout),
        'POST' => await _client
            .post(uri, headers: requestHeaders, body: jsonEncode(body))
            .timeout(_timeout),
        _ => await _client.get(uri, headers: requestHeaders).timeout(_timeout),
      };
      return _handleResponse(response);
    } on TimeoutException {
      throw const ApiException('Request timed out. Please try again.');
    } on http.ClientException catch (error) {
      throw ApiException('Network error: ${error.message}');
    } on FormatException {
      throw const ApiException('Invalid server response.');
    }
  }

  Future<Map<String, String>> _headers(Map<String, String>? extra) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      ...?extra,
    };
    final provider = _deviceIdProvider;
    if (provider != null) {
      try {
        final deviceId = await provider();
        if (deviceId != null && deviceId.trim().isNotEmpty) {
          headers['x-roamy-device-id'] = deviceId.trim();
        }
      } catch (_) {}
    }
    return headers;
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

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    const serverClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
    await _googleSignIn.initialize(
      serverClientId: serverClientId.isEmpty ? null : serverClientId,
    );
    _googleInitialized = true;
  }

  String _googleSignInMessage(GoogleSignInException error) {
    return switch (error.code) {
      GoogleSignInExceptionCode.canceled =>
        'Khong the dang nhap Google. Neu ban khong huy thao tac, hay kiem tra Android OAuth client package/SHA-1 roi thu lai.',
      GoogleSignInExceptionCode.interrupted =>
        'Dang nhap Google bi gian doan. Vui long thu lai.',
      GoogleSignInExceptionCode.clientConfigurationError =>
        'Cau hinh Google Sign-In chua dung. Kiem tra Web client id va Android OAuth client.',
      GoogleSignInExceptionCode.providerConfigurationError =>
        'Google Sign-In chua duoc cau hinh dung tren thiet bi nay.',
      GoogleSignInExceptionCode.uiUnavailable =>
        'Thiet bi nay khong mo duoc giao dien dang nhap Google.',
      _ => 'Khong the dang nhap Google. Vui long thu lai.',
    };
  }
}
