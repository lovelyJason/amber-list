import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/constants/constants.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../data/models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/adaptive/bottom_nav_bar.dart';
import 'widgets/calendar_left_sidebar.dart';
import 'widgets/calendar_header.dart';
import 'widgets/calendar_grid.dart';
import 'widgets/calendar_day_view.dart';
import 'widgets/calendar_filter_menu.dart';
import 'widgets/calendar_dialogs.dart';

/// 日历视图模式
enum CalendarViewMode { month, week, day }

/// 日历页面
/// 主入口组件，组合所有子模块
class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  // 视图状态
  CalendarViewMode _viewMode = CalendarViewMode.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // 搜索和筛选状态
  String _searchQuery = '';
  Set<TaskPriority> _filterPriorities = {};
  bool? _filterIsCompleted;

  // Showcase Keys
  final GlobalKey _addKey = GlobalKey();
  final GlobalKey _viewModeKey = GlobalKey();
  final GlobalKey _navKey = GlobalKey();
  final GlobalKey _todayKey = GlobalKey();
  final GlobalKey _gridKey = GlobalKey();

  bool _hasCheckedTour = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
  }

  /// 检查是否需要显示引导
  void _checkShowcase(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('has_seen_calendar_tour') ?? false;

    if (!hasSeen && context.mounted) {
      ShowCaseWidget.of(context).startShowCase([
        _addKey,
        _viewModeKey,
        _navKey,
        _todayKey,
        _gridKey,
      ]);
      await prefs.setBool('has_seen_calendar_tour', true);
    }
  }

  /// 获取当前日历格式
  CalendarFormat get _currentCalendarFormat {
    switch (_viewMode) {
      case CalendarViewMode.month:
        return CalendarFormat.month;
      case CalendarViewMode.week:
        return CalendarFormat.week;
      case CalendarViewMode.day:
        return CalendarFormat.month;
    }
  }

  @override
  Widget build(BuildContext context) {
    final allTasks = ref.watch(taskProvider);
    final tasks = _filterTasks(allTasks);

    return ShowCaseWidget(
      builder: (context) {
        if (!_hasCheckedTour) {
          _hasCheckedTour = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkShowcase(context);
          });
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile =
                constraints.maxWidth < ResponsiveHelper.mobileBreakpoint;

            if (isMobile) {
              return _buildMobileLayout(context, tasks);
            } else {
              return _buildDesktopLayout(context, tasks);
            }
          },
        );
      },
    );
  }

  /// 过滤任务
  List<Task> _filterTasks(List<Task> allTasks) {
    return allTasks.where((task) {
      // 0. 过滤已删除的任务（垃圾桶里的不显示）
      if (task.isDeleted) return false;

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
  }

  /// 构建日历内容（网格或日视图）
  Widget _buildCalendarContent(List<Task> tasks) {
    if (_viewMode == CalendarViewMode.day) {
      final dayTasks = tasks.where((task) {
        if (task.dueDate == null) return false;
        return isSameDay(task.dueDate!, _selectedDay);
      }).toList();

      return CalendarDayView(
        selectedDay: _selectedDay,
        dayTasks: dayTasks,
      );
    }

    return CalendarGrid(
      focusedDay: _focusedDay,
      selectedDay: _selectedDay,
      calendarFormat: _currentCalendarFormat,
      tasks: tasks,
      onDaySelected: _onDaySelected,
      onPageChanged: _onPageChanged,
      onDayDoubleTap: (day, dayTasks) =>
          CalendarDialogs.showDayTaskListDialog(context, day, dayTasks),
    );
  }

  // ===== 回调方法 =====

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });
  }

  void _onPageChanged(DateTime focusedDay) {
    setState(() {
      _focusedDay = focusedDay;
      _selectedDay = focusedDay;
    });
  }

  void _onViewModeChanged(CalendarViewMode mode) {
    setState(() {
      _viewMode = mode;
      final now = DateTime.now();
      _focusedDay = now;
      _selectedDay = now;
    });
  }

  void _onPreviousPage() {
    setState(() {
      if (_viewMode == CalendarViewMode.month) {
        final nextMonth = _focusedDay.month - 1;
        final year = _focusedDay.year + (nextMonth < 1 ? -1 : 0);
        final month = nextMonth < 1 ? 12 : nextMonth;
        final daysInMonth = DateTime(year, month + 1, 0).day;
        final day =
            _focusedDay.day > daysInMonth ? daysInMonth : _focusedDay.day;
        _focusedDay = DateTime(year, month, day);
        _selectedDay = _focusedDay;
      } else if (_viewMode == CalendarViewMode.week) {
        _focusedDay = _focusedDay.subtract(const Duration(days: 7));
        _selectedDay = _focusedDay;
      } else {
        _focusedDay = _focusedDay.subtract(const Duration(days: 1));
        _selectedDay = _focusedDay;
      }
    });
  }

  void _onNextPage() {
    setState(() {
      if (_viewMode == CalendarViewMode.month) {
        final nextMonth = _focusedDay.month + 1;
        final year = _focusedDay.year + (nextMonth > 12 ? 1 : 0);
        final month = nextMonth > 12 ? 1 : nextMonth;
        final daysInMonth = DateTime(year, month + 1, 0).day;
        final day =
            _focusedDay.day > daysInMonth ? daysInMonth : _focusedDay.day;
        _focusedDay = DateTime(year, month, day);
        _selectedDay = _focusedDay;
      } else if (_viewMode == CalendarViewMode.week) {
        _focusedDay = _focusedDay.add(const Duration(days: 7));
        _selectedDay = _focusedDay;
      } else {
        _focusedDay = _focusedDay.add(const Duration(days: 1));
        _selectedDay = _focusedDay;
      }
    });
  }

  void _onGoToToday() {
    setState(() {
      final now = DateTime.now();
      _focusedDay = now;
      _selectedDay = now;
    });
  }

  void _showFilterMenu(BuildContext buttonContext) {
    CalendarFilterMenu.show(
      buttonContext: buttonContext,
      filterPriorities: _filterPriorities,
      filterIsCompleted: _filterIsCompleted,
      onFilterChanged: (priorities, isCompleted) {
        setState(() {
          _filterPriorities = priorities;
          _filterIsCompleted = isCompleted;
        });
      },
    );
  }

  void _showSpotlightSearch(BuildContext context) {
    CalendarDialogs.showSpotlightSearch(
      context,
      ref,
      selectedDay: _selectedDay,
      focusedDay: _focusedDay,
    );
  }

  // ===== 响应式布局 =====

  /// 构建桌面端布局（原有布局）
  Widget _buildDesktopLayout(BuildContext context, List<Task> tasks) {
    return Scaffold(
      backgroundColor: AmberColors.background,
      body: Row(
        children: [
          // 左侧边栏
          Container(
            width: 260,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                right: BorderSide(color: AmberColors.divider),
              ),
            ),
            child: CalendarLeftSidebar(
              focusedDay: _focusedDay,
              selectedDay: _selectedDay,
              viewMode: _viewMode,
              tasks: tasks,
              addKey: _addKey,
              viewModeKey: _viewModeKey,
              onDaySelected: _onDaySelected,
              onPageChanged: _onPageChanged,
              onViewModeChanged: _onViewModeChanged,
              onAddPressed: () => _showSpotlightSearch(context),
            ),
          ),

          // 中间日历主体
          Expanded(
            child: Column(
              children: [
                // 顶部导航栏
                CalendarHeader(
                  focusedDay: _focusedDay,
                  viewMode: _viewMode,
                  searchQuery: _searchQuery,
                  filterPriorities: _filterPriorities,
                  filterIsCompleted: _filterIsCompleted,
                  navKey: _navKey,
                  todayKey: _todayKey,
                  onSearchChanged: (val) => setState(() => _searchQuery = val),
                  onPreviousPage: _onPreviousPage,
                  onNextPage: _onNextPage,
                  onGoToToday: _onGoToToday,
                  onFilterPressed: _showFilterMenu,
                ),

                // 日历网格或日视图
                Expanded(
                  child: Showcase(
                    key: _gridKey,
                    title: '任务管理',
                    description: '双击有任务的日期，快速查看和管理当天任务',
                    child: _buildCalendarContent(tasks),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建移动端布局
  /// 隐藏左侧边栏，只显示日历主体，底部添加导航栏
  Widget _buildMobileLayout(BuildContext context, List<Task> tasks) {
    return Scaffold(
      backgroundColor: AmberColors.background,
      appBar: AppBar(
        backgroundColor: AmberColors.cardBackground,
        elevation: 0,
        title: Text(
          _getMonthTitle(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AmberColors.textPrimary,
          ),
        ),
        actions: [
          // 今天按钮
          IconButton(
            onPressed: _onGoToToday,
            icon: const Icon(Icons.today, color: AmberColors.textSecondary),
            tooltip: '今天',
          ),
          // 添加任务按钮
          IconButton(
            onPressed: () => _showSpotlightSearch(context),
            icon: const Icon(Icons.add, color: AmberColors.primary),
            tooltip: '添加任务',
          ),
        ],
      ),
      body: Column(
        children: [
          // 视图模式切换
          Container(
            color: AmberColors.cardBackground,
            padding: const EdgeInsets.symmetric(
              horizontal: AmberDimens.spacingMd,
              vertical: AmberDimens.spacingSm,
            ),
            child: Row(
              children: [
                // 上一页
                IconButton(
                  onPressed: _onPreviousPage,
                  icon: const Icon(Icons.chevron_left),
                  iconSize: 20,
                ),
                // 下一页
                IconButton(
                  onPressed: _onNextPage,
                  icon: const Icon(Icons.chevron_right),
                  iconSize: 20,
                ),
                const Spacer(),
                // 视图模式切换
                SegmentedButton<CalendarViewMode>(
                  segments: const [
                    ButtonSegment(
                      value: CalendarViewMode.month,
                      label: Text('月'),
                    ),
                    ButtonSegment(
                      value: CalendarViewMode.week,
                      label: Text('周'),
                    ),
                    ButtonSegment(
                      value: CalendarViewMode.day,
                      label: Text('日'),
                    ),
                  ],
                  selected: {_viewMode},
                  onSelectionChanged: (modes) {
                    if (modes.isNotEmpty) {
                      _onViewModeChanged(modes.first);
                    }
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    textStyle: WidgetStateProperty.all(
                      const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 日历内容
          Expanded(
            child: _buildCalendarContent(tasks),
          ),
        ],
      ),
      bottomNavigationBar: const MobileBottomNavBar(),
    );
  }

  /// 获取月份标题（阿拉伯数字格式：2026年2月）
  String _getMonthTitle() {
    return '${_focusedDay.year}年${_focusedDay.month}月';
  }
}
