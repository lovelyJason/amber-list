import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/constants/constants.dart';
import '../../../../data/models/models.dart';

/// 日历网格组件
/// 显示月视图或周视图的日历网格
class CalendarGrid extends StatelessWidget {
  /// 当前聚焦日期
  final DateTime focusedDay;

  /// 当前选中日期
  final DateTime? selectedDay;

  /// 日历格式（月/周）
  final CalendarFormat calendarFormat;

  /// 任务列表
  final List<Task> tasks;

  /// 日期选择回调
  final void Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;

  /// 页面切换回调
  final void Function(DateTime focusedDay) onPageChanged;

  /// 双击日期回调（显示任务列表）
  final void Function(DateTime day, List<Task> dayTasks) onDayDoubleTap;

  const CalendarGrid({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.calendarFormat,
    required this.tasks,
    required this.onDaySelected,
    required this.onPageChanged,
    required this.onDayDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    return TableCalendar(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: focusedDay,
      selectedDayPredicate: (day) => isSameDay(selectedDay, day),
      calendarFormat: calendarFormat,
      locale: 'zh_CN',
      startingDayOfWeek: StartingDayOfWeek.sunday,
      headerVisible: false,
      shouldFillViewport: true,
      daysOfWeekHeight: 40,
      daysOfWeekStyle: const DaysOfWeekStyle(
        weekdayStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: AmberColors.textSecondary,
        ),
        weekendStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: AmberColors.textSecondary,
        ),
      ),
      calendarStyle: CalendarStyle(
        outsideDaysVisible: true,
        cellMargin: EdgeInsets.zero,
        defaultTextStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        weekendTextStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        todayDecoration: const BoxDecoration(color: Colors.transparent),
        todayTextStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AmberColors.primary,
        ),
        selectedDecoration: const BoxDecoration(color: Colors.transparent),
        selectedTextStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      onPageChanged: onPageChanged,
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) => _buildCell(day),
        todayBuilder: (context, day, focusedDay) =>
            _buildCell(day, isToday: true),
        outsideBuilder: (context, day, focusedDay) => _buildCell(
          day,
          isOutside: true,
          isSelected: isSameDay(day, selectedDay),
        ),
        selectedBuilder: (context, day, focusedDay) => _buildCell(
          day,
          isSelected: true,
          isToday: isSameDay(day, DateTime.now()),
        ),
      ),
      onDaySelected: (selected, focused) {
        // 禁止选中外部月份的日期
        if (selected.month != focused.month) {
          return;
        }
        onDaySelected(selected, focused);
      },
    );
  }

  /// 构建单元格
  Widget _buildCell(
    DateTime day, {
    bool isToday = false,
    bool isOutside = false,
    bool isSelected = false,
  }) {
    // 过滤当天的任务
    final dayTasks = tasks.where((task) {
      if (task.dueDate == null) return false;
      return isSameDay(task.dueDate, day);
    }).toList();

    final content = Container(
      decoration: BoxDecoration(
        color: isOutside
            ? Colors.grey[100]
            : (isSelected
                ? AmberColors.primary.withValues(alpha: 0.05)
                : Colors.white),
        border: Border.all(color: Colors.grey[200]!),
      ),
      padding: const EdgeInsets.all(4),
      child: Opacity(
        opacity: isOutside ? 0.4 : 1.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日期数字
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: isToday
                      ? const BoxDecoration(
                          color: AmberColors.primary,
                          shape: BoxShape.circle,
                        )
                      : null,
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      color: isToday
                          ? Colors.white
                          : (isOutside
                              ? AmberColors.textDisabled
                              : AmberColors.textPrimary),
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                if (isToday) ...[
                  const SizedBox(width: 4),
                  ClipOval(
                    child: Image.asset(
                      'assets/images/mosquito_amber.png',
                      width: 24,
                      height: 24,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            // 任务列表 (最多显示3个)
            ...dayTasks.take(3).map((task) {
              return Tooltip(
                message: task.title,
                waitDuration: const Duration(milliseconds: 500),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(task.priority)
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _getPriorityColor(task.priority)
                          .withValues(alpha: 0.5),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: _getPriorityColor(task.priority),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }),
            if (dayTasks.length > 3)
              Text(
                '+${dayTasks.length - 3} more',
                style: const TextStyle(
                  fontSize: 10,
                  color: AmberColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );

    // 外部月份日期不可点击
    if (isOutside) {
      return content;
    }

    if (dayTasks.isNotEmpty) {
      return InkWell(
        onDoubleTap: () => onDayDoubleTap(day, dayTasks),
        onTap: () => onDaySelected(day, focusedDay),
        borderRadius: BorderRadius.circular(4),
        child: content,
      );
    }
    return content;
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
        return AmberColors.primary;
    }
  }
}
