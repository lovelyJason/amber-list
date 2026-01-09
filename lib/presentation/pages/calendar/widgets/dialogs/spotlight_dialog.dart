import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../../core/constants/constants.dart';
import '../../../../../core/utils/date_utils.dart';
import '../../../../../data/models/models.dart';
import '../../../../providers/providers.dart';

/// Spotlight 搜索对话框 - 快速添加任务
///
/// 支持两种模式：
/// - 紧凑模式：只有标题输入框，回车即可添加
/// - 展开模式：显示截止日期、清单、优先级、标签等选项（点击展开按钮）
class SpotlightDialog extends ConsumerStatefulWidget {
  final DateTime selectedDate;
  final Function(String) onTaskCreated;

  const SpotlightDialog({
    super.key,
    required this.selectedDate,
    required this.onTaskCreated,
  });

  @override
  ConsumerState<SpotlightDialog> createState() => _SpotlightDialogState();
}

class _SpotlightDialogState extends ConsumerState<SpotlightDialog> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

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

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate;
    // Request focus after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 提交任务
  void _submitTask() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;

    // 规范化日期
    final normalizedDate = AmberDateUtils.normalizeToUtcDate(_selectedDate);

    // 创建任务
    ref.read(taskProvider.notifier).createTask(
      title: title,
      dueDate: normalizedDate,
      listId: _selectedListId,
      priority: _selectedPriority,
      tags: _selectedTags,
    );

    // 播放音效
    ref.read(soundServiceProvider).playAdd();

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 输入区域
          _buildInputArea(),

          // 展开模式：显示选项
          if (_isExpanded) ...[
            const Divider(height: 1),
            _buildOptionsArea(),
            const Divider(height: 1),
            _buildFooter(),
          ],
        ],
      ),
    );
  }

  /// 构建输入区域
  Widget _buildInputArea() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Logo
          ClipOval(
            child: Image.asset(
              'assets/images/mosquito_amber.png',
              width: 32,
              height: 32,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          // 输入框
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                filled: false,
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: '添加任务到 ${DateFormat('M月d日', 'zh_CN').format(_selectedDate)}...',
                hintStyle: TextStyle(
                  color: AmberColors.textDisabled.withValues(alpha: 0.5),
                  fontSize: 18,
                ),
              ),
              onChanged: (_) {
                // 输入内容变化时刷新 UI，更新添加按钮的启用状态
                setState(() {});
              },
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  _submitTask();
                }
              },
            ),
          ),
          const SizedBox(width: 12),
          // 展开/收起按钮
          IconButton(
            onPressed: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            icon: Icon(
              _isExpanded ? Icons.expand_less : Icons.expand_more,
              color: AmberColors.textSecondary,
            ),
            tooltip: _isExpanded ? '收起选项' : '展开选项',
            splashRadius: 18,
          ),
          // Enter 按钮（仅紧凑模式显示，可点击提交）
          if (!_isExpanded)
            InkWell(
              onTap: () {
                if (_controller.text.trim().isNotEmpty) {
                  _submitTask();
                }
              },
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AmberColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AmberColors.primary.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Text(
                      'Enter',
                      style: TextStyle(
                        color: AmberColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_return_rounded,
                      size: 14,
                      color: AmberColors.primary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 构建选项区域（截止日期、清单、优先级、标签）
  Widget _buildOptionsArea() {
    final taskLists = ref.watch(taskListProvider);
    final currentList = taskLists.where((l) => l.id == _selectedListId).firstOrNull;
    final allTags = ref.watch(tagsProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // 截止日期
          _buildOptionRow(
            icon: Icons.calendar_today_outlined,
            label: '截止日期',
            value: DateFormat('yyyy年M月d日').format(_selectedDate),
            onTap: () => _showDatePicker(context),
          ),
          // 清单
          _buildOptionRow(
            icon: Icons.list_rounded,
            label: '清单',
            value: currentList?.name ?? '收集箱',
            valueColor: currentList?.color,
            onTap: () => _showListPicker(context, taskLists),
          ),
          // 优先级
          _buildOptionRow(
            icon: Icons.flag_outlined,
            label: '优先级',
            value: _getPriorityText(_selectedPriority),
            valueColor: _getPriorityColor(_selectedPriority),
            onTap: () => _showPriorityPicker(context),
          ),
          // 标签
          _buildOptionRow(
            icon: Icons.label_outline,
            label: '标签',
            value: _selectedTags.isEmpty ? '添加标签' : _selectedTags.join(', '),
            onTap: () => _showTagsDialog(context, allTags),
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
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AmberColors.textSecondary),
            const SizedBox(width: 12),
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
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: AmberColors.textDisabled),
          ],
        ),
      ),
    );
  }

  /// 构建底部操作栏
  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _controller.text.trim().isNotEmpty ? _submitTask : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AmberColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  /// 显示日期选择器
  Future<void> _showDatePicker(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
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
    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  /// 显示清单选择器
  void _showListPicker(BuildContext context, List<TaskList> lists) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
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
                // 收集箱
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedListId = null;
                    });
                    Navigator.pop(dialogContext);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.inbox_rounded, size: 20, color: AmberColors.textSecondary),
                        const SizedBox(width: 16),
                        const Text('收集箱', style: TextStyle(fontSize: 16, color: AmberColors.textPrimary)),
                        const Spacer(),
                        if (_selectedListId == null)
                          const Icon(Icons.check, size: 18, color: AmberColors.primary),
                      ],
                    ),
                  ),
                ),
                // 其他清单
                ...lists.map(
                  (list) => InkWell(
                    onTap: () {
                      setState(() {
                        _selectedListId = list.id;
                      });
                      Navigator.pop(dialogContext);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                          const SizedBox(width: 20),
                          Text(list.name, style: const TextStyle(fontSize: 16, color: AmberColors.textPrimary)),
                          const Spacer(),
                          if (_selectedListId == list.id)
                            const Icon(Icons.check, size: 18, color: AmberColors.primary),
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

  /// 显示优先级选择器
  void _showPriorityPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('设置优先级'),
        children: [
          _buildPriorityOption(dialogContext, TaskPriority.high, '高优先级', AmberColors.priorityHigh),
          _buildPriorityOption(dialogContext, TaskPriority.medium, '中优先级', AmberColors.priorityMedium),
          _buildPriorityOption(dialogContext, TaskPriority.low, '低优先级', AmberColors.priorityLow),
          _buildPriorityOption(dialogContext, TaskPriority.none, '无优先级', AmberColors.priorityNone),
        ],
      ),
    );
  }

  Widget _buildPriorityOption(BuildContext dialogContext, TaskPriority priority, String label, Color color) {
    return SimpleDialogOption(
      onPressed: () {
        setState(() {
          _selectedPriority = priority;
        });
        Navigator.pop(dialogContext);
      },
      child: Row(
        children: [
          Icon(
            priority == TaskPriority.none ? Icons.flag_outlined : Icons.flag,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(label),
          const Spacer(),
          if (_selectedPriority == priority)
            const Icon(Icons.check, size: 18, color: AmberColors.primary),
        ],
      ),
    );
  }

  /// 显示标签选择对话框
  void _showTagsDialog(BuildContext context, List<Tag> allTags) {
    final selectedTags = List<String>.from(_selectedTags);

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('选择标签'),
          content: SizedBox(
            width: 300,
            child: allTags.isEmpty
                ? const Center(child: Text('暂无可用标签'))
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: allTags.map((tag) {
                      final isSelected = selectedTags.contains(tag.name);
                      final tagColor = tag.color;

                      return InkWell(
                        onTap: () {
                          setDialogState(() {
                            if (isSelected) {
                              selectedTags.remove(tag.name);
                            } else {
                              selectedTags.add(tag.name);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? tagColor.withValues(alpha: 0.1)
                                : Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isSelected
                                  ? tagColor.withValues(alpha: 0.3)
                                  : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            tag.name,
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected ? tagColor : AmberColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedTags = selectedTags;
                });
                Navigator.pop(dialogContext);
              },
              child: const Text('确定'),
            ),
          ],
        ),
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
}
