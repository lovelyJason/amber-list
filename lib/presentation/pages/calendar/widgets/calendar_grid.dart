import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/utils/chinese_holidays.dart';
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
        border: Border.all(color: Colors.grey[200]!, width: 0.5),
      ),
      padding: const EdgeInsets.all(4),
      // ClipRect 静默裁剪溢出内容，避免 iOS 上报 overflow 错误
      child: ClipRect(
        child: Opacity(
          opacity: isOutside ? 0.4 : 1.0,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 需要至少 56px 才能显示日期(24) + 间距(4) + 图标(24) + 余量(4)
              final showTodayIcon = constraints.maxWidth >= 56;
              // 获取节假日名称
              final holiday = ChineseHolidays.getHoliday(day);

              // 动态计算可显示任务数（iOS 设备格子小，可能只能放 2 个）
              // 可用高度 = 总高度 - 日期行(24) - 间距(4) - padding(8)
              final availableHeight = constraints.maxHeight - 36;
              // 每个任务项约 20px（fontSize 10 实际渲染 ~14 + padding 4 + margin 2）
              // "+X more" 文本约 14px
              const taskItemHeight = 20.0;
              const moreTextHeight = 14.0;
              // 计算最多能放几个任务（上限 3）
              int maxTasks = (availableHeight / taskItemHeight).floor().clamp(0, 3);
              // 如果任务数超过 maxTasks，需要预留 "+X more" 空间
              if (dayTasks.length > maxTasks && maxTasks > 0) {
                final remaining = availableHeight - (maxTasks * taskItemHeight);
                if (remaining < moreTextHeight) {
                  maxTasks = (maxTasks - 1).clamp(0, 3);
                }
              }
              final visibleTasks = dayTasks.take(maxTasks).toList();
              final hasMore = dayTasks.length > maxTasks;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 日期数字行
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
                            fontWeight:
                                isToday ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      // 仅在宽度足够时显示今日图标（桌面端显示，移动端隐藏）
                      if (isToday && showTodayIcon) ...[
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
                      // 节假日名称显示
                      if (holiday != null && !isToday) ...[
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            holiday,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: isOutside
                                  ? AmberColors.textDisabled
                                  : AmberColors.priorityHigh,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  // 任务列表（根据可用空间动态显示 2-3 个）
                  ...visibleTasks.map((task) {
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
                  if (hasMore)
                    Text(
                      '+${dayTasks.length - maxTasks} more',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AmberColors.textSecondary,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );

    // 外部月份日期（置灰的日期）不可点击和双击
    if (isOutside) {
      return content;
    }

    // 所有当前月份的日期都支持单击选中和双击弹窗
    // 双击弹窗可以查看/添加当天任务
    return InkWell(
      onDoubleTap: () => onDayDoubleTap(day, dayTasks),
      // 修复：单元格点击时，focusedDay 应该更新为点击的日期
      // 而不是沿用组件属性中的旧 focusedDay
      onTap: () => onDaySelected(day, day),
      borderRadius: BorderRadius.circular(4),
      child: content,
    );
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
