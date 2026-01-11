import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:window_manager/window_manager.dart';
import 'package:intl/intl.dart';
import '../../core/constants/constants.dart';
import '../../core/utils/ui_utils.dart';
import '../../data/models/models.dart';
import '../providers/providers.dart';
import 'task_item.dart';

/// ============================================================
/// 已完成任务视图
/// ============================================================
/// 专门用于显示已完成任务的视图
///
/// 与普通 TaskListView 的区别：
/// - 筛选选项：全部 / 今天完成 / 指定日期完成
/// - 排序选项：增加"按完成时间"，且默认按完成时间降序
/// - 不显示快速添加输入框
/// - 不分组显示（所有任务平铺）
class CompletedTasksView extends ConsumerStatefulWidget {
  /// 是否显示头部区域（标题+筛选排序按钮）
  /// 移动端设为 false，因为顶部 AppBar 已有标题
  final bool showHeader;

  const CompletedTasksView({
    super.key,
    this.showHeader = true,
  });

  @override
  ConsumerState<CompletedTasksView> createState() => _CompletedTasksViewState();
}

class _CompletedTasksViewState extends ConsumerState<CompletedTasksView> {
  /// 根据筛选排序状态处理任务列表
  List<Task> _processTasks(List<Task> tasks, CompletedFilterSortState filterSort) {
    var result = List<Task>.from(tasks);

    // 1. 筛选
    switch (filterSort.filterMode) {
      case CompletedFilterMode.all:
        // 不筛选
        break;
      case CompletedFilterMode.today:
        // 今天完成的
        final today = DateTime.now();
        result = result.where((t) {
          if (t.completedAt == null) return false;
          return _isSameDay(t.completedAt!, today);
        }).toList();
        break;
      case CompletedFilterMode.specificDate:
        // 指定日期完成的
        if (filterSort.specificDate != null) {
          result = result.where((t) {
            if (t.completedAt == null) return false;
            return _isSameDay(t.completedAt!, filterSort.specificDate!);
          }).toList();
        }
        break;
    }

    // 2. 排序
    result.sort((a, b) {
      int comparison = 0;
      switch (filterSort.sortOption) {
        case SortOption.completedAt:
          // 按完成时间排序
          if (a.completedAt == null && b.completedAt == null) {
            comparison = 0;
          } else if (a.completedAt == null) {
            comparison = 1;
          } else if (b.completedAt == null) {
            comparison = -1;
          } else {
            comparison = a.completedAt!.compareTo(b.completedAt!);
          }
          break;
        case SortOption.dueDate:
          // 按截止日期排序
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
        case SortOption.smart:
          // 智能排序：按完成时间降序
          if (a.completedAt == null && b.completedAt == null) {
            comparison = 0;
          } else if (a.completedAt == null) {
            comparison = 1;
          } else if (b.completedAt == null) {
            comparison = -1;
          } else {
            comparison = b.completedAt!.compareTo(a.completedAt!);
          }
          break;
      }
      return filterSort.sortAscending ? comparison : -comparison;
    });

    return result;
  }

  /// 判断两个日期是否为同一天
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    // 获取所有已完成任务
    final completedTasks = ref.watch(completedTasksProvider);
    // 获取筛选排序状态
    final filterSort = ref.watch(completedFilterSortProvider);
    // 处理后的任务列表
    final processedTasks = _processTasks(completedTasks, filterSort);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题栏（传入任务数量）
        if (widget.showHeader) _buildHeader(processedTasks.length),
        // 任务列表
        Expanded(
          child: SlidableAutoCloseBehavior(
            child: processedTasks.isEmpty
                ? _buildEmptyState(filterSort)
                : ListView(
                    padding: const EdgeInsets.only(bottom: AmberDimens.spacingLg),
                    children: processedTasks.map((task) => TaskItem(task: task)).toList(),
                  ),
          ),
        ),
      ],
    );
  }

  /// 构建头部区域
  /// [taskCount] 当前筛选后的任务数量
  Widget _buildHeader(int taskCount) {
    final navState = ref.watch(appNavProvider);
    final isSidebarOpen = navState.isListSidebarOpen;
    final filterSort = ref.watch(completedFilterSortProvider);
    final isDesktop = Platform.isMacOS || Platform.isWindows || Platform.isLinux;

    return DragToMoveArea(
      child: Container(
        padding: const EdgeInsets.all(AmberDimens.spacingMd),
        child: Row(
          children: [
            // 桌面端侧边栏展开/收缩按钮
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
              '已完成',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AmberColors.textPrimary,
              ),
            ),
            // 任务数量徽章
            const SizedBox(width: 8),
            _buildTaskCountBadge(taskCount),
            const Spacer(),
            // 筛选按钮
            _buildFilterButton(filterSort),
            // 排序按钮
            _buildSortButton(filterSort),
          ],
        ),
      ),
    );
  }

  /// 构建任务数量徽章
  Widget _buildTaskCountBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AmberDimens.spacingSm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AmberColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AmberColors.primary,
        ),
      ),
    );
  }

  /// 构建筛选按钮
  Widget _buildFilterButton(CompletedFilterSortState filterSort) {
    final filterSortNotifier = ref.read(completedFilterSortProvider.notifier);

    return InstantPopupMenuButton<CompletedFilterMode>(
      tooltip: '筛选',
      offset: const Offset(0, 40),
      icon: Icon(
        filterSort.hasActiveFilter
            ? Icons.filter_alt_rounded
            : Icons.filter_list_rounded,
        color: filterSort.hasActiveFilter ? AmberColors.primary : null,
      ),
      itemBuilder: (context) => [
        // 全部
        PopupMenuItem(
          value: CompletedFilterMode.all,
          onTap: () => filterSortNotifier.setFilterAll(),
          child: Row(
            children: [
              if (filterSort.filterMode == CompletedFilterMode.all)
                const Icon(Icons.check, size: 18, color: AmberColors.primary)
              else
                const SizedBox(width: 18),
              const SizedBox(width: 8),
              const Text('全部'),
            ],
          ),
        ),
        // 今天
        PopupMenuItem(
          value: CompletedFilterMode.today,
          onTap: () => filterSortNotifier.setFilterToday(),
          child: Row(
            children: [
              if (filterSort.filterMode == CompletedFilterMode.today)
                const Icon(Icons.check, size: 18, color: AmberColors.primary)
              else
                const SizedBox(width: 18),
              const SizedBox(width: 8),
              const Text('今天'),
            ],
          ),
        ),
        // 指定日期
        PopupMenuItem(
          value: CompletedFilterMode.specificDate,
          onTap: () => _showDatePicker(context),
          child: Row(
            children: [
              if (filterSort.filterMode == CompletedFilterMode.specificDate)
                const Icon(Icons.check, size: 18, color: AmberColors.primary)
              else
                const SizedBox(width: 18),
              const SizedBox(width: 8),
              Text(
                filterSort.filterMode == CompletedFilterMode.specificDate &&
                        filterSort.specificDate != null
                    ? DateFormat('M月d日').format(filterSort.specificDate!)
                    : '指定日期',
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 显示日期选择器
  Future<void> _showDatePicker(BuildContext context) async {
    final filterSortNotifier = ref.read(completedFilterSortProvider.notifier);
    final currentState = ref.read(completedFilterSortProvider);

    final picked = await showDatePicker(
      context: context,
      initialDate: currentState.specificDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: DateTime.now(),
      confirmText: '确定',
      cancelText: '取消',
      helpText: '选择日期',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            datePickerTheme: const DatePickerThemeData(
              headerHeadlineStyle: TextStyle(
                fontSize: 16,
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
      filterSortNotifier.setFilterSpecificDate(picked);
    }
  }

  /// 构建排序按钮
  Widget _buildSortButton(CompletedFilterSortState filterSort) {
    final filterSortNotifier = ref.read(completedFilterSortProvider.notifier);

    // 已完成页面的排序选项（不包含智能排序，增加按完成时间）
    final sortOptions = [
      SortOption.completedAt,
      SortOption.dueDate,
      SortOption.priority,
      SortOption.title,
      SortOption.created,
    ];

    return InstantPopupMenuButton<SortOption>(
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
        for (var option in sortOptions)
          PopupMenuItem(
            value: option,
            child: Row(
              children: [
                if (filterSort.sortOption == option)
                  const Icon(Icons.check, size: 18, color: AmberColors.primary)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 8),
                Text(getSortOptionName(option)),
              ],
            ),
          ),
      ],
    );
  }

  /// 构建空状态提示
  Widget _buildEmptyState(CompletedFilterSortState filterSort) {
    String message;
    switch (filterSort.filterMode) {
      case CompletedFilterMode.all:
        message = '还没有完成的任务';
        break;
      case CompletedFilterMode.today:
        message = '今天还没有完成任务';
        break;
      case CompletedFilterMode.specificDate:
        if (filterSort.specificDate != null) {
          message = '${DateFormat('M月d日').format(filterSort.specificDate!)} 没有完成任务';
        } else {
          message = '还没有完成的任务';
        }
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FluentIcons.checkmark_circle_24_regular,
            size: 64,
            color: AmberColors.textDisabled.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 16,
              color: AmberColors.textDisabled,
            ),
          ),
        ],
      ),
    );
  }
}
