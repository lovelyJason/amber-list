import 'package:flutter/material.dart';

/// 设置页标签类型枚举
enum SettingsTabType {
  /// 数据管理（导入/导出）
  dataManagement,

  /// 云同步（WebDAV配置）
  cloudSync,

  /// 关于（版本信息等）
  about;

  /// 获取标签显示名称
  String get displayName {
    switch (this) {
      case SettingsTabType.dataManagement:
        return '数据管理';
      case SettingsTabType.cloudSync:
        return '云同步';
      case SettingsTabType.about:
        return '关于';
    }
  }

  /// 获取标签图标
  IconData get icon {
    switch (this) {
      case SettingsTabType.dataManagement:
        return Icons.storage_outlined;
      case SettingsTabType.cloudSync:
        return Icons.cloud_outlined;
      case SettingsTabType.about:
        return Icons.info_outline;
    }
  }
}
