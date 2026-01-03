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

  const DisplaySettings({
    this.showTags = true,
    this.showDueDate = true,
    this.showPriority = true,
    this.overdueTitleColorValue = 0xFFFF5722,
    this.overdueLabelColorValue = 0xFFFF5722,
  });

  DisplaySettings copyWith({
    bool? showTags,
    bool? showDueDate,
    bool? showPriority,
    int? overdueTitleColorValue,
    int? overdueLabelColorValue,
  }) {
    return DisplaySettings(
      showTags: showTags ?? this.showTags,
      showDueDate: showDueDate ?? this.showDueDate,
      showPriority: showPriority ?? this.showPriority,
      overdueTitleColorValue: overdueTitleColorValue ?? this.overdueTitleColorValue,
      overdueLabelColorValue: overdueLabelColorValue ?? this.overdueLabelColorValue,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() => {
        'showTags': showTags,
        'showDueDate': showDueDate,
        'showPriority': showPriority,
        'overdueTitleColorValue': overdueTitleColorValue,
        'overdueLabelColorValue': overdueLabelColorValue,
      };

  /// 从 JSON 创建
  factory DisplaySettings.fromJson(Map<String, dynamic> json) {
    return DisplaySettings(
      showTags: json['showTags'] as bool? ?? true,
      showDueDate: json['showDueDate'] as bool? ?? true,
      showPriority: json['showPriority'] as bool? ?? true,
      overdueTitleColorValue: json['overdueTitleColorValue'] as int? ?? 0xFFFF5722,
      overdueLabelColorValue: json['overdueLabelColorValue'] as int? ?? 0xFFFF5722,
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

  /// 加载设置
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_configKey);

      if (jsonStr != null && jsonStr.isNotEmpty) {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        state = DisplaySettings.fromJson(json);
        debugPrint('[DisplaySettings] 已加载显示设置');
      }
    } catch (e) {
      debugPrint('[DisplaySettings] 加载设置失败: $e');
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
}

/// 显示设置 Provider
final displaySettingsProvider =
    StateNotifierProvider<DisplaySettingsNotifier, DisplaySettings>((ref) {
  return DisplaySettingsNotifier();
});
