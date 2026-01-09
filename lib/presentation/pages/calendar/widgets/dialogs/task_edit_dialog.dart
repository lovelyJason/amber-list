import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/constants.dart';
import '../../../../../core/utils/date_utils.dart';
import '../../../../../data/models/models.dart';
import '../../../../providers/providers.dart';

/// 单列模式下的任务编辑对话框
/// 用于编辑任务的标题、截止日期、清单、优先级、标签
/// 通过双击任务列表项触发
///
/// 特点：
/// - 标题支持编辑
/// - 本地状态管理，点击保存才提交
/// - 取消按钮放弃修改
class TaskEditDialog extends ConsumerStatefulWidget {
  final Task task;

  const TaskEditDialog({super.key, required this.task});

  @override
  ConsumerState<TaskEditDialog> createState() => _TaskEditDialogState();
}

class _TaskEditDialogState extends ConsumerState<TaskEditDialog> {
  late TextEditingController _titleController;
  late DateTime? _selectedDate;
  late String? _selectedListId;
  late TaskPriority _selectedPriority;
  late List<String> _selectedTags;

  @override
  void initState() {
    super.initState();
    // 初始化本地状态
    _titleController = TextEditingController(text: widget.task.title);
    _selectedDate = widget.task.dueDate;
    _selectedListId = widget.task.listId;
    _selectedPriority = widget.task.priority;
    _selectedTags = List.from(widget.task.tags);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  /// 保存任务
  void _saveTask() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final updatedTask = widget.task.copyWith(
      title: title,
      dueDate: _selectedDate != null
          ? AmberDateUtils.normalizeToUtcDate(_selectedDate!)
          : null,
      listId: _selectedListId,
      priority: _selectedPriority,
      tags: _selectedTags,
    );

    ref.read(taskProvider.notifier).updateTask(updatedTask);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(taskListProvider);
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

    return AlertDialog(
      title: const Text(
        '编辑任务',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 任务标题输入框
            TextField(
              controller: _titleController,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: '任务标题',
                hintStyle: TextStyle(
                  color: AmberColors.textDisabled,
                  fontWeight: FontWeight.normal,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AmberColors.primary),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            // 选项列表
            _buildOptionRow(
              icon: Icons.calendar_today_outlined,
              label: '截止日期',
              value: _selectedDate != null
                  ? DateFormat('yyyy年M月d日', 'zh_CN').format(_selectedDate!)
                  : '无',
              onTap: _showDatePicker,
            ),
            _buildOptionRow(
              icon: Icons.list_alt_outlined,
              label: '清单',
              value: listName,
              onTap: () => _showListPicker(lists),
            ),
            _buildOptionRow(
              icon: Icons.flag_outlined,
              label: '优先级',
              value: priorityText,
              valueColor: priorityColor,
              onTap: _showPriorityPicker,
            ),
            _buildOptionRow(
              icon: Icons.label_outline,
              label: '标签',
              value: _selectedTags.isEmpty ? '无' : _selectedTags.join(', '),
              onTap: () => _showTagsDialog(tags),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _titleController.text.trim().isNotEmpty ? _saveTask : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AmberColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('保存'),
        ),
      ],
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AmberColors.textSecondary),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontSize: 14)),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                  fontSize: 14, color: valueColor ?? AmberColors.textSecondary),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                size: 18, color: AmberColors.textDisabled),
          ],
        ),
      ),
    );
  }

  /// 显示日期选择器
  Future<void> _showDatePicker() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  /// 显示清单选择器
  void _showListPicker(List<TaskList> lists) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择清单'),
        children: [
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
  void _showPriorityPicker() {
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
  void _showTagsDialog(List<Tag> allTags) {
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
}
