import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../../core/constants/constants.dart';
import '../../core/utils/responsive_helper.dart';
import '../widgets/common/toast/toast_manager.dart';
import '../widgets/common/toast/toast_types.dart';
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
import '../widgets/debug/sticky_note_debugger.dart';
import '../widgets/debug/prefs_editor.dart';
import '../../core/services/splash_service.dart';

/// 主页面
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  /// Debug 按钮的位置（相对于屏幕右下角的偏移量）
  /// 初始值为 (16, 16)，表示距离右下角 16px
  Offset _debugButtonOffset = const Offset(16, 16);

  /// 便签事件通道（便签 -> 主窗口）
  /// 用于接收便签窗口发来的关闭通知、任务切换等事件
  late final WindowMethodChannel _stickyNoteEventChannel;

  @override
  void initState() {
    super.initState();

    // 初始化便签事件通道（单向模式：主窗口注册处理器，所有便签都可以发送消息）
    _stickyNoteEventChannel = const WindowMethodChannel(
      StickyNoteChannel.events,
      mode: ChannelMode.unidirectional,
    );

    // 注册便签事件处理器
    _registerStickyNoteEventHandler();
  }

  /// 注册便签事件处理器
  /// 接收来自便签窗口的消息（关闭通知、任务切换等）
  Future<void> _registerStickyNoteEventHandler() async {
    await _stickyNoteEventChannel.setMethodCallHandler((call) async {
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
    // 移除事件处理器
    _stickyNoteEventChannel.setMethodCallHandler(null);
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
    // 日历、笔记、番茄时钟页面使用全屏布局
    final isFullScreenView = navState.currentView == NavView.calendar ||
        navState.currentView == NavView.notes ||
        navState.currentView == NavView.pomodoro;

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
                child: FloatingActionButton(
                  tooltip: '调试工具箱（可拖拽）',
                  elevation: 4,
                  highlightElevation: 8,
                  backgroundColor: AmberColors.primary,
                  child: const Icon(Icons.bug_report, color: Colors.white),
                  onPressed: () => _showDebugToolbox(context),
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
  /// - 日历、笔记、番茄钟页面有自己的完整 Scaffold（含 AppBar 和 BottomNavigationBar）
  /// - 任务列表页面（清单、今天等）使用 HomePage 的 Scaffold 容器
  /// - 这样避免嵌套 Scaffold 导致双重底部导航栏的问题
  Widget _buildMobileLayout(BuildContext context, AppNavState navState, List<Task> tasks) {
    // 日历、笔记、番茄钟页面有自己的完整布局（含 Scaffold 和 BottomNavigationBar）
    // 直接返回它们，不再套 HomePage 的 Scaffold
    final isFullScreenView = navState.currentView == NavView.calendar ||
        navState.currentView == NavView.notes ||
        navState.currentView == NavView.pomodoro;

    if (isFullScreenView) {
      return _buildMainContent(ref, navState, tasks, isMobile: true);
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
              onPressed: () => _showDebugToolbox(context),
            )
          : null,
    );
  }

  /// 构建移动端同步按钮
  Widget _buildMobileSyncButton(WidgetRef ref) {
    // 监听同步状态和配置
    final syncState = ref.watch(syncStateProvider);
    final isConfigured =
        ref.watch(syncConfigProvider) != null ||
        ref.watch(qiniuConfigProvider) != null;

    // 未配置同步则隐藏
    if (!isConfigured) {
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
      onPressed: () async {
        // 设置冲突决策回调（在同步过程中弹窗让用户选择）
        ref.read(syncStateProvider.notifier).onConflictDetected = (conflicts) async {
          if (!mounted) return null;
          // 弹出冲突决策弹窗
          return showSyncConflictDialog(context, conflicts: conflicts);
        };

        final success = await ref.read(syncStateProvider.notifier).manualSync();
        if (success) {
          ref.read(soundServiceProvider).playSuccess();
        }
      },
    );
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

  /// 显示 Debug 调试工具箱弹窗
  void _showDebugToolbox(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AmberColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.build_circle,
                        color: AmberColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      '调试工具箱',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AmberColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close,
                        size: 20,
                        color: AmberColors.textSecondary,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: AmberColors.sidebarBackground,
                        padding: const EdgeInsets.all(8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildDebugOption(
                  context,
                  icon: Icons.sticky_note_2_rounded,
                  label: '便签注册表监控',
                  description: '查看便签窗口状态与进程',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (context) => const Dialog(
                        backgroundColor: Colors.transparent,
                        child: StickyNoteDebugger(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildDebugOption(
                  context,
                  icon: Icons.settings_applications_rounded,
                  label: 'SharedPreferences Editor',
                  description: '查看和修改本地配置 (Prefs)',
                  color: Colors.blueGrey,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PrefsEditor()),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildDebugOption(
                  context,
                  icon: Icons.screen_lock_portrait_rounded,
                  label: 'Splash 屏幕预览',
                  description: '显示启动 Splash 屏幕 3 秒',
                  color: Colors.amber,
                  onTap: () async {
                    Navigator.pop(context);
                    // 调用 SplashService 显示 Splash
                    await SplashService.showSplash(duration: 3000);
                  },
                ),
                const SizedBox(height: 12),
                _buildDebugOption(
                  context,
                  icon: Icons.restore_page,
                  label: '重置本地数据',
                  description: '清空所有数据并恢复初始状态',
                  color: Colors.red,
                  onTap: () async {
                    // Double check dialog
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('确认重置？'),
                        content: const Text(
                          '此操作将永久删除所有本地数据，\n不仅限于任务，还包括笔记和统计。\n\n此操作无法撤销。',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('确认重置'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      Navigator.pop(context);
                      await ref.read(databaseProvider).resetDatabase();
                      // 重新同步标签（因 resetDatabase 不会重置 Tags 表，但 Tasks 表已重置并包含 JSON 标签）
                      await ref.read(tagsProvider.notifier).syncTags();

                      if (context.mounted) {
                        ToastManager().show(
                          context,
                          '数据已重置',
                          type: ToastType.success,
                          position: ToastPosition.top,
                        );
                      }
                    }
                  },
                ),
                const SizedBox(height: 12),
                _buildDebugOption(
                  context,
                  icon: Icons.vpn_key_rounded,
                  label: '生成激活码',
                  description: '生成应用激活码（仅生成）',
                  color: Colors.purple,
                  onTap: () {
                    Navigator.pop(context);
                    _showActivationCodeGenerator(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 生成激活码
  /// 格式：AMBER-XXXXX-XXXXX-XXXXX（琥珀前缀 + 15位随机码）
  String _generateActivationCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // 去掉容易混淆的字符 I/1, O/0
    final random = DateTime.now().millisecondsSinceEpoch;
    final buffer = StringBuffer('AMBER-');

    for (var i = 0; i < 3; i++) {
      if (i > 0) buffer.write('-');
      for (var j = 0; j < 5; j++) {
        final index = (random ~/ (i * 5 + j + 1) + DateTime.now().microsecondsSinceEpoch + i * j) % chars.length;
        buffer.write(chars[index]);
      }
    }

    return buffer.toString();
  }

  /// 显示激活码生成器弹窗
  void _showActivationCodeGenerator(BuildContext context) {
    String code = _generateActivationCode();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(24),
              child: Container(
                width: 360,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 头部图标
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.purple.shade400,
                            Colors.purple.shade600,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.vpn_key_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '激活码生成器',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AmberColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '点击刷新按钮生成新的激活码',
                      style: TextStyle(
                        fontSize: 13,
                        color: AmberColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // 激活码展示区
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 20,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.purple.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: SelectableText(
                        code,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                          fontFamily: 'monospace',
                          color: Colors.purple.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // 操作按钮
                    Row(
                      children: [
                        // 刷新按钮
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                code = _generateActivationCode();
                              });
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('刷新'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.purple,
                              side: BorderSide(color: Colors.purple.shade300),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // 复制按钮
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: code));
                              ToastManager().show(
                                context,
                                '激活码已复制',
                                type: ToastType.success,
                              );
                            },
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            label: const Text('复制'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 关闭按钮
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('关闭'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 构建主内容区
  /// [isMobile] 是否为移动端，移动端会隐藏 TaskListView 的 header
  Widget _buildMainContent(
    WidgetRef ref,
    AppNavState navState,
    List<Task> tasks, {
    bool isMobile = false,
  }) {
    switch (navState.currentView) {
      case NavView.all:
        // 显示所有任务（包括已完成），但不包括已删除
        final allTasks = tasks.where((t) => !t.isDeleted).toList();
        return TaskListView(
          title: '全部',
          tasks: allTasks,
          showHeader: !isMobile,
        );
      case NavView.inbox:
        // Inbox now shows ALL tasks as per user request (excluding deleted)
        final allTasks = tasks.where((t) => !t.isDeleted).toList();
        return TaskListView(
          title: '收集箱',
          tasks: allTasks,
          showDatePicker: true,
          showHeader: !isMobile,
        );
      case NavView.today:
        final todayTasks = ref.watch(todayTasksProvider);
        return TaskListView(
          title: '今天',
          tasks: todayTasks,
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
      case NavView.calendar:
        return const CalendarPage();
      case NavView.notes:
        return const NotesPage();
      case NavView.pomodoro:
        return const PomodoroPage();
      case NavView.list:
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
      case NavView.completed:
        final completedTasks = ref.watch(completedTasksProvider);
        return TaskListView(
          title: '已完成',
          tasks: completedTasks,
          showInput: false,
          groupCompleted: false,
          showHeader: !isMobile,
          showFilterSort: false, // 已完成页面不需要筛选排序
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

  Widget _buildDebugOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: AmberColors.divider),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AmberColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AmberColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AmberColors.textDisabled,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
