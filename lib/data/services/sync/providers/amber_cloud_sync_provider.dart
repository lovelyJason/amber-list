import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import '../../../repositories/amber_cloud_repository.dart';
import 'sync_storage_provider.dart';

/// ============================================================
/// 琥珀云同步存储提供者
/// ============================================================
/// 实现 ISyncStorageProvider 接口，通过 AmberCloudRepository 与服务端通信
/// 这是"琥珀云托管"功能的核心实现
///
/// 特点：
/// - 用户无需配置（不需要输入服务器地址、密钥）
/// - 使用激活码自动认证
/// - 数据按激活码隔离存储
/// ============================================================
class AmberCloudSyncProvider implements ISyncStorageProvider {
  final AmberCloudRepository _repository;

  /// 远程文件名常量
  static const String _dbFilename = 'sync.db';
  static const String _metadataFilename = 'sync.meta.json';
  static const String _lockFilename = '.sync.lock';
  static const String _snapshotsDir = 'snapshots';

  AmberCloudSyncProvider(this._repository);

  /// 从激活码创建 Provider
  ///
  /// 使用激活码获取 Token，然后初始化 Provider
  static Future<AmberCloudSyncProvider> fromActivationCode(
    String activationCode,
  ) async {
    final repository = AmberCloudRepository();
    final tokenResult = await repository.getToken(activationCode);

    if (!tokenResult.success) {
      throw Exception(tokenResult.message ?? '获取 Token 失败');
    }

    return AmberCloudSyncProvider(repository);
  }

  /// 从已有 Token 创建 Provider（已登录用户）
  static AmberCloudSyncProvider fromExistingToken() {
    return AmberCloudSyncProvider(AmberCloudRepository());
  }

  @override
  SyncStorageType get type => SyncStorageType.amberCloud;

  @override
  Future<SyncResult<void>> testConnection() async {
    final result = await _repository.testConnection();
    return _convertResult(result);
  }

  @override
  Future<SyncResult<void>> ensureAppDirectory() async {
    // 琥珀云服务端会自动按激活码创建目录，不需要客户端操作
    debugPrint('[AmberCloudSync] ensureAppDirectory: 服务端自动管理目录');
    return const SyncResult.success(null);
  }

  @override
  Future<SyncResult<void>> uploadDatabase(String localPath) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) {
        return const SyncResult.failure('本地数据库文件不存在');
      }

      final content = await file.readAsBytes();
      debugPrint('[AmberCloudSync] 上传数据库: ${content.length} bytes');

      final result = await _repository.uploadFile(_dbFilename, content);
      return _convertResult(result);
    } catch (e) {
      debugPrint('[AmberCloudSync] 上传数据库失败: $e');
      return SyncResult.failure('上传失败: $e', SyncErrorType.unknown);
    }
  }

  @override
  Future<SyncResult<bool>> downloadDatabase(String localPath) async {
    try {
      final result = await _repository.downloadFile(_dbFilename);

      if (!result.success) {
        if (result.isNotFound) {
          debugPrint('[AmberCloudSync] 远程数据库不存在（首次同步）');
          return const SyncResult.success(false);
        }
        return SyncResult.failure(
          result.message ?? '下载失败',
          _mapErrorType(result),
        );
      }

      // 写入本地文件
      final file = File(localPath);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(result.data!);

      debugPrint('[AmberCloudSync] 下载数据库成功: ${result.data!.length} bytes');
      return const SyncResult.success(true);
    } catch (e) {
      debugPrint('[AmberCloudSync] 下载数据库失败: $e');
      return SyncResult.failure('下载失败: $e', SyncErrorType.unknown);
    }
  }

  @override
  Future<SyncResult<Map<String, dynamic>?>> readMetadata() async {
    try {
      final result = await _repository.downloadFile(_metadataFilename);

      if (!result.success) {
        if (result.isNotFound) {
          debugPrint('[AmberCloudSync] 元数据不存在（首次同步）');
          return const SyncResult.success(null);
        }
        return SyncResult.failure(
          result.message ?? '读取失败',
          _mapErrorType(result),
        );
      }

      final jsonStr = utf8.decode(result.data!);
      final metadata = jsonDecode(jsonStr) as Map<String, dynamic>;

      debugPrint('[AmberCloudSync] 读取元数据成功');
      return SyncResult.success(metadata);
    } catch (e) {
      debugPrint('[AmberCloudSync] 读取元数据失败: $e');
      return SyncResult.failure('读取元数据失败: $e', SyncErrorType.unknown);
    }
  }

  @override
  Future<SyncResult<void>> writeMetadata(Map<String, dynamic> data) async {
    try {
      final jsonStr = jsonEncode(data);
      final content = utf8.encode(jsonStr);

      debugPrint('[AmberCloudSync] 写入元数据');

      final result = await _repository.uploadFile(
        _metadataFilename,
        Uint8List.fromList(content),
      );
      return _convertResult(result);
    } catch (e) {
      debugPrint('[AmberCloudSync] 写入元数据失败: $e');
      return SyncResult.failure('写入元数据失败: $e', SyncErrorType.unknown);
    }
  }

  @override
  Future<SyncResult<bool>> acquireLock({
    required String deviceId,
    bool forceAcquire = false,
    Duration lockTimeout = const Duration(minutes: 5),
  }) async {
    try {
      // 先尝试读取现有锁
      final existingLockResult = await _repository.downloadFile(_lockFilename);

      if (existingLockResult.success) {
        // 解析锁文件
        final lockContent = utf8.decode(existingLockResult.data!);
        final lockData = jsonDecode(lockContent) as Map<String, dynamic>;
        final lockDeviceId = lockData['deviceId'] as String?;
        final lockTime = lockData['timestamp'] as int?;

        if (lockDeviceId != null && lockTime != null) {
          final lockDateTime =
              DateTime.fromMillisecondsSinceEpoch(lockTime);
          final isExpired = DateTime.now().difference(lockDateTime) > lockTimeout;

          // 锁未过期且不是当前设备
          if (!isExpired && lockDeviceId != deviceId) {
            if (!forceAcquire) {
              debugPrint('[AmberCloudSync] 锁被其他设备持有: $lockDeviceId');
              return const SyncResult.failure(
                '同步锁被其他设备持有，请稍后重试',
                SyncErrorType.locked,
              );
            }
            debugPrint('[AmberCloudSync] 强制获取锁，忽略现有锁');
          }
        }
      }

      // 创建新锁
      final lockData = {
        'deviceId': deviceId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      final lockContent = utf8.encode(jsonEncode(lockData));

      final result = await _repository.uploadFile(
        _lockFilename,
        Uint8List.fromList(lockContent),
      );

      if (result.success) {
        debugPrint('[AmberCloudSync] 获取锁成功: $deviceId');
        return const SyncResult.success(true);
      }

      return SyncResult.failure(
        result.message ?? '获取锁失败',
        _mapErrorType(result),
      );
    } catch (e) {
      debugPrint('[AmberCloudSync] 获取锁失败: $e');
      return SyncResult.failure('获取锁失败: $e', SyncErrorType.unknown);
    }
  }

  @override
  Future<SyncResult<void>> releaseLock(String deviceId) async {
    try {
      // 先检查锁是否是当前设备持有
      final existingLockResult = await _repository.downloadFile(_lockFilename);

      if (existingLockResult.success) {
        final lockContent = utf8.decode(existingLockResult.data!);
        final lockData = jsonDecode(lockContent) as Map<String, dynamic>;
        final lockDeviceId = lockData['deviceId'] as String?;

        if (lockDeviceId != null && lockDeviceId != deviceId) {
          debugPrint('[AmberCloudSync] 锁不属于当前设备，跳过释放');
          return const SyncResult.success(null);
        }
      } else if (existingLockResult.isNotFound) {
        // 锁不存在，无需释放
        return const SyncResult.success(null);
      }

      // 删除锁文件
      final result = await _repository.deleteFile(_lockFilename);

      if (result.success || result.isNotFound) {
        debugPrint('[AmberCloudSync] 释放锁成功: $deviceId');
        return const SyncResult.success(null);
      }

      return SyncResult.failure(
        result.message ?? '释放锁失败',
        _mapErrorType(result),
      );
    } catch (e) {
      debugPrint('[AmberCloudSync] 释放锁失败: $e');
      return SyncResult.failure('释放锁失败: $e', SyncErrorType.unknown);
    }
  }

  @override
  Future<SyncResult<void>> uploadSnapshot(
    String localPath,
    String snapshotName,
  ) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) {
        return const SyncResult.failure('本地文件不存在');
      }

      final content = await file.readAsBytes();
      final remoteFilename = '$_snapshotsDir/$snapshotName';

      debugPrint('[AmberCloudSync] 上传快照: $snapshotName');

      final result = await _repository.uploadFile(remoteFilename, content);
      return _convertResult(result);
    } catch (e) {
      debugPrint('[AmberCloudSync] 上传快照失败: $e');
      return SyncResult.failure('上传快照失败: $e', SyncErrorType.unknown);
    }
  }

  @override
  Future<SyncResult<void>> cleanOldSnapshots({int keepCount = 10}) async {
    try {
      // 获取文件列表
      final listResult = await _repository.listFiles();
      if (!listResult.success) {
        return SyncResult.failure(
          listResult.message ?? '获取文件列表失败',
          _mapErrorType(listResult),
        );
      }

      // 过滤出快照文件
      final snapshots = listResult.data!
          .where((f) => (f['key'] as String).startsWith('$_snapshotsDir/'))
          .toList();

      if (snapshots.length <= keepCount) {
        debugPrint('[AmberCloudSync] 快照数量未超过限制，无需清理');
        return const SyncResult.success(null);
      }

      // 按时间排序（最新的在前）
      snapshots.sort((a, b) {
        final timeA = a['putTime'] as int? ?? 0;
        final timeB = b['putTime'] as int? ?? 0;
        return timeB.compareTo(timeA);
      });

      // 删除旧快照
      final toDelete = snapshots.skip(keepCount).toList();
      for (final snapshot in toDelete) {
        final key = snapshot['key'] as String;
        final filename = path.basename(key);
        await _repository.deleteFile('$_snapshotsDir/$filename');
        debugPrint('[AmberCloudSync] 删除旧快照: $filename');
      }

      debugPrint('[AmberCloudSync] 清理完成，删除 ${toDelete.length} 个快照');
      return const SyncResult.success(null);
    } catch (e) {
      debugPrint('[AmberCloudSync] 清理快照失败: $e');
      return SyncResult.failure('清理快照失败: $e', SyncErrorType.unknown);
    }
  }

  @override
  void dispose() {
    _repository.dispose();
  }

  /// 转换 API 结果为同步结果
  SyncResult<T> _convertResult<T>(AmberCloudApiResult<T> result) {
    if (result.success) {
      return SyncResult.success(result.data);
    }

    return SyncResult.failure(
      result.message ?? '操作失败',
      _mapErrorType(result),
    );
  }

  /// 映射错误类型
  SyncErrorType _mapErrorType(AmberCloudApiResult result) {
    if (result.isAuthError) {
      return SyncErrorType.authFailed;
    }
    if (result.isNotFound) {
      return SyncErrorType.notFound;
    }
    return SyncErrorType.unknown;
  }
}
