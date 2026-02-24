import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/constants.dart';
import '../../../../data/models/task.dart';

/// 嵌入式任务卡片
///
/// 设计哲学：
/// - 在笔记关联任务区域以卡片形式展示任务摘要
/// - 显示任务标题、完成状态、截止日期、优先级
/// - 点击复选框可直接切换完成状态
/// - 点击卡片跳转到任务详情
class EmbeddedTaskCard extends StatelessWidget {
  final Task task;

  /// 点击卡片跳转任务详情
  final VoidCallback? onTap;

  /// 切换完成状态
  final ValueChanged<bool>? onToggleComplete;

  /// 取消关联
  final VoidCallback? onUnlink;

  const EmbeddedTaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.onToggleComplete,
    this.onUnlink,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(AmberDimens.spacingSm),
        decoration: BoxDecoration(
          color: task.isCompleted
              ? AmberColors.divider.withValues(alpha: 0.3)
              : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _borderColor,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // 完成状态复选框
            _buildCheckbox(),
            const SizedBox(width: AmberDimens.spacingSm),
            // 任务信息（标题 + 元数据）
            Expanded(child: _buildTaskInfo()),
            // 取消关联按钮
            if (onUnlink != null) _buildUnlinkButton(),
          ],
        ),
      ),
    );
  }

  /// 左侧完成状态复选框
  Widget _buildCheckbox() {
    return GestureDetector(
      onTap: () => onToggleComplete?.call(!task.isCompleted),
      child: Icon(
        task.isCompleted
            ? Icons.check_circle
            : Icons.radio_button_unchecked,
        size: 20,
        color: task.isCompleted
            ? AmberColors.primary
            : AmberColors.textSecondary,
      ),
    );
  }

  /// 任务信息：标题 + 截止日期 / 优先级标签
  Widget _buildTaskInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 标题
        Text(
          task.title,
          style: TextStyle(
            fontSize: 13,
            color: task.isCompleted
                ? AmberColors.textSecondary
                : AmberColors.textPrimary,
            decoration:
                task.isCompleted ? TextDecoration.lineThrough : null,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // 元数据行（截止日期 + 优先级）
        if (_hasMetadata) ...[
          const SizedBox(height: 2),
          _buildMetadataRow(),
        ],
      ],
    );
  }

  /// 是否有元数据需要显示
  bool get _hasMetadata =>
      task.dueDate != null || task.priority != TaskPriority.none;

  /// 元数据行：截止日期 + 优先级
  Widget _buildMetadataRow() {
    return Row(
      children: [
        if (task.dueDate != null) ...[
          Icon(
            Icons.calendar_today_outlined,
            size: 12,
            color: _dueDateColor,
          ),
          const SizedBox(width: 2),
          Text(
            DateFormat('MM/dd').format(task.dueDate!),
            style: TextStyle(fontSize: 11, color: _dueDateColor),
          ),
          const SizedBox(width: AmberDimens.spacingSm),
        ],
        if (task.priority != TaskPriority.none) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: _priorityColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              task.priority.label,
              style: TextStyle(fontSize: 10, color: _priorityColor),
            ),
          ),
        ],
      ],
    );
  }

  /// 取消关联按钮
  Widget _buildUnlinkButton() {
    return GestureDetector(
      onTap: onUnlink,
      child: const Padding(
        padding: EdgeInsets.all(4),
        child: Icon(
          Icons.close,
          size: 14,
          color: AmberColors.textSecondary,
        ),
      ),
    );
  }

  /// 卡片边框颜色（根据优先级）
  Color get _borderColor {
    if (task.isCompleted) return AmberColors.divider;
    if (task.priority == TaskPriority.high) {
      return Colors.red.withValues(alpha: 0.3);
    }
    return AmberColors.divider;
  }

  /// 截止日期颜色（过期为红色）
  Color get _dueDateColor {
    if (task.dueDate == null) return AmberColors.textSecondary;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (task.dueDate!.isBefore(today) && !task.isCompleted) {
      return Colors.red;
    }
    return AmberColors.textSecondary;
  }

  /// 优先级颜色
  Color get _priorityColor {
    switch (task.priority) {
      case TaskPriority.high:
        return Colors.red;
      case TaskPriority.medium:
        return Colors.orange;
      case TaskPriority.low:
        return Colors.blue;
      case TaskPriority.none:
        return AmberColors.textSecondary;
    }
  }
}
