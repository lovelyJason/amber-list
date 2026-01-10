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
import 'providers/amber_cloud_sync_provider.dart';
import '../../repositories/amber_cloud_repository.dart';

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

  /// 数据库替换前回调（用于关闭数据库连接）
  /// 在下载远程数据库并覆盖本地之前调用
  /// 必须确保数据库连接已关闭，否则会导致 "database disk image is malformed" 错误
  Future<void> Function()? onBeforeDbReplace;

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

  /// 强制下载模式标志（用于数据恢复场景）
  bool _forceDownloadMode = false;

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
    final platform = Platform.isAndroid
        ? 'android'
        : Platform.isIOS
            ? 'ios'
            : Platform.isMacOS
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

      case SyncType.amberCloud:
        // 琥珀云托管服务：检查是否已登录
        final repository = AmberCloudRepository();
        final isLoggedIn = await repository.isLoggedIn();
        if (!isLoggedIn) {
          debugPrint('[SyncManager] 琥珀云未登录，请先获取 Token');
          return null;
        }
        return AmberCloudSyncProvider(repository);

      case SyncType.aliOss:
      case SyncType.tencentCos:
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

    // 保存 forceDownload 标志，后续流程会用到
    _forceDownloadMode = forceDownload;

    if (forceDownload) {
      debugPrint('[Sync] 强制下载模式：将直接下载云端数据覆盖本地');
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

          // 强制下载模式下跳过预检查优化，必须走完整流程
          if (_forceDownloadMode) {
            debugPrint('[Sync] 强制下载模式，跳过预检查优化');
          } else if (remoteMeta.checksum.isNotEmpty &&
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
    debugPrint('[Sync] readMetadata 结果: success=${metaResult.success}, '
        'hasData=${metaResult.data != null}, error=${metaResult.error}');

    if (!metaResult.success) {
      _updateStatus(SyncStatus.failed, metaResult.error ?? '读取元数据失败');
      return false;
    }

    final remoteMeta = metaResult.data != null
        ? RemoteSyncMetadata.fromJson(metaResult.data!)
        : null;

    debugPrint('[Sync] remoteMeta 解析结果: ${remoteMeta != null ? "version=${remoteMeta.version}" : "null（云端无元数据）"}');

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
    debugPrint('[Sync] _forceDownloadMode=$_forceDownloadMode');

    // ========== 强制下载模式：跳过所有判断，直接下载覆盖 ==========
    if (_forceDownloadMode) {
      debugPrint('[Sync] 强制下载模式激活，跳过变化检测，直接下载云端数据');
      _forceDownloadMode = false; // 重置标志，避免影响后续同步

      if (remoteMeta == null) {
        _updateStatus(SyncStatus.failed, '云端无数据，无法恢复');
        return false;
      }

      return await _downloadOnlyWithProvider(provider, localDbPath, remoteMeta);
    }

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
    // ========== 上传前验证本地数据库完整性 ==========
    // 确保不会上传损坏的数据库到云端，避免污染其他设备
    _updateStatus(SyncStatus.uploading, '验证本地数据库...');
    final integrityResult = await DatabaseIntegrityUtils.verifyDatabase(localDbPath);
    if (!integrityResult.isOk) {
      debugPrint('[Sync] ❌ 本地数据库损坏，取消上传: ${integrityResult.message}');
      _updateStatus(
        SyncStatus.failed,
        '本地数据库损坏，无法上传。请尝试重启应用或清除数据',
      );
      return false;
    }

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

    // ========== 关键步骤 0：验证下载的数据库完整性 ==========
    // 在替换本地数据库之前，必须先验证下载的文件是否损坏
    // 避免用损坏的数据库覆盖正常的本地数据
    _updateStatus(SyncStatus.downloading, '验证数据库完整性...');
    final integrityResult = await DatabaseIntegrityUtils.verifyDatabase(remoteDbPath);
    if (!integrityResult.isOk) {
      debugPrint('[Sync] ❌ 下载的数据库损坏: ${integrityResult.message}');
      // 清理损坏的临时文件
      try {
        await File(remoteDbPath).delete();
      } catch (_) {}
      _updateStatus(
        SyncStatus.failed,
        '云端数据库已损坏，请在上传设备重新同步或联系支持',
      );
      return false;
    }

    // ========== 关键步骤 1：关闭数据库连接 ==========
    // 在覆盖本地数据库之前，必须先关闭现有的数据库连接
    // 否则 SQLite 可能在内存中持有旧状态，导致覆盖不完整或损坏
    if (onBeforeDbReplace != null) {
      debugPrint('[Sync] 关闭数据库连接...');
      await onBeforeDbReplace!();
    }

    // ========== 关键步骤 2：删除本地 WAL 和 SHM 文件 ==========
    // SQLite 的 WAL (Write-Ahead Logging) 模式会创建 .db-wal 和 .db-shm 文件
    // 如果不删除这些文件，新下载的 DB 会尝试应用旧的 WAL 日志
    // 导致 "database disk image is malformed" 错误
    final walFile = File('$localDbPath-wal');
    final shmFile = File('$localDbPath-shm');
    if (await walFile.exists()) {
      await walFile.delete();
      debugPrint('[Sync] 已删除本地 WAL 文件');
    }
    if (await shmFile.exists()) {
      await shmFile.delete();
      debugPrint('[Sync] 已删除本地 SHM 文件');
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

    // ========== 验证下载的数据库完整性 ==========
    _updateStatus(SyncStatus.downloading, '验证数据库完整性...');
    final integrityResult = await DatabaseIntegrityUtils.verifyDatabase(remoteDbPath);
    if (!integrityResult.isOk) {
      debugPrint('[Sync] ❌ 下载的远程数据库损坏: ${integrityResult.message}');
      // 清理损坏的临时文件
      try {
        await File(remoteDbPath).delete();
      } catch (_) {}
      _updateStatus(
        SyncStatus.failed,
        '云端数据库已损坏，请在上传设备重新同步或联系支持',
      );
      return false;
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

    // ========== 上传前验证合并后的数据库完整性 ==========
    final mergedIntegrity = await DatabaseIntegrityUtils.verifyDatabase(localDbPath);
    if (!mergedIntegrity.isOk) {
      debugPrint('[Sync] ❌ 合并后的数据库损坏，取消上传: ${mergedIntegrity.message}');
      _updateStatus(
        SyncStatus.failed,
        '合并后数据库损坏，请重试或联系支持',
      );
      return false;
    }

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

  /// 检测首次同步冲突
  /// 用于在首次同步时检测双端都有数据的情况
  /// 返回: null 表示无冲突（可以正常同步），否则返回冲突信息
  Future<FirstSyncConflictInfo?> detectFirstSyncConflict() async {
    try {
      // 1. 创建同步提供者
      final provider = await _createProvider();
      if (provider == null) {
        return null; // 未配置同步，无需检测
      }

      // 2. 加载本地同步状态
      final localState = await SyncStateService.loadState();

      // 如果已经同步过（版本号 > 0），则不是首次同步
      if (localState.lastSyncedVersion > 0) {
        debugPrint('[Sync] 非首次同步，跳过冲突检测');
        return null;
      }

      // 3. 测试连接
      final testResult = await provider.testConnection();
      if (!testResult.success) {
        debugPrint('[Sync] 连接失败，跳过冲突检测');
        return null;
      }

      // 4. 读取远程元数据
      final metaResult = await provider.readMetadata();
      if (!metaResult.success || metaResult.data == null) {
        debugPrint('[Sync] 远程无数据，首次同步将上传本地');
        return null;
      }

      final remoteMeta = RemoteSyncMetadata.fromJson(metaResult.data!);

      // 如果远程版本号为 0，说明云端也是空的
      if (remoteMeta.version == 0) {
        debugPrint('[Sync] 远程版本为0，首次同步将上传本地');
        return null;
      }

      // 5. 检查本地是否有数据
      final paths = await _getSyncPaths();
      final localDbPath = paths['local']!;
      final localDbFile = File(localDbPath);

      if (!localDbFile.existsSync()) {
        debugPrint('[Sync] 本地无数据，首次同步将下载云端');
        return null;
      }

      // 6. 计算本地数据校验和
      final localChecksum = await ChecksumUtils.computeFileChecksum(localDbPath);

      // 如果本地和远程校验和一致，说明数据一样，无需询问
      if (localChecksum == remoteMeta.checksum) {
        debugPrint('[Sync] 本地与云端数据一致，无需询问');
        return null;
      }

      // 7. 统计本地任务数量（打开数据库查询）
      int localTaskCount = 0;
      try {
        final db = sqlite3.open(localDbPath);
        final result = db.select('SELECT COUNT(*) as count FROM tasks');
        if (result.isNotEmpty) {
          localTaskCount = result.first['count'] as int;
        }
        db.dispose();
      } catch (e) {
        debugPrint('[Sync] 统计本地任务数失败: $e');
      }

      // 8. 检测到首次同步冲突！
      debugPrint('[Sync] 检测到首次同步冲突：'
          '本地 $localTaskCount 条任务，云端版本 ${remoteMeta.version}');

      return FirstSyncConflictInfo(
        localTaskCount: localTaskCount,
        remoteVersion: remoteMeta.version,
        remoteDevice: remoteMeta.deviceId,
        remoteLastSync: remoteMeta.lastModified,
      );
    } catch (e) {
      debugPrint('[Sync] 首次同步冲突检测失败: $e');
      return null;
    }
  }
}

/// 首次同步冲突信息
class FirstSyncConflictInfo {
  final int localTaskCount;
  final int remoteVersion;
  final String? remoteDevice;
  final DateTime? remoteLastSync;

  FirstSyncConflictInfo({
    required this.localTaskCount,
    required this.remoteVersion,
    this.remoteDevice,
    this.remoteLastSync,
  });
}
