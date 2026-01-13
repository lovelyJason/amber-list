import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../data/datasources/local/database.dart';
import '../../data/repositories/holiday_repository.dart';
import 'notification_service.dart';

/// 待办积压通知调度器
///
/// 设计哲学:
/// - 每分钟检查一次当前时间
/// - 在用户配置的时间触发通知检查（默认16:00，下班前2小时）
/// - 一天仅发送一次通知（使用 SharedPreferences 记录）
/// - 周末和中国法定节假日跳过
/// - 仅应用运行时生效（不使用后台服务）
///
/// 触发条件:
/// - 当前时间为配置的小时（minute 在 0-59 之间首次触发）
/// - 今日尚未发送过通知
/// - 通知功能已开启
/// - 不是周末或节假日
/// - 存在积压任务（未完成且已过期）
class BacklogNotificationScheduler {
  final AppDatabase _database;
  Timer? _timer;

  /// SharedPreferences key: 今日是否已通知
  static const _keyLastNotifyDate = 'backlog_last_notify_date';

  /// SharedPreferences key: 通知功能是否开启
  static const keyEnabled = 'backlog_notification_enabled';

  /// SharedPreferences key: 通知时间（小时）
  static const keyNotifyHour = 'backlog_notify_hour';

  BacklogNotificationScheduler(this._database);

  /// 启动调度器
  void start() {
    // 每分钟检查一次
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkAndNotify();
    });

    // 启动后立即检查一次（用于测试场景）
    _checkAndNotify();
  }

  /// 停止调度器
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// 检查并发送通知
  ///
  /// 注意: 使用中国时区（Asia/Shanghai）判断时间和节假日
  /// 确保海外用户也能在中国时间 16:00 收到通知
  Future<void> _checkAndNotify() async {
    try {
      // 使用中国时区获取当前时间（确保与节假日数据一致）
      final now = tz.TZDateTime.now(tz.getLocation('Asia/Shanghai'));
      final prefs = await SharedPreferences.getInstance();

      // 1. 获取配置的通知时间（默认16点）
      final notifyHour = prefs.getInt(keyNotifyHour) ?? 16;

      // 2. 检查是否为配置的时间（整个小时内都可以触发）
      if (now.hour != notifyHour) return;

      // 3. 检查今日是否已通知（避免重复）
      final lastNotifyDate = prefs.getString(_keyLastNotifyDate);
      final today = _formatDate(now);

      if (lastNotifyDate == today) return;

      // 4. 检查设置是否开启（默认开启）
      final enabled = prefs.getBool(keyEnabled) ?? true;
      if (!enabled) return;

      // 5. 检查是否为周末或节假日
      final isHoliday = await HolidayRepository.instance.isHoliday(now);
      if (isHoliday) return;

      // 6. 查询积压任务（未完成且已过期）
      final backlogTasks = await _getBacklogTasks();
      if (backlogTasks.isEmpty) return;

      // 7. 找出最高优先级任务
      final topTask = _getTopPriorityTask(backlogTasks);

      // 8. 发送通知
      await NotificationService.instance.showBacklogNotification(
        backlogCount: backlogTasks.length,
        topTaskTitle: topTask.title,
      );

      // 9. 记录今日已通知
      await prefs.setString(_keyLastNotifyDate, today);
    } catch (e) {
      // 记录错误但不影响应用运行
      // ignore: avoid_print
      // print('[BacklogScheduler] Error: $e');
    }
  }

  /// 查询积压任务（未完成且已过期）
  ///
  /// 积压定义:
  /// - 未完成（isCompleted == false）
  /// - 未删除（isDeleted == false）
  /// - 有截止日期（dueDate != null）
  /// - 截止日期早于今天（dueDate < today 00:00:00）
  ///
  /// 注意: 使用中国时区判断"今天"，与节假日数据保持一致
  Future<List<Task>> _getBacklogTasks() async {
    final allTasks = await _database.getAllTasks();
    // 使用中国时区获取今天日期
    final today = tz.TZDateTime.now(tz.getLocation('Asia/Shanghai'));
    final todayStart = DateTime(today.year, today.month, today.day);

    return allTasks.where((task) {
      return !task.isCompleted &&
          !task.isDeleted &&
          task.dueDate != null &&
          task.dueDate!.isBefore(todayStart);
    }).toList();
  }

  /// 获取最高优先级任务
  ///
  /// 优先级排序: high(3) > medium(2) > low(1) > none(0)
  Task _getTopPriorityTask(List<Task> tasks) {
    final sortedTasks = tasks.toList()
      ..sort((a, b) {
        // priority 是 int，值越大优先级越高
        return b.priority.compareTo(a.priority);
      });

    return sortedTasks.first;
  }

  /// 格式化日期为 "YYYY-MM-DD" 格式
  String _formatDate(DateTime date) {
    final year = date.year;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
