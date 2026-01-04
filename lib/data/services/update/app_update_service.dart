import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../env/env.dart';
import '../../models/app_update_info.dart';

/// ============================================================
/// 应用更新服务
/// ============================================================
/// 负责检查应用更新、版本比较、跳转下载等功能
/// 支持全平台（macOS、Windows、Android、iOS）

class AppUpdateService {
  /// 单例模式
  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService() => _instance;
  AppUpdateService._internal();

  /// 更新检查 API 地址（从 .env 环境变量读取）
  /// 可以是 GitHub Raw、CDN、自建服务器等
  static String get _updateCheckUrl => Env.appUpdateUrl;

  /// HTTP 请求超时时间
  static const Duration _requestTimeout = Duration(seconds: 10);

  /// 缓存的 PackageInfo
  PackageInfo? _cachedPackageInfo;

  /// 获取当前应用的 PackageInfo（带缓存）
  Future<PackageInfo> getPackageInfo() async {
    _cachedPackageInfo ??= await PackageInfo.fromPlatform();
    return _cachedPackageInfo!;
  }

  /// 检查更新
  ///
  /// [customUrl] 可选的自定义更新检查 URL（用于测试或私有部署）
  /// 返回 [UpdateCheckResult] 包含更新信息和状态
  Future<UpdateCheckResult> checkForUpdates({String? customUrl}) async {
    try {
      final packageInfo = await getPackageInfo();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = packageInfo.buildNumber;

      debugPrint('[AppUpdateService] 当前版本: $currentVersion ($currentBuildNumber)');

      // 发起 HTTP 请求获取更新信息
      // 添加时间戳参数绕过 CDN 缓存，确保每次都获取最新内容
      final baseUrl = customUrl ?? _updateCheckUrl;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final separator = baseUrl.contains('?') ? '&' : '?';
      final url = '$baseUrl${separator}_t=$timestamp';

      debugPrint('[AppUpdateService] 请求 URL: $url');

      final response = await http
          .get(Uri.parse(url))
          .timeout(_requestTimeout);

      if (response.statusCode != 200) {
        debugPrint('[AppUpdateService] 请求失败: ${response.statusCode}');
        return UpdateCheckResult.failure(
          currentVersion: currentVersion,
          currentBuildNumber: currentBuildNumber,
          error: '服务器响应错误: ${response.statusCode}',
        );
      }

      // 解析 JSON 响应
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final updateInfo = AppUpdateInfo.fromJson(json);

      debugPrint('[AppUpdateService] 最新版本: ${updateInfo.latestVersion}');
      debugPrint('[AppUpdateService] 最低版本: ${updateInfo.minimumVersion}');

      // 如果服务端禁用了更新检查
      if (!updateInfo.updateEnabled) {
        debugPrint('[AppUpdateService] 服务端已禁用更新检查');
        return UpdateCheckResult.success(
          updateInfo: updateInfo,
          currentVersion: currentVersion,
          currentBuildNumber: currentBuildNumber,
          updateType: UpdateType.none,
        );
      }

      // 判断更新类型
      final updateType = _determineUpdateType(
        currentVersion: currentVersion,
        latestVersion: updateInfo.latestVersion,
        minimumVersion: updateInfo.minimumVersion,
      );

      debugPrint('[AppUpdateService] 更新类型: $updateType');

      return UpdateCheckResult.success(
        updateInfo: updateInfo,
        currentVersion: currentVersion,
        currentBuildNumber: currentBuildNumber,
        updateType: updateType,
      );
    } catch (e) {
      debugPrint('[AppUpdateService] 检查更新失败: $e');

      // 获取当前版本信息（用于错误返回）
      String currentVersion = '0.0.0';
      String currentBuildNumber = '0';
      try {
        final packageInfo = await getPackageInfo();
        currentVersion = packageInfo.version;
        currentBuildNumber = packageInfo.buildNumber;
      } catch (_) {}

      return UpdateCheckResult.failure(
        currentVersion: currentVersion,
        currentBuildNumber: currentBuildNumber,
        error: '检查更新失败: ${e.toString()}',
      );
    }
  }

  /// 判断更新类型
  ///
  /// 规则：
  /// 1. 如果当前版本 < 最低版本 → 强制更新
  /// 2. 如果当前版本 < 最新版本 → 可选更新
  /// 3. 否则 → 无需更新
  UpdateType _determineUpdateType({
    required String currentVersion,
    required String latestVersion,
    required String minimumVersion,
  }) {
    // 比较当前版本和最低版本
    final cmpWithMinimum = compareVersions(currentVersion, minimumVersion);
    if (cmpWithMinimum < 0) {
      // 当前版本低于最低版本，必须强制更新
      return UpdateType.force;
    }

    // 比较当前版本和最新版本
    final cmpWithLatest = compareVersions(currentVersion, latestVersion);
    if (cmpWithLatest < 0) {
      // 有新版本可用
      return UpdateType.optional;
    }

    // 已是最新版本
    return UpdateType.none;
  }

  /// 版本号比较
  ///
  /// 返回值：
  /// - 负数：v1 < v2
  /// - 0：v1 == v2
  /// - 正数：v1 > v2
  ///
  /// 支持格式：1.0.0、1.0、1
  static int compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    // 补齐长度
    while (parts1.length < 3) {
      parts1.add(0);
    }
    while (parts2.length < 3) {
      parts2.add(0);
    }

    // 逐位比较
    for (int i = 0; i < 3; i++) {
      if (parts1[i] < parts2[i]) return -1;
      if (parts1[i] > parts2[i]) return 1;
    }

    return 0;
  }

  /// 获取当前平台的下载链接
  String? getDownloadUrl(AppUpdateInfo updateInfo) {
    if (Platform.isMacOS) {
      return updateInfo.macosDownloadUrl;
    } else if (Platform.isWindows) {
      return updateInfo.windowsDownloadUrl;
    } else if (Platform.isAndroid) {
      return updateInfo.androidDownloadUrl;
    } else if (Platform.isIOS) {
      return updateInfo.iosDownloadUrl;
    }
    return null;
  }

  /// 打开下载链接
  ///
  /// 根据当前平台选择对应的下载链接并在浏览器中打开
  Future<bool> openDownloadUrl(AppUpdateInfo updateInfo) async {
    final url = getDownloadUrl(updateInfo);
    if (url == null || url.isEmpty) {
      debugPrint('[AppUpdateService] 当前平台无下载链接');
      return false;
    }

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        debugPrint('[AppUpdateService] 已打开下载链接: $url');
        return true;
      } else {
        debugPrint('[AppUpdateService] 无法打开链接: $url');
        return false;
      }
    } catch (e) {
      debugPrint('[AppUpdateService] 打开链接失败: $e');
      return false;
    }
  }

  /// 获取当前平台名称（用于显示）
  String get currentPlatformName {
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    return 'Unknown';
  }

  /// 判断当前平台是否支持应用内更新
  ///
  /// - macOS/Windows: 需要手动下载安装包
  /// - Android: 可以下载 APK 直接安装（需要权限）
  /// - iOS: 只能跳转 App Store
  bool get supportsInAppUpdate {
    // 目前所有平台都跳转浏览器下载，暂不支持应用内更新
    return false;
  }
}
