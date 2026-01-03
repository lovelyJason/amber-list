import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/constants/constants.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/models.dart';
import '../providers/providers.dart';

/// 任务详情面板
class TaskDetailPanel extends ConsumerStatefulWidget {
  final Task task;

  const TaskDetailPanel({super.key, required this.task});

  @override
  ConsumerState<TaskDetailPanel> createState() => _TaskDetailPanelState();
}

class _TaskDetailPanelState extends ConsumerState<TaskDetailPanel> {
  late TextEditingController _titleController;
  late TextEditingController _descController;

  /// FocusNode 用于监听标题输入框的失焦事件
  late FocusNode _titleFocusNode;
  /// FocusNode 用于监听描述输入框的失焦事件
  late FocusNode _descFocusNode;

  /// 记录原始标题值，用于判断是否有修改
  late String _originalTitle;
  /// 记录原始描述值，用于判断是否有修改
  late String _originalDesc;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _descController = TextEditingController(text: widget.task.description ?? '');

    _originalTitle = widget.task.title;
    _originalDesc = widget.task.description ?? '';

    _titleFocusNode = FocusNode();
    _descFocusNode = FocusNode();

    // 监听标题输入框失焦事件，失焦时保存
    _titleFocusNode.addListener(_onTitleFocusChange);
    // 监听描述输入框失焦事件，失焦时保存
    _descFocusNode.addListener(_onDescFocusChange);
  }

  @override
  void didUpdateWidget(covariant TaskDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 切换到不同任务时，重置输入框和原始值
    if (oldWidget.task.id != widget.task.id) {
      _titleController.text = widget.task.title;
      _descController.text = widget.task.description ?? '';
      _originalTitle = widget.task.title;
      _originalDesc = widget.task.description ?? '';
    }
  }

  @override
  void dispose() {
    // 移除监听器
    _titleFocusNode.removeListener(_onTitleFocusChange);
    _descFocusNode.removeListener(_onDescFocusChange);
    _titleFocusNode.dispose();
    _descFocusNode.dispose();
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  /// 标题输入框失焦回调：失焦时保存标题
  void _onTitleFocusChange() {
    if (!_titleFocusNode.hasFocus) {
      _saveTitleIfChanged();
    }
  }

  /// 描述输入框失焦回调：失焦时保存描述
  void _onDescFocusChange() {
    if (!_descFocusNode.hasFocus) {
      _saveDescIfChanged();
    }
  }

  /// 保存标题（仅当有变化时）
  void _saveTitleIfChanged() {
    final newTitle = _titleController.text.trim();
    if (newTitle.isNotEmpty && newTitle != _originalTitle) {
      ref.read(taskProvider.notifier).updateTask(
        widget.task.copyWith(title: newTitle, updatedAt: DateTime.now()),
      );
      _originalTitle = newTitle; // 更新原始值，避免重复保存
    }
  }

  /// 保存描述（仅当有变化时）
  void _saveDescIfChanged() {
    final newDesc = _descController.text;
    if (newDesc != _originalDesc) {
      ref.read(taskProvider.notifier).updateTask(
        widget.task.copyWith(description: newDesc, updatedAt: DateTime.now()),
      );
      _originalDesc = newDesc; // 更新原始值，避免重复保存
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskLists = ref.watch(taskListProvider);
    final currentList = taskLists.where((l) => l.id == widget.task.listId).firstOrNull;

    return Container(
      width: AmberDimens.detailPanelWidth,
      color: AmberColors.cardBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部
          _buildHeader(),
          const Divider(height: 1),
          // 内容
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AmberDimens.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题输入框：失焦或回车时保存，关闭时丢弃修改
                  TextField(
                    controller: _titleController,
                    focusNode: _titleFocusNode,
                    readOnly: widget.task.isDeleted,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: widget.task.isDeleted
                          ? AmberColors.textSecondary
                          : AmberColors.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: '任务标题',
                    ),
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    // 回车键保存标题并移除焦点
                    onSubmitted: widget.task.isDeleted ? null : (_) {
                      _saveTitleIfChanged();
                      _titleFocusNode.unfocus();
                    },
                  ),
                  const SizedBox(height: AmberDimens.spacingMd),
                  // 属性列表
                  _buildPropertyRow(
                    icon: Icons.calendar_today_outlined,
                    label: '截止日期',
                    value: widget.task.dueDate != null
                        ? DateFormat('yyyy年M月d日').format(widget.task.dueDate!)
                        : '未设置',
                    onTap: widget.task.isDeleted
                        ? null
                        : () => _showDatePicker(context),
                  ),
                  _buildPropertyRow(
                    icon: Icons.list_rounded,
                    label: '清单',
                    value: currentList?.name ?? '收集箱',
                    valueColor: currentList?.color,
                    onTap: widget.task.isDeleted
                        ? null
                        : () => _showListPicker(context, taskLists),
                  ),
                  _buildPropertyRow(
                    icon: Icons.flag_outlined,
                    label: '优先级',
                    value: _getPriorityText(widget.task.priority),
                    valueColor: _getPriorityColor(widget.task.priority),
                    onTap: widget.task.isDeleted
                        ? null
                        : () => _showPriorityPicker(context),
                  ),
                  _buildPropertyRow(
                    icon: Icons.label_outline,
                    label: '标签',
                    value: widget.task.tags.isEmpty
                        ? '添加标签'
                        : widget.task.tags.join(', '),
                    onTap: widget.task.isDeleted
                        ? null
                        : () {
                            _showTagsDialog(context);
                          },
                  ),
                  const SizedBox(height: AmberDimens.spacingLg),
                  // 描述
                  const Text(
                    '描述',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AmberColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AmberDimens.spacingSm),
                  // 描述输入框：失焦时保存，关闭时丢弃修改
                  TextField(
                    controller: _descController,
                    focusNode: _descFocusNode,
                    readOnly: widget.task.isDeleted,
                    maxLines: null,
                    minLines: 4,
                    decoration: InputDecoration(
                      hintText: widget.task.isDeleted ? null : '添加描述...',
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    // 描述不需要 onSubmitted，因为多行文本回车是换行
                    // 只在失焦时通过 FocusNode 监听器保存
                  ),
                ],
              ),
            ),
          ),
          // 底部操作栏
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AmberDimens.spacingMd,
        vertical: AmberDimens.spacingSm,
      ),
      child: Row(
        children: [
          const Text(
            '任务详情',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AmberColors.textSecondary,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              // 关闭面板，失焦时会自动保存修改
              ref.read(appNavProvider.notifier).closeDetailPanel();
            },
            icon: const Icon(Icons.close, size: 20),
            tooltip: '关闭',
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AmberDimens.spacingSm),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AmberColors.textSecondary),
            const SizedBox(width: AmberDimens.spacingMd),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AmberColors.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: valueColor ?? AmberColors.textPrimary,
              ),
            ),
            const SizedBox(width: AmberDimens.spacingXs),
            const Icon(Icons.chevron_right, size: 18, color: AmberColors.textDisabled),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(AmberDimens.spacingMd),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AmberColors.divider)),
      ),
      child: Row(
        children: [
          Text(
            '创建于 ${DateFormat('M月d日').format(widget.task.createdAt)}',
            style: const TextStyle(
              fontSize: 12,
              color: AmberColors.textDisabled,
            ),
          ),
          const Spacer(),
          if (!widget.task.isDeleted)
            IconButton(
              onPressed: () {
                _deleteTask();
              },
              icon: const Icon(Icons.delete_outline, size: 20),
              color: AmberColors.warning,
              tooltip: '删除任务',
              splashRadius: 18,
            ),
        ],
      ),
    );
  }

  Future<void> _showDatePicker(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: widget.task.dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            datePickerTheme: const DatePickerThemeData(
              headerHeadlineStyle: TextStyle(
                fontSize: 16, // Smaller font size to prevent wrapping
                fontWeight: FontWeight.bold,
              ),
              headerHelpStyle: TextStyle(fontSize: 14),
            ),
          ),
          child: child!,
        );
      },
    );
    if (date != null) {
      // 规范化为 UTC 日期存储，确保跨设备同步时日期一致
      final normalizedDate = AmberDateUtils.normalizeToUtcDate(date);
      ref.read(taskProvider.notifier).updateTask(
        widget.task.copyWith(dueDate: normalizedDate, updatedAt: DateTime.now()),
      );
    }
  }

  void _showListPicker(BuildContext context, List<TaskList> lists) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          width: 320,
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () {
                    ref
                        .read(taskProvider.notifier)
                        .updateTask(
                          widget.task.copyWith(
                            listId: null,
                            updatedAt: DateTime.now(),
                          ),
                        );
                    Navigator.pop(context);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.inbox_rounded,
                          size: 20,
                          color: AmberColors.textSecondary,
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          '收集箱',
                          style: TextStyle(
                            fontSize: 16,
                            color: AmberColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ...lists.map(
                  (list) => InkWell(
                    onTap: () {
                      ref
                          .read(taskProvider.notifier)
                          .updateTask(
                            widget.task.copyWith(
                              listId: list.id,
                              updatedAt: DateTime.now(),
                            ),
                          );
                      Navigator.pop(context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: list.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(
                            width: 20,
                          ), // Align with icon center (20px icon / 2 = 10; 12px dot / 2 = 6; diff ~4, plus gap) -> roughly
                          // Actually icon is 20, dot is 12. Center alignment:
                          // Icon center at 10. Dot center at 6.
                          // To align text start:
                          // IconRow: Icon(20) + Gap(16) -> Text starts at 36
                          // DotRow: Dot(12) + Gap(?) -> Text starts at 36?
                          // Gap = 36 - 12 = 24.
                          // Let's use SizedBox(width: 24) for dot.
                          Text(
                            list.name,
                            style: const TextStyle(
                              fontSize: 16,
                              color: AmberColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPriorityPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('设置优先级'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              ref
                  .read(taskProvider.notifier)
                  .updateTask(
                    widget.task.copyWith(
                      priority: TaskPriority.high,
                      updatedAt: DateTime.now(),
                    ),
                  );
              Navigator.pop(context);
            },
            child: const Row(
              children: [
                Icon(Icons.flag, color: AmberColors.priorityHigh, size: 18),
                SizedBox(width: 8),
                Text('高优先级'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              ref
                  .read(taskProvider.notifier)
                  .updateTask(
                    widget.task.copyWith(
                      priority: TaskPriority.medium,
                      updatedAt: DateTime.now(),
                    ),
                  );
              Navigator.pop(context);
            },
            child: const Row(
              children: [
                Icon(Icons.flag, color: AmberColors.priorityMedium, size: 18),
                SizedBox(width: 8),
                Text('中优先级'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              ref
                  .read(taskProvider.notifier)
                  .updateTask(
                    widget.task.copyWith(
                      priority: TaskPriority.low,
                      updatedAt: DateTime.now(),
                    ),
                  );
              Navigator.pop(context);
            },
            child: const Row(
              children: [
                Icon(Icons.flag, color: AmberColors.priorityLow, size: 18),
                SizedBox(width: 8),
                Text('低优先级'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              ref
                  .read(taskProvider.notifier)
                  .updateTask(
                    widget.task.copyWith(
                      priority: TaskPriority.none,
                      updatedAt: DateTime.now(),
                    ),
                  );
              Navigator.pop(context);
            },
            child: const Row(
              children: [
                Icon(
                  Icons.flag_outlined,
                  color: AmberColors.priorityNone,
                  size: 18,
                ),
                SizedBox(width: 8),
                Text('无优先级'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _deleteTask() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除任务'),
        content: const Text('确定要删除这个任务吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AmberColors.warning,
            ),
            child: const Text('删除'),
            onPressed: () async {
              final success = await ref
                  .read(taskProvider.notifier)
                  .deleteTask(widget.task.id);

              if (!context.mounted) return;

              if (success) {
                ref.read(soundServiceProvider).playDelete();
                ref.read(appNavProvider.notifier).closeDetailPanel();
                Navigator.pop(context);
              } else {
                // 有番茄记录冲突
                Navigator.pop(context); // 先关闭当前对话框
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('无法删除'),
                    content: const Text(
                      '该任务有关联的番茄时钟记录。\n\n'
                      '请先前往番茄时钟页面删除相关记录，或选择"强制删除"移入垃圾桶。',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          ref
                              .read(taskProvider.notifier)
                              .forceDeleteTask(widget.task.id);
                          ref.read(soundServiceProvider).playDelete();
                          ref.read(appNavProvider.notifier).closeDetailPanel();
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                        child: const Text(
                          '强制删除',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  String _getPriorityText(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return '高';
      case TaskPriority.medium:
        return '中';
      case TaskPriority.low:
        return '低';
      case TaskPriority.none:
        return '无';
    }
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return AmberColors.priorityHigh;
      case TaskPriority.medium:
        return AmberColors.priorityMedium;
      case TaskPriority.low:
        return AmberColors.priorityLow;
      case TaskPriority.none:
        return AmberColors.priorityNone;
    }
  }
  void _showTagsDialog(BuildContext context) {
    final allTags = ref.read(tagsProvider);
    final selectedTags = List<String>.from(widget.task.tags);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('管理任务标签'),
          content: SizedBox(
            width: 300,
            child: allTags.isEmpty
                ? const Center(child: Text('暂无可用标签'))
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: allTags.map((tag) {
                      final isSelected = selectedTags.contains(tag.name);
                      final tagColor = tag.color; // Tag.color is Color

                      return InkWell(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              selectedTags.remove(tag.name);
                            } else {
                              selectedTags.add(tag.name);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            // 选中时显示浅色背景，未选中显示灰色背景
                            color: isSelected
                                ? tagColor.withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              // 选中时显示同色边框，未选中无边框
                              color: isSelected
                                  ? tagColor.withOpacity(0.3)
                                  : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            tag.name,
                            style: TextStyle(
                              fontSize: 12,
                              // 选中时显示同色文字，未选中显示深灰文字
                              color: isSelected
                                  ? tagColor
                                  : AmberColors.textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                ref
                    .read(taskProvider.notifier)
                    .updateTask(widget.task.copyWith(tags: selectedTags));
                Navigator.pop(context);
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
  }
}
