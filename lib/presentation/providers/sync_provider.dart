import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/sync/sync_config.dart';
import '../../data/services/sync/sync_manager.dart';
import '../../data/services/sync/sync_metadata.dart';
import '../../data/services/sync/three_way_merge.dart';
import 'database_provider.dart';

/// ============================================================
/// 同步状态 Provider
/// ============================================================
/// 管理云同步的全局状态（支持 WebDAV 和 OSS）

/// 首次同步冲突检测结果
/// 用于在首次同步时检测双端都有数据的情况
@immutable
class FirstSyncConflict {
  /// 本地任务数量
  final int localTaskCount;

  /// 云端版本号
  final int remoteVersion;

  /// 云端最后同步设备
  final String? remoteDevice;

  /// 云端最后同步时间
  final DateTime? remoteLastSync;

  const FirstSyncConflict({
    required this.localTaskCount,
    required this.remoteVersion,
    this.remoteDevice,
    this.remoteLastSync,
  });
}

/// 首次同步冲突用户选择
enum FirstSyncChoice {
  /// 从云端恢复（覆盖本地）
  downloadFromCloud,

  /// 上传到云端（覆盖云端）
  uploadToCloud,

  /// 取消同步
  cancel,
}

/// 首次同步冲突决策回调
/// 当检测到首次同步且双端都有数据时调用
/// 返回用户的选择
typedef FirstSyncConflictCallback = Future<FirstSyncChoice?> Function(
  FirstSyncConflict conflict,
);

/// 同步状态数据类
@immutable
class SyncState {
  /// 是否正在同步
  final bool isSyncing;

  /// 上次同步时间
  final DateTime? lastSyncTime;

  /// 上次错误信息
  final String? lastError;

  /// 标签冲突列表
  final List<TagConflict> tagConflicts;

  const SyncState({
    this.isSyncing = false,
    this.lastSyncTime,
    this.lastError,
    this.tagConflicts = const [],
  });

  SyncState copyWith({
    bool? isSyncing,
    DateTime? lastSyncTime,
    String? lastError,
    bool? clearError,
    List<TagConflict>? tagConflicts,
    bool? clearConflicts,
  }) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      lastError: clearError == true ? null : (lastError ?? this.lastError),
      tagConflicts: clearConflicts == true
          ? []
          : (tagConflicts ?? this.tagConflicts),
    );
  }
}

/// 同步配置 Provider（WebDAV）
final syncConfigProvider = StateProvider<SyncConfig?>((ref) => null);

/// 七牛云配置 Provider
final qiniuConfigProvider = StateProvider<QiniuOssConfig?>((ref) => null);

/// 当前同步类型 Provider
final syncTypeProvider = StateProvider<SyncType?>((ref) => null);

/// 同步状态 Provider
final syncStateProvider = StateNotifierProvider<SyncStateNotifier, SyncState>((ref) {
  return SyncStateNotifier(ref);
});

/// 同步状态 Notifier
class SyncStateNotifier extends StateNotifier<SyncState> {
  final Ref _ref;
  SyncManager? _syncManager;

  /// 冲突决策回调（由 UI 层设置）
  /// 当检测到冲突时，通过此回调让 UI 弹窗让用户选择
  ConflictResolutionCallback? onConflictDetected;

  /// 首次同步冲突决策回调（由 UI 层设置）
  /// 当检测到首次同步且双端都有数据时调用
  FirstSyncConflictCallback? onFirstSyncConflict;

  /// 首次同步完成标志 Completer
  /// 用于桌面端启动时等待首次同步完成
  Completer<bool>? _initialSyncCompleter;

  /// 是否已触发首次同步
  bool _hasTriggeredInitialSync = false;

  /// 初始化完成标志 Completer
  /// 用于确保外部代码可以等待配置加载完成
  final Completer<void> _loadCompleter = Completer<void>();

  SyncStateNotifier(this._ref) : super(const SyncState()) {
    _initialize();
  }

  /// 等待初始化完成（配置加载完成）
  /// 确保 syncTypeProvider 等已从 SharedPreferences 加载
  Future<void> waitForLoad() => _loadCompleter.future;

  /// 等待首次同步完成（供启动流程调用）
  ///
  /// 桌面端启动时调用此方法，阻塞 Splash 隐藏直到同步完成
  /// 返回 true = 同步成功，false = 同步失败或未配置
  ///
  /// 注意：此方法只会触发一次同步，后续调用直接返回缓存结果
  Future<bool> waitForInitialSync() async {
    // 检查是否配置了云同步
    final syncType = _ref.read(syncTypeProvider);
    if (syncType == null) {
      debugPrint('[SyncProvider] 未配置云同步，跳过首次同步');
      return false;
    }

    // 如果已经有 Completer 在等待，直接返回
    if (_initialSyncCompleter != null) {
      return _initialSyncCompleter!.future;
    }

    // 如果已经触发过，返回 false（避免重复触发）
    if (_hasTriggeredInitialSync) {
      debugPrint('[SyncProvider] 首次同步已触发过，跳过');
      return false;
    }

    // 创建 Completer 并触发首次同步
    _initialSyncCompleter = Completer<bool>();
    _hasTriggeredInitialSync = true;

    debugPrint('[SyncProvider] 桌面端启动，触发首次同步...');

    try {
      final success = await manualSync();
      _initialSyncCompleter!.complete(success);
      return success;
    } catch (e) {
      debugPrint('[SyncProvider] 首次同步异常: $e');
      _initialSyncCompleter!.complete(false);
      return false;
    }
  }

  /// 初始化 - 加载所有配置并启动当前激活的同步
  Future<void> _initialize() async {
    try {
      // 1. 加载当前同步类型
      final syncType = await SyncConfigService.getSyncType();
      _ref.read(syncTypeProvider.notifier).state = syncType;

      // 2. 加载所有平台的配置（不管当前激活哪个）
      // 这样用户可以在 UI 上看到所有已配置的平台
      await _loadAllConfigs();

      // 标记配置加载完成（无论成功与否）
      if (!_loadCompleter.isCompleted) {
        _loadCompleter.complete();
      }

      // 3. 根据当前激活的同步类型启动自动同步
      if (syncType == SyncType.webdav) {
        await _startWebDavAutoSync();
      } else if (syncType == SyncType.qiniuOss) {
        await _startQiniuAutoSync();
      }
    } catch (e) {
      debugPrint('[SyncProvider] 初始化失败: $e');
      state = state.copyWith(lastError: '初始化失败: $e');
      // 即使失败也标记完成，避免永远阻塞
      if (!_loadCompleter.isCompleted) {
        _loadCompleter.complete();
      }
    }
  }

  /// 加载所有平台的配置到 Provider
  Future<void> _loadAllConfigs() async {
    // 加载 WebDAV 配置
    final webdavConfig = await SyncConfigService.loadConfig();
    _ref.read(syncConfigProvider.notifier).state =
        webdavConfig.isConfigured ? webdavConfig : null;

    // 加载七牛云配置
    final qiniuConfig = await SyncConfigService.loadQiniuConfig();
    _ref.read(qiniuConfigProvider.notifier).state =
        qiniuConfig.isConfigured ? qiniuConfig : null;
  }

  /// 启动 WebDAV 自动同步
  Future<void> _startWebDavAutoSync() async {
    final config = await SyncConfigService.loadConfig();
    if (!config.isConfigured) return;

    // 更新同步状态
    state = state.copyWith(
      lastSyncTime: config.lastSyncTime,
      lastError: config.lastSyncError,
      clearError: config.lastSyncSuccess == true,
    );

    // 启动自动同步
    if (config.autoSync) {
      await _startAutoSync(config.syncInterval);
      debugPrint('[SyncProvider] WebDAV 自动同步已启动');
    }
  }

  /// 启动七牛云自动同步
  Future<void> _startQiniuAutoSync() async {
    final config = await SyncConfigService.loadQiniuConfig();
    if (!config.isConfigured) return;

    // 更新同步状态
    state = state.copyWith(
      lastSyncTime: config.lastSyncTime,
      lastError: config.lastSyncError,
      clearError: config.lastSyncSuccess == true,
    );

    // 启动自动同步
    if (config.autoSync) {
      await _startAutoSync(config.syncInterval);
      debugPrint('[SyncProvider] 七牛云 OSS 自动同步已启动');
    }
  }

  /// 启动自动同步
  Future<void> _startAutoSync(Duration interval) async {
    _syncManager = SyncManager();
    _syncManager!.onBeforeSync = () async {
      await _ref.read(databaseProvider).checkpoint();
    };
    // 数据库替换前回调：关闭数据库连接
    _syncManager!.onBeforeDbReplace = () async {
      debugPrint('[SyncProvider] 关闭数据库连接以准备替换...');
      await _ref.read(databaseProvider).close();
    };
    await _syncManager!.initialize();
    _syncManager!.onSyncComplete = (success) {
      if (success && _syncManager!.hasDataChanged) {
        debugPrint('[SyncProvider] 自动同步成功且有数据变化，刷新数据库连接...');
        _ref.invalidate(databaseProvider);
      } else if (success) {
        debugPrint('[SyncProvider] 自动同步成功但无数据变化，跳过刷新');
      }
    };

    // 创建一个临时配置用于启动定时器
    final tempConfig = SyncConfig(
      syncIntervalMinutes: interval.inMinutes,
      autoSync: true,
    );
    _syncManager!.startAutoSync(tempConfig);
  }

  /// 测试 WebDAV 连接
  Future<bool> testConnection(SyncConfig config, String password) async {
    try {
      final manager = SyncManager();
      await manager.initialize();
      final result = await manager.testConnection(
        serverUrl: config.serverUrl,
        username: config.username,
        password: password,
      );
      return result.success;
    } catch (e) {
      debugPrint('[SyncProvider] 测试连接失败: $e');
      return false;
    }
  }

  /// 测试七牛云 OSS 连接
  Future<bool> testQiniuConnection(QiniuOssConfig config, String secretKey) async {
    try {
      final manager = SyncManager();
      await manager.initialize();
      final result = await manager.testQiniuConnection(
        accessKey: config.accessKey,
        secretKey: secretKey,
        bucket: config.bucket,
        region: config.region,
        customDomain: config.customDomain,
      );
      return result.success;
    } catch (e) {
      debugPrint('[SyncProvider] 测试七牛云连接失败: $e');
      return false;
    }
  }

  /// 保存 WebDAV 配置并启用同步
  /// password: 用户输入的密码,会加密存储到系统钥匙串
  Future<void> saveConfig(SyncConfig config, String password) async {
    try {
      // 检查是否切换了同步类型
      final currentType = _ref.read(syncTypeProvider);
      if (currentType != SyncType.webdav) {
        // 切换到新服务商，清除本地同步状态，确保首次同步上传数据
        await SyncStateService.clearState();
        debugPrint('[SyncProvider] 切换到 WebDAV，已清除本地同步状态');
      }

      // 设置同步类型
      await SyncConfigService.setSyncType(SyncType.webdav);
      _ref.read(syncTypeProvider.notifier).state = SyncType.webdav;

      // 保存配置(不含密码)
      await SyncConfigService.saveConfig(config);
      // 保存密码到系统钥匙串
      await SyncConfigService.savePassword(config.username, password);

      _ref.read(syncConfigProvider.notifier).state = config;

      // 启动自动同步
      if (config.autoSync) {
        await _startAutoSync(config.syncInterval);
        debugPrint('[SyncProvider] WebDAV 自动同步已启动');
      }

      state = state.copyWith(clearError: true);
    } catch (e) {
      debugPrint('[SyncProvider] 保存配置失败: $e');
      state = state.copyWith(lastError: '保存配置失败: $e');
    }
  }

  /// 保存七牛云 OSS 配置并启用同步
  /// secretKey: 用户输入的 SecretKey，会加密存储到系统钥匙串
  Future<void> saveQiniuConfig(QiniuOssConfig config, String secretKey) async {
    try {
      // 检查是否切换了同步类型
      final currentType = _ref.read(syncTypeProvider);
      if (currentType != SyncType.qiniuOss) {
        // 切换到新服务商，清除本地同步状态，确保首次同步上传数据
        await SyncStateService.clearState();
        debugPrint('[SyncProvider] 切换到七牛云，已清除本地同步状态');
      }

      // 设置同步类型
      await SyncConfigService.setSyncType(SyncType.qiniuOss);
      _ref.read(syncTypeProvider.notifier).state = SyncType.qiniuOss;

      // 保存配置（不含 SecretKey）
      await SyncConfigService.saveQiniuConfig(config);
      // 保存 SecretKey 到系统钥匙串
      await SyncConfigService.saveQiniuSecretKey(config.accessKey, secretKey);

      _ref.read(qiniuConfigProvider.notifier).state = config;

      // 启动自动同步
      if (config.autoSync) {
        await _startAutoSync(config.syncInterval);
        debugPrint('[SyncProvider] 七牛云 OSS 自动同步已启动');
      }

      state = state.copyWith(clearError: true);
    } catch (e) {
      debugPrint('[SyncProvider] 保存七牛云配置失败: $e');
      state = state.copyWith(lastError: '保存配置失败: $e');
    }
  }

  /// 删除配置并停止同步
  Future<void> deleteConfig() async {
    try {
      final syncType = _ref.read(syncTypeProvider);

      // 根据同步类型清除对应配置
      if (syncType == SyncType.webdav) {
        await SyncConfigService.clearAll();
        _ref.read(syncConfigProvider.notifier).state = null;
      } else if (syncType == SyncType.qiniuOss) {
        await SyncConfigService.clearQiniuConfig();
        _ref.read(qiniuConfigProvider.notifier).state = null;
      }

      // 清除同步类型
      await SyncConfigService.clearSyncType();
      _ref.read(syncTypeProvider.notifier).state = null;

      // 停止自动同步
      _syncManager?.stopAutoSync();

      state = const SyncState(); // 重置状态
      debugPrint('[SyncProvider] 已删除同步配置');
    } catch (e) {
      debugPrint('[SyncProvider] 删除配置失败: $e');
      state = state.copyWith(lastError: '删除配置失败: $e');
    }
  }

  /// 删除七牛云配置并停止同步
  Future<void> deleteQiniuConfig() async {
    try {
      await SyncConfigService.clearQiniuConfig();
      await SyncConfigService.clearSyncType();

      _ref.read(qiniuConfigProvider.notifier).state = null;
      _ref.read(syncTypeProvider.notifier).state = null;

      // 停止自动同步
      _syncManager?.stopAutoSync();

      state = const SyncState(); // 重置状态
      debugPrint('[SyncProvider] 已删除七牛云配置');
    } catch (e) {
      debugPrint('[SyncProvider] 删除七牛云配置失败: $e');
      state = state.copyWith(lastError: '删除配置失败: $e');
    }
  }

  /// 切换同步类型（不删除配置，只切换激活状态）
  /// [type] 目标同步类型，null 表示关闭同步
  ///
  /// 重要：切换到新的同步服务商时，会清除本地同步状态，
  /// 确保首次同步时将本地数据上传到新服务商
  Future<void> switchSyncType(SyncType? type) async {
    try {
      // 获取当前同步类型
      final currentType = _ref.read(syncTypeProvider);

      // 停止当前自动同步
      _syncManager?.stopAutoSync();

      if (type == null) {
        // 关闭同步
        await SyncConfigService.clearSyncType();
        _ref.read(syncTypeProvider.notifier).state = null;
        state = const SyncState();
        debugPrint('[SyncProvider] 已关闭云同步');
        return;
      }

      // 如果切换到不同的服务商，清除本地同步状态
      // 这样首次同步时会将本地数据上传到新服务商
      if (currentType != type) {
        await SyncStateService.clearState();
        debugPrint('[SyncProvider] 切换服务商，已清除本地同步状态');
      }

      // 切换到指定类型
      await SyncConfigService.setSyncType(type);
      _ref.read(syncTypeProvider.notifier).state = type;

      // 根据类型启动自动同步
      if (type == SyncType.webdav) {
        final config = await SyncConfigService.loadConfig();
        if (config.isConfigured && config.autoSync) {
          await _startAutoSync(config.syncInterval);
        }
        state = state.copyWith(
          lastSyncTime: config.lastSyncTime,
          lastError: config.lastSyncError,
          clearError: config.lastSyncSuccess == true,
        );
      } else if (type == SyncType.qiniuOss) {
        final config = await SyncConfigService.loadQiniuConfig();
        if (config.isConfigured && config.autoSync) {
          await _startAutoSync(config.syncInterval);
        }
        state = state.copyWith(
          lastSyncTime: config.lastSyncTime,
          lastError: config.lastSyncError,
          clearError: config.lastSyncSuccess == true,
        );
      } else if (type == SyncType.amberCloud) {
        // 琥珀云：启动自动同步（默认 10 分钟间隔）
        await _startAutoSync(const Duration(minutes: 10));
        state = state.copyWith(clearError: true);
      }

      debugPrint('[SyncProvider] 已切换到 ${type.displayName}');
    } catch (e) {
      debugPrint('[SyncProvider] 切换同步类型失败: $e');
      state = state.copyWith(lastError: '切换失败: $e');
    }
  }

  /// 启用琥珀云同步
  ///
  /// 前提条件：已通过 AmberCloudRepository.getToken() 获取了 Token
  /// 此方法只负责切换同步类型，不负责获取 Token
  Future<void> enableAmberCloud() async {
    await switchSyncType(SyncType.amberCloud);
    debugPrint('[SyncProvider] 琥珀云同步已启用');
  }

  /// 手动触发同步
  /// [forceDownload] 强制从云端下载（忽略本地状态，用于数据恢复场景）
  /// [forceUpload] 强制上传本地数据（清除本地同步状态后上传）
  /// [skipFirstSyncCheck] 跳过首次同步冲突检测（用户已确认选择后）
  Future<bool> manualSync({
    bool forceDownload = false,
    bool forceUpload = false,
    bool skipFirstSyncCheck = false,
  }) async {
    final syncType = _ref.read(syncTypeProvider);

    // 检查是否有配置
    bool isConfigured = false;
    if (syncType == SyncType.webdav) {
      final config = _ref.read(syncConfigProvider);
      isConfigured = config != null && config.isConfigured;
    } else if (syncType == SyncType.qiniuOss) {
      final config = _ref.read(qiniuConfigProvider);
      isConfigured = config != null && config.isConfigured;
    } else if (syncType == SyncType.amberCloud) {
      // 琥珀云：通过 SyncManager._createProvider 检查是否已登录
      isConfigured = true; // 让 SyncManager 去判断
    }

    if (!isConfigured) {
      state = state.copyWith(lastError: '未配置同步');
      return false;
    }

    // 初始化 SyncManager(如果还没初始化)
    _syncManager ??= SyncManager();
    _syncManager!.onBeforeSync = () async {
      await _ref.read(databaseProvider).checkpoint();
    };
    // 数据库替换前回调：关闭数据库连接
    // 这是解决 "database disk image is malformed" 错误的关键
    _syncManager!.onBeforeDbReplace = () async {
      debugPrint('[SyncProvider] 关闭数据库连接以准备替换...');
      await _ref.read(databaseProvider).close();
    };
    await _syncManager!.initialize();
    _syncManager!.onSyncComplete = (success) {
      if (success && _syncManager!.hasDataChanged) {
        debugPrint('[SyncProvider] 同步成功且有数据变化，刷新数据库连接...');
        _ref.invalidate(databaseProvider);
      } else if (success) {
        debugPrint('[SyncProvider] 同步成功但无数据变化，跳过刷新');
      }
    };
    // 设置冲突决策回调
    _syncManager!.onConflictDetected = onConflictDetected;

    try {
      // ========== 首次同步冲突检测 ==========
      // 如果不是强制操作，且设置了回调，检测首次同步冲突
      if (!forceDownload && !forceUpload && !skipFirstSyncCheck && onFirstSyncConflict != null) {
        final conflictInfo = await _syncManager!.detectFirstSyncConflict();

        if (conflictInfo != null) {
          // 检测到首次同步冲突，询问用户
          final conflict = FirstSyncConflict(
            localTaskCount: conflictInfo.localTaskCount,
            remoteVersion: conflictInfo.remoteVersion,
            remoteDevice: conflictInfo.remoteDevice,
            remoteLastSync: conflictInfo.remoteLastSync,
          );

          final choice = await onFirstSyncConflict!(conflict);

          if (choice == null || choice == FirstSyncChoice.cancel) {
            debugPrint('[SyncProvider] 用户取消首次同步');
            return false;
          }

          if (choice == FirstSyncChoice.downloadFromCloud) {
            // 用户选择从云端恢复
            debugPrint('[SyncProvider] 用户选择从云端恢复');
            return manualSync(forceDownload: true, skipFirstSyncCheck: true);
          } else if (choice == FirstSyncChoice.uploadToCloud) {
            // 用户选择上传到云端
            debugPrint('[SyncProvider] 用户选择上传到云端');
            return manualSync(forceUpload: true, skipFirstSyncCheck: true);
          }
        }
      }

      // 强制上传：清除本地同步状态，让系统认为"本地有变化，远程没变化"
      if (forceUpload) {
        debugPrint('[SyncProvider] 强制上传模式：清除本地同步状态');
        await SyncStateService.clearState();
      }

      state = state.copyWith(
        isSyncing: true,
        clearError: true,
        clearConflicts: true, // 清除旧冲突
      );

      final success = await _syncManager!.sync(forceDownload: forceDownload);

      // Check for conflicts even if success (merge might have finished with conflicts pending)
      List<TagConflict> conflicts = [];
      if (_syncManager!.lastMergeResult != null) {
        conflicts = _syncManager!.lastMergeResult!.stats.tagConflicts;
      }

      if (success) {
        // 重新加载配置获取最新的同步时间
        DateTime? lastSyncTime;
        if (syncType == SyncType.webdav) {
          final updatedConfig = await SyncConfigService.loadConfig();
          lastSyncTime = updatedConfig.lastSyncTime;
        } else if (syncType == SyncType.qiniuOss) {
          final updatedConfig = await SyncConfigService.loadQiniuConfig();
          lastSyncTime = updatedConfig.lastSyncTime;
        } else if (syncType == SyncType.amberCloud) {
          // 琥珀云：直接使用当前时间作为同步时间
          lastSyncTime = DateTime.now();
        }

        state = state.copyWith(
          isSyncing: false,
          lastSyncTime: lastSyncTime,
          clearError: true,
          tagConflicts: conflicts,
        );
        debugPrint('[SyncProvider] 同步成功. 冲突数: ${conflicts.length}');
        return true;
      } else {
        // 直接从 SyncManager 获取错误信息（更可靠）
        final lastError = _syncManager?.lastError;

        state = state.copyWith(
          isSyncing: false,
          lastError: lastError ?? '同步失败',
          tagConflicts: conflicts,
        );
        debugPrint('[SyncProvider] 同步失败: $lastError');
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isSyncing: false,
        lastError: '同步异常: $e',
      );
      debugPrint('[SyncProvider] 同步异常: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _syncManager?.stopAutoSync();
    super.dispose();
  }
}
