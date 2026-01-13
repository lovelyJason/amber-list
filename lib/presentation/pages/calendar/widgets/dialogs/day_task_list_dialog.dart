import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../../core/constants/constants.dart';
import '../../../../../core/utils/date_utils.dart';
import '../../../../../data/models/models.dart';
import '../../../../providers/providers.dart';
import '../../../../widgets/common/tag_selector_dialog.dart';
import '../../../../widgets/task_item.dart';

/// 当天任务列表弹窗组件
/// 包含展开式任务输入框和任务列表
/// 支持单列/双列两种布局模式：
/// - 单列模式：任务列表全宽，双击任务弹出编辑对话框
/// - 双列模式：左侧任务列表 + 右侧详情面板，单击选中任务
class DayTaskListDialog extends ConsumerStatefulWidget {
  final DateTime day;

  const DayTaskListDialog({super.key, required this.day});

  @override
  ConsumerState<DayTaskListDialog> createState() => _DayTaskListDialogState();
}

class _DayTaskListDialogState extends ConsumerState<DayTaskListDialog> {
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

  /// 构建布局切换按钮
  Widget _buildLayoutToggleButton({
    required IconData icon,
    required String tooltip,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isSelected
                ? AmberColors.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isSelected ? AmberColors.primary : AmberColors.textSecondary,
          ),
        ),
      ),
    );
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

    // 判断是否为移动端（宽度小于 600）
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    // 从 Provider 读取布局偏好（移动端强制单列模式）
    final calendarPrefs = ref.watch(calendarPreferencesProvider);
    final isTwoColumnMode = isMobile
        ? false
        : calendarPrefs.dialogLayout == CalendarDialogLayout.twoColumn;

    // 如果正在编辑任务，从最新列表中获取更新后的任务数据
    if (_editingTask != null) {
      final updatedTask =
          allTasks.where((t) => t.id == _editingTask!.id).firstOrNull;
      if (updatedTask == null) {
        // 任务被删除了，需要在下一帧重置编辑面板
        // 不能直接在 build 里 setState，用 addPostFrameCallback 延迟处理
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() => _editingTask = null);
          }
        });
      } else {
        // 任务数据有更新，同步到编辑面板（这里直接赋值没问题，因为下次 build 会用新值）
        _editingTask = updatedTask;
      }
    }

    // 双列模式下始终显示右侧面板，单列模式下不显示
    final showRightPanel = isTwoColumnMode;

    return AlertDialog(
      title: Row(
        children: [
          Expanded(
            child: Text(
              DateFormat('yyyy年MM月dd日 EEEE', 'zh_CN').format(widget.day),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          // 布局切换按钮（移动端隐藏，强制单列模式）
          if (!isMobile)
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 单列模式按钮
                  _buildLayoutToggleButton(
                    icon: Icons.view_agenda_outlined,
                    tooltip: '单列模式',
                    isSelected: !isTwoColumnMode,
                    onTap: () {
                      ref
                          .read(calendarPreferencesProvider.notifier)
                          .setDialogLayout(CalendarDialogLayout.singleColumn);
                      setState(() => _editingTask = null);
                    },
                  ),
                  // 双列模式按钮
                  _buildLayoutToggleButton(
                    icon: Icons.view_sidebar_outlined,
                    tooltip: '双列模式',
                    isSelected: isTwoColumnMode,
                    onTap: () => ref
                        .read(calendarPreferencesProvider.notifier)
                        .setDialogLayout(CalendarDialogLayout.twoColumn),
                  ),
                ],
              ),
            ),
        ],
      ),
      content: SizedBox(
        // 移动端自适应宽度，桌面端固定宽度
        width: isMobile
            ? screenWidth * 0.9
            : (showRightPanel ? 900 : 550),
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
                  // 任务列表（与输入框保持相同宽度和样式）
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFEEEEEE),
                          width: 1,
                        ),
                      ),
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
                              behavior:
                                  ScrollConfiguration.of(context).copyWith(
                                scrollbars: false,
                              ),
                              child: ListView.builder(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                shrinkWrap: true,
                                itemCount: currentDayTasks.length,
                                itemBuilder: (context, index) {
                                  final task = currentDayTasks[index];
                                  // 双列模式：单击选中任务显示右侧详情
                                  // 单列模式：使用 GestureDetector 捕获双击弹出编辑对话框
                                  if (isTwoColumnMode) {
                                    // 双列模式：单击选中任务显示右侧详情面板
                                    // 选中状态通过 isSelected 参数传入，覆盖默认的全局导航状态判断
                                    return TaskItem(
                                      task: task,
                                      isSelected: _editingTask?.id == task.id,
                                      onTap: () =>
                                          setState(() => _editingTask = task),
                                    );
                                  } else {
                                    // 单列模式：双击任务时切换到双列模式并选中该任务
                                    return GestureDetector(
                                      onDoubleTap: () {
                                        // 切换到双列模式
                                        ref
                                            .read(calendarPreferencesProvider.notifier)
                                            .setDialogLayout(CalendarDialogLayout.twoColumn);
                                        // 选中当前任务
                                        setState(() => _editingTask = task);
                                      },
                                      child: TaskItem(task: task),
                                    );
                                  }
                                },
                              ),
                            ),
                    ),
                  ),
                  // 底部操作按钮（全选/反选/关闭）
                  const SizedBox(height: AmberDimens.spacingSm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          for (var task in currentDayTasks) {
                            if (!task.isCompleted) {
                              ref
                                  .read(taskProvider.notifier)
                                  .toggleTaskComplete(task.id);
                            }
                          }
                        },
                        child: const Text('全选'),
                      ),
                      TextButton(
                        onPressed: () {
                          for (var task in currentDayTasks) {
                            ref
                                .read(taskProvider.notifier)
                                .toggleTaskComplete(task.id);
                          }
                        },
                        child: const Text('反选'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('关闭'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 右侧：任务详情编辑面板（仅双列模式显示）
            if (showRightPanel) ...[
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: _editingTask != null
                    ? _buildTaskDetailPanel(_editingTask!)
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.touch_app_outlined,
                              size: 48,
                              color: AmberColors.textDisabled,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '点击左侧任务查看详情',
                              style: TextStyle(
                                color: AmberColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ],
        ),
      ),
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
                      hintText:
                          '添加任务到 ${DateFormat('M月d日', 'zh_CN').format(_selectedDate)}...',
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
                // Enter 按钮（紧凑模式下显示，展开模式下用透明占位保持布局一致）
                if (!_isExpanded)
                  InkWell(
                    onTap: () {
                      if (_inputController.text.trim().isNotEmpty) {
                        _addTask();
                      }
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AmberColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: AmberColors.primary.withValues(alpha: 0.3)),
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
                          Icon(Icons.keyboard_return_rounded,
                              size: 12, color: AmberColors.primary),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(width: 6),
                // 展开/收起按钮（固定在最右侧，位置保持不变）
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
              style:
                  const TextStyle(fontSize: 13, color: AmberColors.textSecondary),
            ),
            const Spacer(),
            Text(
              value,
              style:
                  TextStyle(fontSize: 13, color: valueColor ?? AmberColors.textPrimary),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                size: 16, color: AmberColors.textDisabled),
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

  /// 构建任务详情编辑面板（双列模式右侧面板）
  Widget _buildTaskDetailPanel(Task task) {
    final lists = ref.watch(taskListProvider);

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
          // 标题栏（双列模式下不需要关闭按钮，点击左边任务即可切换）
          const Text(
            '编辑任务',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          // 任务标题
          Text(
            task.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
              color:
                  task.isCompleted ? AmberColors.textDisabled : AmberColors.textPrimary,
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
            onTap: () => _editTaskTags(task),
          ),
          // 创建时间（精确到时分秒，不可编辑）
          _buildEditOptionRow(
            icon: Icons.access_time_outlined,
            label: '创建时间',
            value: DateFormat('yyyy年M月d日 HH:mm:ss').format(task.createdAt),
            onTap: () {}, // 不可编辑，空操作
            showArrow: false,
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
    bool showArrow = true,
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
              style:
                  TextStyle(fontSize: 14, color: valueColor ?? AmberColors.textSecondary),
            ),
            if (showArrow) ...[
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  size: 18, color: AmberColors.textDisabled),
            ],
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
                      const Icon(Icons.check,
                          color: AmberColors.primary, size: 20),
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

  Widget _buildPriorityOption(
      BuildContext ctx, TaskPriority priority, String label, Color? color) {
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
                        selectedColor:
                            AmberColors.primary.withValues(alpha: 0.2),
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
  // 编辑任务时的选择器（双列模式右侧面板）
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
                      const Icon(Icons.check,
                          color: AmberColors.primary, size: 20),
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
          _buildEditPriorityOption(
              ctx, task, TaskPriority.low, '低', Colors.green),
          _buildEditPriorityOption(
              ctx, task, TaskPriority.medium, '中', Colors.orange),
          _buildEditPriorityOption(
              ctx, task, TaskPriority.high, '高', Colors.red),
        ],
      ),
    );
  }

  Widget _buildEditPriorityOption(BuildContext ctx, Task task,
      TaskPriority priority, String label, Color? color) {
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
  /// 使用统一的 TagSelectorDialog 组件
  Future<void> _editTaskTags(Task task) async {
    final result = await TagSelectorDialog.show(
      context: context,
      ref: ref,
      selectedTags: task.tags,
      title: '管理任务标签',
    );

    if (result != null) {
      final updatedTask = task.copyWith(tags: result);
      ref.read(taskProvider.notifier).updateTask(updatedTask);
    }
  }
}
