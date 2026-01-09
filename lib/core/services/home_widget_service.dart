import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../../data/models/task.dart';
import '../models/widget_skins.dart';

/// 桌面小组件服务
///
/// 负责 Flutter ↔ Android/iOS 原生小组件之间的数据同步
/// 使用 home_widget 插件作为桥梁，通过 SharedPreferences 共享数据
///
/// 核心职责：
/// 1. 序列化今日任务数据到 SharedPreferences
/// 2. 触发原生小组件刷新
/// 3. 处理小组件上的用户交互（如点击完成任务）
class HomeWidgetService {
  /// Android Widget 的类名（相对于包名，插件会自动拼接 "包名." 前缀）
  /// 注意：不要以点开头，否则会出现双点问题
  static const String _androidWidgetName = 'widget.AmberWidgetProvider';

  /// iOS Widget 的 App Group ID（iOS 特有，用于跨进程数据共享）
  /// 格式：group.com.你的包名
  static const String _iOSAppGroupId = 'group.com.example.amberlist';

  /// SharedPreferences 中存储任务数据的 Key
  static const String _keyWidgetTasks = 'widget_tasks';

  /// SharedPreferences 中存储待处理操作的 Key（用户在 Widget 上的点击）
  static const String _keyPendingAction = 'widget_pending_action';

  /// SharedPreferences 中存储 Small Widget 皮肤设置的 Key
  static const String _keySmallWidgetSkin = 'widget_small_skin';

  /// 单例实例
  static final HomeWidgetService _instance = HomeWidgetService._internal();

  factory HomeWidgetService() => _instance;

  HomeWidgetService._internal();

  /// 初始化服务
  ///
  /// 设置 App Group ID（iOS）并注册后台回调
  Future<void> init() async {
    // 仅移动端支持
    if (!Platform.isAndroid && !Platform.isIOS) return;

    try {
      // iOS 需要设置 App Group ID
      if (Platform.isIOS) {
        await HomeWidget.setAppGroupId(_iOSAppGroupId);
      }

      // 注册后台交互回调（用户点击 Widget 时触发）
      // 这个回调在 App 启动时会被调用，用于处理 Widget 上的用户操作
      HomeWidget.widgetClicked.listen(_handleWidgetClick);

      debugPrint('[HomeWidgetService] 初始化成功');
    } catch (e) {
      debugPrint('[HomeWidgetService] 初始化失败: $e');
    }
  }

  /// 更新小组件数据
  ///
  /// 将任务列表序列化为 JSON 并存储到 SharedPreferences
  /// 然后触发原生小组件刷新
  ///
  /// [tasks] 全部任务列表（未筛选）
  /// 此方法会自动筛选出需要显示的任务：
  /// - 今日任务（dueDate = 今天）
  /// - autoPostpone=true 的已过期任务
  Future<void> updateWidgetData(List<Task> tasks) async {
    // 仅移动端支持
    if (!Platform.isAndroid && !Platform.isIOS) return;

    try {
      // 筛选需要显示的任务
      final widgetTasks = _filterWidgetTasks(tasks);

      // 序列化为 JSON
      final jsonData = _serializeTasks(widgetTasks);

      // 存储到 SharedPreferences
      await HomeWidget.saveWidgetData<String>(_keyWidgetTasks, jsonData);

      // 触发小组件刷新
      await _refreshWidget();

      debugPrint('[HomeWidgetService] 已更新小组件数据，任务数: ${widgetTasks.length}');
    } catch (e) {
      debugPrint('[HomeWidgetService] 更新数据失败: $e');
    }
  }

  /// 筛选需要在小组件上显示的任务
  ///
  /// 筛选规则：
  /// 1. 未删除、未完成
  /// 2. 有截止日期
  /// 3. 截止日期在当前月份前后3个月范围内（用于日历 Widget 显示任务标记）
  ///
  /// 注意：日历 Widget 需要显示整月的任务标记，所以不能只传今日任务
  List<Task> _filterWidgetTasks(List<Task> tasks) {
    final result = <Task>[];

    // 计算日期范围：当前月前后3个月
    final now = DateTime.now();
    final rangeStart = DateTime(now.year, now.month - 3, 1);
    final rangeEnd = DateTime(now.year, now.month + 4, 0); // 下3个月的最后一天

    for (final task in tasks) {
      // 排除已删除和已完成的任务
      if (task.isDeleted || task.isCompleted) continue;

      // 排除没有截止日期的任务
      if (task.dueDate == null) continue;

      // 检查是否在日期范围内
      final dueDate = task.dueDate!;
      if (dueDate.isBefore(rangeStart) || dueDate.isAfter(rangeEnd)) {
        continue;
      }

      result.add(task);
    }

    // 排序：按截止日期升序，同日期按优先级降序
    result.sort((a, b) {
      final dateCompare = a.dueDate!.compareTo(b.dueDate!);
      if (dateCompare != 0) return dateCompare;
      return b.priority.value.compareTo(a.priority.value);
    });

    // 限制最多返回 100 条（日历 Widget 需要更多数据）
    if (result.length > 100) {
      return result.sublist(0, 100);
    }

    return result;
  }

  /// 序列化任务列表为 JSON 字符串
  ///
  /// 只序列化小组件需要的字段，减少数据量
  String _serializeTasks(List<Task> tasks) {
    final list = tasks.map((task) {
      // 格式化截止时间为 HH:mm（如果有的话）
      String? dueTimeDisplay;
      if (task.dueDate != null) {
        final hour = task.dueDate!.hour.toString().padLeft(2, '0');
        final minute = task.dueDate!.minute.toString().padLeft(2, '0');
        // 只有当时间不是 00:00 时才显示（因为只设日期时默认是 00:00）
        if (task.dueDate!.hour != 0 || task.dueDate!.minute != 0) {
          dueTimeDisplay = '$hour:$minute';
        }
      }

      // 格式化完整的截止日期为 YYYY-MM-DD（用于日历 Widget 标记任务日期）
      String? dueDateStr;
      if (task.dueDate != null) {
        final year = task.dueDate!.year.toString();
        final month = task.dueDate!.month.toString().padLeft(2, '0');
        final day = task.dueDate!.day.toString().padLeft(2, '0');
        dueDateStr = '$year-$month-$day';
      }

      return {
        'id': task.id,
        'title': task.title,
        'isCompleted': task.isCompleted,
        'priority': task.priority.value,
        'dueDate': task.dueDate?.millisecondsSinceEpoch,
        'dueTime': dueDateStr, // YYYY-MM-DD 格式，用于日历 Widget 标记任务日期
        'dueTimeDisplay': dueTimeDisplay, // HH:mm 格式，用于显示时间
      };
    }).toList();

    return jsonEncode(list);
  }

  /// 触发原生小组件刷新
  Future<void> _refreshWidget() async {
    try {
      if (Platform.isAndroid) {
        // Android: 刷新指定类名的 Widget
        await HomeWidget.updateWidget(
          name: _androidWidgetName,
          androidName: _androidWidgetName,
        );
      } else if (Platform.isIOS) {
        // iOS: 刷新所有 Widget Timeline
        await HomeWidget.updateWidget(
          name: 'AmberWidget',
          iOSName: 'AmberWidget',
        );
      }
      debugPrint('[HomeWidgetService] 已触发小组件刷新');
    } catch (e) {
      debugPrint('[HomeWidgetService] 触发刷新失败: $e');
    }
  }

  /// 处理小组件点击事件
  ///
  /// 当用户在小组件上点击任务时，原生代码会将操作写入 SharedPreferences
  /// Flutter 侧通过此方法读取并处理
  void _handleWidgetClick(Uri? uri) {
    if (uri == null) return;

    debugPrint('[HomeWidgetService] 收到 Widget 点击: $uri');

    // URI 格式: amberlist://widget/toggle_task?id=xxx
    if (uri.host == 'widget' && uri.path == '/toggle_task') {
      final taskId = uri.queryParameters['id'];
      if (taskId != null) {
        // 通知外部处理任务完成状态切换
        _pendingToggleTaskId = taskId;
        debugPrint('[HomeWidgetService] 待处理的任务切换: $taskId');
      }
    }
  }

  /// 待处理的任务切换 ID
  /// 外部代码应该定期检查此值，处理后置为 null
  String? _pendingToggleTaskId;

  /// 获取并清除待处理的任务切换 ID
  String? consumePendingToggleTaskId() {
    final id = _pendingToggleTaskId;
    _pendingToggleTaskId = null;
    return id;
  }

  /// 检查是否有待处理的小组件操作
  ///
  /// 从 SharedPreferences 读取 pending_action
  /// 返回任务 ID 如果有待处理的 toggle_task 操作，否则返回 null
  Future<String?> checkPendingAction() async {
    if (!Platform.isAndroid && !Platform.isIOS) return null;

    try {
      final action = await HomeWidget.getWidgetData<String>(_keyPendingAction);
      if (action != null && action.isNotEmpty) {
        // 清除已读取的操作
        await HomeWidget.saveWidgetData<String>(_keyPendingAction, '');

        // 解析操作：格式为 "toggle_task:taskId"
        if (action.startsWith('toggle_task:')) {
          return action.substring('toggle_task:'.length);
        }
      }
    } catch (e) {
      debugPrint('[HomeWidgetService] 检查 pending action 失败: $e');
    }
    return null;
  }

  /// 更新 Small Widget 皮肤设置
  ///
  /// 将皮肤类型名称存储到 SharedPreferences，供原生 Widget 读取
  /// [skinType] 皮肤类型枚举
  Future<void> updateSmallWidgetSkin(WidgetSkinType skinType) async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    try {
      // 存储皮肤名称（与 Android drawable 名称对应）
      final skinName = skinType.name; // amber, white, dark, mint, pink
      await HomeWidget.saveWidgetData<String>(_keySmallWidgetSkin, skinName);

      // 触发 Widget 刷新
      await _refreshWidget();

      debugPrint('[HomeWidgetService] 已更新 Small Widget 皮肤: $skinName');
    } catch (e) {
      debugPrint('[HomeWidgetService] 更新皮肤失败: $e');
    }
  }
}
