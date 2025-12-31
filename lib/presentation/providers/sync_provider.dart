import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/sync/sync_config.dart';
import '../../data/services/sync/sync_manager.dart';
import '../../data/services/sync/three_way_merge.dart';
import 'database_provider.dart';

/// ============================================================
/// 同步状态 Provider
/// ============================================================
/// 管理 WebDAV 云同步的全局状态

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

/// 同步配置 Provider
final syncConfigProvider = StateProvider<SyncConfig?>((ref) => null);

/// 同步状态 Provider
final syncStateProvider = StateNotifierProvider<SyncStateNotifier, SyncState>((ref) {
  return SyncStateNotifier(ref);
});

/// 同步状态 Notifier
class SyncStateNotifier extends StateNotifier<SyncState> {
  final Ref _ref;
  SyncManager? _syncManager;

  SyncStateNotifier(this._ref) : super(const SyncState()) {
    _initialize();
  }

  /// 初始化 - 加载配置并启动自动同步
  Future<void> _initialize() async {
    try {
      final config = await SyncConfigService.loadConfig();
      _ref.read(syncConfigProvider.notifier).state = config;

      // 更新上次同步状态
      state = state.copyWith(
        lastSyncTime: config.lastSyncTime,
        lastError: config.lastSyncError,
        clearError: config.lastSyncSuccess == true,
      );

      // 如果已配置且开启了自动同步,启动自动同步
      if (config.isConfigured && config.autoSync) {
        _syncManager = SyncManager();
        _syncManager!.onBeforeSync = () async {
          await _ref.read(databaseProvider).checkpoint();
        };
        await _syncManager!.initialize();
        _syncManager!.onSyncComplete = (success) {
          if (success) {
            debugPrint('[SyncProvider] 自动同步成功，刷新数据库连接...');
            _ref.invalidate(databaseProvider);
          }
        };
        _syncManager!.startAutoSync(config); // 不需要await,返回void
        debugPrint('[SyncProvider] 自动同步已启动');
      }
    } catch (e) {
      debugPrint('[SyncProvider] 初始化失败: $e');
      state = state.copyWith(lastError: '初始化失败: $e');
    }
  }

  /// 测试连接
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

  /// 保存配置并启用同步
  /// password: 用户输入的密码,会加密存储到系统钥匙串
  Future<void> saveConfig(SyncConfig config, String password) async {
    try {
      // 保存配置(不含密码)
      await SyncConfigService.saveConfig(config);
      // 保存密码到系统钥匙串
      await SyncConfigService.savePassword(config.username, password);

      _ref.read(syncConfigProvider.notifier).state = config;

      // 初始化 SyncManager(如果还没初始化)
      _syncManager ??= SyncManager();
      _syncManager!.onBeforeSync = () async {
        await _ref.read(databaseProvider).checkpoint();
      };
      await _syncManager!.initialize();
      _syncManager!.onSyncComplete = (success) {
        if (success) {
          debugPrint('[SyncProvider] 同步成功，刷新数据库连接...');
          _ref.invalidate(databaseProvider);
        }
      };

      // 启动自动同步(每30分钟)
      if (config.autoSync) {
        _syncManager!.startAutoSync(config);
        debugPrint('[SyncProvider] 自动同步已启动');
      }

      state = state.copyWith(clearError: true);
    } catch (e) {
      debugPrint('[SyncProvider] 保存配置失败: $e');
      state = state.copyWith(lastError: '保存配置失败: $e');
    }
  }

  /// 删除配置并停止同步
  Future<void> deleteConfig() async {
    try {
      // 直接调用 clearAll,会删除配置和所有密码
      await SyncConfigService.clearAll();

      _ref.read(syncConfigProvider.notifier).state = null;

      // 停止自动同步
      _syncManager?.stopAutoSync();

      state = const SyncState(); // 重置状态
      debugPrint('[SyncProvider] 已删除同步配置');
    } catch (e) {
      debugPrint('[SyncProvider] 删除配置失败: $e');
      state = state.copyWith(lastError: '删除配置失败: $e');
    }
  }

  /// 手动触发同步
  Future<bool> manualSync() async {
    final config = _ref.read(syncConfigProvider);
    if (config == null || !config.isConfigured) {
      state = state.copyWith(lastError: '未配置同步');
      return false;
    }

    // 初始化 SyncManager(如果还没初始化)
    _syncManager ??= SyncManager();
    _syncManager!.onBeforeSync = () async {
      await _ref.read(databaseProvider).checkpoint();
    };
    await _syncManager!.initialize();
    _syncManager!.onSyncComplete = (success) {
      if (success) {
        debugPrint('[SyncProvider] 同步成功，刷新数据库连接...');
        _ref.invalidate(databaseProvider);
      }
    };

    try {
      state = state.copyWith(
        isSyncing: true,
        clearError: true,
        clearConflicts: true, // 清除旧冲突
      );

      final success = await _syncManager!.sync();

      // Check for conflicts even if success (merge might have finished with conflicts pending)
      List<TagConflict> conflicts = [];
      if (_syncManager!.lastMergeResult != null) {
        conflicts = _syncManager!.lastMergeResult!.stats.tagConflicts;
      }

      if (success) {
        // 重新加载配置获取最新的同步时间
        final updatedConfig = await SyncConfigService.loadConfig();
        state = state.copyWith(
          isSyncing: false,
          lastSyncTime: updatedConfig.lastSyncTime,
          clearError: true,
          tagConflicts: conflicts,
        );
        debugPrint('[SyncProvider] 同步成功. 冲突数: ${conflicts.length}');
        return true;
      } else {
        // 加载错误信息
        final updatedConfig = await SyncConfigService.loadConfig();
        state = state.copyWith(
          isSyncing: false,
          lastError: updatedConfig.lastSyncError ?? '同步失败',
          tagConflicts: conflicts, // conflicts might exist even on failure
        );
        debugPrint('[SyncProvider] 同步失败');
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
