import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 日历弹窗布局模式
enum CalendarDialogLayout {
  /// 单列模式：任务列表占满宽度，双击任务弹出编辑对话框
  singleColumn,

  /// 双列模式：左侧任务列表 + 右侧详情面板，单击任务显示详情
  twoColumn,
}

/// 日历偏好设置
/// 存储日历页面相关的用户偏好
class CalendarPreferences {
  /// 日历弹窗布局模式（单列/双列）
  final CalendarDialogLayout dialogLayout;

  /// 是否显示节假日（预留）
  final bool showHolidays;

  /// 是否显示农历（预留）
  final bool showLunarCalendar;

  const CalendarPreferences({
    this.dialogLayout = CalendarDialogLayout.singleColumn,
    this.showHolidays = true,
    this.showLunarCalendar = false,
  });

  CalendarPreferences copyWith({
    CalendarDialogLayout? dialogLayout,
    bool? showHolidays,
    bool? showLunarCalendar,
  }) {
    return CalendarPreferences(
      dialogLayout: dialogLayout ?? this.dialogLayout,
      showHolidays: showHolidays ?? this.showHolidays,
      showLunarCalendar: showLunarCalendar ?? this.showLunarCalendar,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() => {
        'dialogLayout': dialogLayout.name,
        'showHolidays': showHolidays,
        'showLunarCalendar': showLunarCalendar,
      };

  /// 从 JSON 创建
  factory CalendarPreferences.fromJson(Map<String, dynamic> json) {
    return CalendarPreferences(
      dialogLayout: CalendarDialogLayout.values.firstWhere(
        (e) => e.name == json['dialogLayout'],
        orElse: () => CalendarDialogLayout.singleColumn,
      ),
      showHolidays: json['showHolidays'] as bool? ?? true,
      showLunarCalendar: json['showLunarCalendar'] as bool? ?? false,
    );
  }
}

/// 日历偏好设置 Notifier
/// 负责管理日历偏好设置状态并持久化到 SharedPreferences
class CalendarPreferencesNotifier extends StateNotifier<CalendarPreferences> {
  CalendarPreferencesNotifier() : super(const CalendarPreferences()) {
    _loadPreferences();
  }

  /// SharedPreferences key
  static const _configKey = 'calendar_preferences';

  /// 加载偏好设置
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_configKey);

      if (jsonStr != null && jsonStr.isNotEmpty) {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        state = CalendarPreferences.fromJson(json);
        // debugPrint('[CalendarPreferences] 已加载日历偏好设置');
      }
    } catch (e) {
      debugPrint('[CalendarPreferences] 加载偏好设置失败: $e');
    }
  }

  /// 保存偏好设置
  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_configKey, jsonEncode(state.toJson()));
      debugPrint('[CalendarPreferences] 已保存日历偏好设置');
    } catch (e) {
      debugPrint('[CalendarPreferences] 保存偏好设置失败: $e');
    }
  }

  /// 设置弹窗布局模式
  void setDialogLayout(CalendarDialogLayout layout) {
    state = state.copyWith(dialogLayout: layout);
    _savePreferences();
  }

  /// 切换弹窗布局模式（单列 <-> 双列）
  void toggleDialogLayout() {
    final newLayout = state.dialogLayout == CalendarDialogLayout.singleColumn
        ? CalendarDialogLayout.twoColumn
        : CalendarDialogLayout.singleColumn;
    state = state.copyWith(dialogLayout: newLayout);
    _savePreferences();
  }

  /// 设置是否显示节假日
  void setShowHolidays(bool value) {
    state = state.copyWith(showHolidays: value);
    _savePreferences();
  }

  /// 设置是否显示农历
  void setShowLunarCalendar(bool value) {
    state = state.copyWith(showLunarCalendar: value);
    _savePreferences();
  }
}

/// 日历偏好设置 Provider
final calendarPreferencesProvider =
    StateNotifierProvider<CalendarPreferencesNotifier, CalendarPreferences>(
        (ref) {
  return CalendarPreferencesNotifier();
});
