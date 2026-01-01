import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 响应式工具类
/// 设计哲学：简单实用，不过度抽象
///
/// 使用方式：
/// - ResponsiveHelper.isMobile(context) 判断是否为移动端
/// - ResponsiveHelper.isDesktop(context) 判断是否为桌面端
/// - ResponsiveHelper.valueWhen(context, mobile: xxx, desktop: xxx) 按平台返回不同值
class ResponsiveHelper {
  ResponsiveHelper._();

  // ===== 断点定义 =====
  /// 移动端断点（小于600px为手机模式）
  static const double mobileBreakpoint = 600.0;

  // ===== 屏幕尺寸判断 =====

  /// 判断是否是移动端布局（< 600px）
  /// 注意：这是基于屏幕宽度判断，不是操作系统
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  /// 判断是否是桌面端布局（>= 600px）
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= mobileBreakpoint;
  }

  // ===== 操作系统判断 =====

  /// 判断是否是移动操作系统（Android/iOS）
  static bool isMobileOS() {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  /// 判断是否是桌面操作系统（macOS/Windows/Linux）
  static bool isDesktopOS() {
    if (kIsWeb) return false;
    return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  }

  /// 判断是否是 macOS
  static bool isMacOS() {
    if (kIsWeb) return false;
    return Platform.isMacOS;
  }

  /// 判断是否是 Windows
  static bool isWindows() {
    if (kIsWeb) return false;
    return Platform.isWindows;
  }

  /// 判断是否是 Android
  static bool isAndroid() {
    if (kIsWeb) return false;
    return Platform.isAndroid;
  }

  /// 判断是否是 iOS
  static bool isIOS() {
    if (kIsWeb) return false;
    return Platform.isIOS;
  }

  // ===== 条件返回值 =====

  /// 根据屏幕宽度返回不同值（类似 CSS media query）
  /// [mobile] 移动端布局时返回的值
  /// [desktop] 桌面端布局时返回的值
  static T valueWhen<T>(
    BuildContext context, {
    required T mobile,
    required T desktop,
  }) {
    return isMobile(context) ? mobile : desktop;
  }

  /// 根据操作系统返回不同值
  /// [mobileOS] Android/iOS 时返回的值
  /// [desktopOS] macOS/Windows/Linux 时返回的值
  static T valueWhenOS<T>({
    required T mobileOS,
    required T desktopOS,
  }) {
    return isMobileOS() ? mobileOS : desktopOS;
  }

  // ===== 尺寸计算 =====

  /// 获取安全的侧边栏宽度（移动端为0）
  static double getSidebarWidth(BuildContext context, {double desktopWidth = 220.0}) {
    return isMobile(context) ? 0 : desktopWidth;
  }

  /// 获取安全的详情面板宽度（移动端为0）
  static double getDetailPanelWidth(BuildContext context, {double desktopWidth = 320.0}) {
    return isMobile(context) ? 0 : desktopWidth;
  }
}
