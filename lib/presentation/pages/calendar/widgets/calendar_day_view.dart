import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/constants.dart';
import '../../../../data/models/models.dart';
import '../../../widgets/task_item.dart';

/// 日历日视图
/// 显示选中日期的所有任务
class CalendarDayView extends StatelessWidget {
  /// 选中的日期
  final DateTime? selectedDay;

  /// 当天的任务列表
  final List<Task> dayTasks;

  const CalendarDayView({
    super.key,
    required this.selectedDay,
    required this.dayTasks,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedDay == null) {
      return const Center(child: Text('请选择一个日期'));
    }

    return Column(
      children: [
        // 顶部显示选中的日期
        Container(
          padding: const EdgeInsets.symmetric(vertical: AmberDimens.spacingMd),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AmberColors.divider)),
          ),
          child: Center(
            child: Text(
              DateFormat('yyyy年MM月dd日 EEEE', 'zh_CN').format(selectedDay!),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),

        // 任务列表
        Expanded(
          child: dayTasks.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    vertical: AmberDimens.spacingMd,
                  ),
                  itemCount: dayTasks.length,
                  itemBuilder: (context, index) {
                    final task = dayTasks[index];
                    return _buildDayViewTaskItem(task);
                  },
                ),
        ),
      ],
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            FluentIcons.checkmark_circle_24_regular,
            size: 48,
            color: AmberColors.textDisabled.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            '今天没有安排任务',
            style: TextStyle(color: AmberColors.textSecondary),
          ),
        ],
      ),
    );
  }

  /// 构建日视图任务项
  Widget _buildDayViewTaskItem(Task task) {
    Widget? timeBadge;
    if (task.dueDate != null &&
        (task.dueDate!.hour != 0 || task.dueDate!.minute != 0)) {
      timeBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          DateFormat('HH:mm').format(task.dueDate!),
          style: const TextStyle(
            fontSize: 12,
            color: AmberColors.textSecondary,
            fontWeight: FontWeight.w500,
            fontFamily: 'Monospace',
          ),
        ),
      );
    }

    return TaskItem(task: task, trailing: timeBadge);
  }
}
