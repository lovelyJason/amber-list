import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:window_manager/window_manager.dart';

import '../../../../core/constants/constants.dart';
import '../../../../data/models/models.dart';
import '../calendar_page.dart';

/// 日历顶部导航栏
/// 包含导航按钮、搜索框、筛选按钮
class CalendarHeader extends StatelessWidget {
  /// 当前聚焦日期
  final DateTime focusedDay;

  /// 当前视图模式
  final CalendarViewMode viewMode;

  /// 搜索查询
  final String searchQuery;

  /// 优先级筛选
  final Set<TaskPriority> filterPriorities;

  /// 完成状态筛选
  final bool? filterIsCompleted;

  /// 导航按钮的 Showcase Key
  final GlobalKey navKey;

  /// 今天按钮的 Showcase Key
  final GlobalKey todayKey;

  /// 搜索变更回调
  final ValueChanged<String> onSearchChanged;

  /// 上一页回调
  final VoidCallback onPreviousPage;

  /// 下一页回调
  final VoidCallback onNextPage;

  /// 回到今天回调
  final VoidCallback onGoToToday;

  /// 筛选菜单点击回调
  final void Function(BuildContext context) onFilterPressed;

  const CalendarHeader({
    super.key,
    required this.focusedDay,
    required this.viewMode,
    required this.searchQuery,
    required this.filterPriorities,
    required this.filterIsCompleted,
    required this.navKey,
    required this.todayKey,
    required this.onSearchChanged,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onGoToToday,
    required this.onFilterPressed,
  });

  @override
  Widget build(BuildContext context) {
    return DragToMoveArea(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AmberDimens.spacingLg,
          vertical: AmberDimens.spacingMd,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: AmberColors.divider)),
        ),
        child: Row(
          children: [
            // 导航按钮组
            _buildNavigationButtons(context),
            const Spacer(),
            // 搜索栏
            _buildSearchBar(),
            const SizedBox(width: AmberDimens.spacingMd),
            // 筛选按钮
            _buildFilterButton(context),
          ],
        ),
      ),
    );
  }

  /// 构建导航按钮组
  Widget _buildNavigationButtons(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AmberColors.divider),
        borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 上一页按钮
          Showcase(
            key: navKey,
            title: '日历导航',
            description: '点击切换上一月/周/日',
            child: Tooltip(
              message: _getPreviousTooltip(),
              child: IconButton(
                icon: const Icon(
                  FluentIcons.chevron_left_20_regular,
                  size: 18,
                ),
                onPressed: onPreviousPage,
                splashRadius: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
            ),
          ),
          Container(width: 1, height: 20, color: AmberColors.divider),
          // 今天显示
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Showcase(
              key: todayKey,
              title: '当前日期',
              description: '点击图标快速回到今天',
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      isSameDay(focusedDay, DateTime.now())
                          ? '今天'
                          : DateFormat('M月d日', 'zh_CN').format(focusedDay),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (!isSameDay(focusedDay, DateTime.now()))
                    Tooltip(
                      message: '回到今天',
                      child: IconButton(
                        icon: const Icon(
                          FluentIcons.calendar_today_16_regular,
                          size: 16,
                          color: AmberColors.primary,
                        ),
                        onPressed: onGoToToday,
                        splashRadius: 16,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Container(width: 1, height: 20, color: AmberColors.divider),
          // 下一页按钮
          Tooltip(
            message: _getNextTooltip(),
            child: IconButton(
              icon: const Icon(
                FluentIcons.chevron_right_20_regular,
                size: 18,
              ),
              onPressed: onNextPage,
              splashRadius: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建搜索栏
  Widget _buildSearchBar() {
    return Flexible(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 240),
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              FluentIcons.search_20_regular,
              size: 16,
              color: AmberColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Transform.translate(
                offset: const Offset(0, -2.5),
                child: TextField(
                  onChanged: onSearchChanged,
                  cursorColor: AmberColors.primary,
                  textAlignVertical: TextAlignVertical.center,
                  style: const TextStyle(fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: '搜索任务...',
                    hintStyle: TextStyle(
                      color: AmberColors.textDisabled,
                      fontSize: 13,
                    ),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    filled: false,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建筛选按钮
  Widget _buildFilterButton(BuildContext context) {
    return Builder(
      builder: (buttonContext) => IconButton(
        icon: Icon(
          FluentIcons.filter_20_regular,
          color: (filterPriorities.isNotEmpty || filterIsCompleted != null)
              ? AmberColors.primary
              : AmberColors.textSecondary,
        ),
        tooltip: '筛选',
        onPressed: () => onFilterPressed(buttonContext),
      ),
    );
  }

  String _getPreviousTooltip() {
    switch (viewMode) {
      case CalendarViewMode.month:
        return '前一月';
      case CalendarViewMode.week:
        return '前一周';
      case CalendarViewMode.day:
        return '前一天';
    }
  }

  String _getNextTooltip() {
    switch (viewMode) {
      case CalendarViewMode.month:
        return '下一月';
      case CalendarViewMode.week:
        return '下一周';
      case CalendarViewMode.day:
        return '后一天';
    }
  }
}
