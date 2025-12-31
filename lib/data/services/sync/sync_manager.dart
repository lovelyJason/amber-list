import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../datasources/local/database.dart';
import 'sync_config.dart';
import 'sync_metadata.dart';
import 'three_way_merge.dart';
import 'webdav_client.dart';

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

/// 同步管理器
class SyncManager {
  /// 当前同步状态
  SyncStatus _status = SyncStatus.idle;
  SyncStatus get status => _status;

  /// 最后同步结果
  MergeResult? _lastMergeResult;
  MergeResult? get lastMergeResult => _lastMergeResult;

  /// 进度回调
  SyncProgressCallback? onProgress;

  /// 同步前回调（用于执行 Checkpoint 等操作）
  Future<void> Function()? onBeforeSync;

  /// 同步完成回调 (bool success)
  void Function(bool success)? onSyncComplete;

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

    debugPrint('[SyncManager] 初始化完成，设备ID: $_deviceId');
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
  String get deviceId => _deviceId ?? 'unknown';

  /// 释放资源
  void dispose() {
    _autoSyncTimer?.cancel();
    _connectivitySubscription?.cancel();
  }

  /// 网络状态变化
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final hasNetwork = results.any((r) => r != ConnectivityResult.none);
    if (hasNetwork) {
      debugPrint('[SyncManager] 网络已恢复');
    }
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

    debugPrint('[SyncManager] 自动同步已启动，间隔: ${config.syncIntervalMinutes} 分钟');
  }

  /// 停止自动同步
  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  // ============================================================
  // 核心同步流程
  // ============================================================

  /// 执行同步
  Future<bool> sync() async {
    if (_isSyncing) {
      debugPrint('[SyncManager] 同步已在进行中');
      return false;
    }

    _isSyncing = true;
    _updateStatus(SyncStatus.connecting, '正在连接服务器...');

    try {
      // 0. 执行同步前钩子 (如 WAL Checkpoint)
      if (onBeforeSync != null) {
        await onBeforeSync!();
      }

      // 1. 加载配置
      final config = await SyncConfigService.loadConfig();
      if (!config.isConfigured) {
        _updateStatus(SyncStatus.failed, '未配置同步服务');
        return false;
      }

      final password = await SyncConfigService.getPassword(config.username);
      if (password == null || password.isEmpty) {
        _updateStatus(SyncStatus.failed, '未保存密码');
        return false;
      }

      // 2. 创建客户端并测试连接
      final client = AmberWebDavClient.fromConfig(config, password);
      final testResult = await client.testConnection();
      if (!testResult.success) {
        _updateStatus(SyncStatus.failed, testResult.error ?? '连接失败');
        await _updateSyncState(success: false, error: testResult.error);
        return false;
      }

      // 3. 确保目录存在
      final dirResult = await client.ensureAppDirectory();
      if (!dirResult.success) {
        _updateStatus(SyncStatus.failed, dirResult.error ?? '创建目录失败');
        return false;
      }

      // ========== 优化：预检查（不获取锁） ==========
      // 在尝试获取锁之前，先检查是否真的需要同步。
      // 这可以避免不必要的 .sync.lock 文件创建/删除（即用户看到的"两条记录"）。
      try {
        _updateStatus(SyncStatus.downloading, '检查远程状态...');

        final metaResult = await client.readMetadata();
        if (metaResult.success && metaResult.data != null) {
          final remoteMeta = RemoteSyncMetadata.fromJson(metaResult.data!);

          // 计算本地校验和
          final paths = await _getSyncPaths();
          final localChecksum = await ChecksumUtils.computeFileChecksum(
            paths['local']!,
          );

          if (remoteMeta.checksum.isNotEmpty &&
              localChecksum == remoteMeta.checksum) {
            debugPrint('[SyncManager] 预检查：本地与远程校验和一致，跳过同步');

            // 更新本地状态
            await _updateSyncState(
              success: true,
              version: remoteMeta.version,
              checksum: localChecksum,
            );

            _updateStatus(SyncStatus.success, '已是最新');
            _isSyncing = false; // 必须手动重置状态，因为直接返回了
            return true;
          }
        }
      } catch (e) {
        // 预检查失败不阻断流程，继续走标准同步
        debugPrint('[SyncManager] 预检查失败: $e');
      }

      // 4. 获取同步锁
      _updateStatus(SyncStatus.connecting, '获取同步锁...');
      final lockResult = await client.acquireLock(deviceId: deviceId);
      if (!lockResult.success) {
        _updateStatus(SyncStatus.failed, lockResult.error ?? '获取锁失败');
        return false;
      }

      try {
        // 5. 执行同步逻辑
        final result = await _doSync(client);
        return result;
      } finally {
        // 释放锁
        await client.releaseLock(deviceId);
      }
    } catch (e, stack) {
      debugPrint('[SyncManager] 同步异常: $e\n$stack');
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

  /// 执行实际的同步逻辑
  Future<bool> _doSync(AmberWebDavClient client) async {
    // 获取路径
    final paths = await _getSyncPaths();
    final localDbPath = paths['local']!;
    final remoteDbPath = paths['remote']!;
    final baseDbPath = paths['base']!;

    // ========== 步骤 1：下载远程元数据 ==========
    _updateStatus(SyncStatus.downloading, '检查远程状态...');

    final metaResult = await client.readMetadata();
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

    debugPrint('[SyncManager] 远程变化: $remoteHasChanges, 本地变化: $localHasChanges');
    debugPrint('[SyncManager] 远程版本: ${remoteMeta?.version ?? 0}, 本地已同步版本: ${localState.lastSyncedVersion}');

    // ========== 情况 A：都没变化 ==========
    if (!remoteHasChanges && !localHasChanges) {
      _updateStatus(SyncStatus.success, '已是最新，无需同步');
      return true;
    }

    // ========== 情况 B：只有本地变化，直接上传 ==========
    if (!remoteHasChanges && localHasChanges) {
      return await _uploadOnly(client, localDbPath, remoteMeta, localChecksum);
    }

    // ========== 情况 C：只有远程变化，直接下载覆盖 ==========
    // remoteHasChanges 为 true 意味着 remoteMeta 一定不为 null（Dart 类型推断）
    if (remoteHasChanges && !localHasChanges) {
      return await _downloadOnly(client, localDbPath, remoteMeta);
    }

    // ========== 情况 D：两边都有变化，三向合并 ==========
    // 走到这里 remoteHasChanges 和 localHasChanges 都为 true
    // remoteHasChanges 为 true 意味着 remoteMeta 一定不为 null
    if (remoteMeta == null) {
      _updateStatus(SyncStatus.failed, '远程元数据异常');
      return false;
    }

    return await _threeWayMerge(
      client,
      localDbPath,
      remoteDbPath,
      baseDbPath,
      remoteMeta,
      localChecksum,
    );
  }

  /// 只上传（本地有改，远程没改）
  Future<bool> _uploadOnly(
    AmberWebDavClient client,
    String localDbPath,
    RemoteSyncMetadata? remoteMeta,
    String localChecksum,
  ) async {
    _updateStatus(SyncStatus.uploading, '上传本地数据...');

    // 上传 DB 文件
    final uploadResult = await client.uploadDatabase(localDbPath);
    if (!uploadResult.success) {
      _updateStatus(SyncStatus.failed, uploadResult.error ?? '上传失败');
      return false;
    }

    // 更新远程元数据
    final newMeta = (remoteMeta ?? RemoteSyncMetadata.initial(deviceId: deviceId))
        .nextVersion(deviceId: deviceId, checksum: localChecksum);

    final metaResult = await client.writeMetadata(newMeta.toJson());
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
    await client.uploadSnapshot(localDbPath, snapshotName);
    await client.cleanOldSnapshots(keepCount: 10);

    _updateStatus(SyncStatus.success, '上传成功！');
    return true;
  }

  /// 只下载（远程有改，本地没改）
  Future<bool> _downloadOnly(
    AmberWebDavClient client,
    String localDbPath,
    RemoteSyncMetadata remoteMeta,
  ) async {
    _updateStatus(SyncStatus.downloading, '下载远程数据...');

    final paths = await _getSyncPaths();
    final remoteDbPath = paths['remote']!;

    // 下载远程 DB
    final downloadResult = await client.downloadDatabase(remoteDbPath);
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

  /// 三向合并（两边都有改）
  Future<bool> _threeWayMerge(
    AmberWebDavClient client,
    String localDbPath,
    String remoteDbPath,
    String baseDbPath,
    RemoteSyncMetadata remoteMeta,
    String localChecksum,
  ) async {
    _updateStatus(SyncStatus.downloading, '下载远程数据...');

    // 下载远程 DB
    final downloadResult = await client.downloadDatabase(remoteDbPath);
    if (!downloadResult.success) {
      _updateStatus(SyncStatus.failed, downloadResult.error ?? '下载失败');
      return false;
    }

    if (downloadResult.data == false) {
      // 远程没有 DB，直接上传本地
      return await _uploadOnly(client, localDbPath, null, localChecksum);
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

    // 上传合并后的 DB
    _updateStatus(SyncStatus.uploading, '上传合并结果...');

    final newChecksum = await ChecksumUtils.computeFileChecksum(localDbPath);

    final uploadResult = await client.uploadDatabase(localDbPath);
    if (!uploadResult.success) {
      _updateStatus(SyncStatus.failed, uploadResult.error ?? '上传失败');
      return false;
    }

    // 更新远程元数据
    final newMeta = remoteMeta.nextVersion(
      deviceId: deviceId,
      checksum: newChecksum,
    );

    final metaResult = await client.writeMetadata(newMeta.toJson());
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
    await client.uploadSnapshot(localDbPath, snapshotName);
    await client.cleanOldSnapshots(keepCount: 10);

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
}
