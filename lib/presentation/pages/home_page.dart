import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/constants.dart';
import '../../core/utils/responsive_helper.dart';
import '../widgets/common/toast/toast_manager.dart';
import '../../data/models/models.dart';
import '../providers/providers.dart';
import '../providers/native_sticky_note_provider.dart';
import '../widgets/widgets.dart';
import '../widgets/adaptive/bottom_nav_bar.dart';
import '../widgets/adaptive/drawer_list_sidebar.dart';
import 'calendar/calendar_page.dart';
import 'notes/notes_page.dart';
import 'pomodoro/pomodoro_page.dart';
import 'settings/settings_page.dart';
import '../pages/sticky_note/sticky_note_registry.dart';
import '../pages/sticky_note/sticky_note_page.dart';
import '../pages/statistics/statistics_page.dart';
import '../widgets/debug/debug_toolbox.dart';
import '../widgets/common/kept_alive_wrapper.dart';

/// 主页面
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  /// SharedPreferences key 用于存储调试按钮位置（JSON 格式：{"x": 16, "y": 16}）
  static const _kDebugButtonPosition = 'debug_button_position';

  /// Debug 按钮的位置（相对于屏幕右下角的偏移量）
  /// 初始值为 (16, 16)，表示距离右下角 16px
  Offset _debugButtonOffset = const Offset(16, 16);

  /// 便签事件通道（便签 -> 主窗口）
  /// 用于接收便签窗口发来的关闭通知、任务切换等事件
  /// 仅桌面端使用，移动端为 null
  WindowMethodChannel? _stickyNoteEventChannel;

  /// PageView 控制器，用于切换页面时保持状态
  /// 与 AutomaticKeepAliveClientMixin 配合，避免页面切换时重建 Widget
  late final PageController _pageController;

  /// 需要保持状态的 NavView 列表
  /// 注意：NavView.list 不在此列表中，因为它依赖 selectedListId，每次都不同
  static const List<NavView> _keepAliveViews = [
    NavView.inbox,
    NavView.today,
    NavView.upcoming,
    NavView.all,
    NavView.calendar,
    NavView.notes,
    NavView.pomodoro,
    NavView.completed,
    NavView.trash,
    NavView.statistics,
  ];

  /// NavView 到 PageView index 的映射
  /// 用于在导航状态变化时，将 NavView 转换为 PageView 的页面索引
  int _navViewToPageIndex(NavView view) {
    final index = _keepAliveViews.indexOf(view);
    return index >= 0 ? index : 0; // 如果是 list 等不在列表中的，返回 0
  }

  @override
  void initState() {
    super.initState();

    // 初始化 PageController，默认显示 today 页面
    // 注意：initialPage 必须与 AppNavState.currentView 的默认值（NavView.today）对应
    // NavView.today 在 _keepAliveViews 中的 index 是 1
    _pageController = PageController(initialPage: 1);

    // 加载调试按钮的缓存位置（仅 Debug 模式）
    if (kDebugMode) {
      _loadDebugButtonPosition();
    }

    // 桌面端：初始化便签事件通道（单向模式：主窗口注册处理器，所有便签都可以发送消息）
    // 移动端不支持 desktop_multi_window，跳过
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      _stickyNoteEventChannel = const WindowMethodChannel(
        StickyNoteChannel.events,
        mode: ChannelMode.unidirectional,
      );

      // 注册便签事件处理器
      _registerStickyNoteEventHandler();
    }
  }

  /// 从 SharedPreferences 加载调试按钮位置
  Future<void> _loadDebugButtonPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_kDebugButtonPosition);
    if (jsonStr != null) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        final x = (map['x'] as num?)?.toDouble();
        final y = (map['y'] as num?)?.toDouble();
        if (x != null && y != null) {
          setState(() {
            _debugButtonOffset = Offset(x, y);
          });
        }
      } catch (_) {
        // JSON 解析失败，使用默认位置
      }
    }
  }

  /// 保存调试按钮位置到 SharedPreferences
  Future<void> _saveDebugButtonPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode({
      'x': _debugButtonOffset.dx,
      'y': _debugButtonOffset.dy,
    });
    await prefs.setString(_kDebugButtonPosition, jsonStr);
  }

  /// 注册便签事件处理器
  /// 接收来自便签窗口的消息（关闭通知、任务切换等）
  Future<void> _registerStickyNoteEventHandler() async {
    await _stickyNoteEventChannel?.setMethodCallHandler((call) async {
      debugPrint('[Main Window] 收到便签事件: ${call.method}');

      if (call.method == 'toggleTask') {
        final taskId = call.arguments as String;
        ref.read(taskProvider.notifier).toggleTaskComplete(taskId);
        return 'ok';
      } else if (call.method == 'stickyNoteClosed') {
        final contentId = call.arguments as String;
        debugPrint('[Main Window] 便签窗口已关闭，取消注册: $contentId');
        // 只需从注册表中移除，窗口自己已经关闭了
        ref.read(stickyNoteRegistryProvider.notifier).unregister(contentId);
        return 'ok';
      }
      return null;
    });
  }

  @override
  void dispose() {
    // 移除事件处理器（桌面端）
    _stickyNoteEventChannel?.setMethodCallHandler(null);
    // 释放 PageController
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 初始化原生便签服务（设置回调）
    // 使用 watch 确保服务在整个生命周期内保持活跃
    // 仅在桌面端初始化（移动端不支持多窗口）
    if (ResponsiveHelper.isDesktopOS()) {
      ref.watch(nativeStickyNoteProvider);
    }

    // 监听导航状态变化，同步更新 PageView
    // 只有当 currentView 是 _keepAliveViews 中的视图时才跳转页面
    ref.listen<AppNavState>(appNavProvider, (previous, next) {
      if (previous?.currentView != next.currentView) {
        final targetIndex = _navViewToPageIndex(next.currentView);
        // 只有目标是 keepAlive 页面时才跳转
        if (_keepAliveViews.contains(next.currentView)) {
          // 使用 addPostFrameCallback 确保在当前帧渲染完成后再跳转
          // 避免在 Widget 树更新过程中调用 jumpToPage 导致状态不一致
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_pageController.hasClients) {
              _pageController.jumpToPage(targetIndex);
            }
          });
        }
      }
    });

    // ref is available in build
    final navState = ref.watch(appNavProvider);
    final tasks = ref.watch(taskProvider);

    // 使用 LayoutBuilder 监听屏幕宽度变化，实现响应式布局
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < ResponsiveHelper.mobileBreakpoint;

        if (isMobile) {
          // 移动端布局：底部导航栏 + 抽屉
          return _buildMobileLayout(context, navState, tasks);
        } else {
          // 桌面端布局：保持原有 Row 布局
          return _buildDesktopLayout(context, navState, tasks);
        }
      },
    );
  }

  /// 构建桌面端布局（原有布局，完全保持不变）
  Widget _buildDesktopLayout(
      BuildContext context, AppNavState navState, List<Task> tasks) {
    // 日历、笔记、番茄时钟、统计页面使用全屏布局
    final isFullScreenView = navState.currentView == NavView.calendar ||
        navState.currentView == NavView.notes ||
        navState.currentView == NavView.pomodoro ||
        navState.currentView == NavView.statistics;

    return Scaffold(
      body: Stack(
        children: [
          // 主体内容区域
          Row(
            children: [
              // 窄侧边栏
              const NarrowSidebar(),
              // 分割线
              const VerticalDivider(width: 1, thickness: 1),
              // 清单侧边栏（日历和笔记页面隐藏，且受 toggle 控制）
              if (!isFullScreenView && navState.isListSidebarOpen) ...[
                const ListSidebar(),
                const VerticalDivider(width: 1, thickness: 1),
              ],
              // 主内容区
              Expanded(
                child: _buildMainContent(ref, navState, tasks, isMobile: false),
              ),
              // 详情面板（日历和笔记页面自带详情面板）
              if (!isFullScreenView &&
                  navState.isDetailPanelOpen &&
                  navState.selectedTaskId != null)
                _buildDetailPanel(ref, tasks, navState.selectedTaskId!),
            ],
          ),
          // 可拖拽的 Debug 调试按钮（仅在调试模式显示）
          if (kDebugMode)
            Positioned(
              right: _debugButtonOffset.dx,
              bottom: _debugButtonOffset.dy,
              child: GestureDetector(
                // 拖拽更新位置
                onPanUpdate: (details) {
                  setState(() {
                    // 注意：向右拖拽时 delta.dx 为正，但 right 定位需要减小
                    // 向下拖拽时 delta.dy 为正，但 bottom 定位需要减小
                    _debugButtonOffset = Offset(
                      (_debugButtonOffset.dx - details.delta.dx).clamp(0, MediaQuery.of(context).size.width - 72),
                      (_debugButtonOffset.dy - details.delta.dy).clamp(0, MediaQuery.of(context).size.height - 72),
                    );
                  });
                },
                // 拖拽结束时保存位置到 SharedPreferences
                onPanEnd: (_) => _saveDebugButtonPosition(),
                child: FloatingActionButton(
                  tooltip: '调试工具箱（可拖拽）',
                  elevation: 4,
                  highlightElevation: 8,
                  backgroundColor: AmberColors.primary,
                  child: const Icon(Icons.bug_report, color: Colors.white),
                  onPressed: () => showDebugToolbox(context, ref),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 构建移动端布局（底部导航栏 + 抽屉）
  ///
  /// 设计说明：
  /// - 日历、笔记、番茄钟、统计页面有自己的完整 Scaffold（含 AppBar 和 BottomNavigationBar）
  /// - 任务列表页面（清单、今天等）使用 HomePage 的 Scaffold 容器
  /// - 这样避免嵌套 Scaffold 导致双重底部导航栏的问题
  Widget _buildMobileLayout(BuildContext context, AppNavState navState, List<Task> tasks) {
    // 日历、笔记、番茄钟、统计页面自带完整的 Scaffold（含 AppBar 和 BottomNavigationBar）
    // 直接返回它们，不再套 HomePage 的 Scaffold，避免双重底部导航栏
    final isFullScreenView = navState.currentView == NavView.calendar ||
        navState.currentView == NavView.notes ||
        navState.currentView == NavView.pomodoro ||
        navState.currentView == NavView.statistics;

    if (isFullScreenView) {
      // 这些页面自己有 Scaffold，直接返回对应的页面组件
      switch (navState.currentView) {
        case NavView.calendar:
          return const CalendarPage();
        case NavView.notes:
          return const NotesPage();
        case NavView.pomodoro:
          return const PomodoroPage();
        case NavView.statistics:
          return const StatisticsPage();
        default:
          break;
      }
    }

    // 任务列表页面使用 HomePage 的 Scaffold 容器
    return Scaffold(
      // 移动端顶部 AppBar
      appBar: AppBar(
        title: Text(
          _getViewTitle(navState.currentView),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AmberColors.textPrimary,
          ),
        ),
        backgroundColor: AmberColors.cardBackground,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: AmberColors.textPrimary),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: '打开清单列表',
          ),
        ),
        actions: [
          // 移动端同步按钮
          _buildMobileSyncButton(ref),
          // 筛选排序按钮
          const FilterSortButtons(compact: true),
          // 设置按钮
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AmberColors.textSecondary),
            onPressed: () => _openSettings(context),
            tooltip: '设置',
          ),
        ],
      ),
      // 左侧抽屉（清单列表）
      drawer: const DrawerListSidebar(),
      // 主内容区
      body: _buildMainContent(ref, navState, tasks, isMobile: true),
      // 底部导航栏
      bottomNavigationBar: const MobileBottomNavBar(),
      // 移动端调试按钮（仅在调试模式显示）
      floatingActionButton: kDebugMode
          ? FloatingActionButton.small(
              tooltip: '调试工具箱',
              backgroundColor: AmberColors.primary,
              child: const Icon(Icons.bug_report, color: Colors.white, size: 20),
              onPressed: () => showDebugToolbox(context, ref),
            )
          : null,
    );
  }

  /// 获取移动端同步按钮（独立组件，避免影响父组件 rebuild）
  Widget _buildMobileSyncButton(WidgetRef ref) {
    return const _MobileSyncButton();
  }

  /// 获取当前视图的标题（用于移动端 AppBar）
  String _getViewTitle(NavView view) {
    switch (view) {
      case NavView.inbox:
        return '收集箱';
      case NavView.today:
        return '今天';
      case NavView.upcoming:
        return '最近7天';
      case NavView.calendar:
        return '日历';
      case NavView.notes:
        return '笔记';
      case NavView.pomodoro:
        return '番茄钟';
      case NavView.list:
        return '清单';
      case NavView.completed:
        return '已完成';
      case NavView.trash:
        return '垃圾桶';
      case NavView.all:
        return '全部';
      case NavView.statistics:
        return '统计';
    }
  }

  /// 打开设置页面（移动端）
  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SettingsPage(windowId: null),
      ),
    );
  }

  /// 构建主内容区（使用 PageView + KeptAliveWrapper 保持页面状态）
  ///
  /// 设计说明：
  /// - 使用 PageView 包裹所有需要保持状态的页面（_keepAliveViews 中定义）
  /// - 每个页面用 KeptAliveWrapper 包裹，配合 AutomaticKeepAliveClientMixin 保持状态
  /// - NavView.list 因为依赖 selectedListId，每次都是新内容，所以单独用条件渲染
  /// - PageView 禁用滑动手势，只通过 _pageController 程序化切换
  ///
  /// [isMobile] 是否为移动端，移动端会隐藏 TaskListView 的 header
  Widget _buildMainContent(
    WidgetRef ref,
    AppNavState navState,
    List<Task> tasks, {
    bool isMobile = false,
  }) {
    // NavView.list 使用条件渲染（因为依赖 selectedListId，每次内容不同）
    if (navState.currentView == NavView.list) {
      if (navState.selectedListId != null) {
        final listTasks = ref.watch(tasksByListProvider(navState.selectedListId!));
        final taskLists = ref.watch(taskListProvider);
        final currentList = taskLists.where((l) => l.id == navState.selectedListId).firstOrNull;
        return TaskListView(
          title: currentList?.name ?? '清单',
          tasks: listTasks,
          listId: navState.selectedListId,
          showHeader: !isMobile,
        );
      }
      return const Center(child: Text('请选择清单'));
    }

    // 其他页面使用 PageView + KeptAliveWrapper 保持状态
    // PageView 会保持所有子页面的状态，切换时不会销毁和重建
    return PageView(
      controller: _pageController,
      physics: const NeverScrollableScrollPhysics(), // 禁用滑动手势，只通过 controller 切换
      children: _keepAliveViews.map((view) {
        return KeptAliveWrapper(
          child: _buildPageForView(ref, view, tasks, isMobile: isMobile),
        );
      }).toList(),
    );
  }

  /// 根据 NavView 构建对应的页面 Widget
  ///
  /// 此方法只被 PageView 的 children 调用，每个页面只会构建一次
  /// KeptAliveWrapper 会保持这些页面的状态，切换时不会重建
  Widget _buildPageForView(
    WidgetRef ref,
    NavView view,
    List<Task> tasks, {
    bool isMobile = false,
  }) {
    switch (view) {
      case NavView.inbox:
        // Inbox 显示所有任务（不含已删除）
        final allTasks = tasks.where((t) => !t.isDeleted).toList();
        return TaskListView(
          title: '收集箱',
          tasks: allTasks,
          showDatePicker: true,
          showHeader: !isMobile,
        );
      case NavView.today:
        // 今天视图使用专门的 TodayView 组件，包含过期任务区域
        return TodayView(
          showHeader: !isMobile,
        );
      case NavView.upcoming:
        final upcomingTasks = ref.watch(upcomingTasksProvider);
        return TaskListView(
          title: '最近7天',
          tasks: upcomingTasks,
          showInput: false,
          showHeader: !isMobile,
        );
      case NavView.all:
        // 显示所有任务（包括已完成），但不包括已删除
        final allTasks = tasks.where((t) => !t.isDeleted).toList();
        return TaskListView(
          title: '全部',
          tasks: allTasks,
          showHeader: !isMobile,
        );
      case NavView.calendar:
        return const CalendarPage();
      case NavView.notes:
        return const NotesPage();
      case NavView.pomodoro:
        return const PomodoroPage();
      case NavView.statistics:
        return const StatisticsPage();
      case NavView.completed:
        // 已完成页面使用专门的 CompletedTasksView 组件
        // 提供按完成日期筛选和按完成时间排序功能
        return CompletedTasksView(
          showHeader: !isMobile,
        );
      case NavView.trash:
        final trashTasks = ref.watch(trashTasksProvider);
        return TaskListView(
          title: '垃圾桶',
          tasks: trashTasks,
          showInput: false,
          groupCompleted: false,
          showHeader: !isMobile,
          showFilterSort: false, // 垃圾桶页面不需要筛选排序
          isTrash: true, // 标记为垃圾桶视图，显示清空按钮
        );
      case NavView.list:
        // list 视图在 _buildMainContent 中单独处理，这里不应该被调用
        // 但为了类型安全，返回一个占位 Widget
        return const Center(child: Text('请选择清单'));
    }
  }

  Widget _buildDetailPanel(WidgetRef ref, List<Task> tasks, String taskId) {
    final task = tasks.where((t) => t.id == taskId).firstOrNull;
    if (task == null) return const SizedBox.shrink();

    return Row(
      children: [
        const VerticalDivider(width: 1, thickness: 1),
        TaskDetailPanel(task: task),
      ],
    );
  }
}

/// 移动端同步按钮（独立组件）
///
/// 抽离成独立 ConsumerWidget，避免 syncStateProvider/syncTypeProvider 的变化
/// 触发整个 HomePage rebuild，导致启动时列表抖动
class _MobileSyncButton extends ConsumerWidget {
  const _MobileSyncButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听同步状态和配置（仅影响本组件 rebuild）
    final syncState = ref.watch(syncStateProvider);
    final syncType = ref.watch(syncTypeProvider);

    // 未配置同步则隐藏（syncType 为 null 表示未选择任何同步方式）
    if (syncType == null) {
      return const SizedBox.shrink();
    }

    if (syncState.isSyncing) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        width: 24,
        height: 24,
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                AmberColors.textSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return IconButton(
      icon: const Icon(
        FluentIcons.arrow_sync_24_regular,
        color: AmberColors.textSecondary,
      ),
      tooltip: '立即同步',
      onPressed: () => _onSyncPressed(context, ref),
    );
  }

  /// 同步按钮点击处理
  Future<void> _onSyncPressed(BuildContext context, WidgetRef ref) async {
    // 设置冲突决策回调（在同步过程中弹窗让用户选择）
    ref.read(syncStateProvider.notifier).onConflictDetected = (
      conflicts, {
      int autoPostponeMergedCount = 0,
    }) async {
      if (!context.mounted) return null;
      // 弹出冲突决策弹窗
      return showSyncConflictDialog(
        context,
        conflicts: conflicts,
        autoPostponeMergedCount: autoPostponeMergedCount,
      );
    };

    // 设置首次同步冲突回调（检测到双端都有数据时弹窗）
    ref.read(syncStateProvider.notifier).onFirstSyncConflict = (conflict) async {
      if (!context.mounted) return null;
      // 弹出首次同步冲突弹窗
      return showFirstSyncConflictDialog(
        context,
        localTaskCount: conflict.localTaskCount,
        remoteVersion: conflict.remoteVersion,
        remoteDevice: conflict.remoteDevice,
        remoteLastSync: conflict.remoteLastSync,
      );
    };

    final success = await ref.read(syncStateProvider.notifier).manualSync();
    if (success) {
      ref.read(soundServiceProvider).playSuccess();
    } else if (context.mounted) {
      // 同步失败，检查错误信息并提示
      final syncState = ref.read(syncStateProvider);
      final errorMsg = syncState.lastError ?? '同步失败';

      // 针对 429 错误特殊处理
      if (errorMsg.contains('429')) {
        ToastManager().show(
          context,
          '请求太频繁，请稍后再试',
          type: ToastType.warning,
        );
      } else {
        ToastManager().show(
          context,
          errorMsg,
          type: ToastType.error,
        );
      }
    }
  }
}
