import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/auth_user.dart';
import '../services/auth_service.dart';
import '../services/auth_token_store.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._authService, this._tokenStore);

  final AuthService _authService;
  final AuthTokenStore _tokenStore;

  AuthUser? _user;
  String? _accessToken;
  bool _isInitializing = true;
  bool _isBusy = false;
  String? _errorMessage;
  String? _pendingVerificationEmail;
  Future<bool>? _refreshInFlight;

  AuthUser? get user => _user;
  String? get accessToken => _accessToken;
  bool get isInitializing => _isInitializing;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;
  String? get pendingVerificationEmail => _pendingVerificationEmail;
  bool get isAuthenticated => _user != null && _accessToken != null;

  Future<void> initialize() async {
    _isInitializing = true;
    notifyListeners();
    try {
      final accessToken = await _tokenStore.readAccessToken();
      final refreshToken = await _tokenStore.readRefreshToken();
      if (accessToken != null && refreshToken != null) {
        final refreshed = await refreshSession();
        if (!refreshed) {
          await _clearLocalSession();
        }
      } else {
        await _clearLocalSession();
      }
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    await _runBusy(() async {
      final session = await _authService.login(
        email: email,
        password: password,
      );
      await _applySession(session);
    });
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    await _runBusy(() async {
      final session = await _authService.register(
        name: name,
        email: email,
        password: password,
      );
      await _applySession(session);
      _pendingVerificationEmail = null;
    });
  }

  Future<void> verifyEmail(String email, String code) async {
    await _runBusy(() async {
      final session = await _authService.verifyEmail(email: email, code: code);
      await _applySession(session);
      _pendingVerificationEmail = null;
    });
  }

  Future<void> resendVerification(String email) async {
    await _runBusy(() => _authService.resendVerification(email));
  }

  Future<void> forgotPassword(String email) async {
    await _runBusy(() => _authService.forgotPassword(email));
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String password,
  }) async {
    await _runBusy(() async {
      final session = await _authService.resetPassword(
        email: email,
        code: code,
        password: password,
      );
      await _applySession(session);
    });
  }

  Future<void> loginWithGoogle() async {
    await _runBusy(() async {
      final session = await _authService.loginWithGoogle();
      await _applySession(session);
    });
  }

  Future<bool> refreshSession() async {
    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _refreshSessionInternal();
    _refreshInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_refreshInFlight, future)) {
        _refreshInFlight = null;
      }
    }
  }

  Future<bool> _refreshSessionInternal() async {
    final refreshToken = await _tokenStore.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }
    try {
      final session = await _authService.refresh(refreshToken);
      await _applySession(session);
      return true;
    } catch (_) {
      await _clearLocalSession();
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    final refreshToken = await _tokenStore.readRefreshToken();
    await _clearLocalSession();
    notifyListeners();
    unawaited(_authService.logout(refreshToken));
  }

  Future<void> forceLogout() async {
    await _clearLocalSession();
    notifyListeners();
  }

  Future<void> updateName(String name) async {
    final token = _accessToken;
    if (token == null) return;
    await _runBusy(() async {
      _user = await _authService.updateMe(token, name: name);
    });
  }

  Future<void> _applySession(AuthSession session) async {
    _user = session.user;
    _accessToken = session.accessToken;
    await _tokenStore.saveTokens(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    );
  }

  Future<void> _clearLocalSession() async {
    _user = null;
    _accessToken = null;
    _pendingVerificationEmail = null;
    await _tokenStore.clear();
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await action();
    } catch (error) {
      _errorMessage = _friendlyAuthError(error.toString());
      rethrow;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  String _friendlyAuthError(String message) {
    final normalized = message.toLowerCase();
    if (normalized.contains('invalid email or password')) {
      return 'Email hoặc mật khẩu không đúng.';
    }
    if (normalized.contains('request timed out')) {
      return 'Kết nối quá lâu. Vui lòng thử lại.';
    }
    if (normalized.contains('email is not verified')) {
      return 'Tài khoản chưa được xác thực.';
    }
    if (normalized.contains('could not send auth email')) {
      return 'Chưa gửi được email. Vui lòng thử lại sau.';
    }
    if (normalized.contains('google')) {
      return message;
    }
    if (normalized.contains('network error')) {
      return 'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng.';
    }
    return message;
  }
}
