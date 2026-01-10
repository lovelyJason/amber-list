import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'core/services/dock_service.dart';
import 'core/services/quick_add/quick_add_service.dart';
import 'core/services/splash_service.dart';
import 'core/theme/amber_theme.dart';
import 'data/models/note.dart';
import 'data/models/task.dart';
import 'presentation/pages/home_page.dart';
import 'presentation/pages/notes/notes_page.dart';
import 'presentation/providers/app_update_provider.dart';
import 'presentation/providers/providers.dart';
import 'presentation/providers/quick_add_settings_provider.dart';
import 'presentation/widgets/app_menu_bar.dart';
import 'presentation/widgets/app_update_dialog.dart';

/// 琥珀清单应用
class AmberListApp extends ConsumerStatefulWidget {
  const AmberListApp({super.key});

  @override
  ConsumerState<AmberListApp> createState() => _AmberListAppState();
}

class _AmberListAppState extends ConsumerState<AmberListApp>
    with WindowListener, TrayListener, WidgetsBindingObserver {
  /// 闪念胶囊服务
  QuickAddService? _quickAddService;

  @override
  void initState() {
    super.initState();
    debugPrint('[App] initState() called');

    // 添加生命周期监听（用于 App 回到前台时刷新数据）
    WidgetsBinding.instance.addObserver(this);

    // 桌面端添加窗口关闭监听（用于最小化到托盘功能）
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      windowManager.addListener(this);
      trayManager.addListener(this);
      // 开启关闭前拦截，允许我们在关闭前决定是否最小化到托盘
      windowManager.setPreventClose(true);
      // 初始化托盘图标
      _initTray();
    }

    // 延迟初始化，避免阻塞启动流程
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('[App] addPostFrameCallback triggered - first frame rendered');
      // 首帧渲染完成，隐藏原生 Splash 屏幕
      _hideSplash();
      _checkForUpdatesOnStartup();
      _initializeQuickAddService();
      // 执行自动顺延（将过期任务移动到今天）
      _performAutoPostpone();
    });
  }

  /// 初始化系统托盘
  ///
  /// 设置托盘图标、菜单，支持点击恢复窗口
  Future<void> _initTray() async {
    try {
      debugPrint('[App] 初始化托盘...');

      // 从 assets 提取图标到临时目录
      final iconPath = await _extractTrayIcon();
      if (iconPath != null) {
        await trayManager.setIcon(iconPath);
        debugPrint('[App] 托盘图标已设置: $iconPath');
      }

      // 设置托盘右键菜单
      final menu = Menu(
        items: [
          MenuItem(key: 'show_window', label: '显示琥珀清单'),
          MenuItem.separator(),
          MenuItem(key: 'exit_app', label: '退出'),
        ],
      );
      await trayManager.setContextMenu(menu);
      debugPrint('[App] 托盘菜单已设置');
    } catch (e) {
      debugPrint('[App] 初始化托盘失败: $e');
    }
  }

  /// 从 assets 提取托盘图标到临时目录
  ///
  /// tray_manager 需要文件路径，不能直接用 asset
  Future<String?> _extractTrayIcon() async {
    try {
      final byteData = await rootBundle.load('assets/images/logo_transparent.png');
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/amber_tray_icon.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      return file.path;
    } catch (e) {
      debugPrint('[App] 提取托盘图标失败: $e');
      return null;
    }
  }

  /// 托盘图标左键单击（TrayListener 回调）
  ///
  /// 显示并聚焦主窗口，同时恢复 Dock 显示（如果之前隐藏了）
  @override
  void onTrayIconMouseDown() {
    _showWindowFromTray();
  }

  /// 托盘图标右键单击（TrayListener 回调）
  ///
  /// 弹出右键菜单
  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  /// 托盘菜单项点击（TrayListener 回调）
  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show_window') {
      _showWindowFromTray();
    } else if (menuItem.key == 'exit_app') {
      _exitApp();
    }
  }

  /// 从托盘恢复窗口显示
  ///
  /// 显示并聚焦主窗口，同时恢复 Dock 显示（如果之前隐藏了）
  Future<void> _showWindowFromTray() async {
    // macOS: 先恢复 Dock 显示（如果之前隐藏了）
    if (Platform.isMacOS) {
      await DockService.showInDock();
    }
    // 显示并聚焦窗口
    await windowManager.show();
    await windowManager.focus();
    debugPrint('[App] 从托盘恢复窗口显示');
  }

  /// 退出应用
  Future<void> _exitApp() async {
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
    debugPrint('[App] 应用已退出');
  }

  /// 隐藏原生 Splash 屏幕
  ///
  /// 在 Flutter 首帧渲染后调用，触发 Splash 淡出动画
  /// Windows 平台额外延迟一小段时间，让用户能看到 Splash 效果
  Future<void> _hideSplash() async {
    debugPrint('[App] _hideSplash() called, platform: ${Platform.operatingSystem}');
    if (Platform.isMacOS || Platform.isWindows) {
      // Windows 启动较快，额外延迟让用户看到 Splash
      if (Platform.isWindows) {
        debugPrint(
          '[App] Windows platform - waiting 3s before hiding splash...',
        );
        await Future.delayed(const Duration(milliseconds: 3000));
      }
      debugPrint('[App] Calling SplashService.hideSplash()...');
      await SplashService.hideSplash();
      debugPrint('[App] 原生 Splash 已隐藏');
    } else {
      debugPrint('[App] Skipping splash hide - not macOS/Windows');
    }
  }

  @override
  void dispose() {
    // 移除生命周期监听
    WidgetsBinding.instance.removeObserver(this);
    // 桌面端移除窗口和托盘监听
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      windowManager.removeListener(this);
      trayManager.removeListener(this);
    }
    _quickAddService?.dispose();
    super.dispose();
  }

  /// App 生命周期变化回调（WidgetsBindingObserver）
  ///
  /// 当 App 从后台回到前台时，重新加载任务数据
  /// 这确保 Widget 上的修改能同步到 App 界面
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    debugPrint('[App] 生命周期变化: $state');

    if (state == AppLifecycleState.resumed) {
      // App 回到前台，重新从数据库加载任务数据
      // 这样 Widget 上的勾选操作就能同步到 App 界面
      debugPrint('[App] 回到前台，刷新任务数据...');
      ref.read(taskProvider.notifier).refresh();
    }
  }

  /// 窗口关闭事件处理（WindowListener 回调）
  ///
  /// 根据用户设置决定：
  /// - minimizeToTray = true: 隐藏窗口到托盘，应用继续在后台运行
  /// - minimizeToTray = false: 直接退出应用
  @override
  void onWindowClose() async {
    // 读取用户设置
    final displaySettings = ref.read(displaySettingsProvider);
    final minimizeToTray = displaySettings.minimizeToTray;
    final showInDockWhenMinimized = displaySettings.showInDockWhenMinimized;

    debugPrint('[App] onWindowClose: minimizeToTray=$minimizeToTray, showInDock=$showInDockWhenMinimized');

    if (minimizeToTray) {
      // 最小化到托盘：隐藏窗口，应用继续运行
      await windowManager.hide();
      debugPrint('[App] 窗口已隐藏到托盘');

      // macOS: 根据用户设置决定是否从 Dock 隐藏
      if (Platform.isMacOS && !showInDockWhenMinimized) {
        await DockService.hideFromDock();
        debugPrint('[App] 已从 Dock 隐藏');
      }
    } else {
      // 直接退出：先取消关闭拦截，再销毁窗口
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
      debugPrint('[App] 应用已退出');
    }
  }

  /// 初始化闪念胶囊服务（仅桌面端）
  Future<void> _initializeQuickAddService() async {
    if (!Platform.isMacOS && !Platform.isWindows) return;

    _quickAddService = ref.read(quickAddServiceProvider);

    // 设置任务创建回调
    _quickAddService!.onTaskCreated = (title, dueDate, priority, tags, listId) {
      // 播放添加音效
      ref.read(soundServiceProvider).playAdd();
      // 创建任务（包含标签）
      ref.read(taskProvider.notifier).createTask(
            title: title,
            dueDate: dueDate,
            priority: TaskPriority.fromValue(priority),
            listId: listId,
            tags: tags,
          );
      // 注意：清单选择已在 onListSelected 回调中实时持久化，无需在此重复保存
      debugPrint(
          '[App] 闪念胶囊创建任务: $title, 优先级: $priority, 标签: $tags, 列表: $listId');
    };

    // 设置笔记创建回调
    _quickAddService!.onNoteCreated = (content, tags) {
      // 播放添加音效
      ref.read(soundServiceProvider).playAdd();
      // 创建笔记
      final now = DateTime.now();
      final newNote = Note(
        id: now.millisecondsSinceEpoch.toString(),
        title: content.length > 20 ? '${content.substring(0, 20)}...' : content,
        content: content,
        tags: tags,
        createdAt: now,
        updatedAt: now,
      );
      ref.read(notesProvider.notifier).addNote(newNote);
      debugPrint('[App] 闪念胶囊创建笔记: $content, 标签: $tags');
    };

    // 设置日期选择器回调（TODO: 后续实现原生日期选择器）
    _quickAddService!.onDatePickerRequested = (currentDate, onDateSelected) {
      // 暂时直接使用当前日期，后续可以弹出 Flutter 日期选择器
      debugPrint('[App] 日期选择器请求: $currentDate');
      // onDateSelected(currentDate);
    };

    // 设置清单选中回调（立即持久化清单选择偏好）
    _quickAddService!.onListSelected = (listId) {
      // 立即保存到 SharedPreferences
      ref.read(quickAddSettingsProvider.notifier).setLastSelectedListId(listId);
      debugPrint('[App] 闪念胶囊清单选中: ${listId ?? "收集箱"}');
    };

    // 设置热键触发回调，获取最新数据后显示窗口
    _quickAddService!.onHotKeyTriggered = _showQuickAddWithData;

    // 等待快捷键设置加载完成（从 SharedPreferences 异步加载）
    final quickAddSettings =
        await ref.read(quickAddSettingsProvider.notifier).waitForLoad();
    final customHotKey = quickAddSettings.toHotKey();

    // 初始化服务（使用用户配置的快捷键）
    await _quickAddService!.initialize(customHotKey: customHotKey);
    debugPrint('[App] 闪念胶囊服务已初始化，快捷键: ${quickAddSettings.displayText}');
  }

  /// 显示闪念胶囊窗口（带数据）
  void _showQuickAddWithData() {
    if (_quickAddService == null) return;

    // 获取标签列表
    final tags = ref.read(tagsProvider);
    final tagNames = tags.map((t) => t.name).toList();

    // 获取任务列表
    final taskLists = ref.read(taskListProvider);
    final taskListData = taskLists
        .where((l) => !l.isFolder) // 排除文件夹
        .map((l) => {'id': l.id, 'name': l.name})
        .toList();

    // 获取上次选中的清单 ID（用于展开模式默认选中）
    final quickAddSettings = ref.read(quickAddSettingsProvider);
    final lastSelectedListId = quickAddSettings.lastSelectedListId;

    _quickAddService!.showQuickAdd(
      tags: tagNames,
      taskLists: taskListData,
      selectedListId: lastSelectedListId,
    );
  }

  /// 执行自动顺延
  ///
  /// 在 App 启动时调用，将符合条件的过期任务自动顺延到今天
  /// 条件：autoPostpone=true AND 已过期 AND 全局开关开启
  Future<void> _performAutoPostpone() async {
    // 等待 TaskManagementSettings 加载完成（确保读取到用户的真实设置）
    await ref.read(taskManagementSettingsProvider.notifier).waitForLoad();

    // 稍微延迟，确保 TaskNotifier 已经从数据库加载完数据
    await Future.delayed(const Duration(milliseconds: 300));

    final count = await ref.read(taskProvider.notifier).performAutoPostpone();
    if (count > 0) {
      debugPrint('[App] 自动顺延完成，已顺延 $count 个任务到今天');
    }
  }

  /// 应用启动时自动检查更新
  Future<void> _checkForUpdatesOnStartup() async {
    // 静默检查更新，不显示对话框（除非是强制更新）
    final result = await ref.read(appUpdateProvider.notifier).checkForUpdates(
          showDialogOnForce: true,
        );

    // 如果需要强制更新，且用户没有关闭对话框，则显示强制更新页面
    // 这里的逻辑是：检查完成后，如果是强制更新，Provider 会设置 showForceUpdateDialog = true
    // 下面的 build 方法会监听这个状态并显示强制更新页面
    if (result.isForceUpdate && mounted) {
      debugPrint('[App] 检测到强制更新要求');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 监听更新状态
    final updateState = ref.watch(appUpdateProvider);

    return MaterialApp(
      title: '琥珀清单',
      debugShowCheckedModeBanner: false,
      theme: AmberTheme.lightTheme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'), // 中文简体
      ],
      locale: const Locale('zh', 'CN'), // 强制使用中文
      // 如果需要强制更新，显示强制更新页面，否则显示正常主页
      home: updateState.showForceUpdateDialog &&
              updateState.lastCheckResult != null &&
              updateState.isForceUpdate
          ? ForceUpdateScreen(result: updateState.lastCheckResult!)
          : const AmberMenuBar(child: HomePage()),
    );
  }
}
