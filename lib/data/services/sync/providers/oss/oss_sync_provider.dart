import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../sync_storage_provider.dart';
import 'oss_provider.dart';

/// ============================================================
/// OSS 同步存储提供者
/// ============================================================
/// 将 IOssClient 适配为 ISyncStorageProvider
/// 实现同步锁、元数据读写等高级功能
/// 所有 OSS 服务（七牛云、阿里云、腾讯云）共用此适配器
/// ============================================================
class OssSyncProvider implements ISyncStorageProvider {
  final IOssClient _client;
  final SyncStorageType _type;

  /// 应用根目录（与 WebDAV 保持一致）
  static const String appRootDir = 'AmberList';

  /// 数据库文件名
  static const String dbFileName = 'amber_list.db';

  /// 元数据文件名
  static const String metaFileName = 'amber_list_meta.json';

  /// 同步锁文件名
  static const String lockFileName = '.sync.lock';

  /// 快照目录
  static const String snapshotDir = 'snapshots';

  OssSyncProvider(this._client, this._type);

  /// 从七牛云客户端创建
  factory OssSyncProvider.qiniu(IOssClient client) {
    return OssSyncProvider(client, SyncStorageType.qiniuOss);
  }

  /// 从阿里云客户端创建（预留）
  factory OssSyncProvider.aliyun(IOssClient client) {
    return OssSyncProvider(client, SyncStorageType.aliOss);
  }

  /// 从腾讯云客户端创建（预留）
  factory OssSyncProvider.tencent(IOssClient client) {
    return OssSyncProvider(client, SyncStorageType.tencentCos);
  }

  @override
  SyncStorageType get type => _type;

  @override
  Future<SyncResult<void>> testConnection() async {
    return _client.testConnection();
  }

  @override
  Future<SyncResult<void>> ensureAppDirectory() async {
    // OSS 是对象存储，不需要显式创建目录
    // 对象 key 自带路径，上传时会自动创建
    // 但我们可以验证一下 bucket 是否可访问
    return const SyncResult.success(null);
  }

  @override
  Future<SyncResult<void>> uploadDatabase(String localPath) async {
    final remoteKey = '$appRootDir/$dbFileName';
    return _client.uploadFile(localPath, remoteKey);
  }

  @override
  Future<SyncResult<bool>> downloadDatabase(String localPath) async {
    final remoteKey = '$appRootDir/$dbFileName';
    return _client.downloadFile(remoteKey, localPath);
  }

  @override
  Future<SyncResult<Map<String, dynamic>?>> readMetadata() async {
    final remoteKey = '$appRootDir/$metaFileName';

    final result = await _client.downloadBytes(remoteKey);
    if (!result.success) {
      return SyncResult.failure(result.error!, result.errorType);
    }

    if (result.data == null) {
      // 文件不存在
      return const SyncResult.success(null);
    }

    try {
      final jsonStr = utf8.decode(result.data!);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      return SyncResult.success(data);
    } catch (e) {
      return SyncResult.failure('解析元数据失败: $e', SyncErrorType.unknown);
    }
  }

  @override
  Future<SyncResult<void>> writeMetadata(Map<String, dynamic> data) async {
    final remoteKey = '$appRootDir/$metaFileName';

    try {
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      final bytes = utf8.encode(jsonStr);
      return _client.uploadBytes(bytes, remoteKey);
    } catch (e) {
      return SyncResult.failure('序列化元数据失败: $e', SyncErrorType.unknown);
    }
  }

  @override
  Future<SyncResult<bool>> acquireLock({
    required String deviceId,
    bool forceAcquire = false,
    Duration lockTimeout = const Duration(minutes: 5),
  }) async {
    final remoteKey = '$appRootDir/$lockFileName';

    // 1. 检查现有锁
    if (!forceAcquire) {
      final existingLockResult = await _client.downloadBytes(remoteKey);
      if (existingLockResult.success && existingLockResult.data != null) {
        try {
          final lockJson = utf8.decode(existingLockResult.data!);
          final lockData = jsonDecode(lockJson) as Map<String, dynamic>;

          final lockDeviceId = lockData['deviceId'] as String?;
          final lockTimeStr = lockData['lockTime'] as String?;

          if (lockDeviceId != null && lockTimeStr != null) {
            final lockTime = DateTime.parse(lockTimeStr);
            final lockAge = DateTime.now().difference(lockTime);

            debugPrint('[Sync] 发现锁: 设备=$lockDeviceId, 时间=$lockTimeStr, 已过${lockAge.inMinutes}分钟');
            debugPrint('[Sync] 当前设备=$deviceId, 锁超时=${lockTimeout.inMinutes}分钟');

            // 如果锁未超时且不是自己的锁，则获取失败
            if (lockAge < lockTimeout && lockDeviceId != deviceId) {
              debugPrint('[Sync] ❌ 锁冲突: 其他设备锁未超时');
              return const SyncResult.failure(
                '其他设备正在同步中，请稍后再试',
                SyncErrorType.locked,
              );
            }

            // 锁超时或是自己的锁，可以覆盖
            if (lockAge >= lockTimeout) {
              debugPrint('[Sync] ⚠️ 锁已超时，将覆盖旧锁');
            } else {
              debugPrint('[Sync] ✅ 是自己的锁，将更新锁时间');
            }
          }
        } catch (e) {
          // 锁文件格式错误，忽略继续获取
        }
      }
    }

    // 2. 写入新锁
    try {
      final lockData = {
        'deviceId': deviceId,
        'lockTime': DateTime.now().toIso8601String(),
      };
      final lockJson = jsonEncode(lockData);
      final lockBytes = utf8.encode(lockJson);

      final uploadResult = await _client.uploadBytes(lockBytes, remoteKey);
      if (!uploadResult.success) {
        return SyncResult.failure(
          uploadResult.error ?? '写入锁文件失败',
          uploadResult.errorType,
        );
      }

      return const SyncResult.success(true);
    } catch (e) {
      return SyncResult.failure('获取锁失败: $e', SyncErrorType.unknown);
    }
  }

  @override
  Future<SyncResult<void>> releaseLock(String deviceId) async {
    final remoteKey = '$appRootDir/$lockFileName';

    // 直接删除锁文件
    // 说明：既然同步已经成功完成，说明锁已经被当前设备获取（可能是覆盖了超时的旧锁）
    // 此时应该无条件删除锁，避免因为 deviceId 不匹配（如 unknown-xxx 的历史遗留锁）而残留
    debugPrint('[Sync] 释放锁: $remoteKey');
    final deleteResult = await _client.deleteFile(remoteKey);
    if (!deleteResult.success) {
      debugPrint('[Sync] ⚠️ 删除锁文件失败: ${deleteResult.error}');
      // 锁删除失败不应阻断同步流程，但要记录下来
    } else {
      debugPrint('[Sync] ✅ 锁已释放');
    }
    return const SyncResult.success(null);
  }

  @override
  Future<SyncResult<void>> uploadSnapshot(
    String localPath,
    String snapshotName,
  ) async {
    final remoteKey = '$appRootDir/$snapshotDir/$snapshotName';
    return _client.uploadFile(localPath, remoteKey);
  }

  @override
  Future<SyncResult<void>> cleanOldSnapshots({int keepCount = 10}) async {
    final prefix = '$appRootDir/$snapshotDir/';

    // 列出所有快照
    final listResult = await _client.listFiles(prefix);
    if (!listResult.success) {
      return SyncResult.failure(listResult.error!, listResult.errorType);
    }

    final snapshots = listResult.data ?? [];
    if (snapshots.length <= keepCount) {
      return const SyncResult.success(null);
    }

    // 按名称排序（名称包含时间戳）
    snapshots.sort();

    // 删除最旧的快照
    final toDelete = snapshots.take(snapshots.length - keepCount);
    for (final snapshotKey in toDelete) {
      await _client.deleteFile(snapshotKey);
    }

    return const SyncResult.success(null);
  }

  @override
  void dispose() {
    _client.dispose();
  }
}
