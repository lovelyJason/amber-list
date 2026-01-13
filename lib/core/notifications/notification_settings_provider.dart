import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'backlog_notification_scheduler.dart';

/// 通知设置数据模型
class NotificationSettings {
  /// 是否启用待办积压通知
  final bool backlogNotificationEnabled;

  /// 通知时间（小时，24小时制，默认16点）
  final int notifyHour;

  const NotificationSettings({
    required this.backlogNotificationEnabled,
    required this.notifyHour,
  });

  /// 默认设置（开启通知，16点提醒）
  factory NotificationSettings.defaults() => const NotificationSettings(
        backlogNotificationEnabled: true,
        notifyHour: 16,
      );

  NotificationSettings copyWith({
    bool? backlogNotificationEnabled,
    int? notifyHour,
  }) {
    return NotificationSettings(
      backlogNotificationEnabled:
          backlogNotificationEnabled ?? this.backlogNotificationEnabled,
      notifyHour: notifyHour ?? this.notifyHour,
    );
  }
}

/// 通知设置 Notifier
///
/// 职责:
/// - 从 SharedPreferences 加载设置
/// - 提供修改设置的方法
/// - 自动持久化设置变更
class NotificationSettingsNotifier extends StateNotifier<NotificationSettings> {
  NotificationSettingsNotifier() : super(NotificationSettings.defaults()) {
    _loadSettings();
  }

  /// SharedPreferences key: 通知时间
  static const _keyNotifyHour = 'backlog_notify_hour';

  /// 从 SharedPreferences 加载设置
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled =
        prefs.getBool(BacklogNotificationScheduler.keyEnabled) ?? true;
    final notifyHour = prefs.getInt(_keyNotifyHour) ?? 16;

    state = NotificationSettings(
      backlogNotificationEnabled: enabled,
      notifyHour: notifyHour,
    );
  }

  /// 设置是否启用积压通知
  Future<void> setBacklogNotificationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(BacklogNotificationScheduler.keyEnabled, enabled);

    state = state.copyWith(backlogNotificationEnabled: enabled);
  }

  /// 设置通知时间（小时）
  Future<void> setNotifyHour(int hour) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyNotifyHour, hour);

    state = state.copyWith(notifyHour: hour);
  }
}

/// 通知设置 Provider 实例
final notificationSettingsProvider =
    StateNotifierProvider<NotificationSettingsNotifier, NotificationSettings>(
        (ref) {
  return NotificationSettingsNotifier();
});
