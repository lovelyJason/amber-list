import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/utils/responsive_helper.dart';
import '../../../presentation/widgets/adaptive/bottom_nav_bar.dart';
import 'monthly_view.dart';
import 'weekly_view.dart';

/// 统计页面
///
/// 设计说明：
/// - PC 端：无 AppBar，标题和切换按钮在页面内部
/// - 移动端：有 AppBar（标题+切换按钮）+ 底部导航栏，独立全屏页面
/// - 支持月视图和周视图切换
class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  // 0: Month, 1: Week
  int _selectedIndex = 0;

  /// 当前选中的日期范围（周视图用周，月视图用月）
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  /// 获取当前周的起止日期
  (DateTime, DateTime) get _currentWeekRange {
    final weekday = _selectedDate.weekday;
    final startOfWeek = _selectedDate.subtract(Duration(days: weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    return (startOfWeek, endOfWeek);
  }

  /// 格式化日期范围显示文本
  /// 周视图：显示日期范围，如 "2023年10月23日 - 10月29日"
  /// 跨年时：显示 "2023年12月25日 - 2024年1月1日"
  String get _dateRangeText {
    if (_selectedIndex == 1) {
      // 周视图：显示日期范围
      final (start, end) = _currentWeekRange;
      final isCrossYear = start.year != end.year;

      if (isCrossYear) {
        // 跨年：两边都带年份
        final startFormat = DateFormat('yyyy年M月d日');
        final endFormat = DateFormat('yyyy年M月d日');
        return '${startFormat.format(start)} - ${endFormat.format(end)}';
      } else {
        // 同年：开始带年份，结束只显示月日
        final startFormat = DateFormat('yyyy年M月d日');
        final endFormat = DateFormat('M月d日');
        return '${startFormat.format(start)} - ${endFormat.format(end)}';
      }
    } else {
      // 月视图：只显示年月
      final monthFormat = DateFormat('yyyy年M月');
      return monthFormat.format(_selectedDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < ResponsiveHelper.mobileBreakpoint;

    if (isMobile) {
      return _buildMobileLayout();
    } else {
      return _buildDesktopLayout();
    }
  }

  /// 构建移动端布局
  /// 独立全屏页面，包含 AppBar 和底部导航栏
  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: AmberColors.background,
      appBar: AppBar(
        title: const Text(
          '统计',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AmberColors.textPrimary,
          ),
        ),
        backgroundColor: AmberColors.cardBackground,
        elevation: 0,
        centerTitle: false,
        actions: [
          // 月/周视图切换按钮
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _buildSegmentControl(),
          ),
        ],
      ),
      body: _selectedIndex == 0
          ? MonthlyView(isMobile: true, selectedDate: _selectedDate)
          : WeeklyView(isMobile: true, selectedDate: _selectedDate),
      bottomNavigationBar: const MobileBottomNavBar(),
    );
  }

  /// 构建桌面端布局（保持原有布局）
  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: AmberColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              children: [
                const Text(
                  '统计',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AmberColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 16),
                // 月/周视图切换按钮（紧跟标题）
                _buildSegmentControl(),
                const Spacer(),
                // 右侧操作按钮组
                _buildHeaderActions(),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _selectedIndex == 0
                ? MonthlyView(selectedDate: _selectedDate)
                : WeeklyView(selectedDate: _selectedDate),
          ),
        ],
      ),
    );
  }

  /// 构建 Header 右侧操作按钮组
  /// 包含：时间选择器、导出按钮、更多菜单
  Widget _buildHeaderActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 时间选择器按钮
        _buildDateRangeButton(),
        const SizedBox(width: 8),
        // 导出按钮
        _buildExportButton(),
        const SizedBox(width: 8),
        // 更多菜单按钮
        _buildMoreMenuButton(),
      ],
    );
  }

  /// 时间选择器按钮
  /// 显示当前日期范围，点击弹出日期选择器
  /// 样式：浅黄色背景 + 浅边框（参考设计稿）
  Widget _buildDateRangeButton() {
    return InkWell(
      onTap: _showDatePicker,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AmberColors.primaryLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AmberColors.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              FluentIcons.calendar_ltr_16_regular,
              size: 16,
              color: AmberColors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              _dateRangeText,
              style: const TextStyle(
                fontSize: 13,
                color: AmberColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 导出按钮（纯图标，无背景无边框）
  Widget _buildExportButton() {
    return IconButton(
      onPressed: _handleExport,
      tooltip: '导出数据',
      icon: Icon(
        Icons.file_download_outlined,
        size: 22,
        color: AmberColors.textSecondary,
      ),
    );
  }

  /// 更多菜单按钮（纯图标，无背景无边框）
  Widget _buildMoreMenuButton() {
    return PopupMenuButton<String>(
      onSelected: _handleMenuAction,
      tooltip: '更多选项',
      icon: Icon(
        FluentIcons.more_horizontal_16_regular,
        size: 20,
        color: AmberColors.textSecondary,
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'share',
          child: Row(
            children: [
              Icon(FluentIcons.share_16_regular, size: 18),
              SizedBox(width: 12),
              Text('分享统计'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'set_goal',
          child: Row(
            children: [
              Icon(FluentIcons.target_16_regular, size: 18),
              SizedBox(width: 12),
              Text('设置目标'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'preferences',
          child: Row(
            children: [
              Icon(FluentIcons.settings_16_regular, size: 18),
              SizedBox(width: 12),
              Text('统计偏好'),
            ],
          ),
        ),
      ],
    );
  }

  /// 显示时间选择器
  /// 月视图：显示月份选择器
  /// 周视图：显示周选择器（左右切换）
  void _showDatePicker() {
    if (_selectedIndex == 0) {
      // 月视图：弹出月份选择器
      _showMonthPicker();
    } else {
      // 周视图：弹出周选择器
      _showWeekPicker();
    }
  }

  /// 显示月份选择器弹窗
  Future<void> _showMonthPicker() async {
    final now = DateTime.now();
    int selectedYear = _selectedDate.year;
    int selectedMonth = _selectedDate.month;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('选择月份'),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              content: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 年份选择器
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: selectedYear > 2020
                              ? () => setDialogState(() => selectedYear--)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text(
                          '$selectedYear年',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        IconButton(
                          onPressed: selectedYear < now.year
                              ? () => setDialogState(() => selectedYear++)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 月份网格
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        childAspectRatio: 1.5,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: 12,
                      itemBuilder: (context, index) {
                        final month = index + 1;
                        // 是否为未来月份（不可选）
                        final isFuture = selectedYear > now.year ||
                            (selectedYear == now.year && month > now.month);
                        // 是否为当前选中的月份（弹窗内临时选中状态，未来月份不能选中）
                        final isSelected = !isFuture && month == selectedMonth;
                        // 是否为当前月（特殊高亮）
                        final isCurrentMonth =
                            selectedYear == now.year && month == now.month;

                        return InkWell(
                          onTap: isFuture
                              ? null
                              : () => setDialogState(() => selectedMonth = month),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isFuture
                                  ? Colors.grey.withValues(alpha: 0.1)
                                  : isSelected
                                      ? AmberColors.primary
                                      : isCurrentMonth
                                          ? AmberColors.primaryLight
                                          : null,
                              borderRadius: BorderRadius.circular(8),
                              border: isCurrentMonth && !isSelected
                                  ? Border.all(
                                      color:
                                          AmberColors.primary.withValues(alpha: 0.5))
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$month月',
                              style: TextStyle(
                                color: isFuture
                                    ? AmberColors.textDisabled
                                    : isSelected
                                        ? Colors.white
                                        : AmberColors.textPrimary,
                                fontWeight:
                                    isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _selectedDate = DateTime(selectedYear, selectedMonth);
                    });
                    Navigator.pop(context);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AmberColors.primary,
                  ),
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 显示周选择器弹窗
  Future<void> _showWeekPicker() async {
    final now = DateTime.now();
    DateTime tempSelectedDate = _selectedDate;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // 计算当前选中周的范围
            final weekday = tempSelectedDate.weekday;
            final startOfWeek =
                tempSelectedDate.subtract(Duration(days: weekday - 1));
            final endOfWeek = startOfWeek.add(const Duration(days: 6));

            // 格式化周范围显示
            String weekRangeText;
            if (startOfWeek.year != endOfWeek.year) {
              weekRangeText =
                  '${DateFormat('yyyy年M月d日').format(startOfWeek)} - ${DateFormat('yyyy年M月d日').format(endOfWeek)}';
            } else if (startOfWeek.month != endOfWeek.month) {
              weekRangeText =
                  '${DateFormat('M月d日').format(startOfWeek)} - ${DateFormat('M月d日').format(endOfWeek)}';
            } else {
              weekRangeText =
                  '${DateFormat('M月d日').format(startOfWeek)} - ${endOfWeek.day}日';
            }

            // 是否可以往后（不能超过当前周）
            final canGoNext = endOfWeek.isBefore(now);

            return AlertDialog(
              title: const Text('选择周'),
              contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 年份显示
                    Text(
                      '${startOfWeek.year}年',
                      style: TextStyle(
                        fontSize: 14,
                        color: AmberColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 周切换器
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 上一周
                        IconButton(
                          onPressed: () {
                            setDialogState(() {
                              tempSelectedDate = tempSelectedDate
                                  .subtract(const Duration(days: 7));
                            });
                          },
                          icon: const Icon(Icons.chevron_left),
                          tooltip: '上一周',
                        ),
                        // 周范围显示（用 Flexible 防止跨年日期过长溢出）
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AmberColors.primaryLight,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              weekRangeText,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        // 下一周
                        IconButton(
                          onPressed: canGoNext
                              ? () {
                                  setDialogState(() {
                                    tempSelectedDate = tempSelectedDate
                                        .add(const Duration(days: 7));
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.chevron_right),
                          tooltip: '下一周',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 快捷选项
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildWeekShortcut(
                          '本周',
                          now,
                          tempSelectedDate,
                          (date) => setDialogState(() => tempSelectedDate = date),
                        ),
                        _buildWeekShortcut(
                          '上周',
                          now.subtract(const Duration(days: 7)),
                          tempSelectedDate,
                          (date) => setDialogState(() => tempSelectedDate = date),
                        ),
                        _buildWeekShortcut(
                          '上上周',
                          now.subtract(const Duration(days: 14)),
                          tempSelectedDate,
                          (date) => setDialogState(() => tempSelectedDate = date),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _selectedDate = tempSelectedDate;
                    });
                    Navigator.pop(context);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AmberColors.primary,
                  ),
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// 构建周快捷选项按钮
  Widget _buildWeekShortcut(
    String label,
    DateTime targetDate,
    DateTime currentSelected,
    void Function(DateTime) onSelect,
  ) {
    // 判断是否选中（同一周）
    final targetWeekday = targetDate.weekday;
    final targetStart = targetDate.subtract(Duration(days: targetWeekday - 1));

    final selectedWeekday = currentSelected.weekday;
    final selectedStart =
        currentSelected.subtract(Duration(days: selectedWeekday - 1));

    final isSelected = targetStart.year == selectedStart.year &&
        targetStart.month == selectedStart.month &&
        targetStart.day == selectedStart.day;

    return OutlinedButton(
      onPressed: () => onSelect(targetDate),
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? AmberColors.primary : null,
        foregroundColor: isSelected ? Colors.white : AmberColors.textSecondary,
        side: BorderSide(
          color: isSelected ? AmberColors.primary : AmberColors.divider,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: Text(label),
    );
  }

  /// 处理导出操作
  void _handleExport() {
    // TODO: 实现导出功能
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('导出功能开发中...')),
    );
  }

  /// 处理菜单操作
  void _handleMenuAction(String action) {
    switch (action) {
      case 'share':
        // TODO: 实现分享功能
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('分享功能开发中...')),
        );
        break;
      case 'set_goal':
        // TODO: 实现设置目标功能
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设置目标功能开发中...')),
        );
        break;
      case 'preferences':
        // TODO: 实现统计偏好设置
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('统计偏好功能开发中...')),
        );
        break;
    }
  }

  /// 构建分段控制器（月/周视图切换）
  Widget _buildSegmentControl() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AmberColors.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AmberColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSegmentButton('月视图', 0),
          _buildSegmentButton('周视图', 1),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(String text, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AmberColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : AmberColors.textSecondary,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
