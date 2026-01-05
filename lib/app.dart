import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/services/quick_add/quick_add_service.dart';
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

class _AmberListAppState extends ConsumerState<AmberListApp> {
  /// 闪念胶囊服务
  QuickAddService? _quickAddService;

  @override
  void initState() {
    super.initState();
    // 延迟初始化，避免阻塞启动流程
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdatesOnStartup();
      _initializeQuickAddService();
    });
  }

  @override
  void dispose() {
    _quickAddService?.dispose();
    super.dispose();
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

    // 设置热键触发回调，获取最新数据后显示窗口
    _quickAddService!.onHotKeyTriggered = _showQuickAddWithData;

    // 读取用户保存的快捷键设置
    final quickAddSettings = ref.read(quickAddSettingsProvider);
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

    _quickAddService!.showQuickAdd(
      tags: tagNames,
      taskLists: taskListData,
    );
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
