import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../data/models/models.dart';
import '../../../providers/providers.dart';
import '../../../widgets/task_item.dart';
import 'spotlight_dialog.dart';

/// 日历相关对话框
/// 包含任务列表弹窗、Spotlight 搜索等
class CalendarDialogs {
  /// 显示当天任务列表对话框
  /// 包含任务输入框和任务列表
  static void showDayTaskListDialog(
    BuildContext context,
    DateTime day,
    List<Task> initialTasks,
  ) {
    showDialog(
      context: context,
      builder: (context) => _DayTaskListDialog(day: day),
    );
  }

  /// 显示 Spotlight 搜索对话框
  ///
  /// 双击日历单元格时弹出，支持快速添加任务
  /// - 紧凑模式：只有标题输入框，回车即可添加
  /// - 展开模式：点击展开按钮显示截止日期、清单、优先级、标签选项
  static void showSpotlightSearch(
    BuildContext context,
    WidgetRef ref, {
    required DateTime? selectedDay,
    required DateTime focusedDay,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 100),
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: 600,
                // SpotlightDialog 内部已经是 ConsumerStatefulWidget
                // 会直接通过 ref 创建任务，不需要外部回调
                child: SpotlightDialog(
                  selectedDate: selectedDay ?? focusedDay,
                  onTaskCreated: (_) {
                    // 任务创建已在 SpotlightDialog 内部处理
                    // 保留此回调仅为 API 兼容性
                  },
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            child: child,
          ),
        );
      },
    );
  }
}

/// 当天任务列表弹窗组件
/// 包含展开式任务输入框和任务列表（支持双击编辑）
class _DayTaskListDialog extends ConsumerStatefulWidget {
  final DateTime day;

  const _DayTaskListDialog({required this.day});

  @override
  ConsumerState<_DayTaskListDialog> createState() => _DayTaskListDialogState();
}

class _DayTaskListDialogState extends ConsumerState<_DayTaskListDialog> {
  final _inputController = TextEditingController();
  final _focusNode = FocusNode();

  /// 是否展开模式
  bool _isExpanded = false;

  /// 选中的截止日期
  late DateTime _selectedDate;

  /// 选中的清单 ID
  String? _selectedListId;

  /// 选中的优先级
  TaskPriority _selectedPriority = TaskPriority.none;

  /// 选中的标签
  List<String> _selectedTags = [];

  /// 当前编辑的任务（用于右侧详情面板）
  Task? _editingTask;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.day;
    // 弹窗打开后自动聚焦输入框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 添加任务
  void _addTask() {
    final title = _inputController.text.trim();
    if (title.isEmpty) return;

    // 规范化为 UTC 日期存储，确保跨设备同步时日期一致
    final normalizedDate = AmberDateUtils.normalizeToUtcDate(_selectedDate);

    ref.read(soundServiceProvider).playAdd();
    ref.read(taskProvider.notifier).createTask(
          title: title,
          dueDate: normalizedDate,
          listId: _selectedListId,
          priority: _selectedPriority,
          tags: _selectedTags,
        );

    _inputController.clear();
    setState(() {
      _isExpanded = false;
      _selectedPriority = TaskPriority.none;
      _selectedTags = [];
    });
  }

  /// 双击任务打开编辑面板
  void _onTaskDoubleTap(Task task) {
    setState(() {
      _editingTask = task;
    });
  }

  /// 关闭编辑面板
  void _closeEditPanel() {
    setState(() {
      _editingTask = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final allTasks = ref.watch(taskProvider);
    final currentDayTasks = allTasks.where((task) {
      // 过滤已删除的任务（垃圾桶里的不显示）
      if (task.isDeleted) return false;
      if (task.dueDate == null) return false;
      return isSameDay(task.dueDate!, widget.day);
    }).toList();

    // 如果正在编辑任务，从最新列表中获取更新后的任务数据
    if (_editingTask != null) {
      final updatedTask = allTasks.where((t) => t.id == _editingTask!.id).firstOrNull;
      if (updatedTask == null) {
        // 任务被删除了，关闭编辑面板
        _editingTask = null;
      } else {
        _editingTask = updatedTask;
      }
    }

    return AlertDialog(
      title: Text(
        DateFormat('yyyy年MM月dd日 EEEE', 'zh_CN').format(widget.day),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: _editingTask != null ? 900 : 550,
        height: MediaQuery.of(context).size.height * 0.65,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左侧：任务列表区域
            Expanded(
              flex: _editingTask != null ? 1 : 1,
              child: Column(
                children: [
                  // 展开式任务输入框
                  _buildExpandableQuickAdd(),
                  const SizedBox(height: AmberDimens.spacingSm),
                  // 任务列表
                  Expanded(
                    child: currentDayTasks.isEmpty
                        ? Center(
                            child: Text(
                              '暂无任务',
                              style: TextStyle(
                                color: AmberColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          )
                        : ScrollConfiguration(
                            behavior: ScrollConfiguration.of(context).copyWith(
                              scrollbars: false,
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: currentDayTasks.length,
                              itemBuilder: (context, index) {
                                final task = currentDayTasks[index];
                                return GestureDetector(
                                  onDoubleTap: () => _onTaskDoubleTap(task),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: _editingTask?.id == task.id
                                          ? AmberColors.primary.withValues(alpha: 0.08)
                                          : null,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: TaskItem(task: task),
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
            // 右侧：任务详情编辑面板
            if (_editingTask != null) ...[
              const VerticalDivider(width: 1),
              Expanded(
                flex: 1,
                child: _buildTaskDetailPanel(_editingTask!),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            for (var task in currentDayTasks) {
              if (!task.isCompleted) {
                ref.read(taskProvider.notifier).toggleTaskComplete(task.id);
              }
            }
          },
          child: const Text('全选'),
        ),
        TextButton(
          onPressed: () {
            for (var task in currentDayTasks) {
              ref.read(taskProvider.notifier).toggleTaskComplete(task.id);
            }
          },
          child: const Text('反选'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  /// 构建展开式快速添加输入框
  Widget _buildExpandableQuickAdd() {
    final lists = ref.watch(taskListProvider);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isExpanded ? AmberColors.primary : const Color(0xFFEEEEEE),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            offset: Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 输入行
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_rounded,
                  color: AmberColors.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    focusNode: _focusNode,
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      filled: false,
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: '添加任务到 ${DateFormat('M月d日', 'zh_CN').format(_selectedDate)}...',
                      hintStyle: TextStyle(
                        color: AmberColors.textDisabled.withValues(alpha: 0.6),
                        fontSize: 15,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) {
                      if (_inputController.text.trim().isNotEmpty) {
                        _addTask();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // 展开/收起按钮
                IconButton(
                  onPressed: () => setState(() => _isExpanded = !_isExpanded),
                  icon: Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AmberColors.textSecondary,
                  ),
                  tooltip: _isExpanded ? '收起选项' : '展开选项',
                  splashRadius: 16,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                // Enter 按钮（紧凑模式）
                if (!_isExpanded)
                  InkWell(
                    onTap: () {
                      if (_inputController.text.trim().isNotEmpty) {
                        _addTask();
                      }
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AmberColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AmberColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Enter',
                            style: TextStyle(
                              color: AmberColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(width: 3),
                          Icon(Icons.keyboard_return_rounded, size: 12, color: AmberColors.primary),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // 展开模式：选项区域
          if (_isExpanded) ...[
            const Divider(height: 1),
            _buildOptionsArea(lists),
            const Divider(height: 1),
            _buildFooter(),
          ],
        ],
      ),
    );
  }

  /// 构建选项区域
  Widget _buildOptionsArea(List<TaskList> lists) {
    final tags = ref.watch(tagsProvider);

    // 获取清单名称
    String listName = '收集箱';
    if (_selectedListId != null) {
      final list = lists.where((l) => l.id == _selectedListId).firstOrNull;
      if (list != null) listName = list.name;
    }

    // 优先级显示
    String priorityText;
    Color? priorityColor;
    switch (_selectedPriority) {
      case TaskPriority.high:
        priorityText = '高';
        priorityColor = Colors.red;
        break;
      case TaskPriority.medium:
        priorityText = '中';
        priorityColor = Colors.orange;
        break;
      case TaskPriority.low:
        priorityText = '低';
        priorityColor = Colors.green;
        break;
      case TaskPriority.none:
        priorityText = '无';
        priorityColor = null;
        break;
    }

    // 标签显示
    String tagsText = _selectedTags.isEmpty ? '添加标签' : _selectedTags.join(', ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          _buildOptionRow(
            icon: Icons.calendar_today_outlined,
            label: '截止日期',
            value: DateFormat('yyyy年M月d日', 'zh_CN').format(_selectedDate),
            onTap: () => _showDatePicker(context),
          ),
          _buildOptionRow(
            icon: Icons.list_alt_outlined,
            label: '清单',
            value: listName,
            onTap: () => _showListPicker(context, lists),
          ),
          _buildOptionRow(
            icon: Icons.flag_outlined,
            label: '优先级',
            value: priorityText,
            valueColor: priorityColor,
            onTap: () => _showPriorityPicker(context),
          ),
          _buildOptionRow(
            icon: Icons.label_outline,
            label: '标签',
            value: tagsText,
            onTap: () => _showTagsDialog(context, tags),
          ),
        ],
      ),
    );
  }

  /// 构建选项行
  Widget _buildOptionRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AmberColors.textSecondary),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(fontSize: 13, color: AmberColors.textSecondary),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(fontSize: 13, color: valueColor ?? AmberColors.textPrimary),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 16, color: AmberColors.textDisabled),
          ],
        ),
      ),
    );
  }

  /// 构建底部操作栏
  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => setState(() => _isExpanded = false),
            child: const Text('取消'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _inputController.text.trim().isNotEmpty ? _addTask : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AmberColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  /// 构建任务详情编辑面板
  Widget _buildTaskDetailPanel(Task task) {
    final lists = ref.watch(taskListProvider);
    final tags = ref.watch(tagsProvider);

    // 获取清单名称
    String listName = '收集箱';
    if (task.listId != null) {
      final list = lists.where((l) => l.id == task.listId).firstOrNull;
      if (list != null) listName = list.name;
    }

    // 优先级显示
    String priorityText;
    Color? priorityColor;
    switch (task.priority) {
      case TaskPriority.high:
        priorityText = '高';
        priorityColor = Colors.red;
        break;
      case TaskPriority.medium:
        priorityText = '中';
        priorityColor = Colors.orange;
        break;
      case TaskPriority.low:
        priorityText = '低';
        priorityColor = Colors.green;
        break;
      case TaskPriority.none:
        priorityText = '无';
        priorityColor = null;
        break;
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Row(
            children: [
              const Text(
                '编辑任务',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                onPressed: _closeEditPanel,
                icon: const Icon(Icons.close, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 任务标题
          Text(
            task.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
              color: task.isCompleted ? AmberColors.textDisabled : AmberColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          // 选项列表
          _buildEditOptionRow(
            icon: Icons.calendar_today_outlined,
            label: '截止日期',
            value: task.dueDate != null
                ? DateFormat('yyyy年M月d日', 'zh_CN').format(task.dueDate!)
                : '无',
            onTap: () => _editTaskDate(task),
          ),
          _buildEditOptionRow(
            icon: Icons.list_alt_outlined,
            label: '清单',
            value: listName,
            onTap: () => _editTaskList(task, lists),
          ),
          _buildEditOptionRow(
            icon: Icons.flag_outlined,
            label: '优先级',
            value: priorityText,
            valueColor: priorityColor,
            onTap: () => _editTaskPriority(task),
          ),
          _buildEditOptionRow(
            icon: Icons.label_outline,
            label: '标签',
            value: task.tags.isEmpty ? '无' : task.tags.join(', '),
            onTap: () => _editTaskTags(task, tags),
          ),
          const Spacer(),
          // 删除按钮
          Center(
            child: TextButton.icon(
              onPressed: () {
                ref.read(taskProvider.notifier).deleteTask(task.id);
                _closeEditPanel();
              },
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
              label: const Text('删除任务', style: TextStyle(color: Colors.red)),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建编辑面板的选项行
  Widget _buildEditOptionRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AmberColors.textSecondary),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontSize: 14)),
            const Spacer(),
            Text(
              value,
              style: TextStyle(fontSize: 14, color: valueColor ?? AmberColors.textSecondary),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: AmberColors.textDisabled),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 添加任务时的选择器
  // ============================================================

  /// 显示日期选择器
  Future<void> _showDatePicker(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  /// 显示清单选择器
  void _showListPicker(BuildContext context, List<TaskList> lists) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择清单'),
        children: [
          // 收集箱选项
          SimpleDialogOption(
            onPressed: () {
              setState(() => _selectedListId = null);
              Navigator.pop(ctx);
            },
            child: Row(
              children: [
                const Icon(Icons.inbox_outlined, size: 20),
                const SizedBox(width: 12),
                const Text('收集箱'),
                const Spacer(),
                if (_selectedListId == null)
                  const Icon(Icons.check, color: AmberColors.primary, size: 20),
              ],
            ),
          ),
          // 清单列表
          ...lists.map((list) => SimpleDialogOption(
                onPressed: () {
                  setState(() => _selectedListId = list.id);
                  Navigator.pop(ctx);
                },
                child: Row(
                  children: [
                    Icon(Icons.list, size: 20, color: list.color),
                    const SizedBox(width: 12),
                    Text(list.name),
                    const Spacer(),
                    if (_selectedListId == list.id)
                      const Icon(Icons.check, color: AmberColors.primary, size: 20),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  /// 显示优先级选择器
  void _showPriorityPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择优先级'),
        children: [
          _buildPriorityOption(ctx, TaskPriority.none, '无', null),
          _buildPriorityOption(ctx, TaskPriority.low, '低', Colors.green),
          _buildPriorityOption(ctx, TaskPriority.medium, '中', Colors.orange),
          _buildPriorityOption(ctx, TaskPriority.high, '高', Colors.red),
        ],
      ),
    );
  }

  Widget _buildPriorityOption(BuildContext ctx, TaskPriority priority, String label, Color? color) {
    return SimpleDialogOption(
      onPressed: () {
        setState(() => _selectedPriority = priority);
        Navigator.pop(ctx);
      },
      child: Row(
        children: [
          Icon(Icons.flag, size: 20, color: color ?? AmberColors.textDisabled),
          const SizedBox(width: 12),
          Text(label),
          const Spacer(),
          if (_selectedPriority == priority)
            const Icon(Icons.check, color: AmberColors.primary, size: 20),
        ],
      ),
    );
  }

  /// 显示标签选择对话框
  void _showTagsDialog(BuildContext context, List<Tag> tags) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('选择标签'),
          content: SizedBox(
            width: 280,
            child: tags.isEmpty
                ? const Center(child: Text('暂无标签'))
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tags.map((tag) {
                      final isSelected = _selectedTags.contains(tag.name);
                      return FilterChip(
                        label: Text(tag.name),
                        selected: isSelected,
                        selectedColor: AmberColors.primary.withValues(alpha: 0.2),
                        onSelected: (selected) {
                          setDialogState(() {
                            if (selected) {
                              _selectedTags.add(tag.name);
                            } else {
                              _selectedTags.remove(tag.name);
                            }
                          });
                          setState(() {});
                        },
                      );
                    }).toList(),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('完成'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // 编辑任务时的选择器
  // ============================================================

  /// 编辑任务日期
  Future<void> _editTaskDate(Task task) async {
    final date = await showDatePicker(
      context: context,
      initialDate: task.dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (date != null) {
      final updatedTask = task.copyWith(
        dueDate: AmberDateUtils.normalizeToUtcDate(date),
      );
      ref.read(taskProvider.notifier).updateTask(updatedTask);
    }
  }

  /// 编辑任务清单
  void _editTaskList(Task task, List<TaskList> lists) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择清单'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              final updatedTask = task.copyWith(listId: null);
              ref.read(taskProvider.notifier).updateTask(updatedTask);
              Navigator.pop(ctx);
            },
            child: Row(
              children: [
                const Icon(Icons.inbox_outlined, size: 20),
                const SizedBox(width: 12),
                const Text('收集箱'),
                const Spacer(),
                if (task.listId == null)
                  const Icon(Icons.check, color: AmberColors.primary, size: 20),
              ],
            ),
          ),
          ...lists.map((list) => SimpleDialogOption(
                onPressed: () {
                  final updatedTask = task.copyWith(listId: list.id);
                  ref.read(taskProvider.notifier).updateTask(updatedTask);
                  Navigator.pop(ctx);
                },
                child: Row(
                  children: [
                    Icon(Icons.list, size: 20, color: list.color),
                    const SizedBox(width: 12),
                    Text(list.name),
                    const Spacer(),
                    if (task.listId == list.id)
                      const Icon(Icons.check, color: AmberColors.primary, size: 20),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  /// 编辑任务优先级
  void _editTaskPriority(Task task) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择优先级'),
        children: [
          _buildEditPriorityOption(ctx, task, TaskPriority.none, '无', null),
          _buildEditPriorityOption(ctx, task, TaskPriority.low, '低', Colors.green),
          _buildEditPriorityOption(ctx, task, TaskPriority.medium, '中', Colors.orange),
          _buildEditPriorityOption(ctx, task, TaskPriority.high, '高', Colors.red),
        ],
      ),
    );
  }

  Widget _buildEditPriorityOption(
      BuildContext ctx, Task task, TaskPriority priority, String label, Color? color) {
    return SimpleDialogOption(
      onPressed: () {
        final updatedTask = task.copyWith(priority: priority);
        ref.read(taskProvider.notifier).updateTask(updatedTask);
        Navigator.pop(ctx);
      },
      child: Row(
        children: [
          Icon(Icons.flag, size: 20, color: color ?? AmberColors.textDisabled),
          const SizedBox(width: 12),
          Text(label),
          const Spacer(),
          if (task.priority == priority)
            const Icon(Icons.check, color: AmberColors.primary, size: 20),
        ],
      ),
    );
  }

  /// 编辑任务标签
  void _editTaskTags(Task task, List<Tag> allTags) {
    List<String> selectedTags = List.from(task.tags);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('选择标签'),
          content: SizedBox(
            width: 280,
            child: allTags.isEmpty
                ? const Center(child: Text('暂无标签'))
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: allTags.map((tag) {
                      final isSelected = selectedTags.contains(tag.name);
                      return FilterChip(
                        label: Text(tag.name),
                        selected: isSelected,
                        selectedColor: AmberColors.primary.withValues(alpha: 0.2),
                        onSelected: (selected) {
                          setDialogState(() {
                            if (selected) {
                              selectedTags.add(tag.name);
                            } else {
                              selectedTags.remove(tag.name);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final updatedTask = task.copyWith(tags: selectedTags);
                ref.read(taskProvider.notifier).updateTask(updatedTask);
                Navigator.pop(ctx);
              },
              child: const Text('完成'),
            ),
          ],
        ),
      ),
    );
  }
}
