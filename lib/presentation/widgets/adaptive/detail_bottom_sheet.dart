import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/constants.dart';
import '../../../data/models/models.dart';
import '../../providers/providers.dart';

/// ============================================================
/// 移动端任务详情面板（BottomSheet 形式）
/// ============================================================
/// 用于在移动端展示任务详情，替代桌面端的侧边栏面板
///
/// 设计说明：
/// - 使用 DraggableScrollableSheet 实现可拖拽的底部抽屉
/// - 采用 Modern/Premium 风格：大标题、干净的列表项、无框输入区
/// - 支持手势滑动关闭
/// - 所有布局使用弹性约束，适配不同屏幕尺寸
class DetailBottomSheet {
  DetailBottomSheet._();

  /// 显示任务详情底部抽屉
  /// [context] 当前上下文
  /// [task] 要显示的任务
  static void show(BuildContext context, Task task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 允许占满屏幕高度
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (context) => _DetailSheetContent(task: task),
    );
  }

  /// 显示任务详情（通过任务ID）
  /// 会从 Provider 中查找任务
  static void showById(BuildContext context, WidgetRef ref, String taskId) {
    final tasks = ref.read(taskProvider);
    final task = tasks.where((t) => t.id == taskId).firstOrNull;
    if (task != null) {
      show(context, task);
    }
  }
}

/// 详情抽屉内容组件
/// 使用 ConsumerStatefulWidget 以支持 Provider 和 TextEditingController
class _DetailSheetContent extends ConsumerStatefulWidget {
  final Task task;

  const _DetailSheetContent({required this.task});

  @override
  ConsumerState<_DetailSheetContent> createState() => _DetailSheetContentState();
}

class _DetailSheetContentState extends ConsumerState<_DetailSheetContent> {
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late FocusNode _descFocusNode;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _descController = TextEditingController(text: widget.task.description ?? '');
    _descFocusNode = FocusNode();
    _descFocusNode.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _descFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taskLists = ref.watch(taskListProvider);
    final currentList = taskLists.where((l) => l.id == widget.task.listId).firstOrNull;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.25,
      maxChildSize: 0.95,
      snap: true,
      snapSizes: const [0.4, 0.7, 0.95],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AmberColors.cardBackground,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AmberDimens.radiusXl),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              // 顶部拖拽指示器（点击关闭）
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: _buildDragHandle(),
              ),
              // 任务详情内容（可滚动）
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AmberDimens.spacingMd,
                  ),
                  children: [
                    // 标题输入框
                    _buildTitleField(),
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
                          : () => _showTagsDialog(context),
                    ),
                    const SizedBox(height: AmberDimens.spacingLg),
                    // 描述区域
                    _buildDescriptionSection(),
                    const SizedBox(height: AmberDimens.spacingLg),
                    // 底部信息和删除按钮
                    _buildFooter(),
                    // 底部安全区域
                    SizedBox(height: MediaQuery.of(context).padding.bottom + AmberDimens.spacingMd),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建顶部拖拽指示器
  Widget _buildDragHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 20),
      width: 48,
      height: 5,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(2.5),
      ),
    );
  }

  /// 构建标题输入框
  Widget _buildTitleField() {
    return TextField(
      controller: _titleController,
      readOnly: widget.task.isDeleted,
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: widget.task.isDeleted
            ? AmberColors.textSecondary
            : AmberColors.textPrimary,
        fontFamily: 'PingFang SC', // 确保中文显示效果
      ),
      decoration: const InputDecoration(
        border: InputBorder.none,
        hintText: '准备做什么？',
        hintStyle: TextStyle(color: Colors.black26),
        contentPadding: EdgeInsets.zero,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      ),
      onSubmitted: widget.task.isDeleted ? null : _updateTitle,
    );
  }

  /// 构建属性行（日期、清单、优先级、标签）
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
        padding: const EdgeInsets.symmetric(vertical: AmberDimens.spacingMd),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AmberColors.textSecondary),
            const SizedBox(width: AmberDimens.spacingMd),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                color: AmberColors.textSecondary,
              ),
            ),
            const SizedBox(width: AmberDimens.spacingMd),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 16,
                  color: valueColor ?? AmberColors.textPrimary.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            // 小箭头更精致一点
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Colors.grey.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建描述区域
  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.description_outlined,
              size: 20,
              color: AmberColors.textSecondary,
            ),
            const SizedBox(width: 8),
            const Text(
              '描述',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AmberColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _descFocusNode.hasFocus
                ? AmberColors.primary.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _descFocusNode.hasFocus
                  ? AmberColors.primary.withOpacity(0.2)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: TextField(
            controller: _descController,
            focusNode: _descFocusNode,
            readOnly: widget.task.isDeleted,
            maxLines: null,
            minLines: 3,
            cursorColor: AmberColors.primary,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              color: AmberColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: widget.task.isDeleted ? null : '添加详细描述...',
              hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false, // 覆盖主题默认的 true
              contentPadding: const EdgeInsets.all(16),
            ),
            onChanged: widget.task.isDeleted ? null : _updateDescription,
          ),
        ),
      ],
    );
  }

  /// 构建底部信息和操作
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AmberDimens.spacingMd),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AmberColors.divider)),
      ),
      child: Row(
        children: [
          Text(
            '创建于 ${DateFormat('M月d日').format(widget.task.createdAt)}',
            style: const TextStyle(
              fontSize: 13,
              color: AmberColors.textDisabled,
            ),
          ),
          const Spacer(),
          if (!widget.task.isDeleted)
            TextButton.icon(
              onPressed: _deleteTask,
              icon: const Icon(Icons.delete_outline, size: 20),
              label: const Text('删除'),
              style: TextButton.styleFrom(
                foregroundColor: AmberColors.warning,
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // 数据更新方法
  // ============================================================

  void _updateTitle(String title) {
    if (title.trim().isEmpty) return;
    ref.read(taskProvider.notifier).updateTask(
      widget.task.copyWith(title: title.trim(), updatedAt: DateTime.now()),
    );
  }

  void _updateDescription(String desc) {
    ref.read(taskProvider.notifier).updateTask(
      widget.task.copyWith(description: desc, updatedAt: DateTime.now()),
    );
  }

  // ============================================================
  // 选择器弹窗
  // ============================================================

  /// 显示日期选择器
  Future<void> _showDatePicker(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: widget.task.dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (date != null) {
      ref.read(taskProvider.notifier).updateTask(
        widget.task.copyWith(dueDate: date, updatedAt: DateTime.now()),
      );
    }
  }

  /// 显示清单选择器
  void _showListPicker(BuildContext context, List<TaskList> lists) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AmberColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 收集箱选项
            ListTile(
              leading: const Icon(Icons.inbox_rounded, color: AmberColors.textSecondary),
              title: const Text('收集箱'),
              onTap: () {
                ref.read(taskProvider.notifier).updateTask(
                  widget.task.copyWith(listId: null, updatedAt: DateTime.now()),
                );
                Navigator.pop(context);
              },
            ),
            // 其他清单
            ...lists.map((list) => ListTile(
              leading: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: list.color,
                  shape: BoxShape.circle,
                ),
              ),
              title: Text(list.name),
              onTap: () {
                ref.read(taskProvider.notifier).updateTask(
                  widget.task.copyWith(listId: list.id, updatedAt: DateTime.now()),
                );
                Navigator.pop(context);
              },
            )),
            const SizedBox(height: AmberDimens.spacingMd),
          ],
        ),
      ),
    );
  }

  /// 显示优先级选择器
  void _showPriorityPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AmberColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag, color: AmberColors.priorityHigh),
              title: const Text('高优先级'),
              onTap: () => _setPriority(TaskPriority.high),
            ),
            ListTile(
              leading: const Icon(Icons.flag, color: AmberColors.priorityMedium),
              title: const Text('中优先级'),
              onTap: () => _setPriority(TaskPriority.medium),
            ),
            ListTile(
              leading: const Icon(Icons.flag, color: AmberColors.priorityLow),
              title: const Text('低优先级'),
              onTap: () => _setPriority(TaskPriority.low),
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: AmberColors.priorityNone),
              title: const Text('无优先级'),
              onTap: () => _setPriority(TaskPriority.none),
            ),
            const SizedBox(height: AmberDimens.spacingMd),
          ],
        ),
      ),
    );
  }

  void _setPriority(TaskPriority priority) {
    ref.read(taskProvider.notifier).updateTask(
      widget.task.copyWith(priority: priority, updatedAt: DateTime.now()),
    );
    Navigator.pop(context);
  }

  /// 显示标签选择器
  void _showTagsDialog(BuildContext context) {
    final allTags = ref.read(tagsProvider);
    final selectedTags = List<String>.from(widget.task.tags);

    showModalBottomSheet(
      context: context,
      backgroundColor: AmberColors.cardBackground,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AmberDimens.spacingMd),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '选择标签',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AmberDimens.spacingMd),
                if (allTags.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AmberDimens.spacingLg),
                    child: Center(child: Text('暂无可用标签')),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: allTags.map((tag) {
                      final isSelected = selectedTags.contains(tag.name);
                      final tagColor = tag.color;

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
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? tagColor.withValues(alpha: 0.15)
                                : Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? tagColor.withValues(alpha: 0.5)
                                  : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            tag.name,
                            style: TextStyle(
                              fontSize: 14,
                              color: isSelected ? tagColor : AmberColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: AmberDimens.spacingLg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: AmberDimens.spacingSm),
                    ElevatedButton(
                      onPressed: () {
                        ref.read(taskProvider.notifier).updateTask(
                          widget.task.copyWith(tags: selectedTags),
                        );
                        Navigator.pop(context);
                      },
                      child: const Text('保存'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 删除任务
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
            onPressed: () {
              ref.read(soundServiceProvider).playDelete();
              ref.read(taskProvider.notifier).deleteTask(widget.task.id);
              Navigator.pop(context); // 关闭确认对话框
              Navigator.pop(context); // 关闭 BottomSheet
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 辅助方法
  // ============================================================

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
