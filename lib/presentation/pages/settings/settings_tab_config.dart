import 'dart:io';

import 'package:flutter/material.dart';
import 'settings_tab_type.dart';
import 'tabs/profile_tab.dart';
import 'tabs/display_tab.dart';
import 'tabs/task_management_tab.dart';
import 'tabs/quick_add_tab.dart';
import 'tabs/widget_tab.dart';
import 'tabs/data_management_tab.dart';
import 'tabs/cloud_sync_tab.dart';
import 'tabs/notification_tab.dart';
import 'tabs/about_tab.dart';

/// 设置页标签配置
class SettingsTabConfig {
  /// 标签类型
  final SettingsTabType type;

  /// 内容构建器
  final WidgetBuilder builder;

  /// 是否仅限桌面端显示
  /// 为 true 时，移动端（iOS/Android）不显示此标签
  final bool desktopOnly;

  const SettingsTabConfig({
    required this.type,
    required this.builder,
    this.desktopOnly = false,
  });

  /// 获取所有标签配置（核心配置注册表）
  ///
  /// 自动根据平台过滤：
  /// - 桌面端（macOS/Windows/Linux）：显示所有标签
  /// - 移动端（iOS/Android）：隐藏 desktopOnly=true 的标签（如闪念胶囊）
  static List<SettingsTabConfig> getAllTabs() {
    final allTabs = [
      SettingsTabConfig(
        type: SettingsTabType.profile,
        builder: (context) => const ProfileTab(),
      ),
      SettingsTabConfig(
        type: SettingsTabType.display,
        builder: (context) => const DisplayTab(),
      ),
      SettingsTabConfig(
        type: SettingsTabType.taskManagement,
        builder: (context) => const TaskManagementTab(),
      ),
      // 闪念胶囊是全局快捷键功能，仅桌面端支持
      SettingsTabConfig(
        type: SettingsTabType.quickAdd,
        builder: (context) => const QuickAddTab(),
        desktopOnly: true,
      ),
      SettingsTabConfig(
        type: SettingsTabType.widget,
        builder: (context) => const WidgetTab(),
      ),
      SettingsTabConfig(
        type: SettingsTabType.dataManagement,
        builder: (context) => const DataManagementTab(),
      ),
      SettingsTabConfig(
        type: SettingsTabType.cloudSync,
        builder: (context) => const CloudSyncTab(),
      ),
      SettingsTabConfig(
        type: SettingsTabType.notification,
        builder: (context) => const NotificationTab(),
      ),
      SettingsTabConfig(
        type: SettingsTabType.about,
        builder: (context) => const AboutTab(),
      ),
    ];

    // 移动端过滤掉 desktopOnly 的标签
    final isMobile = Platform.isIOS || Platform.isAndroid;
    if (isMobile) {
      return allTabs.where((tab) => !tab.desktopOnly).toList();
    }

    return allTabs;
  }
}
