import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/app_update_info.dart';
import '../../data/services/update/app_update_service.dart';

/// ============================================================
/// 应用更新状态 Provider
/// ============================================================
/// 管理应用更新检查的全局状态
/// 支持手动检查更新、强制更新拦截等功能

/// 应用更新状态数据类
@immutable
class AppUpdateState {
  /// 是否正在检查更新
  final bool isChecking;

  /// 最近一次检查结果
  final UpdateCheckResult? lastCheckResult;

  /// 是否显示强制更新对话框
  final bool showForceUpdateDialog;

  /// 是否已经跳过当前版本更新（仅对可选更新生效）
  final bool skippedCurrentVersion;

  const AppUpdateState({
    this.isChecking = false,
    this.lastCheckResult,
    this.showForceUpdateDialog = false,
    this.skippedCurrentVersion = false,
  });

  /// 是否有可用更新
  bool get hasUpdate => lastCheckResult?.hasUpdate ?? false;

  /// 是否需要强制更新
  bool get isForceUpdate => lastCheckResult?.isForceUpdate ?? false;

  /// 最新版本号
  String? get latestVersion => lastCheckResult?.updateInfo?.latestVersion;

  /// 当前版本号
  String get currentVersion => lastCheckResult?.currentVersion ?? '未知';

  /// 更新日志
  String get releaseNotes => lastCheckResult?.updateInfo?.releaseNotes ?? '';

  AppUpdateState copyWith({
    bool? isChecking,
    UpdateCheckResult? lastCheckResult,
    bool? showForceUpdateDialog,
    bool? skippedCurrentVersion,
  }) {
    return AppUpdateState(
      isChecking: isChecking ?? this.isChecking,
      lastCheckResult: lastCheckResult ?? this.lastCheckResult,
      showForceUpdateDialog:
          showForceUpdateDialog ?? this.showForceUpdateDialog,
      skippedCurrentVersion:
          skippedCurrentVersion ?? this.skippedCurrentVersion,
    );
  }
}

/// 应用更新 Provider
final appUpdateProvider =
    StateNotifierProvider<AppUpdateNotifier, AppUpdateState>((ref) {
  return AppUpdateNotifier();
});

/// 应用更新状态通知器
class AppUpdateNotifier extends StateNotifier<AppUpdateState> {
  final AppUpdateService _updateService = AppUpdateService();

  AppUpdateNotifier() : super(const AppUpdateState());

  /// 检查更新
  ///
  /// [showDialogOnForce] 如果需要强制更新，是否自动弹出对话框
  /// [customUrl] 自定义更新检查 URL（用于测试）
  Future<UpdateCheckResult> checkForUpdates({
    bool showDialogOnForce = true,
    String? customUrl,
  }) async {
    if (state.isChecking) {
      debugPrint('[AppUpdateProvider] 正在检查中，跳过重复请求');
      return state.lastCheckResult ??
          UpdateCheckResult.failure(
            currentVersion: '0.0.0',
            currentBuildNumber: '0',
            error: '正在检查中',
          );
    }

    state = state.copyWith(isChecking: true);

    try {
      final result = await _updateService.checkForUpdates(customUrl: customUrl);

      state = state.copyWith(
        isChecking: false,
        lastCheckResult: result,
        showForceUpdateDialog:
            showDialogOnForce && result.isForceUpdate && result.success,
      );

      debugPrint(
          '[AppUpdateProvider] 检查完成: hasUpdate=${result.hasUpdate}, type=${result.updateType}');

      return result;
    } catch (e) {
      debugPrint('[AppUpdateProvider] 检查异常: $e');

      final errorResult = UpdateCheckResult.failure(
        currentVersion: state.lastCheckResult?.currentVersion ?? '0.0.0',
        currentBuildNumber:
            state.lastCheckResult?.currentBuildNumber ?? '0',
        error: e.toString(),
      );

      state = state.copyWith(
        isChecking: false,
        lastCheckResult: errorResult,
      );

      return errorResult;
    }
  }

  /// 跳过当前版本更新（仅对可选更新有效）
  void skipCurrentVersion() {
    if (!state.isForceUpdate) {
      state = state.copyWith(skippedCurrentVersion: true);
      debugPrint('[AppUpdateProvider] 已跳过当前版本更新');
    }
  }

  /// 重置跳过状态（当检测到新版本时调用）
  void resetSkipStatus() {
    state = state.copyWith(skippedCurrentVersion: false);
  }

  /// 关闭强制更新对话框（注意：这不会阻止强制更新逻辑）
  void dismissForceUpdateDialog() {
    state = state.copyWith(showForceUpdateDialog: false);
  }

  /// 打开下载链接
  Future<bool> openDownloadUrl() async {
    final updateInfo = state.lastCheckResult?.updateInfo;
    if (updateInfo == null) {
      debugPrint('[AppUpdateProvider] 无更新信息，无法打开下载链接');
      return false;
    }

    return await _updateService.openDownloadUrl(updateInfo);
  }

  /// 获取当前平台名称
  String get platformName => _updateService.currentPlatformName;

  /// 获取当前平台的下载链接
  String? get downloadUrl {
    final updateInfo = state.lastCheckResult?.updateInfo;
    if (updateInfo == null) return null;
    return _updateService.getDownloadUrl(updateInfo);
  }
}
