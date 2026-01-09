/// ============================================================
/// 琥珀云同步 Token 模型
/// ============================================================
/// 用于存储和管理云同步的认证凭证
/// - Access Token: 短期凭证，用于 API 调用（24小时）
/// - Refresh Token: 长期凭证，用于刷新 Access Token（30天）
/// ============================================================

/// 琥珀云 Token 对
///
/// 包含访问令牌和刷新令牌，以及它们的过期时间
/// 存储在 SharedPreferences 中，不使用 FlutterSecureStorage
/// （避免 macOS/iOS 钥匙串需要 Apple Developer 账号）
class AmberCloudToken {
  /// 访问令牌（用于 API 认证）
  final String accessToken;

  /// 访问令牌过期时间
  final DateTime accessTokenExpiresAt;

  /// 刷新令牌（用于刷新访问令牌）
  final String refreshToken;

  /// 刷新令牌过期时间
  final DateTime refreshTokenExpiresAt;

  /// 创建时间
  final DateTime createdAt;

  const AmberCloudToken({
    required this.accessToken,
    required this.accessTokenExpiresAt,
    required this.refreshToken,
    required this.refreshTokenExpiresAt,
    required this.createdAt,
  });

  /// 访问令牌是否已过期
  ///
  /// 提前 5 分钟判定为过期，给刷新留出时间
  bool get isAccessTokenExpired {
    final buffer = const Duration(minutes: 5);
    return DateTime.now().isAfter(accessTokenExpiresAt.subtract(buffer));
  }

  /// 刷新令牌是否已过期
  ///
  /// 刷新令牌过期后需要重新获取 Token（重新输入激活码）
  bool get isRefreshTokenExpired {
    return DateTime.now().isAfter(refreshTokenExpiresAt);
  }

  /// 是否需要刷新访问令牌
  ///
  /// 访问令牌过期但刷新令牌未过期时返回 true
  bool get needsRefresh {
    return isAccessTokenExpired && !isRefreshTokenExpired;
  }

  /// 是否完全过期（需要重新认证）
  ///
  /// 刷新令牌过期时返回 true
  bool get isFullyExpired {
    return isRefreshTokenExpired;
  }

  /// 从 JSON 反序列化
  factory AmberCloudToken.fromJson(Map<String, dynamic> json) {
    return AmberCloudToken(
      accessToken: json['accessToken'] as String,
      accessTokenExpiresAt:
          DateTime.parse(json['accessTokenExpiresAt'] as String),
      refreshToken: json['refreshToken'] as String,
      refreshTokenExpiresAt:
          DateTime.parse(json['refreshTokenExpiresAt'] as String),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  /// 序列化为 JSON
  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'accessTokenExpiresAt': accessTokenExpiresAt.toIso8601String(),
      'refreshToken': refreshToken,
      'refreshTokenExpiresAt': refreshTokenExpiresAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// 使用新的访问令牌创建副本
  ///
  /// 刷新令牌时使用，保持刷新令牌不变
  AmberCloudToken copyWithNewAccessToken({
    required String accessToken,
    required DateTime accessTokenExpiresAt,
  }) {
    return AmberCloudToken(
      accessToken: accessToken,
      accessTokenExpiresAt: accessTokenExpiresAt,
      refreshToken: refreshToken,
      refreshTokenExpiresAt: refreshTokenExpiresAt,
      createdAt: createdAt,
    );
  }

  @override
  String toString() {
    return 'AmberCloudToken('
        'accessExpired: $isAccessTokenExpired, '
        'refreshExpired: $isRefreshTokenExpired)';
  }
}
