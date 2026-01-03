import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../datasources/local/database.dart';
import 'sync_config.dart';
import 'sync_metadata.dart';
import 'three_way_merge.dart';
import 'webdav_client.dart';
import 'providers/sync_storage_provider.dart';
import 'providers/webdav_sync_provider.dart';
import 'providers/oss/oss_sync_provider.dart';
import 'providers/oss/qiniu_oss_client.dart';

/// ============================================================
/// 同步管理器
/// ============================================================
/// 云同步的核心协调者，按照文档设计实现 DB 文件同步：
///
/// 同步流程：
/// 1. 下载远程 DB 文件 → temp_remote.db
/// 2. 下载远程元数据 → 判断本地/远程是否有变化
/// 3. 根据变化情况选择策略：
///    - 远程没更新 & 本地没改 → 结束
///    - 远程没更新 & 本地有改 → 直接上传
///    - 远程有更新 & 本地没改 → 直接下载覆盖
///    - 远程有更新 & 本地有改 → 三向合并
/// 4. 上传合并后的 DB 和元数据
/// 5. 更新本地同步快照
/// ============================================================

/// 同步状态
enum SyncStatus {
  /// 空闲
  idle,

  /// 正在连接
  connecting,

  /// 正在下载
  downloading,

  /// 正在合并
  merging,

  /// 正在上传
  uploading,

  /// 同步成功
  success,

  /// 同步失败
  failed,
}

/// 同步进度回调
typedef SyncProgressCallback = void Function(
  SyncStatus status,
  String message,
);

/// 冲突决策回调
/// 当检测到需要用户决策的冲突时调用
/// 返回用户对每个冲突的决策列表
typedef ConflictResolutionCallback = Future<List<ConflictResolution>?> Function(
  List<RecordConflict> conflicts,
);

/// 同步管理器
class SyncManager {
  /// 当前同步状态
  SyncStatus _status = SyncStatus.idle;
  SyncStatus get status => _status;

  /// 最后一次同步的错误信息（用于 UI 显示）
  String? _lastError;
  String? get lastError => _lastError;

  /// 最后同步结果
  MergeResult? _lastMergeResult;
  MergeResult? get lastMergeResult => _lastMergeResult;

  /// 进度回调
  SyncProgressCallback? onProgress;

  /// 同步前回调（用于执行 Checkpoint 等操作）
  Future<void> Function()? onBeforeSync;

  /// 同步完成回调 (bool success)
  void Function(bool success)? onSyncComplete;

  /// 冲突决策回调
  /// 当检测到冲突时，通过此回调让 UI 层弹窗让用户选择
  /// 如果未设置或返回 null，则跳过冲突处理（冲突记录保持原样）
  ConflictResolutionCallback? onConflictDetected;

  /// 设备 ID
  String? _deviceId;

  /// SharedPreferences key
  static const _deviceIdKey = 'amber_list_device_id';

  /// 自动同步定时器
  Timer? _autoSyncTimer;

  /// 网络状态订阅
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// 是否正在同步
  bool _isSyncing = false;

  /// 初始化同步管理器
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString(_deviceIdKey);

    if (_deviceId == null) {
      _deviceId = _generateDeviceId();
      await prefs.setString(_deviceIdKey, _deviceId!);
    }

    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen(_onConnectivityChanged);

    debugPrint('[Sync] 设备: $_deviceId');
  }

  /// 生成设备 ID
  String _generateDeviceId() {
    final platform = Platform.isMacOS
        ? 'mac'
        : Platform.isWindows
            ? 'win'
            : Platform.isLinux
                ? 'linux'
                : 'unknown';
    final uuid = const Uuid().v4().substring(0, 8);
    return '$platform-$uuid';
  }

  /// 获取设备 ID
  /// 注意：必须在 initialize() 完成后调用，否则抛出异常
  String get deviceId {
    if (_deviceId == null) {
      throw StateError('[SyncManager] deviceId 尚未初始化，请先调用 initialize()');
    }
    return _deviceId!;
  }

  /// 释放资源
  void dispose() {
    _autoSyncTimer?.cancel();
    _connectivitySubscription?.cancel();
  }

  /// 网络状态变化
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    // 网络恢复时可触发自动同步（暂时只记录状态）
  }

  /// 启动自动同步
  void startAutoSync(SyncConfig config) {
    _autoSyncTimer?.cancel();

    if (!config.autoSync || !config.isConfigured) {
      return;
    }

    _autoSyncTimer = Timer.periodic(
      config.syncInterval,
      (_) => sync(),
    );
  }

  /// 停止自动同步
  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  // ============================================================
  // 核心同步流程
  // ============================================================

  /// 创建同步存储提供者
  /// 根据当前配置的同步类型创建对应的 Provider
  Future<ISyncStorageProvider?> _createProvider() async {
    final syncType = await SyncConfigService.getSyncType();
    if (syncType == null) return null;

    switch (syncType) {
      case SyncType.webdav:
        final config = await SyncConfigService.loadConfig();
        if (!config.isConfigured) return null;

        final password = await SyncConfigService.getPassword(config.username);
        if (password == null || password.isEmpty) return null;

        final client = AmberWebDavClient.fromConfig(config, password);
        return WebDavSyncProvider(client);

      case SyncType.qiniuOss:
        final config = await SyncConfigService.loadQiniuConfig();
        if (!config.isConfigured) return null;

        final secretKey = await SyncConfigService.getQiniuSecretKey(config.accessKey);
        if (secretKey == null || secretKey.isEmpty) return null;

        final ossClient = QiniuOssClient(
          accessKey: config.accessKey,
          secretKey: secretKey,
          bucket: config.bucket,
          region: config.region,
          customDomain: config.customDomain,
        );
        return OssSyncProvider.qiniu(ossClient);

      case SyncType.aliOss:
      case SyncType.tencentCos:
      case SyncType.amberCloud:
        // 预留：暂未实现
        debugPrint('[SyncManager] 同步类型 $syncType 暂未实现');
        return null;
    }
  }

  /// 执行同步
  /// [forceDownload] 强制从云端下载（忽略本地状态，用于数据恢复场景）
  Future<bool> sync({bool forceDownload = false}) async {
    if (_isSyncing) {
      return false;
    }

    // 强制下载模式：清除本地同步状态，让系统认为"远程有变化"
    if (forceDownload) {
      debugPrint('[Sync] 强制下载模式：清除本地同步状态');
      await SyncStateService.clearState();
    }

    _isSyncing = true;
    _updateStatus(SyncStatus.connecting, '正在连接服务器...');

    try {
      // 0. 执行同步前钩子 (如 WAL Checkpoint)
      if (onBeforeSync != null) {
        await onBeforeSync!();
      }

      // 0.1 额外保险：用原生 sqlite3 再做一次 checkpoint
      // 确保 Drift 的 checkpoint 真的生效了
      try {
        final dbPath = await AppDatabase.getDatabasePath();
        final db = sqlite3.open(dbPath);
        db.execute('PRAGMA wal_checkpoint(TRUNCATE);');
        db.dispose();
        debugPrint('[Sync] 原生 sqlite3 checkpoint 完成');
      } catch (e) {
        debugPrint('[Sync] 原生 sqlite3 checkpoint 失败: $e');
      }

      // 1. 创建同步提供者
      final provider = await _createProvider();
      if (provider == null) {
        _updateStatus(SyncStatus.failed, '未配置同步服务');
        return false;
      }

      // 2. 测试连接
      final testResult = await provider.testConnection();
      if (!testResult.success) {
        _updateStatus(SyncStatus.failed, testResult.error ?? '连接失败');
        await _updateSyncState(success: false, error: testResult.error);
        return false;
      }

      // 3. 确保目录存在
      final dirResult = await provider.ensureAppDirectory();
      if (!dirResult.success) {
        _updateStatus(SyncStatus.failed, dirResult.error ?? '创建目录失败');
        return false;
      }

      // ========== 优化：预检查（不获取锁） ==========
      // 在尝试获取锁之前，先检查是否真的需要同步。
      // 这可以避免不必要的 .sync.lock 文件创建/删除（即用户看到的"两条记录"）。
      try {
        _updateStatus(SyncStatus.downloading, '检查远程状态...');

        final metaResult = await provider.readMetadata();
        if (metaResult.success && metaResult.data != null) {
          final remoteMeta = RemoteSyncMetadata.fromJson(metaResult.data!);

          // 计算本地校验和
          final paths = await _getSyncPaths();
          final localDbFile = File(paths['local']!);

          // 调试：输出数据库文件信息（包括 WAL）
          if (localDbFile.existsSync()) {
            final stat = await localDbFile.stat();
            debugPrint('[Sync] 本地DB文件: ${paths['local']}');
            debugPrint('[Sync] 本地DB大小: ${stat.size} bytes, 修改时间: ${stat.modified}');

            // 检查 WAL 文件
            final walFile = File('${paths['local']}-wal');
            if (walFile.existsSync()) {
              final walStat = await walFile.stat();
              debugPrint('[Sync] WAL文件大小: ${walStat.size} bytes');
              if (walStat.size > 0) {
                debugPrint('[Sync] ⚠️ WAL文件不为空！checkpoint 可能没有完全生效');
              }
            } else {
              debugPrint('[Sync] WAL文件不存在（正常，checkpoint 后会被清空）');
            }
          }

          final localChecksum = await ChecksumUtils.computeFileChecksum(
            paths['local']!,
          );

          debugPrint('[Sync] 预检查: 本地checksum=$localChecksum, 远程checksum=${remoteMeta.checksum}');

          if (remoteMeta.checksum.isNotEmpty &&
              localChecksum == remoteMeta.checksum) {
            // 快速路径：checksum 一致，无需获取锁
            debugPrint('[Sync] 双端无变化 (远程v${remoteMeta.version}, 本地checksum一致)');

            // 更新本地状态
            await _updateSyncState(
              success: true,
              version: remoteMeta.version,
              checksum: localChecksum,
            );

            _updateStatus(SyncStatus.success, '已是最新');
            _isSyncing = false; // 必须手动重置状态，因为直接返回了
            return true;
          } else {
            debugPrint('[Sync] 预检查发现变化，继续完整同步流程');
          }
        }
      } catch (e) {
        debugPrint('[Sync] 预检查异常: $e');
        // 预检查失败不阻断流程，继续走标准同步
      }

      // 4. 获取同步锁
      _updateStatus(SyncStatus.connecting, '获取同步锁...');
      final lockResult = await provider.acquireLock(deviceId: deviceId);
      if (!lockResult.success) {
        _updateStatus(SyncStatus.failed, lockResult.error ?? '获取锁失败');
        return false;
      }

      try {
        // 5. 执行同步逻辑
        final result = await _doSyncWithProvider(provider);
        return result;
      } finally {
        // 释放锁
        await provider.releaseLock(deviceId);
      }
    } catch (e, stack) {
      debugPrint('[Sync] 异常: $e\n$stack');
      _updateStatus(SyncStatus.failed, '同步异常: $e');
      await _updateSyncState(success: false, error: e.toString());
      return false;
    } finally {
      _isSyncing = false;
      onSyncComplete?.call(
        _lastMergeResult?.success ?? _status == SyncStatus.success,
      );
    }
  }

  /// 执行实际的同步逻辑（使用统一接口）
  Future<bool> _doSyncWithProvider(ISyncStorageProvider provider) async {
    // 获取路径
    final paths = await _getSyncPaths();
    final localDbPath = paths['local']!;
    final remoteDbPath = paths['remote']!;
    final baseDbPath = paths['base']!;

    // ========== 步骤 1：下载远程元数据 ==========
    _updateStatus(SyncStatus.downloading, '检查远程状态...');

    final metaResult = await provider.readMetadata();
    if (!metaResult.success) {
      _updateStatus(SyncStatus.failed, metaResult.error ?? '读取元数据失败');
      return false;
    }

    final remoteMeta = metaResult.data != null
        ? RemoteSyncMetadata.fromJson(metaResult.data!)
        : null;

    // 加载本地状态
    final localState = await SyncStateService.loadState();

    // 计算本地数据库校验和
    final localChecksum = await ChecksumUtils.computeFileChecksum(localDbPath);

    // ========== 步骤 2：判断变化情况 ==========
    final remoteHasChanges = remoteMeta != null &&
        remoteMeta.version > localState.lastSyncedVersion;
    final localHasChanges = localChecksum != localState.lastSyncedChecksum;

    // 输出详细的同步状态摘要（帮助排查冲突检测问题）
    final remoteVer = remoteMeta?.version ?? 0;
    final localVer = localState.lastSyncedVersion;
    final statusDesc = !remoteHasChanges && !localHasChanges
        ? '双端无变化'
        : !remoteHasChanges && localHasChanges
            ? '本地领先 → 上传'
            : remoteHasChanges && !localHasChanges
                ? '远程领先 → 下载'
                : '双端都有变化 → 合并';
    debugPrint('[Sync] $statusDesc');
    debugPrint('[Sync] 远程: version=$remoteVer, checksum=${remoteMeta?.checksum ?? "无"}');
    debugPrint('[Sync] 本地: lastSyncedVersion=$localVer, lastSyncedChecksum=${localState.lastSyncedChecksum}');
    debugPrint('[Sync] 当前本地checksum=$localChecksum');
    debugPrint('[Sync] remoteHasChanges=$remoteHasChanges, localHasChanges=$localHasChanges');

    // ========== 情况 A：都没变化 ==========
    if (!remoteHasChanges && !localHasChanges) {
      _updateStatus(SyncStatus.success, '已是最新，无需同步');
      return true;
    }

    // ========== 情况 B：只有本地变化，直接上传 ==========
    if (!remoteHasChanges && localHasChanges) {
      return await _uploadOnlyWithProvider(provider, localDbPath, remoteMeta, localChecksum);
    }

    // ========== 情况 C：只有远程变化，直接下载覆盖 ==========
    // remoteHasChanges 为 true 意味着 remoteMeta 一定不为 null（Dart 类型推断）
    if (remoteHasChanges && !localHasChanges) {
      return await _downloadOnlyWithProvider(provider, localDbPath, remoteMeta);
    }

    // ========== 情况 D：两边都有变化，三向合并 ==========
    // 走到这里 remoteHasChanges 和 localHasChanges 都为 true
    // remoteHasChanges 为 true 意味着 remoteMeta 一定不为 null
    if (remoteMeta == null) {
      _updateStatus(SyncStatus.failed, '远程元数据异常');
      return false;
    }

    return await _threeWayMergeWithProvider(
      provider,
      localDbPath,
      remoteDbPath,
      baseDbPath,
      remoteMeta,
      localChecksum,
    );
  }

  /// 只上传（本地有改，远程没改）- 统一接口版本
  Future<bool> _uploadOnlyWithProvider(
    ISyncStorageProvider provider,
    String localDbPath,
    RemoteSyncMetadata? remoteMeta,
    String localChecksum,
  ) async {
    _updateStatus(SyncStatus.uploading, '上传本地数据...');

    // 上传 DB 文件
    final uploadResult = await provider.uploadDatabase(localDbPath);
    if (!uploadResult.success) {
      _updateStatus(SyncStatus.failed, uploadResult.error ?? '上传失败');
      return false;
    }

    // 更新远程元数据
    final newMeta = (remoteMeta ?? RemoteSyncMetadata.initial(deviceId: deviceId))
        .nextVersion(deviceId: deviceId, checksum: localChecksum);

    final metaResult = await provider.writeMetadata(newMeta.toJson());
    if (!metaResult.success) {
      _updateStatus(SyncStatus.failed, metaResult.error ?? '更新元数据失败');
      return false;
    }

    // 保存本地快照
    await _saveLocalSnapshot(localDbPath);

    // 更新本地状态
    await _updateSyncState(
      success: true,
      version: newMeta.version,
      checksum: localChecksum,
    );

    // 上传远程快照
    final snapshotName = 'amber_list_${DateTime.now().millisecondsSinceEpoch}.db';
    await provider.uploadSnapshot(localDbPath, snapshotName);
    await provider.cleanOldSnapshots(keepCount: 10);

    _updateStatus(SyncStatus.success, '上传成功！');
    return true;
  }

  /// 只下载（远程有改，本地没改）- 统一接口版本
  Future<bool> _downloadOnlyWithProvider(
    ISyncStorageProvider provider,
    String localDbPath,
    RemoteSyncMetadata remoteMeta,
  ) async {
    _updateStatus(SyncStatus.downloading, '下载远程数据...');

    final paths = await _getSyncPaths();
    final remoteDbPath = paths['remote']!;

    // 下载远程 DB
    final downloadResult = await provider.downloadDatabase(remoteDbPath);
    if (!downloadResult.success) {
      _updateStatus(SyncStatus.failed, downloadResult.error ?? '下载失败');
      return false;
    }

    if (downloadResult.data == false) {
      _updateStatus(SyncStatus.failed, '远程数据库不存在');
      return false;
    }

    // 用远程 DB 覆盖本地
    await File(remoteDbPath).copy(localDbPath);

    // 保存本地快照
    await _saveLocalSnapshot(localDbPath);

    // 计算新的校验和
    final newChecksum = await ChecksumUtils.computeFileChecksum(localDbPath);

    // 更新本地状态
    await _updateSyncState(
      success: true,
      version: remoteMeta.version,
      checksum: newChecksum,
    );

    // 清理临时文件
    await File(remoteDbPath).delete();

    _updateStatus(SyncStatus.success, '下载成功！');
    return true;
  }

  /// 三向合并（两边都有改）- 统一接口版本
  Future<bool> _threeWayMergeWithProvider(
    ISyncStorageProvider provider,
    String localDbPath,
    String remoteDbPath,
    String baseDbPath,
    RemoteSyncMetadata remoteMeta,
    String localChecksum,
  ) async {
    _updateStatus(SyncStatus.downloading, '下载远程数据...');

    // 下载远程 DB
    final downloadResult = await provider.downloadDatabase(remoteDbPath);
    if (!downloadResult.success) {
      _updateStatus(SyncStatus.failed, downloadResult.error ?? '下载失败');
      return false;
    }

    if (downloadResult.data == false) {
      // 远程没有 DB，直接上传本地
      return await _uploadOnlyWithProvider(provider, localDbPath, null, localChecksum);
    }

    // 执行三向合并
    _updateStatus(SyncStatus.merging, '合并数据...');

    final mergeEngine = ThreeWayMergeEngine();
    final mergeResult = await mergeEngine.merge(
      localDbPath: localDbPath,
      remoteDbPath: remoteDbPath,
      baseDbPath: File(baseDbPath).existsSync() ? baseDbPath : null,
    );

    _lastMergeResult = mergeResult;

    if (!mergeResult.success) {
      _updateStatus(SyncStatus.failed, mergeResult.error ?? '合并失败');
      return false;
    }

    debugPrint('[SyncManager] 合并完成: ${mergeResult.stats}');

    // ========== 处理冲突 ==========
    // 如果有需要用户决策的冲突，通过回调让 UI 弹窗
    if (mergeResult.stats.hasPendingConflicts) {
      final conflicts = mergeResult.stats.pendingConflicts;
      debugPrint('[SyncManager] 检测到 ${conflicts.length} 个冲突，等待用户决策...');

      if (onConflictDetected != null) {
        _updateStatus(SyncStatus.merging, '发现 ${conflicts.length} 个冲突，请选择...');

        // 调用回调，让 UI 层弹窗
        final resolutions = await onConflictDetected!(conflicts);

        if (resolutions == null || resolutions.length != conflicts.length) {
          // 用户取消或决策不完整，中止同步
          _updateStatus(SyncStatus.failed, '用户取消了冲突处理');
          return false;
        }

        // 应用用户决策
        final applied = await mergeEngine.applyConflictResolutions(
          localDbPath: localDbPath,
          conflicts: conflicts,
          resolutions: resolutions,
        );

        if (!applied) {
          _updateStatus(SyncStatus.failed, '应用冲突决策失败');
          return false;
        }

        debugPrint('[SyncManager] 已应用 ${conflicts.length} 个冲突决策');
      } else {
        // 没有设置回调，跳过冲突处理（保持本地版本）
        debugPrint('[SyncManager] 未设置冲突回调，跳过冲突处理');
      }
    }

    // 上传合并后的 DB
    _updateStatus(SyncStatus.uploading, '上传合并结果...');

    // 验证冲突解决后的数据（调试用）
    if (mergeResult.stats.hasPendingConflicts) {
      try {
        final verifyDb = sqlite3.open(localDbPath);
        for (final conflict in mergeResult.stats.pendingConflicts) {
          final rows = verifyDb.select(
            'SELECT * FROM ${conflict.tableName} WHERE id = ?',
            [conflict.recordId],
          );
          debugPrint('[SyncManager] 上传前验证 ${conflict.tableName}/${conflict.recordId}: '
              '${rows.isNotEmpty ? rows.first : "已删除"}');
        }
        verifyDb.dispose();
      } catch (e) {
        debugPrint('[SyncManager] 上传前验证失败: $e');
      }
    }

    final newChecksum = await ChecksumUtils.computeFileChecksum(localDbPath);

    final uploadResult = await provider.uploadDatabase(localDbPath);
    if (!uploadResult.success) {
      _updateStatus(SyncStatus.failed, uploadResult.error ?? '上传失败');
      return false;
    }

    // 更新远程元数据
    final newMeta = remoteMeta.nextVersion(
      deviceId: deviceId,
      checksum: newChecksum,
    );

    final metaResult = await provider.writeMetadata(newMeta.toJson());
    if (!metaResult.success) {
      _updateStatus(SyncStatus.failed, metaResult.error ?? '更新元数据失败');
      return false;
    }

    // 保存本地快照
    await _saveLocalSnapshot(localDbPath);

    // 更新本地状态
    await _updateSyncState(
      success: true,
      version: newMeta.version,
      checksum: newChecksum,
    );

    // 上传远程快照
    final snapshotName = 'amber_list_${DateTime.now().millisecondsSinceEpoch}.db';
    await provider.uploadSnapshot(localDbPath, snapshotName);
    await provider.cleanOldSnapshots(keepCount: 10);

    // 清理临时文件
    await File(remoteDbPath).delete();

    _updateStatus(
      SyncStatus.success,
      '同步成功！${mergeResult.stats}',
    );
    return true;
  }

  // ============================================================
  // 辅助方法
  // ============================================================

  /// 获取同步相关的文件路径
  Future<Map<String, String>> _getSyncPaths() async {
    final docDir = await getApplicationDocumentsDirectory();

    return {
      'local': await AppDatabase.getDatabasePath(),
      'remote': p.join(docDir.path, 'temp_remote.db'),
      'base': p.join(docDir.path, 'amber_list_sync_base.db'),
    };
  }

  /// 保存本地快照
  Future<void> _saveLocalSnapshot(String localDbPath) async {
    try {
      final paths = await _getSyncPaths();
      final baseDbPath = paths['base']!;
      await File(localDbPath).copy(baseDbPath);
      debugPrint('[SyncManager] 本地快照已保存');
    } catch (e) {
      debugPrint('[SyncManager] 保存本地快照失败: $e');
    }
  }

  /// 更新状态
  void _updateStatus(SyncStatus status, String message) {
    _status = status;
    // 失败时保存错误信息，成功时清空
    if (status == SyncStatus.failed) {
      _lastError = message;
    } else if (status == SyncStatus.success) {
      _lastError = null;
    }
    onProgress?.call(status, message);
    debugPrint('[SyncManager] $status: $message');
  }

  /// 更新同步状态
  Future<void> _updateSyncState({
    required bool success,
    int? version,
    String? checksum,
    String? error,
  }) async {
    final state = await SyncStateService.loadState();

    LocalSyncState newState;
    if (success) {
      newState = state.withSyncSuccess(
        version: version ?? state.lastSyncedVersion,
        checksum: checksum ?? state.lastSyncedChecksum,
      );
    } else {
      newState = state.withSyncFailure(error ?? '未知错误');
    }

    await SyncStateService.saveState(newState);

    // 同时更新 SyncConfig 中的状态（用于设置页面显示）
    await SyncConfigService.updateLastSyncStatus(
      success: success,
      error: error,
    );
  }

  /// 检查网络是否可用
  Future<bool> isNetworkAvailable() async {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// 测试 WebDAV 连接
  Future<WebDavResult<void>> testConnection({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    final client = AmberWebDavClient(
      serverUrl: serverUrl,
      username: username,
      password: password,
    );
    return client.testConnection();
  }

  /// 测试七牛云 OSS 连接
  Future<SyncResult<void>> testQiniuConnection({
    required String accessKey,
    required String secretKey,
    required String bucket,
    required QiniuRegion region,
    String? customDomain,
  }) async {
    final client = QiniuOssClient(
      accessKey: accessKey,
      secretKey: secretKey,
      bucket: bucket,
      region: region,
      customDomain: customDomain,
    );
    return client.testConnection();
  }
}
