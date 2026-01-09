import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// macOS Dock 图标服务
///
/// 用于控制应用在 macOS Dock 中的显示/隐藏。
/// 当用户最小化到托盘时，可选择是否从 Dock 中完全隐藏。
///
/// 原理:
/// - NSApp.setActivationPolicy(.regular) - 在 Dock 中显示
/// - NSApp.setActivationPolicy(.accessory) - 从 Dock 中隐藏（仅托盘图标可见）
///
/// 注意: 此服务仅在 macOS 上有效，其他平台调用会静默忽略。
class DockService {
  DockService._();

  /// Platform Channel 名称，与原生端保持一致
  static const String _channelName = 'com.amberlist.dock';

  /// Method Channel 实例
  static const MethodChannel _channel = MethodChannel(_channelName);

  /// 在 Dock 中显示应用图标
  ///
  /// 调用后应用会出现在 Dock 中，运行时显示小黑点。
  /// 仅 macOS 有效。
  static Future<void> showInDock() async {
    if (!Platform.isMacOS) return;

    debugPrint('[DockService] showInDock() called');
    try {
      await _channel.invokeMethod<void>('showInDock');
      debugPrint('[DockService] showInDock() success');
    } on PlatformException catch (e) {
      debugPrint('[DockService] showInDock PlatformException: ${e.code} - ${e.message}');
    } on MissingPluginException catch (e) {
      debugPrint('[DockService] showInDock MissingPluginException: $e');
    } catch (e, stack) {
      debugPrint('[DockService] showInDock error: $e');
      debugPrint('[DockService] stack: $stack');
    }
  }

  /// 从 Dock 中隐藏应用图标
  ///
  /// 调用后应用会从 Dock 中消失，仅通过托盘图标可见。
  /// 仅 macOS 有效。
  static Future<void> hideFromDock() async {
    if (!Platform.isMacOS) return;

    debugPrint('[DockService] hideFromDock() called');
    try {
      await _channel.invokeMethod<void>('hideFromDock');
      debugPrint('[DockService] hideFromDock() success');
    } on PlatformException catch (e) {
      debugPrint('[DockService] hideFromDock PlatformException: ${e.code} - ${e.message}');
    } on MissingPluginException catch (e) {
      debugPrint('[DockService] hideFromDock MissingPluginException: $e');
    } catch (e, stack) {
      debugPrint('[DockService] hideFromDock error: $e');
      debugPrint('[DockService] stack: $stack');
    }
  }

  /// 根据设置更新 Dock 显示状态
  ///
  /// [showInDock] 是否在 Dock 中显示
  static Future<void> updateDockVisibility(bool showInDock) async {
    if (showInDock) {
      await DockService.showInDock();
    } else {
      await hideFromDock();
    }
  }
}
