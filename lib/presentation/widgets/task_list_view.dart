import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/constants.dart';
import '../../data/models/models.dart';
import '../providers/providers.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:window_manager/window_manager.dart'; // Add import
import '../../core/utils/ui_utils.dart'; // Add import
import 'task_item.dart';
import 'package:intl/intl.dart';

/// 排序选项
enum SortOption {
  smart, // 智能排序 (默认)
  dueDate, // 按截止日期
  priority, // 按优先级
  title, // 按标题
  created, // 按创建时间
}

/// 任务列表视图
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
    this.showDatePicker = false, // Default to false
    this.groupCompleted = true,
  });

  final bool showInput;
  final bool showDatePicker;
  final bool groupCompleted;

  @override
  ConsumerState<TaskListView> createState() => _TaskListViewState();
}

class _TaskListViewState extends ConsumerState<TaskListView> {
  final _inputController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isAddingTask = false;
  DateTime _selectedDate = DateTime.now();

  // 排序与筛选状态
  SortOption _sortOption = SortOption.smart;
  bool _sortAscending = true;
  bool _hideCompleted = false;

  @override
  void dispose() {
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<Task> _processTasks() {
    // 1. 过滤
    var tasks = widget.tasks;
    if (_hideCompleted || (widget.groupCompleted == false && _hideCompleted)) {
      tasks = tasks.where((t) => !t.isCompleted).toList();
    }

    // 2. 排序
    tasks = List<Task>.from(tasks); // Copy list
    tasks.sort((a, b) {
      if (_sortOption == SortOption.smart) {
        // 智能排序: 未完成 > 优先级 > 创建时间
        if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
        if (a.priority.value != b.priority.value) {
          return b.priority.value.compareTo(a.priority.value);
        }
        return b.createdAt.compareTo(a.createdAt);
      }

      int comparison = 0;
      switch (_sortOption) {
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
      return _sortAscending ? comparison : -comparison;
    });

    return tasks;
  }



  String _getSortOptionName(SortOption option) {
    switch (option) {
      case SortOption.smart:
        return '智能排序';
      case SortOption.dueDate:
        return '按截止日期';
      case SortOption.priority:
        return '按优先级';
      case SortOption.title:
        return '按标题';
      case SortOption.created:
        return '按创建时间';
    }
  }

  @override
  Widget build(BuildContext context) {
    final allTasks = _processTasks();
    final incompleteTasks = allTasks.where((t) => !t.isCompleted).toList();
    final completedTasks = allTasks.where((t) => t.isCompleted).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题栏
        _buildHeader(),
        // 快速添加任务
        if (widget.showInput) _buildQuickAdd(),
        // 任务列表
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: AmberDimens.spacingLg),
            children: [
              if (!widget.groupCompleted)
                ...allTasks.map((task) => TaskItem(task: task))
              else ...[
                // 未完成任务
                ...incompleteTasks.map((task) => TaskItem(task: task)),
                // 已完成任务折叠
                if (completedTasks.isNotEmpty && !_hideCompleted)
                  _buildCompletedSection(completedTasks),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    final navState = ref.watch(appNavProvider);
    final isSidebarOpen = navState.isListSidebarOpen;

    return DragToMoveArea(
      child: Container(
        padding: const EdgeInsets.all(AmberDimens.spacingMd),
      child: Row(
        children: [
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
          Text(
            widget.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AmberColors.textPrimary,
            ),
          ),
          const Spacer(),
            InstantPopupMenuButton<bool>(
              tooltip: '筛选',
              offset: const Offset(0, 40), // 下拉位置修正
              icon: Icon(
                _hideCompleted
                    ? Icons.filter_alt_rounded
                    : Icons.filter_list_rounded,
                color: _hideCompleted ? AmberColors.primary : null,
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: true,
                  onTap: () {
                    setState(() {
                      _hideCompleted = !_hideCompleted;
                    });
                  },
                  child: Row(
                    children: [
                      Icon(
                        _hideCompleted
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
            InstantPopupMenuButton<SortOption>(
              tooltip: '排序',
              offset: const Offset(0, 40), // 下拉位置修正
              initialValue: _sortOption,
              icon: Icon(
                Icons.sort_rounded,
                color: _sortOption != SortOption.smart
                    ? AmberColors.primary
                    : null,
              ),
              onSelected: (result) {
                setState(() {
                  if (_sortOption == result && result != SortOption.smart) {
                    _sortAscending = !_sortAscending;
                  } else {
                    _sortOption = result;
                    if (result == SortOption.priority ||
                        result == SortOption.created) {
                      _sortAscending = false;
                    } else {
                      _sortAscending = true;
                    }
                  }
                });
              },
              itemBuilder: (context) => [
                for (var option in SortOption.values)
                  PopupMenuItem(
                    value: option,
                    child: Row(
                      children: [
                        if (_sortOption == option)
                          const Icon(
                            Icons.check,
                            size: 18,
                            color: AmberColors.primary,
                          )
                        else
                          const SizedBox(width: 18),
                        const SizedBox(width: 8),
                        Text(_getSortOptionName(option)),
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

  Widget _buildQuickAdd() {
    return Container(
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

  void _addTask(String title) {
    if (title.trim().isEmpty) return;

    ref.read(soundServiceProvider).playAdd(); // Sound
    ref.read(taskProvider.notifier).createTask(
      title: title.trim(),
      listId: widget.listId,
          dueDate: _selectedDate,
    );

    _inputController.clear();
    setState(() {
      _isAddingTask = false;
      _selectedDate = DateTime.now(); // Reset to today
    });
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
