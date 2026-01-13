import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 任务管理设置状态
///
/// 控制任务行为相关的设置选项，与显示设置（DisplaySettings）分离
/// - 自动顺延：过期任务自动改为今天
/// - 已过期区域折叠状态
/// - 今日已检查标记：避免同一天重复执行自动顺延
/// - 后续可扩展：默认优先级、默认提醒时间等
///
/// 注意：每日任务执行时间通过 .env 中的 DAILY_TASK_HOUR 配置（编译时确定）
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

  /// 上次执行自动顺延的时间戳（yyyy-MM-dd HH:mm:ss 格式字符串）
  /// 用于避免同一天重复执行自动顺延检查
  /// - 如果日期部分与今天相同，跳过检查（今天已经检查过了）
  /// - 如果日期部分与今天不同，执行检查并更新为当前时间
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
  ///
  /// iOS: 从 App Group UserDefaults 读取（与 Widget 共享）
  /// Android: 从 SharedPreferences 读取
  Future<void> _loadSettings() async {
    try {
      String? jsonStr;

      if (Platform.isIOS) {
        // iOS: 从 App Group UserDefaults 读取（Widget 也读写这里）
        jsonStr = await HomeWidget.getWidgetData<String>(_configKey);
      } else {
        // Android: 从 SharedPreferences 读取
        final prefs = await SharedPreferences.getInstance();
        jsonStr = prefs.getString(_configKey);
      }

      if (jsonStr != null && jsonStr.isNotEmpty) {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        state = TaskManagementSettings.fromJson(json);
        // debugPrint('[TaskManagementSettings] 已加载任务管理设置');
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
  ///
  /// 同时保存到两个位置：
  /// 1. SharedPreferences（Flutter 本地存储，Android Widget 可访问）
  /// 2. App Group UserDefaults（iOS Widget 可访问，通过 HomeWidget）
  Future<void> _saveSettings() async {
    final jsonStr = jsonEncode(state.toJson());

    try {
      // 保存到 SharedPreferences（Android Widget 可直接访问 FlutterSharedPreferences）
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_configKey, jsonStr);

      // iOS: 同步到 App Group UserDefaults（iOS Widget 需要通过 App Group 共享数据）
      if (Platform.isIOS) {
        await HomeWidget.saveWidgetData<String>(_configKey, jsonStr);
        debugPrint('[TaskManagementSettings] 已同步设置到 iOS App Group');
      }

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

  /// 更新上次自动顺延时间
  /// 每次执行自动顺延后调用，记录当前时间（含时分秒）
  void setLastAutoPostponeDate(String dateTime) {
    state = state.copyWith(lastAutoPostponeDate: dateTime);
    _saveSettings();
  }

  /// 清除上次自动顺延日期（调试用）
  /// 重置检查状态，下次启动时会重新执行自动顺延检查
  void clearLastAutoPostponeDate() {
    // copyWith 不支持 null，需要直接创建新实例
    state = TaskManagementSettings(
      enableAutoPostpone: state.enableAutoPostpone,
      overdueExpanded: state.overdueExpanded,
      lastAutoPostponeDate: null,
    );
    _saveSettings();
    debugPrint('[TaskManagementSettings] 已清除自动顺延检查日期（调试）');
  }

  /// 检查今天是否已经执行过自动顺延（实时读取存储）
  ///
  /// 返回 true 表示今天已执行过，无需再次执行
  /// 注：只比较日期部分，忽略时分秒
  ///
  /// 重要：此方法直接从存储读取，而不是用内存中的 state。
  /// 因为 Widget 可能在 Flutter 启动前就更新了标记位，
  /// 如果用缓存值会导致 Flutter 无法感知 Widget 已执行过检查。
  ///
  /// 存储位置：
  /// - Android: SharedPreferences（FlutterSharedPreferences）
  /// - iOS: App Group UserDefaults（通过 HomeWidget）
  Future<bool> hasCheckedToday() async {
    try {
      String? jsonStr;

      if (Platform.isIOS) {
        // iOS: 从 App Group UserDefaults 读取（Widget 也写入这里）
        jsonStr = await HomeWidget.getWidgetData<String>(_configKey);
      } else {
        // Android: 从 SharedPreferences 读取
        final prefs = await SharedPreferences.getInstance();
        jsonStr = prefs.getString(_configKey);
      }

      if (jsonStr == null || jsonStr.isEmpty) return false;

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      final lastAutoPostponeDate = json['lastAutoPostponeDate'] as String?;

      if (lastAutoPostponeDate == null) return false;

      final today = DateTime.now();
      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      // 只比较前 10 位（yyyy-MM-dd 部分）
      final lastDatePart = lastAutoPostponeDate.length >= 10
          ? lastAutoPostponeDate.substring(0, 10)
          : lastAutoPostponeDate;

      final checked = lastDatePart == todayStr;
      debugPrint('[TaskManagementSettings] hasCheckedToday: $checked (lastDate=$lastDatePart, today=$todayStr)');
      return checked;
    } catch (e) {
      debugPrint('[TaskManagementSettings] hasCheckedToday error: $e');
      return false;
    }
  }

  /// 获取当前时间字符串（yyyy-MM-dd HH:mm:ss 格式）
  static String getNowDateTimeString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }
}

/// 任务管理设置 Provider
final taskManagementSettingsProvider = StateNotifierProvider<
    TaskManagementSettingsNotifier, TaskManagementSettings>((ref) {
  return TaskManagementSettingsNotifier();
});
