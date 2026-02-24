import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 显示设置状态
/// 控制任务列表项的显示选项
class DisplaySettings {
  /// 是否显示标签
  final bool showTags;

  /// 是否显示截止日期
  final bool showDueDate;

  /// 是否显示优先级标识（暂时预留，后续可扩展）
  final bool showPriority;

  /// 过期任务标题颜色（存储为 ARGB int 值）
  /// 默认为 0xFFFF5722 (AmberColors.warning 同色)
  final int overdueTitleColorValue;

  /// 过期标签颜色（"已过期"文字和日历图标的颜色）
  /// 默认为 0xFFFF5722 (AmberColors.warning 同色)
  final int overdueLabelColorValue;

  /// 是否使用原生标题栏（仅 Windows 有效）
  /// true = Windows 原生标题栏，false = macOS 风格红绿灯
  /// 默认 false（使用 macOS 风格红绿灯）
  final bool useNativeTitleBar;

  /// 关闭窗口时最小化到托盘（仅桌面端有效）
  /// true = 关闭时隐藏到系统托盘，false = 直接退出应用
  /// 默认 true（最小化到托盘）
  final bool minimizeToTray;

  /// 最小化到托盘时是否在 Dock 中显示（仅 macOS 有效）
  /// true = Dock 中显示图标（有小黑点），点击可恢复窗口
  /// false = 从 Dock 中完全隐藏，仅通过托盘图标操作
  /// 默认 true（在 Dock 中显示）
  final bool showInDockWhenMinimized;

  const DisplaySettings({
    this.showTags = true,
    this.showDueDate = true,
    this.showPriority = true,
    this.overdueTitleColorValue = 0xFFFF5722,
    this.overdueLabelColorValue = 0xFFFF5722,
    this.useNativeTitleBar = false,
    this.minimizeToTray = true,
    this.showInDockWhenMinimized = true,
  });

  DisplaySettings copyWith({
    bool? showTags,
    bool? showDueDate,
    bool? showPriority,
    int? overdueTitleColorValue,
    int? overdueLabelColorValue,
    bool? useNativeTitleBar,
    bool? minimizeToTray,
    bool? showInDockWhenMinimized,
  }) {
    return DisplaySettings(
      showTags: showTags ?? this.showTags,
      showDueDate: showDueDate ?? this.showDueDate,
      showPriority: showPriority ?? this.showPriority,
      overdueTitleColorValue: overdueTitleColorValue ?? this.overdueTitleColorValue,
      overdueLabelColorValue: overdueLabelColorValue ?? this.overdueLabelColorValue,
      useNativeTitleBar: useNativeTitleBar ?? this.useNativeTitleBar,
      minimizeToTray: minimizeToTray ?? this.minimizeToTray,
      showInDockWhenMinimized: showInDockWhenMinimized ?? this.showInDockWhenMinimized,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() => {
        'showTags': showTags,
        'showDueDate': showDueDate,
        'showPriority': showPriority,
        'overdueTitleColorValue': overdueTitleColorValue,
        'overdueLabelColorValue': overdueLabelColorValue,
        'useNativeTitleBar': useNativeTitleBar,
        'minimizeToTray': minimizeToTray,
        'showInDockWhenMinimized': showInDockWhenMinimized,
      };

  /// 从 JSON 创建
  factory DisplaySettings.fromJson(Map<String, dynamic> json) {
    return DisplaySettings(
      showTags: json['showTags'] as bool? ?? true,
      showDueDate: json['showDueDate'] as bool? ?? true,
      showPriority: json['showPriority'] as bool? ?? true,
      overdueTitleColorValue: json['overdueTitleColorValue'] as int? ?? 0xFFFF5722,
      overdueLabelColorValue: json['overdueLabelColorValue'] as int? ?? 0xFFFF5722,
      useNativeTitleBar: json['useNativeTitleBar'] as bool? ?? false,
      minimizeToTray: json['minimizeToTray'] as bool? ?? true,
      showInDockWhenMinimized: json['showInDockWhenMinimized'] as bool? ?? true,
    );
  }
}

/// 显示设置 Notifier
/// 负责管理显示设置状态并持久化到 SharedPreferences
class DisplaySettingsNotifier extends StateNotifier<DisplaySettings> {
  DisplaySettingsNotifier() : super(const DisplaySettings()) {
    _loadSettings();
  }

  /// SharedPreferences key
  static const _configKey = 'display_settings';

  /// 加载完成标志 Completer
  /// 用于确保外部代码可以等待设置加载完成
  final Completer<DisplaySettings> _loadCompleter = Completer<DisplaySettings>();

  /// 等待设置加载完成
  /// 返回加载完成后的设置值
  Future<DisplaySettings> waitForLoad() => _loadCompleter.future;

  /// 加载设置
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_configKey);

      if (jsonStr != null && jsonStr.isNotEmpty) {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        state = DisplaySettings.fromJson(json);
        // debugPrint('[DisplaySettings] 已加载显示设置');
      }

      // 标记加载完成（无论成功还是使用默认值）
      if (!_loadCompleter.isCompleted) {
        _loadCompleter.complete(state);
      }
    } catch (e) {
      debugPrint('[DisplaySettings] 加载设置失败: $e');
      // 加载失败时也标记完成，使用默认值
      if (!_loadCompleter.isCompleted) {
        _loadCompleter.complete(state);
      }
    }
  }

  /// 保存设置
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_configKey, jsonEncode(state.toJson()));
      debugPrint('[DisplaySettings] 已保存显示设置');
    } catch (e) {
      debugPrint('[DisplaySettings] 保存设置失败: $e');
    }
  }

  /// 切换标签显示
  void toggleShowTags() {
    state = state.copyWith(showTags: !state.showTags);
    _saveSettings();
  }

  /// 切换截止日期显示
  void toggleShowDueDate() {
    state = state.copyWith(showDueDate: !state.showDueDate);
    _saveSettings();
  }

  /// 切换优先级显示
  void toggleShowPriority() {
    state = state.copyWith(showPriority: !state.showPriority);
    _saveSettings();
  }

  /// 设置标签显示
  void setShowTags(bool value) {
    state = state.copyWith(showTags: value);
    _saveSettings();
  }

  /// 设置截止日期显示
  void setShowDueDate(bool value) {
    state = state.copyWith(showDueDate: value);
    _saveSettings();
  }

  /// 设置优先级显示
  void setShowPriority(bool value) {
    state = state.copyWith(showPriority: value);
    _saveSettings();
  }

  /// 设置过期任务标题颜色
  void setOverdueTitleColor(int colorValue) {
    state = state.copyWith(overdueTitleColorValue: colorValue);
    _saveSettings();
  }

  /// 设置过期标签颜色（"已过期"文字）
  void setOverdueLabelColor(int colorValue) {
    state = state.copyWith(overdueLabelColorValue: colorValue);
    _saveSettings();
  }

  /// 设置是否使用原生标题栏（仅 Windows 有效）
  /// 注意：此设置需要重启应用才能生效
  void setUseNativeTitleBar(bool value) {
    state = state.copyWith(useNativeTitleBar: value);
    _saveSettings();
  }

  /// 设置是否关闭时最小化到托盘
  void setMinimizeToTray(bool value) {
    state = state.copyWith(minimizeToTray: value);
    _saveSettings();
  }

  /// 设置最小化到托盘时是否在 Dock 中显示（仅 macOS 有效）
  void setShowInDockWhenMinimized(bool value) {
    state = state.copyWith(showInDockWhenMinimized: value);
    _saveSettings();
  }
}

/// 显示设置 Provider
final displaySettingsProvider =
    StateNotifierProvider<DisplaySettingsNotifier, DisplaySettings>((ref) {
  return DisplaySettingsNotifier();
});
