import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../core/constants/constants.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/models.dart';
import '../providers/providers.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/utils/ui_utils.dart';
import 'task_item.dart';
import 'package:intl/intl.dart';

// 注意：SortOption 已移至 task_filter_sort_provider.dart，这里重新导出以保持兼容
// 已在 providers.dart 中 export，这里不需要重复定义

/// 任务列表视图
///
/// 设计哲学：
/// - 桌面端：显示完整 header（标题+筛选排序按钮）
/// - 移动端：header 可隐藏，筛选排序按钮由外层 AppBar 提供
/// - 筛选排序状态由 taskFilterSortProvider 统一管理
class TaskListView extends ConsumerStatefulWidget {
  final String title;
  final List<Task> tasks;
  final String? listId;

  const TaskListView({
    super.key,
    required this.title,
    required this.tasks,
    this.listId,
    this.showInput = true,
    this.showDatePicker = false,
    this.groupCompleted = true,
    this.showHeader = true, // 是否显示头部（标题+筛选排序），移动端设为 false
    this.showFilterSort = true, // 是否显示筛选排序按钮，已完成/垃圾桶页面设为 false
    this.isTrash = false, // 是否是垃圾桶视图，垃圾桶视图显示清空按钮
  });

  final bool showInput;
  final bool showDatePicker;
  final bool groupCompleted;

  /// 是否显示头部区域（标题+筛选排序按钮）
  /// 移动端设为 false，因为顶部 AppBar 已有标题
  final bool showHeader;

  /// 是否显示筛选排序按钮
  /// 已完成/垃圾桶页面设为 false，因为这些页面不需要筛选排序
  final bool showFilterSort;

  /// 是否是垃圾桶视图
  /// 垃圾桶视图会显示"清空垃圾桶"按钮
  final bool isTrash;

  @override
  ConsumerState<TaskListView> createState() => _TaskListViewState();
}

class _TaskListViewState extends ConsumerState<TaskListView> {
  final _inputController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isAddingTask = false;
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 根据筛选排序状态处理任务列表
  List<Task> _processTasks(TaskFilterSortState filterSort) {
    // 1. 过滤
    var tasks = widget.tasks;
    if (filterSort.hideCompleted || (widget.groupCompleted == false && filterSort.hideCompleted)) {
      tasks = tasks.where((t) => !t.isCompleted).toList();
    }

    // 过滤已过期任务（截止日期早于今天且未完成的任务）
    // 使用 AmberDateUtils 确保跨时区一致性
    if (filterSort.hideOverdue) {
      tasks = tasks.where((t) {
        if (t.isCompleted) return true; // 已完成的不过滤
        if (t.dueDate == null) return true; // 没有截止日期的不过滤
        return !AmberDateUtils.isOverdue(t.dueDate!); // 过滤掉过期的
      }).toList();
    }

    // 2. 排序
    tasks = List<Task>.from(tasks); // Copy list
    tasks.sort((a, b) {
      if (filterSort.sortOption == SortOption.smart) {
        // 智能排序: 未完成 > 未过期 > 截止日期近 > 优先级 > 创建时间
        // 1. 已完成的排最后
        if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;

        // 2. 已过期的排在未过期后面（仅对未完成任务生效）
        // 使用 AmberDateUtils 确保跨时区一致性
        final aIsOverdue = a.dueDate != null && AmberDateUtils.isOverdue(a.dueDate!);
        final bIsOverdue = b.dueDate != null && AmberDateUtils.isOverdue(b.dueDate!);
        if (aIsOverdue != bIsOverdue) return aIsOverdue ? 1 : -1;

        // 3. 按截止日期排序（日期近的在前，无日期的排最后）
        // 提取日期部分进行比较，忽略时间
        final aDue = a.dueDate != null ? DateTime(a.dueDate!.year, a.dueDate!.month, a.dueDate!.day) : null;
        final bDue = b.dueDate != null ? DateTime(b.dueDate!.year, b.dueDate!.month, b.dueDate!.day) : null;
        if (aDue != null || bDue != null) {
          if (aDue == null) return 1;  // 无日期的排后面
          if (bDue == null) return -1;
          final dueDateComparison = aDue.compareTo(bDue);
          if (dueDateComparison != 0) return dueDateComparison;
        }

        // 4. 按优先级排序（高优先级在前）
        if (a.priority.value != b.priority.value) {
          return b.priority.value.compareTo(a.priority.value);
        }
        // 5. 按创建时间排序（新创建的在前）
        return b.createdAt.compareTo(a.createdAt);
      }

      int comparison = 0;
      switch (filterSort.sortOption) {
        case SortOption.dueDate:
          // Nulls last
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

    return tasks;
  }

  @override
  Widget build(BuildContext context) {
    // 从 Provider 获取筛选排序状态
    final filterSort = ref.watch(taskFilterSortProvider);

    final allTasks = _processTasks(filterSort);
    final incompleteTasks = allTasks.where((t) => !t.isCompleted).toList();
    final completedTasks = allTasks.where((t) => t.isCompleted).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题栏（移动端可隐藏）
        if (widget.showHeader) _buildHeader(),
        // 快速添加任务
        if (widget.showInput) _buildQuickAdd(),
        // 任务列表
        // SlidableAutoCloseBehavior: 滑动一个任务时，其他已打开的会自动关闭（微信风格）
        Expanded(
          child: SlidableAutoCloseBehavior(
            child: ListView(
              padding: const EdgeInsets.only(bottom: AmberDimens.spacingLg),
              children: [
                if (!widget.groupCompleted)
                  ...allTasks.map((task) => TaskItem(task: task))
                else ...[
                  // 未完成任务
                  ...incompleteTasks.map((task) => TaskItem(task: task)),
                  // 已完成任务折叠
                  if (completedTasks.isNotEmpty && !filterSort.hideCompleted)
                    _buildCompletedSection(completedTasks),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final navState = ref.watch(appNavProvider);
    final isSidebarOpen = navState.isListSidebarOpen;
    final filterSort = ref.watch(taskFilterSortProvider);
    final filterSortNotifier = ref.read(taskFilterSortProvider.notifier);
    // 判断是否为桌面端（只有桌面端才有侧边栏展开/收缩功能）
    final isDesktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;

    return DragToMoveArea(
      child: Container(
        padding: const EdgeInsets.all(AmberDimens.spacingMd),
      child: Row(
        children: [
          // 桌面端才显示侧边栏展开/收缩按钮
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
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AmberColors.textPrimary,
            ),
          ),
          const Spacer(),
          // 清空垃圾桶按钮（仅垃圾桶视图显示）
          if (widget.isTrash && widget.tasks.isNotEmpty)
            IconButton(
              onPressed: () => _showEmptyTrashDialog(context),
              icon: const Icon(
                Icons.delete_forever_outlined,
                color: Colors.red,
              ),
              tooltip: '清空垃圾桶',
            ),
          // 筛选排序按钮（已完成/垃圾桶页面不显示）
          if (widget.showFilterSort) ...[
            InstantPopupMenuButton<bool>(
              tooltip: '筛选',
              offset: const Offset(0, 40), // 下拉位置修正
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
                PopupMenuItem(
                  value: false,
                  onTap: () {
                    filterSortNotifier.toggleHideOverdue();
                  },
                  child: Row(
                    children: [
                      Icon(
                        filterSort.hideOverdue
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: 20,
                        color: AmberColors.primary,
                      ),
                      const SizedBox(width: 8),
                      const Text('隐藏已过期任务'),
                    ],
                  ),
                ),
              ],
            ),
            InstantPopupMenuButton<SortOption>(
              tooltip: '排序',
              offset: const Offset(0, 40), // 下拉位置修正
              initialValue: filterSort.sortOption,
              icon: Icon(
                Icons.sort_rounded,
                color: filterSort.hasCustomSort
                    ? AmberColors.primary
                    : null,
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
        ],
      ),
      ),
    );
  }

  Widget _buildQuickAdd() {
    // Material 包裹层：TextField 需要 Material 祖先组件
    // 移动端没有 Scaffold 包裹时会报错 "No Material widget found"
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AmberDimens.spacingMd,
          vertical: 4, // 与 TaskItem 间距对齐
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AmberDimens.spacingMd,
          vertical: 2, // 稍微减小垂直内边距，因为 TextField 本身有高度
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
              color: Color(0x05000000), // 非常淡的阴影
              offset: Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
        children: [
          Icon(
            Icons.add_rounded, // 使用圆角加号
            color: _isAddingTask
                ? AmberColors.primary
                : AmberColors.primary, // 始终显示强调色或灰色
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
                filled: false, // 禁用默认填充
                fillColor: Colors.transparent, // 确保背景透明
                contentPadding: EdgeInsets.symmetric(
                  vertical: 12,
                ), // 增加一点垂直padding
                isDense: true,
              ),
              style: const TextStyle(fontSize: 15),
              onTap: () => setState(() => _isAddingTask = true),
              onSubmitted: _addTask,
            ),
          ),
          if (_isAddingTask) ...[
            if (widget.showDatePicker) ...[
              IconButton(
                onPressed: _pickDate,
                icon: Icon(
                  Icons.calendar_today_outlined,
                  size: 20,
                  color: DateUtils.isSameDay(_selectedDate, DateTime.now())
                      ? AmberColors.textSecondary
                      : AmberColors.primary,
                ),
                tooltip: DateFormat('M月d日', 'zh_CN').format(_selectedDate),
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(8),
                  minimumSize: const Size(32, 32),
                ),
              ),
              const SizedBox(width: 4),
            ],
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
        ],
      ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      confirmText: '确定',
      cancelText: '取消',
      helpText: '选择日期',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            datePickerTheme: const DatePickerThemeData(
              headerHeadlineStyle: TextStyle(
                fontSize: 16, // Smaller font size
                fontWeight: FontWeight.bold,
              ),
              headerHelpStyle: TextStyle(fontSize: 14),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      // Re-focus input
      _focusNode.requestFocus();
    }
  }

  Future<void> _addTask(String title) async {
    if (title.trim().isEmpty) return;

    // 规范化为 UTC 日期存储，确保跨设备同步时日期一致
    final normalizedDate = AmberDateUtils.normalizeToUtcDate(_selectedDate);

    try {
      ref.read(soundServiceProvider).playAdd(); // Sound
      await ref.read(taskProvider.notifier).createTask(
        title: title.trim(),
        listId: widget.listId,
        dueDate: normalizedDate,
      );

      _inputController.clear();
      setState(() {
        _isAddingTask = false;
        _selectedDate = DateTime.now(); // Reset to today
      });
    } catch (e) {
      // 创建任务失败提示（可能是清单已被删除等原因）
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('添加任务失败: ${e.toString().contains('FOREIGN KEY') ? '清单已被删除，请刷新页面' : e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            width: 400,
          ),
        );
      }
    }
  }

  /// 显示清空垃圾桶确认对话框
  void _showEmptyTrashDialog(BuildContext context) {
    final taskCount = widget.tasks.length;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('清空垃圾桶?'),
        content: Text('将永久删除垃圾桶中的 $taskCount 个任务及其番茄记录。\n\n此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogContext);
              // 播放删除音效
              ref.read(soundServiceProvider).playDelete();
              // 清空垃圾桶
              await ref.read(taskProvider.notifier).emptyTrash();
              // 显示成功提示
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已清空 $taskCount 个任务'),
                    behavior: SnackBarBehavior.floating,
                    width: 300,
                  ),
                );
              }
            },
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }

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
          hoverColor: Colors.transparent, // hover颜色放这里!
          expansionTileTheme: const ExpansionTileThemeData(
            backgroundColor: Colors.transparent,
            collapsedBackgroundColor: Colors.transparent,
            shape: Border(),
            collapsedShape: Border(),
          ),
        ),
        child: ExpansionTile(
          key: PageStorageKey(
            'completed_section_v5_${widget.listId ?? widget.title}',
          ),
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

/// 已完成区域标题 - 支持hover效果
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
        // hover时显示灰色背景,并限制宽度!
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.transparent, // 移除 hover 背景
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
                // Hover 时颜色加深
                color: _isHovered
                    ? AmberColors.textPrimary
                    : AmberColors.textSecondary.withOpacity(0.7),
              ),
            ),
            const SizedBox(width: AmberDimens.spacingSm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.15), // 浅灰色 Pill 背景
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${widget.completedCount}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AmberColors.textSecondary.withOpacity(0.8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
