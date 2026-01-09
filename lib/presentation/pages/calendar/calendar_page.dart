import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/constants/constants.dart';
import '../../../core/utils/responsive_helper.dart';
import '../../../data/models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/activation_dialog.dart';
import '../../widgets/adaptive/bottom_nav_bar.dart';
import 'widgets/calendar_left_sidebar.dart';
import 'widgets/calendar_header.dart';
import 'widgets/calendar_grid.dart';
import 'widgets/calendar_day_view.dart';
import 'widgets/calendar_filter_menu.dart';
import 'widgets/dialogs/calendar_dialogs.dart';

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
  bool _hasShownActivationDialog = false;

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
    final activationState = ref.watch(activationProvider);
    final isActivated = activationState.isActivated && !activationState.isExpired;

    // 初始化完成前：显示真实数据（避免闪烁，宁可让未激活用户短暂看到真实数据）
    // 初始化完成后：根据激活状态决定显示真实数据还是假数据
    // 这样已激活用户不会看到假数据闪烁
    final tasks = !activationState.isInitialized || isActivated
        ? _filterTasks(allTasks)
        : _generateDemoTasks();

    return ShowCaseWidget(
      builder: (context) {
        // 检测后台校验失败，自动弹出激活弹窗
        if (activationState.isInitialized &&
            activationState.backgroundVerifyFailed &&
            !_hasShownActivationDialog) {
          _hasShownActivationDialog = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // 清除标志，避免重复弹窗
            ref.read(activationProvider.notifier).clearBackgroundVerifyFailed();
            // 弹出激活弹窗
            ActivationDialog.show(context);
          });
        }

        if (!_hasCheckedTour && isActivated) {
          _hasCheckedTour = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkShowcase(context);
          });
        }

        return Stack(
          children: [
            // 日历主体内容
            // 遮罩层在各自的 Layout 方法内部处理，避免覆盖底部导航栏
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile =
                    constraints.maxWidth < ResponsiveHelper.mobileBreakpoint;
                final showOverlay = activationState.isInitialized && !isActivated;

                if (isMobile) {
                  return _buildMobileLayout(context, tasks, showOverlay: showOverlay);
                } else {
                  return _buildDesktopLayout(context, tasks, showOverlay: showOverlay);
                }
              },
            ),
          ],
        );
      },
    );
  }

  /// 生成假数据用于展示（勾引用户付费）
  /// 在日历上展示丰富的任务分布，让用户看到功能价值
  List<Task> _generateDemoTasks() {
    final now = DateTime.now();
    return [
      // 今天的任务
      Task(
        id: 'demo-1',
        title: '完成项目方案设计',
        priority: TaskPriority.high,
        dueDate: now,
        isCompleted: false,
        createdAt: now,
        updatedAt: now,
      ),
      Task(
        id: 'demo-2',
        title: '回复客户邮件',
        priority: TaskPriority.medium,
        dueDate: now,
        isCompleted: true,
        createdAt: now,
        updatedAt: now,
      ),
      // 未来几天
      Task(
        id: 'demo-3',
        title: '团队周会',
        priority: TaskPriority.medium,
        dueDate: now.add(const Duration(days: 1)),
        isCompleted: false,
        createdAt: now,
        updatedAt: now,
      ),
      Task(
        id: 'demo-4',
        title: '代码审查',
        priority: TaskPriority.low,
        dueDate: now.add(const Duration(days: 2)),
        isCompleted: false,
        createdAt: now,
        updatedAt: now,
      ),
      Task(
        id: 'demo-5',
        title: '提交周报',
        priority: TaskPriority.medium,
        dueDate: now.add(const Duration(days: 3)),
        isCompleted: false,
        createdAt: now,
        updatedAt: now,
      ),
      Task(
        id: 'demo-6',
        title: '产品需求评审',
        priority: TaskPriority.high,
        dueDate: now.add(const Duration(days: 5)),
        isCompleted: false,
        createdAt: now,
        updatedAt: now,
      ),
      Task(
        id: 'demo-7',
        title: '技术分享会',
        priority: TaskPriority.low,
        dueDate: now.add(const Duration(days: 7)),
        isCompleted: false,
        createdAt: now,
        updatedAt: now,
      ),
      Task(
        id: 'demo-8',
        title: '版本发布',
        priority: TaskPriority.high,
        dueDate: now.add(const Duration(days: 10)),
        isCompleted: false,
        createdAt: now,
        updatedAt: now,
      ),
      Task(
        id: 'demo-9',
        title: '季度总结',
        priority: TaskPriority.medium,
        dueDate: now.add(const Duration(days: 14)),
        isCompleted: false,
        createdAt: now,
        updatedAt: now,
      ),
      // 过去几天（已完成）
      Task(
        id: 'demo-10',
        title: '客户需求沟通',
        priority: TaskPriority.high,
        dueDate: now.subtract(const Duration(days: 1)),
        isCompleted: true,
        createdAt: now,
        updatedAt: now,
      ),
      Task(
        id: 'demo-11',
        title: '文档整理',
        priority: TaskPriority.low,
        dueDate: now.subtract(const Duration(days: 2)),
        isCompleted: true,
        createdAt: now,
        updatedAt: now,
      ),
      Task(
        id: 'demo-12',
        title: '系统优化',
        priority: TaskPriority.medium,
        dueDate: now.subtract(const Duration(days: 3)),
        isCompleted: true,
        createdAt: now,
        updatedAt: now,
      ),
      Task(
        id: 'demo-13',
        title: 'Bug修复',
        priority: TaskPriority.high,
        dueDate: now.subtract(const Duration(days: 5)),
        isCompleted: true,
        createdAt: now,
        updatedAt: now,
      ),
      Task(
        id: 'demo-14',
        title: '需求分析',
        priority: TaskPriority.medium,
        dueDate: now.subtract(const Duration(days: 7)),
        isCompleted: true,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }

  /// 构建激活遮罩层
  /// 设计理念：极其轻微的遮罩，让用户几乎感觉不到有遮罩存在
  /// 点击遮罩层本身不弹窗（但会拦截点击阻止操作日历），只有点击中间的激活按钮才触发
  Widget _buildActivationOverlay(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        // 拦截点击但不做任何操作（阻止用户操作下层日历）
        onTap: () {},
        behavior: HitTestBehavior.opaque,
        child: Container(
          // 几乎透明的白色遮罩，只是非常轻微地降低对比度，看起来像没有遮罩
          color: Colors.white.withValues(alpha: 0.03),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AmberDimens.spacingXl,
                vertical: AmberDimens.spacingLg,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AmberDimens.radiusLg),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 锁图标
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AmberColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      color: AmberColors.primary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: AmberDimens.spacingMd),
                  // 标题
                  const Text(
                    '日历功能需要激活',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AmberColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AmberDimens.spacingSm),
                  // 描述
                  const Text(
                    '激活后即可使用完整的日历视图功能',
                    style: TextStyle(
                      fontSize: 14,
                      color: AmberColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AmberDimens.spacingLg),
                  // 激活按钮
                  ElevatedButton.icon(
                    onPressed: () => ActivationDialog.show(context),
                    icon: const Icon(Icons.key, size: 18),
                    label: const Text('立即激活'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AmberColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AmberDimens.spacingXl,
                        vertical: AmberDimens.spacingMd,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
  Widget _buildDesktopLayout(BuildContext context, List<Task> tasks, {bool showOverlay = false}) {
    return Scaffold(
      backgroundColor: AmberColors.background,
      body: Stack(
        children: [
          Row(
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
          // 激活遮罩层（桌面端也需要）
          if (showOverlay) _buildActivationOverlay(context),
        ],
      ),
    );
  }

  /// 构建移动端布局
  /// 隐藏左侧边栏，只显示日历主体，底部添加导航栏
  Widget _buildMobileLayout(BuildContext context, List<Task> tasks, {bool showOverlay = false}) {
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
      // body 用 Stack 包裹，遮罩只覆盖 body 区域，不影响底部导航栏
      body: Stack(
        children: [
          Column(
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
          // 激活遮罩层（只覆盖 body，不影响底部导航栏）
          if (showOverlay) _buildActivationOverlay(context),
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
