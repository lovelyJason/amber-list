import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:window_manager/window_manager.dart';

import '../../../../core/constants/constants.dart';
import '../../../../data/models/models.dart';
import '../calendar_page.dart';
import 'hand_drawn_circle_painter.dart';

/// 日历左侧边栏
/// 包含标题、小日历导航、视图切换
class CalendarLeftSidebar extends StatelessWidget {
  /// 当前聚焦日期
  final DateTime focusedDay;

  /// 当前选中日期
  final DateTime? selectedDay;

  /// 当前视图模式
  final CalendarViewMode viewMode;

  /// 所有任务列表（用于显示日期标记）
  final List<Task> tasks;

  /// 添加按钮的 Showcase Key
  final GlobalKey addKey;

  /// 视图模式的 Showcase Key
  final GlobalKey viewModeKey;

  /// 日期选择回调
  final void Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;

  /// 页面切换回调
  final void Function(DateTime focusedDay) onPageChanged;

  /// 视图模式切换回调
  final void Function(CalendarViewMode mode) onViewModeChanged;

  /// 添加按钮点击回调
  final VoidCallback onAddPressed;

  const CalendarLeftSidebar({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.viewMode,
    required this.tasks,
    required this.addKey,
    required this.viewModeKey,
    required this.onDaySelected,
    required this.onPageChanged,
    required this.onViewModeChanged,
    required this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题栏
        _buildHeader(),

        // 小型月历导航
        _buildMiniCalendar(),

        const SizedBox(height: AmberDimens.spacingLg),

        // 视图切换
        _buildSectionTitle('视图'),
        Showcase(
          key: viewModeKey,
          title: '视图切换',
          description: '切换月、周、日视图，满足不同场景需求',
          child: _buildSidebarItem(
            icon: FluentIcons.calendar_month_24_regular,
            label: '月视图',
            isSelected: viewMode == CalendarViewMode.month,
            onTap: () => onViewModeChanged(CalendarViewMode.month),
            activeColor: AmberColors.primaryLight,
            activeIconColor: AmberColors.primary,
          ),
        ),
        _buildSidebarItem(
          icon: FluentIcons.calendar_work_week_24_regular,
          label: '周视图',
          isSelected: viewMode == CalendarViewMode.week,
          onTap: () => onViewModeChanged(CalendarViewMode.week),
          activeColor: AmberColors.primaryLight,
          activeIconColor: AmberColors.primary,
        ),
        _buildSidebarItem(
          icon: FluentIcons.calendar_day_24_regular,
          label: '日视图',
          isSelected: viewMode == CalendarViewMode.day,
          onTap: () => onViewModeChanged(CalendarViewMode.day),
          activeColor: AmberColors.primaryLight,
          activeIconColor: AmberColors.primary,
        ),

        const SizedBox(height: AmberDimens.spacingLg),
      ],
    );
  }

  /// 构建标题栏
  Widget _buildHeader() {
    return DragToMoveArea(
      child: Padding(
        padding: const EdgeInsets.all(AmberDimens.spacingLg),
        child: Row(
          children: [
            Icon(
              FluentIcons.calendar_ltr_24_filled,
              color: AmberColors.primary,
              size: 28,
            ),
            const SizedBox(width: AmberDimens.spacingSm),
            const Text(
              '日历',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AmberColors.textPrimary,
              ),
            ),
            const Spacer(),
            Showcase(
              key: addKey,
              title: '快速添加',
              description: '点击这里快速添加任务 (Spotlight)',
              child: IconButton(
                icon: const Icon(FluentIcons.add_24_regular, size: 20),
                onPressed: onAddPressed,
                splashRadius: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建小型月历导航
  Widget _buildMiniCalendar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AmberDimens.spacingMd),
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: focusedDay,
        selectedDayPredicate: (day) => isSameDay(selectedDay, day),
        calendarFormat: CalendarFormat.month,
        locale: 'zh_CN',
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          leftChevronIcon:
              Icon(FluentIcons.chevron_left_20_regular, size: 16),
          rightChevronIcon:
              Icon(FluentIcons.chevron_right_20_regular, size: 16),
          headerPadding: EdgeInsets.zero,
        ),
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(
            color: Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: AmberColors.primary),
          ),
          todayTextStyle: const TextStyle(color: AmberColors.primary),
          selectedDecoration: const BoxDecoration(
            color: AmberColors.primary,
            shape: BoxShape.circle,
          ),
          cellMargin: const EdgeInsets.all(4),
          defaultTextStyle: const TextStyle(fontSize: 12),
          weekendTextStyle: const TextStyle(
            fontSize: 12,
            color: AmberColors.textSecondary,
          ),
          outsideTextStyle: const TextStyle(
            fontSize: 12,
            color: AmberColors.textDisabled,
          ),
        ),
        calendarBuilders: CalendarBuilders(
          dowBuilder: (context, day) {
            final text = DateFormat.E('zh_CN').format(day);
            return Center(
              child: Text(
                text.replaceAll('周', ''),
                style: const TextStyle(
                  fontSize: 12,
                  color: AmberColors.textSecondary,
                ),
              ),
            );
          },
          markerBuilder: (context, day, events) {
            // 检查当天是否有任务
            final hasTasks = tasks.any((t) {
              if (t.dueDate == null) return false;
              return isSameDay(t.dueDate, day);
            });

            if (hasTasks) {
              return Positioned.fill(
                child: CustomPaint(painter: HandDrawnCirclePainter()),
              );
            }
            return null;
          },
        ),
        onDaySelected: onDaySelected,
        onPageChanged: onPageChanged,
      ),
    );
  }

  /// 构建分组标题
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AmberDimens.spacingLg,
        vertical: AmberDimens.spacingSm,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          color: AmberColors.textDisabled,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  /// 构建侧边栏项
  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? activeColor,
    Color? activeIconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AmberDimens.spacingMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: 10,
            horizontal: AmberDimens.spacingSm,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? (activeColor ?? AmberColors.primaryLight)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? (activeIconColor ?? AmberColors.primary)
                    : AmberColors.textSecondary,
              ),
              const SizedBox(width: AmberDimens.spacingMd),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected && activeIconColor != null
                      ? activeIconColor
                      : AmberColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
