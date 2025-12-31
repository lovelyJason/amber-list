import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:window_manager/window_manager.dart'; // Add import
import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/common/toast/toast_manager.dart';
import '../../../core/constants/constants.dart';
import '../../../data/models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/task_item.dart';
import 'widgets/spotlight_dialog.dart';
import 'widgets/hand_drawn_circle_painter.dart';


/// 日历页面
class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}


enum CalendarViewMode { month, week, day }

class _CalendarPageState extends ConsumerState<CalendarPage> {
  CalendarViewMode _viewMode = CalendarViewMode.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // 🔍 搜索和筛选状态
  String _searchQuery = '';
  Set<TaskPriority> _filterPriorities = {}; // 空集合表示全选
  bool? _filterIsCompleted; // null: 全部, true: 已完成, false: 未完成

  // Onboarding Keys
  final GlobalKey _addKey = GlobalKey();
  final GlobalKey _viewModeKey = GlobalKey();
  final GlobalKey _navKey = GlobalKey();
  final GlobalKey _todayKey = GlobalKey();
  final GlobalKey _gridKey = GlobalKey();

  bool _hasCheckedTour = false;

  void _checkShowcase(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('has_seen_calendar_tour') ?? false;

    if (!hasSeen && context.mounted) {
      ShowCaseWidget.of(
        context,
      ).startShowCase([_addKey, _viewModeKey, _navKey, _todayKey, _gridKey]);
      await prefs.setBool('has_seen_calendar_tour', true);
    }
  }



  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
  }
  
  CalendarFormat get _currentCalendarFormat {
    switch (_viewMode) {
      case CalendarViewMode.month:
        return CalendarFormat.month;
      case CalendarViewMode.week:
        return CalendarFormat.week;
      case CalendarViewMode.day:
        return CalendarFormat
            .month; // Day view hides calendar, so this doesn't matter much
    }
  }

  @override
  Widget build(BuildContext context) {
    final allTasks = ref.watch(taskProvider);
    final tasks = allTasks.where((task) {
      // 1. 搜索过滤
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchTitle = task.title.toLowerCase().contains(query);
        final matchDesc =
            task.description?.toLowerCase().contains(query) ?? false;
        if (!matchTitle && !matchDesc) return false;
      }

      // 2. 优先级过滤
      if (_filterPriorities.isNotEmpty) {
        if (!_filterPriorities.contains(task.priority)) return false;
      }

      // 3. 完成状态过滤
      if (_filterIsCompleted != null) {
        if (task.isCompleted != _filterIsCompleted) return false;
      }

      return true;
    }).toList();

    return ShowCaseWidget(
      builder: (context) {
        if (!_hasCheckedTour) {
          _hasCheckedTour = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkShowcase(context);
          });
        }
        return Scaffold(
          backgroundColor: AmberColors.background,
          body: Row(
            children: [
              // 左侧：视图和筛选 (对应截图最左侧的 Calendar Sidebar)
              Container(
                width: 260,
                decoration: const BoxDecoration(
                  color: Colors.white, // 左侧栏似乎是白色的
                  border: Border(right: BorderSide(color: AmberColors.divider)),
                ),
                child: _buildLeftSidebar(tasks),
              ),

              // 中间：日历主体
              Expanded(
                child: Column(
                  children: [
                    _buildCalendarHeader(),
                    Expanded(
                      child: Showcase(
                        key: _gridKey,
                        title: '任务管理',
                        description: '双击有任务的日期，快速查看和管理当天任务',
                        child: _buildCalendar(tasks),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // === 左侧边栏 ===

  Widget _buildLeftSidebar(List<Task> tasks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DragToMoveArea(
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
                  key: _addKey,
                  title: '快速添加',
                  description: '点击这里快速添加任务 (Spotlight)',
                  child: IconButton(
                    icon: const Icon(FluentIcons.add_24_regular, size: 20),
                    onPressed: () {
                      _showSpotlightSearch(context);
                    },
                    splashRadius: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // 小型月历导航
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AmberDimens.spacingMd),
          child: TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: CalendarFormat.month,
            locale: 'zh_CN',
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              leftChevronIcon: Icon(FluentIcons.chevron_left_20_regular, size: 16),
              rightChevronIcon: Icon(FluentIcons.chevron_right_20_regular, size: 16),
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
              weekendTextStyle: const TextStyle(fontSize: 12, color: AmberColors.textSecondary),
              outsideTextStyle: const TextStyle(fontSize: 12, color: AmberColors.textDisabled),
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
                // Check if any tasks exist for this day
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
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) {
              // 这里的翻页不应该影响主日历的 focusedDay，除非需要联动
              // 暂时不联动，或者联动？截图里通常是联动的
              setState(() => _focusedDay = focusedDay);
            },
          ),
        ),

        const SizedBox(height: AmberDimens.spacingLg),

        // VIEWS 分区
        _buildSectionTitle('视图'),
        Showcase(
          key: _viewModeKey,
          title: '视图切换',
          description: '切换月、周、日视图，满足不同场景需求',
          child: _buildSidebarItem(
            icon: FluentIcons.calendar_month_24_regular,
            label: '月视图',
            isSelected: _viewMode == CalendarViewMode.month,
            onTap: () => setState(() {
              _viewMode = CalendarViewMode.month;
              final now = DateTime.now();
              _focusedDay = now;
              _selectedDay = now;
            }),
            activeColor: AmberColors.primaryLight,
            activeIconColor: AmberColors.primary,
          ),
        ),
        _buildSidebarItem(
          icon: FluentIcons.calendar_work_week_24_regular,
          label: '周视图',
          isSelected: _viewMode == CalendarViewMode.week,
          onTap: () => setState(() {
            _viewMode = CalendarViewMode.week;
            final now = DateTime.now();
            _focusedDay = now;
            _selectedDay = now;
          }),
          activeColor: AmberColors.primaryLight,
          activeIconColor: AmberColors.primary,
        ),
        _buildSidebarItem(
          icon: FluentIcons.calendar_day_24_regular,
          label: '日视图',
          isSelected: _viewMode == CalendarViewMode.day,
          onTap: () => setState(() {
            _viewMode = CalendarViewMode.day;
            final now = DateTime.now();
            _focusedDay = now;
            _selectedDay = now;
          }),
          activeColor: AmberColors.primaryLight,
          activeIconColor: AmberColors.primary,
        ),

        const SizedBox(height: AmberDimens.spacingLg),


      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AmberDimens.spacingLg, vertical: AmberDimens.spacingSm),
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
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: AmberDimens.spacingSm),
          decoration: BoxDecoration(
            color: isSelected ? (activeColor ?? AmberColors.primaryLight) : Colors.transparent,
            borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? (activeIconColor ?? AmberColors.primary) : AmberColors.textSecondary,
              ),
              const SizedBox(width: AmberDimens.spacingMd),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected && activeIconColor != null ? activeIconColor : AmberColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // === 中间日历区域 ===

  Widget _buildCalendarHeader() {
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
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AmberColors.divider),
                borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Showcase(
                    key: _navKey,
                    title: '日历导航',
                    description: '点击切换上一月/周/日',
                    child: Tooltip(
                      message: _viewMode == CalendarViewMode.month
                          ? '前一月'
                          : (_viewMode == CalendarViewMode.week
                                ? '前一周'
                                : '前一天'),
                      child: IconButton(
                        icon: const Icon(
                          FluentIcons.chevron_left_20_regular,
                          size: 18,
                        ),
                        onPressed: () {
                          setState(() {
                            if (_viewMode == CalendarViewMode.month) {
                              // Handle month navigation with clamping
                              final nextMonth = _focusedDay.month - 1;
                              final year =
                                  _focusedDay.year + (nextMonth < 1 ? -1 : 0);
                              final month = nextMonth < 1 ? 12 : nextMonth;
                              final daysInMonth = DateTime(
                                year,
                                month + 1,
                                0,
                              ).day; // Last day of target month
                              final day = _focusedDay.day > daysInMonth
                                  ? daysInMonth
                                  : _focusedDay.day;
                              _focusedDay = DateTime(year, month, day);
                              _selectedDay = _focusedDay; // Sync selection
                            } else if (_viewMode == CalendarViewMode.week) {
                              _focusedDay = _focusedDay.subtract(
                                const Duration(days: 7),
                              );
                              _selectedDay = _focusedDay; // Sync selection
                            } else {
                              _focusedDay = _focusedDay.subtract(
                                const Duration(days: 1),
                              );
                              _selectedDay = _focusedDay;
                            }
                          });
                        },
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Showcase(
                      key: _todayKey,
                      title: '当前日期',
                      description: '点击图标快速回到今天',
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              isSameDay(_focusedDay, DateTime.now())
                                  ? '今天'
                                  : DateFormat(
                                      'M月d日',
                                      'zh_CN',
                                    ).format(_focusedDay),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (!isSameDay(_focusedDay, DateTime.now()))
                            Tooltip(
                              message: '回到今天',
                              child: IconButton(
                                icon: const Icon(
                                  FluentIcons.calendar_today_16_regular,
                                  size: 16,
                                  color: AmberColors.primary,
                                ),
                                onPressed: () {
                                  setState(() {
                                    final now = DateTime.now();
                                    _focusedDay = now;
                                    _selectedDay = now;
                                  });
                                },
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
                  Tooltip(
                    message: _viewMode == CalendarViewMode.month
                        ? '下一月'
                        : (_viewMode == CalendarViewMode.week ? '下一周' : '后一天'),
                    child: IconButton(
                      icon: const Icon(
                        FluentIcons.chevron_right_20_regular,
                        size: 18,
                      ),
                      onPressed: () {
                        setState(() {
                          if (_viewMode == CalendarViewMode.month) {
                            // Handle month navigation with clamping
                            final nextMonth = _focusedDay.month + 1;
                            final year =
                                _focusedDay.year + (nextMonth > 12 ? 1 : 0);
                            final month = nextMonth > 12 ? 1 : nextMonth;
                            final daysInMonth = DateTime(
                              year,
                              month + 1,
                              0,
                            ).day; // Last day of target month
                            final day = _focusedDay.day > daysInMonth
                                ? daysInMonth
                                : _focusedDay.day;
                            _focusedDay = DateTime(year, month, day);
                            _selectedDay = _focusedDay; // Sync selection
                          } else if (_viewMode == CalendarViewMode.week) {
                            _focusedDay = _focusedDay.add(
                              const Duration(days: 7),
                            );
                            _selectedDay = _focusedDay; // Sync selection
                          } else {
                            _focusedDay = _focusedDay.add(
                              const Duration(days: 1),
                            );
                            _selectedDay = _focusedDay;
                          }
                        });
                      },
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
            ),

            const Spacer(),

            // 搜索栏 (实际功能)
            Flexible(
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 240,
                ), // Slightly wider
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18), // Pill shape
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
                        offset: const Offset(
                          0,
                          -2.5,
                        ), // Manually lift text further up
                        child: TextField(
                          onChanged: (val) =>
                              setState(() => _searchQuery = val),
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
            ),
            const SizedBox(width: AmberDimens.spacingMd),

            // 筛选菜单 (自定义无动画)
            Builder(
              builder: (context) => IconButton(
                icon: Icon(
                  FluentIcons.filter_20_regular,
                  color:
                      (_filterPriorities.isNotEmpty ||
                          _filterIsCompleted != null)
                      ? AmberColors.primary
                      : AmberColors.textSecondary,
                ),
                tooltip: '筛选',
                onPressed: () => _showFilterMenu(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterMenu(BuildContext buttonContext) {
    final renderBox = buttonContext.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    // Align top-right of menu to bottom-right of button
    // But we need screen width to use 'right' property in Stack, or just use 'left'.
    // Using 'left' is easier if we calculate carefully.
    // Let's use Positioned with global coordinates.
    // However, Overlay is usually full screen.

    final menuWidth = 180.0;
    // Calculate left: Button Right - Menu Width
    // Button Right = offset.dx + size.width
    final left = offset.dx + size.width - menuWidth;
    final top = offset.dy + size.height + 4;

    Navigator.of(buttonContext).push(
      PageRouteBuilder(
        opaque: false,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        barrierColor: Colors
            .black12, // Slight dim to show focus? User said "direct out", maybe no dim?
        // Let's use transparent for now as per "direct out" feel or minimal.
        barrierDismissible: true,
        pageBuilder: (context, _, __) {
          return Stack(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(color: Colors.transparent),
              ),
              Positioned(
                top: top,
                left: left,
                width: menuWidth,
                child: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                  shadowColor: Colors.black26,
                  child: StatefulBuilder(
                    builder: (context, setStateMenu) {
                      // Helper to update both menu and parent
                      void updateModel(VoidCallback fn) {
                        setState(() {
                          fn();
                        });
                        setStateMenu(() {});
                      }

                      Widget buildItem(
                        String text,
                        bool checked,
                        VoidCallback onTap,
                      ) {
                        return InkWell(
                          onTap: onTap,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  child: checked
                                      ? const Icon(
                                          FluentIcons.checkmark_20_regular,
                                          size: 16,
                                          color: AmberColors.primary,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    text,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      Widget buildHeader(String text) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                          child: Text(
                            text,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AmberColors.textSecondary,
                            ),
                          ),
                        );
                      }

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          buildHeader('优先级'),
                          ...TaskPriority.values.map(
                            (p) => buildItem(
                              p.label,
                              _filterPriorities.contains(p),
                              () => updateModel(() {
                                if (_filterPriorities.contains(p)) {
                                  _filterPriorities.remove(p);
                                } else {
                                  _filterPriorities.add(p);
                                }
                              }),
                            ),
                          ),
                          const Divider(height: 1),
                          buildHeader('状态'),
                          buildItem(
                            '全部',
                            _filterIsCompleted == null,
                            () => updateModel(() => _filterIsCompleted = null),
                          ),
                          buildItem(
                            '未完成',
                            _filterIsCompleted == false,
                            () => updateModel(() => _filterIsCompleted = false),
                          ),
                          buildItem(
                            '已完成',
                            _filterIsCompleted == true,
                            () => updateModel(() => _filterIsCompleted = true),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCalendar(List<Task> tasks) {
    if (_viewMode == CalendarViewMode.day) {
      return _buildDayView(tasks);
    }

    return TableCalendar(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      calendarFormat: _currentCalendarFormat,
      locale: 'zh_CN',
      startingDayOfWeek: StartingDayOfWeek.sunday, // 截图显示周日开始
      headerVisible: false,
      shouldFillViewport: true, // Fill available height to prevent overflow
      // rowHeight: 120, // Removed fixed height in favor of filling viewport
      daysOfWeekHeight: 40,
      daysOfWeekStyle: const DaysOfWeekStyle(
        weekdayStyle: TextStyle(fontWeight: FontWeight.w600, color: AmberColors.textSecondary),
        weekendStyle: TextStyle(fontWeight: FontWeight.w600, color: AmberColors.textSecondary),
      ),
      calendarStyle: CalendarStyle(
        // 自定义边框
        outsideDaysVisible: true,
        cellMargin: EdgeInsets.zero,
        defaultTextStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        weekendTextStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        todayDecoration: const BoxDecoration(color: Colors.transparent), // 去掉默认圆圈
        todayTextStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AmberColors.primary),
        selectedDecoration: const BoxDecoration(color: Colors.transparent),
        selectedTextStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
      onPageChanged: (focusedDay) {
        setState(() {
          _focusedDay = focusedDay;
          _selectedDay = focusedDay; // Sync selection on swipe
        });
      },
      calendarBuilders: CalendarBuilders(
        // 自定义单元格构建
        defaultBuilder: (context, day, focusedDay) => _buildCell(day, tasks),
        todayBuilder: (context, day, focusedDay) => _buildCell(day, tasks, isToday: true),
        outsideBuilder: (context, day, focusedDay) => _buildCell(
          day,
          tasks,
          isOutside: true,
          isSelected: isSameDay(day, _selectedDay),
        ),
        selectedBuilder: (context, day, focusedDay) => _buildCell(
          day,
          tasks,
          isSelected: true,
          isToday: isSameDay(day, DateTime.now()),
        ),
      ),
      onDaySelected: (selectedDay, focusedDay) {
        // 禁止选中外部月份的日期
        if (selectedDay.month != focusedDay.month) {
          return;
        }
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
      },
    );
  }

  Widget _buildCell(DateTime day, List<Task> tasks, {bool isToday = false, bool isOutside = false, bool isSelected = false}) {
    // 过滤当天的任务
    final dayTasks = tasks.where((task) {
      if (task.dueDate == null) return false;
      return isSameDay(task.dueDate, day);
    }).toList();

    final content = Container(
      decoration: BoxDecoration(
        color: isOutside
            ? Colors.grey[100] // 外部月份用更明显的灰色背景
            : (isSelected
                  ? AmberColors.primary.withValues(alpha: 0.05)
                  : Colors.white),
        border: Border.all(color: Colors.grey[200]!),
      ),
      padding: const EdgeInsets.all(4),
      child: Opacity(
        opacity: isOutside ? 0.4 : 1.0, // 外部月份整体降低不透明度
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
                    color: _getPriorityColor(
                      task.priority,
                    ).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _getPriorityColor(
                        task.priority,
                      ).withValues(alpha: 0.5),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: _getPriorityColor(
                        task.priority,
                      ), // 使用优先级颜色作为文字颜色，看起来更像截图
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
        onDoubleTap: () => _showDayTaskListDialog(context, day, dayTasks),
        onTap: () {
          setState(() {
            _selectedDay = day;
            _focusedDay = day;
          });
        },
        borderRadius: BorderRadius.circular(4),
        child: content,
      );
    }
    return content;
  }

  // === 日视图实现 ===

  Widget _buildDayView(List<Task> tasks) {
    if (_selectedDay == null) return const Center(child: Text("请选择一个日期"));

    // 过滤当天的任务
    final dayTasks = tasks.where((task) {
      if (task.dueDate == null) return false;
      return isSameDay(task.dueDate!, _selectedDay!);
    }).toList();

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
              DateFormat('yyyy年MM月dd日 EEEE', 'zh_CN').format(_selectedDay!),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),

        // 任务列表
        Expanded(
          child: dayTasks.isEmpty
              ? Center(
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
                )
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

  Widget _buildDayViewTaskItem(Task task) {
    // Only show time if non-zero
    Widget? timeBadge;
    if (task.dueDate != null &&
        (task.dueDate!.hour != 0 || task.dueDate!.minute != 0)) {
      timeBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5), // Light gray background
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

    return TaskItem(task: task, trailing: timeBadge,
    );
  }


  // === 右侧详情面板 ===




  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high: return AmberColors.priorityHigh;
      case TaskPriority.medium: return AmberColors.priorityMedium;
      case TaskPriority.low: return AmberColors.priorityLow;
      case TaskPriority.none: return AmberColors.primary;
    }
  }
  void _showDayTaskListDialog(
    BuildContext context,
    DateTime day,
    List<Task> initialTasks,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final allTasks = ref.watch(taskProvider);
            final currentDayTasks = allTasks.where((task) {
              if (task.dueDate == null) return false;
              return isSameDay(task.dueDate!, day);
            }).toList();

            return AlertDialog(
              title: Text(
                DateFormat('yyyy年MM月dd日 EEEE', 'zh_CN').format(day),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: 400,
                height: MediaQuery.of(context).size.height * 0.6,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: currentDayTasks.length,
                  itemBuilder: (context, index) {
                    return TaskItem(task: currentDayTasks[index]);
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    for (var task in currentDayTasks) {
                      if (!task.isCompleted) {
                        ref
                            .read(taskProvider.notifier)
                            .toggleTaskComplete(task.id);
                      }
                    }
                  },
                  child: const Text('全选'),
                ),
                TextButton(
                  onPressed: () {
                    for (var task in currentDayTasks) {
                      ref
                          .read(taskProvider.notifier)
                          .toggleTaskComplete(task.id);
                    }
                  },
                  child: const Text('反选'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('关闭'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSpotlightSearch(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 100),
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: 600,
                child: SpotlightDialog(
                  selectedDate: _selectedDay ?? _focusedDay,
                  onTaskCreated: (title) {
                    final date = _selectedDay ?? _focusedDay;
                    ref
                        .read(taskProvider.notifier)
                        .createTask(title: title, dueDate: date);
                    ToastManager().show(
                      context,
                      '任务已添加至 ${DateFormat('M月d日', 'zh_CN').format(date)}',
                      type: ToastType.success,
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            child: child,
          ),
        );
      },
    );
  }
}
