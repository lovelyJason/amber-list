import 'package:flutter/material.dart';

/// 设置页标签类型枚举
enum SettingsTabType {
  /// 个人信息（头像等）
  profile,

  /// 显示设置（控制任务列表项的显示选项）
  display,

  /// 任务管理（任务行为相关设置）
  taskManagement,

  /// 闪念胶囊（快捷键配置）
  quickAdd,

  /// 小组件（Android/iOS 桌面小组件皮肤设置）
  widget,

  /// 数据管理（导入/导出）
  dataManagement,

  /// 云同步（WebDAV配置）
  cloudSync,

  /// 关于（版本信息等）
  about;

  /// 获取标签显示名称
  String get displayName {
    switch (this) {
      case SettingsTabType.profile:
        return '个人信息';
      case SettingsTabType.display:
        return '显示';
      case SettingsTabType.taskManagement:
        return '任务管理';
      case SettingsTabType.quickAdd:
        return '闪念胶囊';
      case SettingsTabType.widget:
        return '小组件';
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
      case SettingsTabType.profile:
        return Icons.person_outline;
      case SettingsTabType.display:
        return Icons.visibility_outlined;
      case SettingsTabType.taskManagement:
        return Icons.task_alt_outlined;
      case SettingsTabType.quickAdd:
        return Icons.flash_on_outlined;
      case SettingsTabType.widget:
        return Icons.widgets_outlined;
      case SettingsTabType.dataManagement:
        return Icons.storage_outlined;
      case SettingsTabType.cloudSync:
        return Icons.cloud_outlined;
      case SettingsTabType.about:
        return Icons.info_outline;
    }
  }
}
