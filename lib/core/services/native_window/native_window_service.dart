import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 原生窗口服务
///
/// 统一管理所有原生窗口的创建、销毁和通信。
/// 这是 Flutter 与原生窗口交互的唯一入口。
///
/// ## 设计理念
/// - 通用性：支持任意类型的原生窗口，通过 [NativeWindowType] 区分
/// - 解耦合：业务逻辑在各自的 Service 层（如 QuickAddService）实现
/// - 双向通信：支持 Flutter → Native 调用和 Native → Flutter 回调
///
/// ## 使用示例
/// ```dart
/// // 显示窗口
/// await NativeWindowService.instance.createOrShowWindow(
///   type: NativeWindowType.quickAdd.value,
///   arguments: {'defaultDate': DateTime.now().toIso8601String()},
/// );
///
/// // 注册回调
/// NativeWindowService.instance.registerCallback(
///   NativeWindowType.quickAdd.value,
///   'onTaskSubmitted',
///   (args) => print('Task: ${args['title']}'),
/// );
/// ```
class NativeWindowService {
  /// 单例实例
  static final NativeWindowService instance = NativeWindowService._();

  /// Platform Channel 名称
  static const String _channelName = 'com.amberlist.native_window';

  /// Method Channel
  late final MethodChannel _channel;

  /// 窗口消息回调表
  /// 结构：windowType -> method -> callback
  final Map<String, Map<String, Function>> _callbacks = {};

  /// 私有构造函数
  NativeWindowService._() {
    _channel = const MethodChannel(_channelName);
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  /// 是否支持原生窗口（仅 macOS 和 Windows 桌面端）
  bool get isSupported => Platform.isMacOS || Platform.isWindows;

  // ============================================================
  // 窗口生命周期管理
  // ============================================================

  /// 创建或显示窗口
  ///
  /// 如果窗口已存在，则显示并聚焦；否则创建新窗口。
  /// [type] 窗口类型标识
  /// [id] 窗口实例 ID（可选，用于同类型多窗口）
  /// [arguments] 传递给窗口的参数
  Future<bool> createOrShowWindow({
    required String type,
    String? id,
    Map<String, dynamic>? arguments,
  }) async {
    if (!isSupported) {
      debugPrint('[NativeWindow] 当前平台不支持原生窗口');
      return false;
    }

    try {
      final result = await _channel.invokeMethod<Map>(
        'createOrShow',
        {
          'windowType': type,
          if (id != null) 'windowId': id,
          if (arguments != null) 'arguments': arguments,
        },
      );

      final success = result?['success'] == true;
      debugPrint('[NativeWindow] 创建窗口 $type${id != null ? '($id)' : ''}: ${success ? '成功' : '失败'}');
      return success;
    } on PlatformException catch (e) {
      debugPrint('[NativeWindow] 创建窗口失败: ${e.message}');
      return false;
    }
  }

  /// 隐藏窗口（不销毁）
  Future<bool> hideWindow({required String type, String? id}) async {
    if (!isSupported) return false;

    try {
      final result = await _channel.invokeMethod<Map>('hide', {
        'windowType': type,
        if (id != null) 'windowId': id,
      });

      return result?['success'] == true;
    } on PlatformException catch (e) {
      debugPrint('[NativeWindow] 隐藏窗口失败: ${e.message}');
      return false;
    }
  }

  /// 销毁窗口
  Future<bool> destroyWindow({required String type, String? id}) async {
    if (!isSupported) return false;

    try {
      final result = await _channel.invokeMethod<Map>('destroy', {
        'windowType': type,
        if (id != null) 'windowId': id,
      });

      return result?['success'] == true;
    } on PlatformException catch (e) {
      debugPrint('[NativeWindow] 销毁窗口失败: ${e.message}');
      return false;
    }
  }

  // ============================================================
  // 消息通信
  // ============================================================

  /// 向窗口发送消息
  ///
  /// [type] 窗口类型
  /// [id] 窗口实例 ID（可选）
  /// [method] 消息方法名
  /// [arguments] 消息参数
  Future<dynamic> sendMessage({
    required String type,
    String? id,
    required String method,
    Map<String, dynamic>? arguments,
  }) async {
    if (!isSupported) return null;

    try {
      return await _channel.invokeMethod('sendMessage', {
        'windowType': type,
        if (id != null) 'windowId': id,
        'method': method,
        if (arguments != null) 'arguments': arguments,
      });
    } on PlatformException catch (e) {
      debugPrint('[NativeWindow] 发送消息失败: ${e.message}');
      return null;
    }
  }

  // ============================================================
  // 回调注册
  // ============================================================

  /// 注册窗口消息回调
  ///
  /// [windowType] 窗口类型标识
  /// [method] 消息方法名
  /// [callback] 回调函数，参数类型为 Map<String, dynamic>
  void registerCallback(
    String windowType,
    String method,
    Function(Map<String, dynamic>) callback,
  ) {
    _callbacks[windowType] ??= {};
    _callbacks[windowType]![method] = callback;
    // debugPrint('[NativeWindow] 注册回调: $windowType.$method');
  }

  /// 取消注册回调
  void unregisterCallback(String windowType, String method) {
    _callbacks[windowType]?.remove(method);
  }

  /// 取消注册某窗口类型的所有回调
  void unregisterAllCallbacks(String windowType) {
    _callbacks.remove(windowType);
  }

  // ============================================================
  // 私有方法
  // ============================================================

  /// 处理原生端的回调消息
  Future<dynamic> _handleNativeCall(MethodCall call) async {
    final args = call.arguments as Map?;
    final windowType = args?['windowType'] as String?;

    debugPrint('[NativeWindow] 收到原生消息: ${call.method}, windowType=$windowType');

    if (windowType == null) {
      debugPrint('[NativeWindow] 消息缺少窗口类型');
      return null;
    }

    // 查找并执行回调
    final callback = _callbacks[windowType]?[call.method];
    if (callback != null) {
      try {
        final callbackArgs = Map<String, dynamic>.from(args ?? {});
        callback(callbackArgs);
      } catch (e) {
        debugPrint('[NativeWindow] 执行回调失败: $e');
      }
    } else {
      debugPrint('[NativeWindow] 未找到回调: $windowType.${call.method}');
    }

    return null;
  }
}
