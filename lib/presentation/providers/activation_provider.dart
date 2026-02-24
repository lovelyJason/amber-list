import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/activation_code.dart';
import '../../data/repositories/activation_repository.dart';
import '../../data/services/activation/activation_service.dart';

/// ============================================================
/// 激活状态数据类
/// ============================================================
@immutable
class ActivationState {
  /// 是否已激活
  final bool isActivated;

  /// 是否正在验证
  final bool isActivating;

  /// 激活码信息
  final ActivationCode? activationCode;

  /// 最后错误信息
  final String? lastError;

  /// 是否已初始化
  final bool isInitialized;

  /// 后台校验是否失败（用于日历页面显示弹窗）
  /// 启动时静默校验失败后设为 true，日历页面读取后可清除
  final bool backgroundVerifyFailed;

  const ActivationState({
    this.isActivated = false,
    this.isActivating = false,
    this.activationCode,
    this.lastError,
    this.isInitialized = false,
    this.backgroundVerifyFailed = false,
  });

  /// 是否永久激活
  bool get isPermanent => activationCode?.isPermanent ?? false;

  /// 是否已过期
  bool get isExpired => activationCode?.isExpired ?? false;

  /// 剩余天数
  int get remainingDays => activationCode?.remainingDays ?? 0;

  /// 激活码类型
  ActivationCodeType? get type => activationCode?.type;

  ActivationState copyWith({
    bool? isActivated,
    bool? isActivating,
    ActivationCode? activationCode,
    String? lastError,
    bool? isInitialized,
    bool? backgroundVerifyFailed,
    bool clearError = false,
    bool clearActivationCode = false,
  }) {
    return ActivationState(
      isActivated: isActivated ?? this.isActivated,
      isActivating: isActivating ?? this.isActivating,
      activationCode:
          clearActivationCode ? null : (activationCode ?? this.activationCode),
      lastError: clearError ? null : (lastError ?? this.lastError),
      isInitialized: isInitialized ?? this.isInitialized,
      backgroundVerifyFailed:
          backgroundVerifyFailed ?? this.backgroundVerifyFailed,
    );
  }
}

/// ============================================================
/// 激活状态 Provider
/// ============================================================
final activationProvider =
    StateNotifierProvider<ActivationNotifier, ActivationState>((ref) {
  return ActivationNotifier();
});

/// ============================================================
/// 激活状态通知器
/// ============================================================
/// 管理激活码的验证和状态
/// - 启动时加载本地激活状态
/// - 智能判断是否需要在线校验
/// - 支持 7 天离线宽限期
/// ============================================================
class ActivationNotifier extends StateNotifier<ActivationState> {
  final ActivationRepository _repository = ActivationRepository();

  ActivationNotifier() : super(const ActivationState()) {
    _initialize();
  }

  /// 启动时初始化（强制在线校验）
  ///
  /// 每次启动都会向服务端校验激活状态，防止用户篡改本地数据绕过激活
  /// 校验过程静默进行，不阻塞 UI；校验失败后设置 backgroundVerifyFailed 标志
  /// 日历页面会检测该标志并显示激活弹窗
  Future<void> _initialize() async {
    try {
      debugPrint('[ActivationNotifier] 开始初始化（强制在线校验）...');

      // 1. 先检查本地是否有激活码
      final localCode = await ActivationService.getActivationCode();
      final localInfo = await ActivationService.getActivationInfo();

      if (localCode == null || localCode.isEmpty) {
        debugPrint('[ActivationNotifier] 本地无激活码');
        state = state.copyWith(
          isActivated: false,
          isInitialized: true,
        );
        return;
      }

      debugPrint('[ActivationNotifier] 本地激活码: $localCode，开始在线校验...');

      // 2. 强制在线校验（每次启动都校验）
      try {
        final result = await _repository.verify(localCode);

        if (result.success && result.data != null && result.data!.isValid) {
          // 在线校验成功
          await ActivationService.saveActivationInfo(result.data!);
          // debugPrint('[ActivationNotifier] ✅ 在线校验成功');
          state = state.copyWith(
            isActivated: true,
            activationCode: result.data,
            isInitialized: true,
            backgroundVerifyFailed: false,
          );
        } else {
          // 在线校验失败，激活码已失效或被篡改
          debugPrint('[ActivationNotifier] ❌ 在线校验失败: ${result.message}');
          await ActivationService.clearAll();
          state = state.copyWith(
            isActivated: false,
            lastError: result.message ?? '激活码已失效',
            isInitialized: true,
            backgroundVerifyFailed: true, // 标记后台校验失败，日历页会弹窗
            clearActivationCode: true,
          );
        }
      } catch (e) {
        // 网络异常时的策略：
        // 1. 如果本地状态显示已激活，暂时信任本地状态（允许离线使用）
        // 2. 但下次启动会再次尝试校验
        debugPrint('[ActivationNotifier] 在线校验网络异常: $e');

        final isLocalActivated = await ActivationService.isActivatedLocal();
        if (isLocalActivated && localInfo != null) {
          debugPrint('[ActivationNotifier] 网络异常，暂时使用本地状态');
          state = state.copyWith(
            isActivated: true,
            activationCode: localInfo,
            isInitialized: true,
            backgroundVerifyFailed: false,
          );
        } else {
          // 本地状态也不可信，标记为未激活
          state = state.copyWith(
            isActivated: false,
            isInitialized: true,
            backgroundVerifyFailed: true,
            lastError: '网络异常，无法验证激活状态',
          );
        }
      }
    } catch (e) {
      debugPrint('[ActivationNotifier] 初始化失败: $e');
      state = state.copyWith(
        isActivated: false,
        isInitialized: true,
      );
    }
  }

  /// 用户手动激活
  ///
  /// [code] 激活码
  /// 返回是否激活成功
  Future<bool> activate(String code) async {
    if (code.trim().isEmpty) {
      state = state.copyWith(lastError: '请输入激活码');
      return false;
    }

    state = state.copyWith(isActivating: true, clearError: true);

    try {
      debugPrint('[ActivationNotifier] 开始激活: $code');
      final result = await _repository.verify(code.trim());

      if (result.success && result.data != null && result.data!.isValid) {
        // 激活成功
        await ActivationService.saveActivationInfo(result.data!);
        debugPrint('[ActivationNotifier] ✅ 激活成功');
        state = state.copyWith(
          isActivating: false,
          isActivated: true,
          activationCode: result.data,
          clearError: true,
        );
        return true;
      } else {
        // 激活失败
        debugPrint('[ActivationNotifier] ❌ 激活失败: ${result.message}');
        state = state.copyWith(
          isActivating: false,
          lastError: result.message ?? '激活失败',
        );
        return false;
      }
    } catch (e) {
      debugPrint('[ActivationNotifier] 激活异常: $e');
      state = state.copyWith(
        isActivating: false,
        lastError: '网络异常，请检查网络连接',
      );
      return false;
    }
  }

  /// 清除激活（注销）
  Future<void> deactivate() async {
    try {
      await ActivationService.clearAll();
      debugPrint('[ActivationNotifier] 已清除激活');
      state = const ActivationState(
        isActivated: false,
        isInitialized: true,
      );
    } catch (e) {
      debugPrint('[ActivationNotifier] 清除激活失败: $e');
    }
  }

  /// 清除错误信息
  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// 清除后台校验失败标志
  /// 日历页面弹窗显示后应调用此方法
  void clearBackgroundVerifyFailed() {
    state = state.copyWith(backgroundVerifyFailed: false);
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }
}
