import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/constants/dimensions.dart';
import 'core/services/logger_service.dart';
import 'core/theme/amber_theme.dart';
import 'core/utils/startup_logger.dart';
import 'presentation/pages/settings/settings_page.dart';
import 'presentation/pages/sticky_note/sticky_note_page.dart';

/// 窗口类型常量
/// 用于区分不同类型的子窗口
class WindowType {
  static const String main = 'main';
  static const String stickyNote = 'sticky_note';
  static const String settings = 'settings';
}

void main(List<String> args) async {
  // ==================== 全局错误捕获 ====================
  // 使用 runZonedGuarded 捕获所有未处理的异步异常
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // 初始化日志服务（应最先初始化）
    await AppLogger.instance.init();

    // 捕获 Flutter 框架层的错误（Widget build 异常等）
    FlutterError.onError = (FlutterErrorDetails details) {
      AppLogger.error(
        'FlutterError',
        details.exceptionAsString(),
        details.exception,
        details.stack,
      );
      // Debug 模式下仍然打印到控制台方便调试
      if (kDebugMode) {
        FlutterError.dumpErrorToConsole(details);
      }
    };

    // 捕获 Platform Dispatcher 的错误（native 层回调异常）
    PlatformDispatcher.instance.onError = (error, stack) {
      AppLogger.error('PlatformError', '平台层未捕获异常', error, stack);
      return true; // 返回 true 表示已处理，不再向上抛
    };

    // 启动应用
    await _startApp(args);
  }, (error, stackTrace) {
    // 捕获 Zone 内所有未处理的异常（异步代码中的 throw）
    AppLogger.error('UncaughtError', '未捕获的异步异常', error, stackTrace);
  });
}

/// 应用启动逻辑
/// desktop_multi_window 0.3.0 使用统一的入口
/// 所有窗口（主窗口和子窗口）都通过 WindowController.fromCurrentEngine() 获取信息
Future<void> _startApp(List<String> args) async {
  // 初始化窗口管理器
  await windowManager.ensureInitialized();

  // 初始化日期格式化数据
  await initializeDateFormatting(null, null);

  // 🔧 desktop_multi_window 0.3.0 新 API
  // 从当前 Flutter 引擎获取窗口控制器，包含 windowId 和 arguments
  final windowController = await WindowController.fromCurrentEngine();
  final windowId = windowController.windowId;
  final rawArguments = windowController.arguments;

  AppLogger.info('MultiWindow', '窗口启动, windowId=$windowId, args=$rawArguments');

  // 解析参数
  Map<String, dynamic> argument = {};
  String windowType = WindowType.main;

  if (rawArguments.isNotEmpty) {
    try {
      argument = jsonDecode(rawArguments) as Map<String, dynamic>;
      windowType = argument['type'] as String? ?? WindowType.main;
    } catch (e) {
      AppLogger.error('MultiWindow', '解析窗口参数失败', e, null);
    }
  }

  // Log sanitized args to avoid flooding console with task lists
  final logArgs = Map<String, dynamic>.from(argument);
  logArgs.remove('active');
  logArgs.remove('completed');
  AppLogger.info('MultiWindow', '窗口类型=$windowType, 参数=$logArgs');

  // 根据窗口类型启动不同的 UI
  switch (windowType) {
    case WindowType.stickyNote:
      await _launchStickyNoteWindow(windowId, argument);
      break;

    case WindowType.settings:
      await _launchSettingsWindow(windowId);
      break;

    default:
      // 主窗口
      await _launchMainWindow();
  }
}

/// 启动便签窗口
Future<void> _launchStickyNoteWindow(
  String windowId,
  Map<String, dynamic> argument,
) async {
  // 配置便签窗口样式：隐藏标题栏，隐藏红绿灯按钮
  // 窗口大小: macOS 320x360, Windows 340x400
  final size =
      Platform.isMacOS ? const Size(320, 360) : const Size(340, 400);

  final windowOptions = WindowOptions(
    size: size,
    center: true,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false, // 隐藏红绿灯
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: StickyNotePage(windowId: windowId, args: argument),
    ),
  );
}

/// 启动设置窗口
Future<void> _launchSettingsWindow(String windowId) async {
  final windowOptions = WindowOptions(
    size: const Size(800, 600),
    center: true,
    titleBarStyle: TitleBarStyle.hidden,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(ProviderScope(child: SettingsApp(windowId: windowId)));
}

/// 启动主窗口
Future<void> _launchMainWindow() async {
  AppLogger.info('MultiWindow', '主窗口启动');
  StartupLogger.printInfo();

  // 读取用户的标题栏样式偏好（仅 Windows 有效）
  bool useNativeTitleBar = false;
  if (Platform.isWindows) {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('display_settings');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        useNativeTitleBar = json['useNativeTitleBar'] as bool? ?? false;
      }
    } catch (e) {
      AppLogger.error('Main', '读取标题栏设置失败', e, null);
    }
  }

  // 窗口配置：Windows 根据用户设置选择标题栏样式
  final windowOptions = WindowOptions(
    size: const Size(1080, 720),
    minimumSize: const Size(
      AmberDimens.minWindowWidth,
      AmberDimens.minWindowHeight,
    ),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    // Windows: 根据用户设置选择原生标题栏或隐藏标题栏
    // macOS/Linux: 始终隐藏标题栏
    titleBarStyle: (Platform.isWindows && useNativeTitleBar)
        ? TitleBarStyle.normal
        : TitleBarStyle.hidden,
    title: '琥珀清单',
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    if (Platform.isWindows && !useNativeTitleBar) {
      await windowManager.setHasShadow(false);
    }
  });

  runApp(
    const ProviderScope(
      child: AmberListApp(),
    ),
  );
}

/// 设置窗口 App
class SettingsApp extends StatelessWidget {
  const SettingsApp({super.key, required this.windowId});

  final String windowId;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '琥珀清单 - 设置',
      debugShowCheckedModeBanner: false,
      theme: AmberTheme.lightTheme,
      home: SettingsPage(windowId: windowId),
    );
  }
}