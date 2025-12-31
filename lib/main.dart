import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io'; // Import dart:io
import 'app.dart';
import 'core/constants/dimensions.dart';

import 'presentation/pages/settings/settings_page.dart';
import 'core/theme/amber_theme.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'dart:convert';
import 'presentation/pages/sticky_note/sticky_note_page.dart';
import 'core/utils/startup_logger.dart'; // Add Logger import

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

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
    debugPrint('[MultiWindow] 子窗口启动，ID=$windowId, Args=$logArgs');

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
  debugPrint('[MultiWindow] 主窗口启动');

  StartupLogger.printInfo();

  // 初始化窗口管理器（仅主窗口）
  await windowManager.ensureInitialized();

  // 窗口配置
  const windowOptions = WindowOptions(
    size: Size(1080, 720),
    minimumSize: Size(AmberDimens.minWindowWidth, AmberDimens.minWindowHeight),
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
