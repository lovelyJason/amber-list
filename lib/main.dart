import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/constants/dimensions.dart';
import 'core/services/logger_service.dart';
import 'core/theme/amber_theme.dart';
import 'core/utils/startup_logger.dart';
import 'presentation/pages/settings/settings_page.dart';
import 'presentation/pages/sticky_note/sticky_note_page.dart';

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

/// 应用启动逻辑（从原 main 中抽取）
Future<void> _startApp(List<String> args) async {
  // 初始化日志服务（应最先初始化）
  // 注意：已在 runZonedGuarded 内初始化，这里不需要重复

  // 🔧 检查是否是子窗口 - desktop_multi_window 的 args 格式：
  // args[0] = "multi_window"
  // args[1] = windowId (字符串格式的数字)
  // args[2] = arguments (JSON 字符串)
  if (args.isNotEmpty && args.first == 'multi_window') {
    final windowId = int.parse(args[1]);
    final argument = args.length > 2
        ? jsonDecode(args[2]) as Map<String, dynamic>
        : <String, dynamic>{};

    // Log sanitized args to avoid flooding console with task lists
    final logArgs = Map<String, dynamic>.from(argument);
    logArgs.remove('active');
    logArgs.remove('completed');
    AppLogger.info('MultiWindow', '子窗口启动，ID=$windowId, Args=$logArgs');

    // 初始化日期格式化
    await initializeDateFormatting(null, null);
    
    // 必须在子窗口也初始化 WindowManager
    await WindowManager.instance.ensureInitialized();
    
    // 根据 type 区分不同窗口
    if (argument['type'] == 'sticky_note') {
      // 配置便签窗口样式：隐藏标题栏，隐藏红绿灯按钮
      const windowOptions = WindowOptions(
        titleBarStyle: TitleBarStyle.hidden,
        windowButtonVisibility: false, // 关键：隐藏红绿灯
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
      );

      // 等待窗口准备好 (可选，但推荐)
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
    } else {
      // 默认是设置页 (或其他)
      runApp(ProviderScope(child: SettingsApp(windowId: windowId)));
    }
    return; // 子窗口到此结束
  }

  // 初始化日期格式化数据
  await initializeDateFormatting(null, null);

  // 主窗口模式
  AppLogger.info('MultiWindow', '主窗口启动');

  StartupLogger.printInfo();

  // 初始化窗口管理器（仅桌面端）
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();

    // 窗口配置
    const windowOptions = WindowOptions(
      size: Size(1080, 720),
      minimumSize: Size(
        AmberDimens.minWindowWidth,
        AmberDimens.minWindowHeight,
      ),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      title: '琥珀清单',
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
      if (Platform.isWindows) await windowManager.setHasShadow(false);
    });
  }

  runApp(
    const ProviderScope(
      child: AmberListApp(),
    ),
  );
}

class SettingsApp extends StatelessWidget {
  const SettingsApp({super.key, required this.windowId});

  final int windowId;

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
