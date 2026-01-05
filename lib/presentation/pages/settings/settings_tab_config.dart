import 'package:flutter/material.dart';
import 'settings_tab_type.dart';
import 'tabs/display_tab.dart';
import 'tabs/quick_add_tab.dart';
import 'tabs/data_management_tab.dart';
import 'tabs/cloud_sync_tab.dart';
import 'tabs/about_tab.dart';

/// 设置页标签配置
class SettingsTabConfig {
  /// 标签类型
  final SettingsTabType type;

  /// 内容构建器
  final WidgetBuilder builder;

  const SettingsTabConfig({
    required this.type,
    required this.builder,
  });

  /// 获取所有标签配置（核心配置注册表）
  static List<SettingsTabConfig> getAllTabs() {
    return [
      SettingsTabConfig(
        type: SettingsTabType.display,
        builder: (context) => const DisplayTab(),
      ),
      SettingsTabConfig(
        type: SettingsTabType.quickAdd,
        builder: (context) => const QuickAddTab(),
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
        type: SettingsTabType.about,
        builder: (context) => const AboutTab(),
      ),
    ];
  }
}
