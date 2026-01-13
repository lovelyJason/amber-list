import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// 本地通知服务（单例）
///
/// 职责:
/// - 初始化 flutter_local_notifications 插件
/// - 处理各平台通知权限请求
/// - 提供发送通知的统一接口
///
/// 设计哲学:
/// - 跨平台抽象：对外提供统一 API，内部处理平台差异
/// - 懒初始化：仅在需要时初始化通知插件
/// - 权限优雅处理：权限拒绝不阻塞应用，静默降级
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// 初始化通知服务（在 main.dart 调用）
  Future<void> init() async {
    if (_initialized) return;

    // 初始化时区数据库（必须先于通知插件初始化）
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));

    // Android 初始化配置
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // macOS/iOS 初始化配置
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // 请求权限
    await _requestPermissions();

    _initialized = true;
  }

  /// 请求通知权限（iOS/macOS/Android 13+）
  Future<void> _requestPermissions() async {
    if (Platform.isIOS || Platform.isMacOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      await _plugin
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      // Android 13+ 需要请求通知权限
      await androidPlugin?.requestNotificationsPermission();
    }
  }

  /// 发送待办积压通知
  ///
  /// [backlogCount] 积压任务数量
  /// [topTaskTitle] 最高优先级任务的标题
  Future<void> showBacklogNotification({
    required int backlogCount,
    required String topTaskTitle,
  }) async {
    if (!_initialized) {
      // 未初始化时静默忽略
      return;
    }

    const notificationId = 1001; // 积压通知固定 ID（用于覆盖更新）

    // Android 通知详情
    const androidDetails = AndroidNotificationDetails(
      'backlog_reminders', // Channel ID
      '待办积压提醒', // Channel Name
      channelDescription: '下班前提醒你清理积压的待办事项',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    // iOS/macOS 通知详情
    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _plugin.show(
      notificationId,
      '待办积压提醒',
      '你有 $backlogCount 个待办积压，最高优先级: $topTaskTitle',
      details,
    );
  }

  /// 发送测试通知（调试用）
  ///
  /// 与 showBacklogNotification 的区别：使用随机 ID，每次都会弹出新通知
  /// 用于调试工具箱测试通知功能是否正常
  Future<void> showTestNotification({
    required int backlogCount,
    required String topTaskTitle,
  }) async {
    if (!_initialized) return;

    // 使用随机 ID，确保每次都弹出新通知
    final notificationId = DateTime.now().millisecondsSinceEpoch % 100000;

    const androidDetails = AndroidNotificationDetails(
      'backlog_reminders',
      '待办积压提醒',
      channelDescription: '下班前提醒你清理积压的待办事项',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    await _plugin.show(
      notificationId,
      '待办积压提醒（测试）',
      '你有 $backlogCount 个待办积压，最高优先级: $topTaskTitle',
      details,
    );
  }

  /// 用户点击通知回调
  void _onNotificationTap(NotificationResponse response) {
    // 点击通知后的行为（如跳转到今天视图）
    // 可通过 payload 传递参数
    // 当前版本暂不处理，后续可扩展
  }
}
