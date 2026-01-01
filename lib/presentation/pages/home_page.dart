import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';

import '../../core/constants/constants.dart';
import '../widgets/common/toast/toast_manager.dart';
import '../widgets/common/toast/toast_types.dart';
import '../../data/models/models.dart';
import '../providers/providers.dart';
import '../providers/native_sticky_note_provider.dart';
import '../widgets/widgets.dart';
import 'calendar/calendar_page.dart';
import 'notes/notes_page.dart';
import 'pomodoro/pomodoro_page.dart';
import '../pages/sticky_note/sticky_note_registry.dart';
import '../widgets/debug/sticky_note_debugger.dart';
import '../widgets/debug/prefs_editor.dart';

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

  @override
  void initState() {
    super.initState();
    // Register method call handler from other windows globally here
    DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
      debugPrint(
        '[Main Window] Received method: ${call.method} from $fromWindowId',
      );

      if (call.method == 'toggleTask') {
        final taskId = call.arguments as String;
        // 使用 ref 读取 provider
        ref.read(taskProvider.notifier).toggleTaskComplete(taskId);
        return 'ok';
      } else if (call.method == 'stickyNoteClosed') {
        final contentId = call.arguments as String;
        final windowId = ref
            .read(stickyNoteRegistryProvider.notifier)
            .getWindowId(contentId);
        ref.read(stickyNoteRegistryProvider.notifier).unregister(contentId);
        
        // Explicitly ensure the window is closed from the main side
        if (windowId != null) {
          try {
            await DesktopMultiWindow.invokeMethod(
              windowId,
              'close',
              null,
            ); // use invoke to signal if needed, or controller
            // Actually the plugin exposes WindowController
            await WindowController.fromWindowId(windowId).close();
          } catch (e) {
            debugPrint('Error closing window $windowId from main: $e');
          }
        }
        return 'ok';
      }
      return null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 初始化原生便签服务（设置回调）
    // 使用 watch 确保服务在整个生命周期内保持活跃
    ref.watch(nativeStickyNoteProvider);

    // ref is available in build
    final navState = ref.watch(appNavProvider);
    final tasks = ref.watch(taskProvider);

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
                child: _buildMainContent(ref, navState, tasks),
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
                  tooltip: 'Debug 调试器（可拖拽）',
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
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainContent(WidgetRef ref, AppNavState navState, List<Task> tasks) {
    switch (navState.currentView) {
      case NavView.all:
        // 显示所有任务（包括已完成），但不包括已删除
        final allTasks = tasks.where((t) => !t.isDeleted).toList();
        return TaskListView(title: '全部', tasks: allTasks);
      case NavView.inbox:
        // Inbox now shows ALL tasks as per user request (excluding deleted)
        final allTasks = tasks.where((t) => !t.isDeleted).toList();
        return TaskListView(
          title: '收集箱',
          tasks: allTasks,
          showDatePicker: true,
        );
      case NavView.today:
        final todayTasks = ref.watch(todayTasksProvider);
        return TaskListView(
          title: '今天',
          tasks: todayTasks,
        );
      case NavView.upcoming:
        final upcomingTasks = ref.watch(upcomingTasksProvider);
        return TaskListView(
          title: '最近7天',
          tasks: upcomingTasks,
          showInput: false,
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
        );
      case NavView.trash:
        final trashTasks = ref.watch(trashTasksProvider);
        return TaskListView(
          title: '垃圾桶',
          tasks: trashTasks,
          showInput: false,
          groupCompleted: false,
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
