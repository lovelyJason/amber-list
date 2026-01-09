import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/constants/constants.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/ui_utils.dart';
import '../../data/models/models.dart';
import '../providers/providers.dart';
import 'task_item.dart';
import 'overdue_tasks_section.dart';

/// 今天视图组件
///
/// 设计哲学：
/// - 专门为"今天"视图设计，包含过期任务区域
/// - 过期任务区域显示在顶部，红色高亮警示
/// - 提供"全部顺延"和单个"顺延"按钮
/// - 下方是今天的任务列表（标准 TaskItem）
class TodayView extends ConsumerStatefulWidget {
  /// 是否显示头部（标题+筛选排序按钮）
  /// 移动端设为 false，因为顶部 AppBar 已有标题
  final bool showHeader;

  const TodayView({
    super.key,
    this.showHeader = true,
  });

  @override
  ConsumerState<TodayView> createState() => _TodayViewState();
}

class _TodayViewState extends ConsumerState<TodayView> {
  final _inputController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isAddingTask = false;

  @override
  void dispose() {
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 获取今天视图的数据（今天的任务 + 过期任务）
    final todayViewTasks = ref.watch(todayViewTasksProvider);
    final filterSort = ref.watch(taskFilterSortProvider);

    // 处理今天的任务（应用筛选排序）
    final todayTasks = _processTasks(todayViewTasks.todayTasks, filterSort);
    final incompleteTasks = todayTasks.where((t) => !t.isCompleted).toList();
    final completedTasks = todayTasks.where((t) => t.isCompleted).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题栏（移动端可隐藏）
        if (widget.showHeader) _buildHeader(),

        // 快速添加任务
        _buildQuickAdd(),

        // 任务列表（含过期区域）
        Expanded(
          child: SlidableAutoCloseBehavior(
            child: ListView(
              padding: const EdgeInsets.only(bottom: AmberDimens.spacingLg),
              children: [
                // 过期任务区域（放在最顶部）
                OverdueTasksSection(
                  overdueTasks: todayViewTasks.overdueTasks,
                ),

                // 今天的未完成任务
                ...incompleteTasks.map((task) => TaskItem(task: task)),

                // 今天的已完成任务（可折叠）
                if (completedTasks.isNotEmpty && !filterSort.hideCompleted)
                  _buildCompletedSection(completedTasks),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 处理任务列表（应用筛选排序）
  List<Task> _processTasks(List<Task> tasks, TaskFilterSortState filterSort) {
    var result = tasks.toList();

    // 过滤已完成任务
    if (filterSort.hideCompleted) {
      result = result.where((t) => !t.isCompleted).toList();
    }

    // 排序
    result.sort((a, b) {
      if (filterSort.sortOption == SortOption.smart) {
        // 智能排序：未完成 > 优先级 > 创建时间
        if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
        if (a.priority.value != b.priority.value) {
          return b.priority.value.compareTo(a.priority.value);
        }
        return b.createdAt.compareTo(a.createdAt);
      }

      int comparison = 0;
      switch (filterSort.sortOption) {
        case SortOption.dueDate:
          if (a.dueDate == null && b.dueDate == null) {
            comparison = 0;
          } else if (a.dueDate == null) {
            comparison = 1;
          } else if (b.dueDate == null) {
            comparison = -1;
          } else {
            comparison = a.dueDate!.compareTo(b.dueDate!);
          }
          break;
        case SortOption.priority:
          comparison = a.priority.value.compareTo(b.priority.value);
          break;
        case SortOption.title:
          comparison = a.title.compareTo(b.title);
          break;
        case SortOption.created:
          comparison = a.createdAt.compareTo(b.createdAt);
          break;
        default:
          comparison = 0;
      }
      return filterSort.sortAscending ? comparison : -comparison;
    });

    return result;
  }

  /// 构建标题栏
  Widget _buildHeader() {
    final navState = ref.watch(appNavProvider);
    final isSidebarOpen = navState.isListSidebarOpen;
    final filterSort = ref.watch(taskFilterSortProvider);
    final filterSortNotifier = ref.read(taskFilterSortProvider.notifier);
    final isDesktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;

    return DragToMoveArea(
      child: Container(
        padding: const EdgeInsets.all(AmberDimens.spacingMd),
        child: Row(
          children: [
            if (isDesktop) ...[
              IconButton(
                onPressed: () {
                  ref.read(appNavProvider.notifier).toggleListSidebar();
                },
                icon: Icon(
                  isSidebarOpen
                      ? FluentIcons.panel_left_contract_20_regular
                      : FluentIcons.panel_left_expand_20_regular,
                  color: AmberColors.textSecondary,
                ),
                tooltip: isSidebarOpen ? '收起侧边栏' : '展开侧边栏',
              ),
              const SizedBox(width: 8),
            ],
            const Text(
              '今天',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AmberColors.textPrimary,
              ),
            ),
            const Spacer(),
            // 筛选按钮
            InstantPopupMenuButton<bool>(
              tooltip: '筛选',
              offset: const Offset(0, 40),
              icon: Icon(
                filterSort.hasActiveFilter
                    ? Icons.filter_alt_rounded
                    : Icons.filter_list_rounded,
                color: filterSort.hasActiveFilter ? AmberColors.primary : null,
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: true,
                  onTap: () {
                    filterSortNotifier.toggleHideCompleted();
                  },
                  child: Row(
                    children: [
                      Icon(
                        filterSort.hideCompleted
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: 20,
                        color: AmberColors.primary,
                      ),
                      const SizedBox(width: 8),
                      const Text('隐藏已完成任务'),
                    ],
                  ),
                ),
              ],
            ),
            // 排序按钮
            InstantPopupMenuButton<SortOption>(
              tooltip: '排序',
              offset: const Offset(0, 40),
              initialValue: filterSort.sortOption,
              icon: Icon(
                Icons.sort_rounded,
                color: filterSort.hasCustomSort ? AmberColors.primary : null,
              ),
              onSelected: (result) {
                filterSortNotifier.setSortOption(result);
              },
              itemBuilder: (context) => [
                for (var option in SortOption.values)
                  PopupMenuItem(
                    value: option,
                    child: Row(
                      children: [
                        if (filterSort.sortOption == option)
                          const Icon(
                            Icons.check,
                            size: 18,
                            color: AmberColors.primary,
                          )
                        else
                          const SizedBox(width: 18),
                        const SizedBox(width: 8),
                        Text(getSortOptionName(option)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建快速添加任务区域
  Widget _buildQuickAdd() {
    // Material 包裹层：TextField 需要 Material 祖先组件
    // 移动端没有 Scaffold 包裹时会报错 "No Material widget found"
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AmberDimens.spacingMd,
          vertical: 4,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AmberDimens.spacingMd,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isAddingTask ? AmberColors.primary : const Color(0xFFEEEEEE),
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x05000000),
              offset: Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
        children: [
          Icon(
            Icons.add_rounded,
            color: _isAddingTask ? AmberColors.primary : AmberColors.primary,
            size: 24,
          ),
          const SizedBox(width: AmberDimens.spacingMd),
          Expanded(
            child: TextField(
              controller: _inputController,
              focusNode: _focusNode,
              decoration: const InputDecoration(
                hintText: '添加任务...',
                hintStyle: TextStyle(
                  color: AmberColors.textDisabled,
                  fontSize: 15,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                fillColor: Colors.transparent,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 15),
              onTap: () => setState(() => _isAddingTask = true),
              onSubmitted: _addTask,
            ),
          ),
          if (_isAddingTask)
            IconButton(
              onPressed: () {
                _addTask(_inputController.text);
              },
              icon: const Icon(Icons.arrow_upward_rounded, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: AmberColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(8),
                minimumSize: const Size(32, 32),
              ),
              color: Colors.white,
            ),
        ],
      ),
      ),
    );
  }

  /// 添加任务
  Future<void> _addTask(String title) async {
    if (title.trim().isEmpty) return;

    // 今天视图添加的任务，截止日期设为今天
    final today = AmberDateUtils.normalizeToUtcDate(DateTime.now());

    try {
      ref.read(soundServiceProvider).playAdd();
      await ref.read(taskProvider.notifier).createTask(
        title: title.trim(),
        dueDate: today,
      );

      _inputController.clear();
      setState(() {
        _isAddingTask = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('添加任务失败: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            width: 400,
          ),
        );
      }
    }
  }

  /// 构建已完成任务区域
  Widget _buildCompletedSection(List<Task> completedTasks) {
    return ListTileTheme(
      data: const ListTileThemeData(
        tileColor: Colors.transparent,
        selectedTileColor: Colors.transparent,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          expansionTileTheme: const ExpansionTileThemeData(
            backgroundColor: Colors.transparent,
            collapsedBackgroundColor: Colors.transparent,
            shape: Border(),
            collapsedShape: Border(),
          ),
        ),
        child: ExpansionTile(
          key: const PageStorageKey('today_completed_section'),
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AmberDimens.spacingMd + 8,
            vertical: 0,
          ),
          childrenPadding: EdgeInsets.zero,
          shape: const Border(),
          collapsedShape: const Border(),
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
          title: _CompletedSectionTitle(completedCount: completedTasks.length),
          children: completedTasks.map((task) => TaskItem(task: task)).toList(),
        ),
      ),
    );
  }
}

/// 已完成区域标题
class _CompletedSectionTitle extends StatefulWidget {
  final int completedCount;

  const _CompletedSectionTitle({required this.completedCount});

  @override
  State<_CompletedSectionTitle> createState() => _CompletedSectionTitleState();
}

class _CompletedSectionTitleState extends State<_CompletedSectionTitle> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '已完成',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: _isHovered
                    ? AmberColors.textPrimary
                    : AmberColors.textSecondary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(width: AmberDimens.spacingSm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${widget.completedCount}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AmberColors.textSecondary.withValues(alpha: 0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
