import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 任务管理设置状态
///
/// 控制任务行为相关的设置选项，与显示设置（DisplaySettings）分离
/// - 自动顺延：过期任务自动改为今天
/// - 已过期区域折叠状态
/// - 今日已检查标记：避免同一天重复执行自动顺延
/// - 后续可扩展：默认优先级、默认提醒时间等
class TaskManagementSettings {
  /// 是否启用自动顺延功能（全局开关）
  /// true = App 启动时自动将 autoPostpone=true 的过期任务顺延到今天
  /// false = 不自动顺延，所有过期任务都显示在"已过期"区域
  /// 默认 true（启用自动顺延）
  final bool enableAutoPostpone;

  /// "已过期"区域是否展开
  /// true = 展开显示过期任务列表
  /// false = 折叠隐藏过期任务列表
  /// 默认 true（展开，让用户看到过期任务）
  final bool overdueExpanded;

  /// 上次执行自动顺延的日期（yyyy-MM-dd 格式字符串）
  /// 用于避免同一天重复执行自动顺延检查
  /// - 如果与今天日期相同，跳过检查（今天已经检查过了）
  /// - 如果与今天日期不同，执行检查并更新为今天日期
  final String? lastAutoPostponeDate;

  const TaskManagementSettings({
    this.enableAutoPostpone = true,
    this.overdueExpanded = true,
    this.lastAutoPostponeDate,
  });

  TaskManagementSettings copyWith({
    bool? enableAutoPostpone,
    bool? overdueExpanded,
    String? lastAutoPostponeDate,
  }) {
    return TaskManagementSettings(
      enableAutoPostpone: enableAutoPostpone ?? this.enableAutoPostpone,
      overdueExpanded: overdueExpanded ?? this.overdueExpanded,
      lastAutoPostponeDate: lastAutoPostponeDate ?? this.lastAutoPostponeDate,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() => {
        'enableAutoPostpone': enableAutoPostpone,
        'overdueExpanded': overdueExpanded,
        'lastAutoPostponeDate': lastAutoPostponeDate,
      };

  /// 从 JSON 创建
  factory TaskManagementSettings.fromJson(Map<String, dynamic> json) {
    return TaskManagementSettings(
      enableAutoPostpone: json['enableAutoPostpone'] as bool? ?? true,
      overdueExpanded: json['overdueExpanded'] as bool? ?? true,
      lastAutoPostponeDate: json['lastAutoPostponeDate'] as String?,
    );
  }
}

/// 任务管理设置 Notifier
///
/// 负责管理任务行为设置状态并持久化到 SharedPreferences
class TaskManagementSettingsNotifier
    extends StateNotifier<TaskManagementSettings> {
  TaskManagementSettingsNotifier() : super(const TaskManagementSettings()) {
    _loadSettings();
  }

  /// SharedPreferences key
  static const _configKey = 'task_management_settings';

  /// 加载完成标志 Completer
  /// 用于确保外部代码可以等待设置加载完成
  final Completer<TaskManagementSettings> _loadCompleter =
      Completer<TaskManagementSettings>();

  /// 等待设置加载完成
  /// 返回加载完成后的设置值
  Future<TaskManagementSettings> waitForLoad() => _loadCompleter.future;

  /// 加载设置
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_configKey);

      if (jsonStr != null && jsonStr.isNotEmpty) {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        state = TaskManagementSettings.fromJson(json);
        debugPrint('[TaskManagementSettings] 已加载任务管理设置');
      }

      // 标记加载完成（无论成功还是使用默认值）
      if (!_loadCompleter.isCompleted) {
        _loadCompleter.complete(state);
      }
    } catch (e) {
      debugPrint('[TaskManagementSettings] 加载设置失败: $e');
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
      debugPrint('[TaskManagementSettings] 已保存任务管理设置');
    } catch (e) {
      debugPrint('[TaskManagementSettings] 保存设置失败: $e');
    }
  }

  /// 设置是否启用自动顺延功能
  void setEnableAutoPostpone(bool value) {
    state = state.copyWith(enableAutoPostpone: value);
    _saveSettings();
  }

  /// 设置"已过期"区域是否展开
  void setOverdueExpanded(bool value) {
    state = state.copyWith(overdueExpanded: value);
    _saveSettings();
  }

  /// 切换"已过期"区域展开/折叠状态
  void toggleOverdueExpanded() {
    setOverdueExpanded(!state.overdueExpanded);
  }

  /// 更新上次自动顺延日期
  /// 每次执行自动顺延后调用，记录今天的日期
  void setLastAutoPostponeDate(String date) {
    state = state.copyWith(lastAutoPostponeDate: date);
    _saveSettings();
  }

  /// 检查今天是否已经执行过自动顺延
  /// 返回 true 表示今天已执行过，无需再次执行
  bool hasCheckedToday() {
    if (state.lastAutoPostponeDate == null) return false;
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    return state.lastAutoPostponeDate == todayStr;
  }

  /// 获取今天的日期字符串（yyyy-MM-dd 格式）
  static String getTodayDateString() {
    final today = DateTime.now();
    return '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  }
}

/// 任务管理设置 Provider
final taskManagementSettingsProvider = StateNotifierProvider<
    TaskManagementSettingsNotifier, TaskManagementSettings>((ref) {
  return TaskManagementSettingsNotifier();
});
