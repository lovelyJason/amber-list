import 'package:flutter/foundation.dart';

/// ============================================================
/// 应用更新信息模型
/// ============================================================
/// 用于存储从服务端获取的版本更新信息
/// 支持全平台（macOS、Windows、Android、iOS）

/// 更新类型枚举
enum UpdateType {
  /// 无需更新
  none,

  /// 可选更新（用户可以跳过）
  optional,

  /// 强制更新（用户必须更新才能继续使用）
  force,
}

/// 应用更新信息
@immutable
class AppUpdateInfo {
  /// 最新版本号（如 "1.2.0"）
  final String latestVersion;

  /// 最新构建号（如 "10"）
  final String latestBuildNumber;

  /// 最低支持版本（低于此版本必须强制更新）
  final String minimumVersion;

  /// 更新日志/发布说明
  final String releaseNotes;

  /// macOS 下载链接
  final String? macosDownloadUrl;

  /// Windows 下载链接
  final String? windowsDownloadUrl;

  /// Android 下载链接（APK 直接下载或应用市场链接）
  final String? androidDownloadUrl;

  /// iOS App Store 链接
  final String? iosDownloadUrl;

  /// 发布日期
  final DateTime? releaseDate;

  /// 是否启用更新检查（服务端开关）
  final bool updateEnabled;

  const AppUpdateInfo({
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.minimumVersion,
    this.releaseNotes = '',
    this.macosDownloadUrl,
    this.windowsDownloadUrl,
    this.androidDownloadUrl,
    this.iosDownloadUrl,
    this.releaseDate,
    this.updateEnabled = true,
  });

  /// 从 JSON 解析
  ///
  /// 服务端返回的 JSON 格式示例：
  /// ```json
  /// {
  ///   "latest_version": "1.2.0",
  ///   "latest_build_number": "10",
  ///   "minimum_version": "1.0.0",
  ///   "release_notes": "- 新增功能A\n- 修复问题B",
  ///   "download_urls": {
  ///     "macos": "https://example.com/AmberList-1.2.0.dmg",
  ///     "windows": "https://example.com/AmberList-1.2.0.exe",
  ///     "android": "https://example.com/AmberList-1.2.0.apk",
  ///     "ios": "https://apps.apple.com/app/amber-list/id123456789"
  ///   },
  ///   "release_date": "2025-01-15T00:00:00Z",
  ///   "update_enabled": true
  /// }
  /// ```
  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    final downloadUrls = json['download_urls'] as Map<String, dynamic>? ?? {};

    return AppUpdateInfo(
      latestVersion: json['latest_version'] as String? ?? '0.0.0',
      latestBuildNumber: json['latest_build_number'] as String? ?? '0',
      minimumVersion: json['minimum_version'] as String? ?? '0.0.0',
      releaseNotes: json['release_notes'] as String? ?? '',
      macosDownloadUrl: downloadUrls['macos'] as String?,
      windowsDownloadUrl: downloadUrls['windows'] as String?,
      androidDownloadUrl: downloadUrls['android'] as String?,
      iosDownloadUrl: downloadUrls['ios'] as String?,
      releaseDate: json['release_date'] != null
          ? DateTime.tryParse(json['release_date'] as String)
          : null,
      updateEnabled: json['update_enabled'] as bool? ?? true,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'latest_version': latestVersion,
      'latest_build_number': latestBuildNumber,
      'minimum_version': minimumVersion,
      'release_notes': releaseNotes,
      'download_urls': {
        if (macosDownloadUrl != null) 'macos': macosDownloadUrl,
        if (windowsDownloadUrl != null) 'windows': windowsDownloadUrl,
        if (androidDownloadUrl != null) 'android': androidDownloadUrl,
        if (iosDownloadUrl != null) 'ios': iosDownloadUrl,
      },
      if (releaseDate != null) 'release_date': releaseDate!.toIso8601String(),
      'update_enabled': updateEnabled,
    };
  }

  /// 默认/空值
  static const empty = AppUpdateInfo(
    latestVersion: '0.0.0',
    latestBuildNumber: '0',
    minimumVersion: '0.0.0',
  );

  @override
  String toString() {
    return 'AppUpdateInfo(latest: $latestVersion, minimum: $minimumVersion)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppUpdateInfo &&
        other.latestVersion == latestVersion &&
        other.latestBuildNumber == latestBuildNumber &&
        other.minimumVersion == minimumVersion;
  }

  @override
  int get hashCode {
    return latestVersion.hashCode ^
        latestBuildNumber.hashCode ^
        minimumVersion.hashCode;
  }
}

/// 更新检查结果
@immutable
class UpdateCheckResult {
  /// 更新信息
  final AppUpdateInfo? updateInfo;

  /// 当前版本号
  final String currentVersion;

  /// 当前构建号
  final String currentBuildNumber;

  /// 更新类型
  final UpdateType updateType;

  /// 检查是否成功
  final bool success;

  /// 错误信息（如果检查失败）
  final String? error;

  /// 检查时间
  final DateTime checkTime;

  const UpdateCheckResult({
    this.updateInfo,
    required this.currentVersion,
    required this.currentBuildNumber,
    required this.updateType,
    required this.success,
    this.error,
    required this.checkTime,
  });

  /// 是否有可用更新
  bool get hasUpdate => updateType != UpdateType.none && success;

  /// 是否需要强制更新
  bool get isForceUpdate => updateType == UpdateType.force;

  /// 创建成功结果
  factory UpdateCheckResult.success({
    required AppUpdateInfo updateInfo,
    required String currentVersion,
    required String currentBuildNumber,
    required UpdateType updateType,
  }) {
    return UpdateCheckResult(
      updateInfo: updateInfo,
      currentVersion: currentVersion,
      currentBuildNumber: currentBuildNumber,
      updateType: updateType,
      success: true,
      checkTime: DateTime.now(),
    );
  }

  /// 创建失败结果
  factory UpdateCheckResult.failure({
    required String currentVersion,
    required String currentBuildNumber,
    required String error,
  }) {
    return UpdateCheckResult(
      currentVersion: currentVersion,
      currentBuildNumber: currentBuildNumber,
      updateType: UpdateType.none,
      success: false,
      error: error,
      checkTime: DateTime.now(),
    );
  }

  @override
  String toString() {
    if (success) {
      return 'UpdateCheckResult(current: $currentVersion, latest: ${updateInfo?.latestVersion}, type: $updateType)';
    }
    return 'UpdateCheckResult(failed: $error)';
  }
}
