import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ============================================================
/// 同步配置模型和服务
/// ============================================================
/// 管理 WebDAV 云同步的配置信息：
/// - 服务器地址、用户名（存储在 SharedPreferences）
/// - 密码（加密存储在系统钥匙串 - macOS Keychain / Windows Credential Manager）
/// - 同步设置（自动同步开关、同步间隔）
/// ============================================================

/// WebDAV 服务商预设配置
enum SyncProvider {
  /// 坚果云 - 国内最常用的 WebDAV 服务
  jianguoyun(
    displayName: '坚果云',
    defaultUrl: 'https://dav.jianguoyun.com/dav/',
    helpUrl: 'https://help.jianguoyun.com/?p=2064',
  ),

  /// 通用 WebDAV 服务器（用户自定义）
  generic(
    displayName: '通用 WebDAV',
    defaultUrl: '',
    helpUrl: '',
  );

  final String displayName;
  final String defaultUrl;
  final String helpUrl;

  const SyncProvider({
    required this.displayName,
    required this.defaultUrl,
    required this.helpUrl,
  });
}

/// 同步配置实体类
/// 存储用户配置的 WebDAV 服务器信息和同步设置
class SyncConfig {
  /// 服务商类型（坚果云 / 通用 WebDAV）
  final SyncProvider provider;

  /// WebDAV 服务器地址
  /// 坚果云示例: https://dav.jianguoyun.com/dav/
  final String serverUrl;

  /// 用户名（坚果云使用邮箱）
  final String username;

  /// 是否启用自动同步
  final bool autoSync;

  /// 自动同步间隔（分钟）
  final int syncIntervalMinutes;

  /// 最后同步时间
  final DateTime? lastSyncTime;

  /// 最后同步是否成功
  final bool? lastSyncSuccess;

  /// 最后同步错误信息
  final String? lastSyncError;

  const SyncConfig({
    this.provider = SyncProvider.jianguoyun,
    this.serverUrl = '',
    this.username = '',
    this.autoSync = true,
    this.syncIntervalMinutes = 10,
    this.lastSyncTime,
    this.lastSyncSuccess,
    this.lastSyncError,
  });

  /// 是否已配置（有有效的服务器地址和用户名）
  bool get isConfigured => serverUrl.isNotEmpty && username.isNotEmpty;

  /// 同步间隔 Duration
  Duration get syncInterval => Duration(minutes: syncIntervalMinutes);

  /// 复制并修改配置
  SyncConfig copyWith({
    SyncProvider? provider,
    String? serverUrl,
    String? username,
    bool? autoSync,
    int? syncIntervalMinutes,
    DateTime? lastSyncTime,
    bool? lastSyncSuccess,
    String? lastSyncError,
  }) {
    return SyncConfig(
      provider: provider ?? this.provider,
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      autoSync: autoSync ?? this.autoSync,
      syncIntervalMinutes: syncIntervalMinutes ?? this.syncIntervalMinutes,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      lastSyncSuccess: lastSyncSuccess ?? this.lastSyncSuccess,
      lastSyncError: lastSyncError ?? this.lastSyncError,
    );
  }

  /// 序列化为 JSON（不包含密码）
  Map<String, dynamic> toJson() => {
        'provider': provider.name,
        'serverUrl': serverUrl,
        'username': username,
        'autoSync': autoSync,
        'syncIntervalMinutes': syncIntervalMinutes,
        'lastSyncTime': lastSyncTime?.toIso8601String(),
        'lastSyncSuccess': lastSyncSuccess,
        'lastSyncError': lastSyncError,
      };

  /// 从 JSON 反序列化
  factory SyncConfig.fromJson(Map<String, dynamic> json) {
    return SyncConfig(
      provider: SyncProvider.values.firstWhere(
        (e) => e.name == json['provider'],
        orElse: () => SyncProvider.jianguoyun,
      ),
      serverUrl: json['serverUrl'] ?? '',
      username: json['username'] ?? '',
      autoSync: json['autoSync'] ?? true,
      syncIntervalMinutes: json['syncIntervalMinutes'] ?? 10,
      lastSyncTime: json['lastSyncTime'] != null
          ? DateTime.tryParse(json['lastSyncTime'])
          : null,
      lastSyncSuccess: json['lastSyncSuccess'],
      lastSyncError: json['lastSyncError'],
    );
  }
}

/// ============================================================
/// 同步配置服务
/// ============================================================
/// 负责同步配置的持久化存储：
/// - 密码使用 flutter_secure_storage 加密存储到系统钥匙串
/// - 其他配置使用 shared_preferences 存储
/// ============================================================
class SyncConfigService {
  // SharedPreferences key
  static const _configKey = 'sync_config';

  // flutter_secure_storage 密码存储
  // 注意：macOS/Windows 桌面端不需要特殊配置，直接使用系统钥匙串
  static FlutterSecureStorage get _storage => const FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    mOptions: MacOsOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // 密码存储的 key 前缀
  static const _passwordKeyPrefix = 'amber_list_webdav_password_';

  /// 加载同步配置
  static Future<SyncConfig> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_configKey);

      if (jsonStr == null || jsonStr.isEmpty) {
        return const SyncConfig();
      }

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return SyncConfig.fromJson(json);
    } catch (e) {
      // 配置损坏时返回默认配置
      return const SyncConfig();
    }
  }

  /// 保存同步配置（不包含密码）
  static Future<void> saveConfig(SyncConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(config.toJson());
    await prefs.setString(_configKey, jsonStr);
  }

  /// 保存密码到系统钥匙串
  /// [username] 用户名，用于生成唯一的存储 key
  /// [password] 密码
  static Future<void> savePassword(String username, String password) async {
    final key = '$_passwordKeyPrefix$username';
    print('[SyncConfig] 开始保存密码到钥匙串: key=$key');

    // 1. 尝试使用默认选项删除（处理旧版本残留）
    try {
      const defaultStorage = FlutterSecureStorage();
      await defaultStorage.delete(key: key);
      print('[SyncConfig] 已清除默认选项下的旧密钥');
    } catch (_) {
      // 忽略删除失败（可能不存在）
    }

    // 2. 尝试使用当前选项删除（处理重复项）
    try {
      await _storage.delete(key: key);
      print('[SyncConfig] 已清除当前选项下的旧密钥');
    } catch (_) {
      // 忽略
    }

    // 3. 写入新密码
    try {
      await _storage.write(key: key, value: password);
      print('[SyncConfig] ✅ 密码保存成功');
    } catch (e) {
      print('[SyncConfig] ❌ 密码保存失败: $e');
      rethrow;
    }
  }

  /// 从系统钥匙串读取密码
  /// [username] 用户名
  /// 返回密码，如果不存在返回 null
  static Future<String?> getPassword(String username) async {
    final key = '$_passwordKeyPrefix$username';
    return await _storage.read(key: key);
  }

  /// 删除密码
  static Future<void> deletePassword(String username) async {
    final key = '$_passwordKeyPrefix$username';
    await _storage.delete(key: key);
  }

  /// 清除所有同步配置（包括密码）
  static Future<void> clearAll() async {
    // 清除 SharedPreferences 中的配置
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_configKey);

    // 清除所有保存的密码（遍历删除所有以 prefix 开头的 key）
    final allKeys = await _storage.readAll();
    for (final key in allKeys.keys) {
      if (key.startsWith(_passwordKeyPrefix)) {
        await _storage.delete(key: key);
      }
    }
  }

  /// 更新最后同步状态
  static Future<void> updateLastSyncStatus({
    required bool success,
    String? error,
  }) async {
    final config = await loadConfig();
    final updated = config.copyWith(
      lastSyncTime: DateTime.now(),
      lastSyncSuccess: success,
      lastSyncError: error,
    );
    await saveConfig(updated);
  }
}
