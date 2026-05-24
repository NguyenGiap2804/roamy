class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.name,
    required this.emailVerified,
    this.avatarUrl,
    this.emailVerifiedAt,
    this.lastLoginAt,
    this.createdAt,
  });

  final String id;
  final String email;
  final String name;
  final bool emailVerified;
  final String? avatarUrl;
  final DateTime? emailVerifiedAt;
  final DateTime? lastLoginAt;
  final DateTime? createdAt;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? '',
      emailVerified: json['emailVerified'] as bool? ?? false,
      avatarUrl: json['avatarUrl'] as String?,
      emailVerifiedAt: _date(json['emailVerifiedAt']),
      lastLoginAt: _date(json['lastLoginAt']),
      createdAt: _date(json['createdAt']),
    );
  }

  AuthUser copyWith({
    String? name,
    String? avatarUrl,
    bool? emailVerified,
  }) {
    return AuthUser(
      id: id,
      email: email,
      name: name ?? this.name,
      emailVerified: emailVerified ?? this.emailVerified,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      emailVerifiedAt: emailVerifiedAt,
      lastLoginAt: lastLoginAt,
      createdAt: createdAt,
    );
  }
}

class AuthSession {
  const AuthSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  final AuthUser user;
  final String accessToken;
  final String refreshToken;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
    );
  }
}

DateTime? _date(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return DateTime.tryParse(value);
}
