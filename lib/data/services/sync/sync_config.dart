import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../env/env.dart';
import 'providers/oss/qiniu_oss_client.dart';

/// ============================================================
/// 同步配置模型和服务
/// ============================================================
/// 管理云同步的配置信息，支持多种同步方式：
/// - WebDAV（坚果云等）
/// - OSS（七牛云、阿里云、腾讯云）
///
/// 配置存储方式：
/// - 密码/SecretKey 存储由 .env 中的 SECRET_STORAGE_TYPE 决定：
///   - keychain: 加密存储在系统钥匙串 (macOS Keychain / Windows Credential Manager)
///   - shared_preferences: 存储在 SharedPreferences（不推荐，仅用于调试）
/// - 其他配置使用 SharedPreferences 存储
/// ============================================================

/// 同步方式类型
/// 用于区分不同的同步后端（WebDAV vs OSS）
enum SyncType {
  /// WebDAV 协议（坚果云等）
  webdav('WebDAV', 'WebDAV 协议同步'),

  /// 七牛云 OSS
  qiniuOss('七牛云 OSS', '七牛云对象存储'),

  /// 阿里云 OSS（预留）
  aliOss('阿里云 OSS', '阿里云对象存储'),

  /// 腾讯云 COS（预留）
  tencentCos('腾讯云 COS', '腾讯云对象存储'),

  /// 琥珀云（托管服务，预留）
  amberCloud('琥珀云', '琥珀清单官方托管服务');

  final String displayName;
  final String description;

  const SyncType(this.displayName, this.description);

  /// 是否是 OSS 类型
  bool get isOss => this == SyncType.qiniuOss ||
                    this == SyncType.aliOss ||
                    this == SyncType.tencentCos;

  /// 是否已实现（可用）
  bool get isAvailable => this == SyncType.webdav || this == SyncType.qiniuOss;
}

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

/// ============================================================
/// 七牛云 OSS 配置实体类
/// ============================================================
/// 存储用户配置的七牛云 OSS 信息
class QiniuOssConfig {
  /// Access Key
  final String accessKey;

  /// Bucket 名称
  final String bucket;

  /// 区域代码
  final String regionCode;

  /// 自定义域名（可选，用于下载加速）
  final String? customDomain;

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

  const QiniuOssConfig({
    this.accessKey = '',
    this.bucket = '',
    this.regionCode = 'z0',
    this.customDomain,
    this.autoSync = true,
    this.syncIntervalMinutes = 10,
    this.lastSyncTime,
    this.lastSyncSuccess,
    this.lastSyncError,
  });

  /// 是否已配置（有有效的 AK 和 Bucket）
  bool get isConfigured => accessKey.isNotEmpty && bucket.isNotEmpty;

  /// 同步间隔 Duration
  Duration get syncInterval => Duration(minutes: syncIntervalMinutes);

  /// 获取区域对象
  QiniuRegion get region => QiniuRegion.fromCode(regionCode) ?? QiniuRegion.z0;

  /// 复制并修改配置
  QiniuOssConfig copyWith({
    String? accessKey,
    String? bucket,
    String? regionCode,
    String? customDomain,
    bool? autoSync,
    int? syncIntervalMinutes,
    DateTime? lastSyncTime,
    bool? lastSyncSuccess,
    String? lastSyncError,
  }) {
    return QiniuOssConfig(
      accessKey: accessKey ?? this.accessKey,
      bucket: bucket ?? this.bucket,
      regionCode: regionCode ?? this.regionCode,
      customDomain: customDomain ?? this.customDomain,
      autoSync: autoSync ?? this.autoSync,
      syncIntervalMinutes: syncIntervalMinutes ?? this.syncIntervalMinutes,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      lastSyncSuccess: lastSyncSuccess ?? this.lastSyncSuccess,
      lastSyncError: lastSyncError ?? this.lastSyncError,
    );
  }

  /// 序列化为 JSON（不包含 SecretKey）
  Map<String, dynamic> toJson() => {
        'accessKey': accessKey,
        'bucket': bucket,
        'regionCode': regionCode,
        'customDomain': customDomain,
        'autoSync': autoSync,
        'syncIntervalMinutes': syncIntervalMinutes,
        'lastSyncTime': lastSyncTime?.toIso8601String(),
        'lastSyncSuccess': lastSyncSuccess,
        'lastSyncError': lastSyncError,
      };

  /// 从 JSON 反序列化
  factory QiniuOssConfig.fromJson(Map<String, dynamic> json) {
    return QiniuOssConfig(
      accessKey: json['accessKey'] ?? '',
      bucket: json['bucket'] ?? '',
      regionCode: json['regionCode'] ?? 'z0',
      customDomain: json['customDomain'],
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

/// 同步配置实体类（WebDAV）
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
/// - 密码/SecretKey 存储方式由 Env.secretStorageType 决定（编译时配置）
/// - 其他配置使用 shared_preferences 存储
/// - 支持 WebDAV 和 OSS 两种同步方式
/// ============================================================
class SyncConfigService {
  // SharedPreferences keys
  static const _syncTypeKey = 'sync_type';              // 当前同步类型
  static const _configKey = 'sync_config';              // WebDAV 配置
  static const _qiniuConfigKey = 'qiniu_oss_config';    // 七牛云配置

  // flutter_secure_storage 密码存储（钥匙串模式使用）
  // 注意：macOS/Windows 桌面端不需要特殊配置，直接使用系统钥匙串
  static FlutterSecureStorage get _secureStorage => const FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    mOptions: MacOsOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // 密码/密钥存储的 key 前缀
  static const _passwordKeyPrefix = 'amber_list_webdav_password_';
  static const _qiniuSecretKeyPrefix = 'amber_list_qiniu_sk_';

  /// 是否使用钥匙串存储（由 .env 配置决定）
  static bool get _useKeychain => Env.useKeychain;

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

  /// 保存密码
  /// 存储方式由 Env.secretStorageType 决定：
  /// - keychain: 使用系统钥匙串（更安全）
  /// - shared_preferences: 使用 SharedPreferences（调试用）
  /// [username] 用户名，用于生成唯一的存储 key
  /// [password] 密码
  static Future<void> savePassword(String username, String password) async {
    final key = '$_passwordKeyPrefix$username';
    final storageType = _useKeychain ? 'keychain' : 'shared_preferences';
    print('[SyncConfig] 开始保存密码: key=$key, 存储方式=$storageType');

    if (_useKeychain) {
      // 钥匙串模式
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
        await _secureStorage.delete(key: key);
        print('[SyncConfig] 已清除当前选项下的旧密钥');
      } catch (_) {
        // 忽略
      }

      // 3. 写入新密码
      try {
        await _secureStorage.write(key: key, value: password);
        print('[SyncConfig] ✅ 密码保存成功 (keychain)');
      } catch (e) {
        print('[SyncConfig] ❌ 密码保存失败: $e');
        rethrow;
      }
    } else {
      // SharedPreferences 模式（调试用，不推荐生产环境）
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(key, password);
        print('[SyncConfig] ✅ 密码保存成功 (shared_preferences)');
      } catch (e) {
        print('[SyncConfig] ❌ 密码保存失败: $e');
        rethrow;
      }
    }
  }

  /// 读取密码
  /// 存储方式由 Env.secretStorageType 决定
  /// [username] 用户名
  /// 返回密码，如果不存在返回 null
  static Future<String?> getPassword(String username) async {
    final key = '$_passwordKeyPrefix$username';
    if (_useKeychain) {
      return await _secureStorage.read(key: key);
    } else {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    }
  }

  /// 删除密码
  /// 存储方式由 Env.secretStorageType 决定
  static Future<void> deletePassword(String username) async {
    final key = '$_passwordKeyPrefix$username';
    if (_useKeychain) {
      await _secureStorage.delete(key: key);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    }
  }

  /// 清除所有同步配置（包括密码）
  /// 会同时清除钥匙串和 SharedPreferences 中的数据，确保彻底清除
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();

    // 清除 SharedPreferences 中的配置
    await prefs.remove(_configKey);

    if (_useKeychain) {
      // 钥匙串模式：清除钥匙串中的密码
      final allKeys = await _secureStorage.readAll();
      for (final key in allKeys.keys) {
        if (key.startsWith(_passwordKeyPrefix)) {
          await _secureStorage.delete(key: key);
        }
      }
    } else {
      // SharedPreferences 模式：清除所有密码 key
      final allKeys = prefs.getKeys();
      for (final key in allKeys) {
        if (key.startsWith(_passwordKeyPrefix)) {
          await prefs.remove(key);
        }
      }
    }
  }

  /// 更新最后同步状态（WebDAV）
  static Future<void> updateLastSyncStatus({
    required bool success,
    String? error,
  }) async {
    final syncType = await getSyncType();
    if (syncType == SyncType.webdav) {
      final config = await loadConfig();
      final updated = config.copyWith(
        lastSyncTime: DateTime.now(),
        lastSyncSuccess: success,
        lastSyncError: error,
      );
      await saveConfig(updated);
    } else if (syncType == SyncType.qiniuOss) {
      final config = await loadQiniuConfig();
      final updated = config.copyWith(
        lastSyncTime: DateTime.now(),
        lastSyncSuccess: success,
        lastSyncError: error,
      );
      await saveQiniuConfig(updated);
    }
  }

  // ============================================================
  // 同步类型管理
  // ============================================================

  /// 获取当前同步类型
  static Future<SyncType?> getSyncType() async {
    final prefs = await SharedPreferences.getInstance();
    final typeStr = prefs.getString(_syncTypeKey);
    if (typeStr == null) return null;

    return SyncType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => SyncType.webdav,
    );
  }

  /// 设置当前同步类型
  static Future<void> setSyncType(SyncType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_syncTypeKey, type.name);
  }

  /// 清除同步类型（禁用同步）
  static Future<void> clearSyncType() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_syncTypeKey);
  }

  /// 检查是否有任何同步配置
  static Future<bool> hasAnySyncConfig() async {
    final syncType = await getSyncType();
    if (syncType == null) return false;

    if (syncType == SyncType.webdav) {
      final config = await loadConfig();
      return config.isConfigured;
    } else if (syncType == SyncType.qiniuOss) {
      final config = await loadQiniuConfig();
      return config.isConfigured;
    }

    return false;
  }

  // ============================================================
  // 七牛云 OSS 配置管理
  // ============================================================

  /// 加载七牛云配置
  static Future<QiniuOssConfig> loadQiniuConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_qiniuConfigKey);

      if (jsonStr == null || jsonStr.isEmpty) {
        return const QiniuOssConfig();
      }

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return QiniuOssConfig.fromJson(json);
    } catch (e) {
      // 配置损坏时返回默认配置
      return const QiniuOssConfig();
    }
  }

  /// 保存七牛云配置（不包含 SecretKey）
  static Future<void> saveQiniuConfig(QiniuOssConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(config.toJson());
    await prefs.setString(_qiniuConfigKey, jsonStr);
  }

  /// 保存七牛云 SecretKey
  /// [accessKey] Access Key，用于生成唯一的存储 key
  /// [secretKey] Secret Key（敏感信息）
  static Future<void> saveQiniuSecretKey(String accessKey, String secretKey) async {
    final key = '$_qiniuSecretKeyPrefix$accessKey';
    final storageType = _useKeychain ? 'keychain' : 'shared_preferences';
    print('[SyncConfig] 开始保存七牛云SK: key=$key, 存储方式=$storageType');

    if (_useKeychain) {
      // 钥匙串模式
      try {
        await _secureStorage.delete(key: key);
      } catch (_) {}

      try {
        await _secureStorage.write(key: key, value: secretKey);
        print('[SyncConfig] ✅ 七牛云SK保存成功 (keychain)');
      } catch (e) {
        print('[SyncConfig] ❌ 七牛云SK保存失败: $e');
        rethrow;
      }
    } else {
      // SharedPreferences 模式（调试用）
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(key, secretKey);
        print('[SyncConfig] ✅ 七牛云SK保存成功 (shared_preferences)');
      } catch (e) {
        print('[SyncConfig] ❌ 七牛云SK保存失败: $e');
        rethrow;
      }
    }
  }

  /// 读取七牛云 SecretKey
  /// [accessKey] Access Key
  /// 返回 SecretKey，如果不存在返回 null
  static Future<String?> getQiniuSecretKey(String accessKey) async {
    final key = '$_qiniuSecretKeyPrefix$accessKey';
    if (_useKeychain) {
      return await _secureStorage.read(key: key);
    } else {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    }
  }

  /// 删除七牛云 SecretKey
  static Future<void> deleteQiniuSecretKey(String accessKey) async {
    final key = '$_qiniuSecretKeyPrefix$accessKey';
    if (_useKeychain) {
      await _secureStorage.delete(key: key);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    }
  }

  /// 清除七牛云配置（包括 SecretKey）
  static Future<void> clearQiniuConfig() async {
    final prefs = await SharedPreferences.getInstance();

    // 清除配置
    await prefs.remove(_qiniuConfigKey);

    // 清除所有七牛云 SecretKey
    if (_useKeychain) {
      final allKeys = await _secureStorage.readAll();
      for (final key in allKeys.keys) {
        if (key.startsWith(_qiniuSecretKeyPrefix)) {
          await _secureStorage.delete(key: key);
        }
      }
    } else {
      final allKeys = prefs.getKeys();
      for (final key in allKeys) {
        if (key.startsWith(_qiniuSecretKeyPrefix)) {
          await prefs.remove(key);
        }
      }
    }
  }

  /// 更新七牛云最后同步状态
  static Future<void> updateQiniuLastSyncStatus({
    required bool success,
    String? error,
  }) async {
    final config = await loadQiniuConfig();
    final updated = config.copyWith(
      lastSyncTime: DateTime.now(),
      lastSyncSuccess: success,
      lastSyncError: error,
    );
    await saveQiniuConfig(updated);
  }
}
