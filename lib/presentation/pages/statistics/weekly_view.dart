import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/constants.dart';
import '../../providers/statistics_provider.dart';

/// 周视图统计页面
/// 显示指定周的任务完成趋势和达成率
///
/// 设计说明：
/// - PC 端：左右分栏布局（柱状图 6:4 折线图）
/// - 移动端：上下堆叠布局，卡片 2 列，图表全宽
/// - 支持通过 selectedDate 参数查看任意周的数据
class WeeklyView extends ConsumerStatefulWidget {
  /// 是否为移动端布局
  final bool isMobile;

  /// 选中的日期（用于确定要显示哪一周的数据）
  /// 如果为 null，则显示本周数据
  final DateTime? selectedDate;

  const WeeklyView({super.key, this.isMobile = false, this.selectedDate});

  @override
  ConsumerState<WeeklyView> createState() => _WeeklyViewState();
}

class _WeeklyViewState extends ConsumerState<WeeklyView> {
  // 星期标签
  final List<String> _weekDays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  /// 获取目标日期（优先使用传入的 selectedDate，否则使用今天）
  DateTime get _targetDate => widget.selectedDate ?? DateTime.now();

  /// 获取统计数据
  /// 如果指定了 selectedDate，使用 family Provider 获取指定周数据
  /// 否则使用默认的 statisticsProvider（本周数据）
  WeeklyStatistics? _getStats() {
    if (widget.selectedDate != null) {
      final asyncValue = ref.watch(weeklyStatisticsForDateProvider(_targetDate));
      return asyncValue.valueOrNull;
    }
    return ref.watch(statisticsProvider);
  }

  // 从 Provider 获取的统计数据（带空值保护）
  List<int> get _weeklyCompletedTasks =>
      _getStats()?.dailyCompletedCounts ?? [0, 0, 0, 0, 0, 0, 0];

  List<double> get _dailyCompletionRates =>
      _getStats()?.dailyAchievementRates ?? [-1, -1, -1, -1, -1, -1, -1];

  // 获取每日达成率详情（用于调试）
  List<DailyAchievementDetail> get _dailyAchievementDetails =>
      _getStats()?.dailyAchievementDetails ?? [];

  // 计算周平均达成率
  double get _weeklyAverageRate =>
      _getStats()?.weeklyAverageRate ?? 0;

  // 找到最高完成数的索引
  int get _maxTaskIndex {
    if (_weeklyCompletedTasks.isEmpty) return 0;
    int maxIndex = 0;
    int maxValue = _weeklyCompletedTasks[0];
    for (int i = 1; i < _weeklyCompletedTasks.length; i++) {
      if (_weeklyCompletedTasks[i] > maxValue) {
        maxValue = _weeklyCompletedTasks[i];
        maxIndex = i;
      }
    }
    return maxIndex;
  }

  @override
  Widget build(BuildContext context) {
    // 如果使用 family Provider 且数据还在加载中，显示加载指示器
    if (widget.selectedDate != null) {
      final asyncValue = ref.watch(weeklyStatisticsForDateProvider(_targetDate));
      if (asyncValue.isLoading) {
        return const Center(
          child: CircularProgressIndicator(color: AmberColors.primary),
        );
      }
      if (asyncValue.hasError) {
        return Center(
          child: Text(
            '加载失败: ${asyncValue.error}',
            style: const TextStyle(color: AmberColors.textSecondary),
          ),
        );
      }
    }

    if (widget.isMobile) {
      return _buildMobileLayout();
    } else {
      return _buildDesktopLayout();
    }
  }

  /// 构建移动端布局
  /// 卡片 2 列，图表上下堆叠
  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部统计卡片（2 列）
          _buildMobileSummaryCards(),
          const SizedBox(height: 16),
          // 柱状图（全宽）
          _buildBarChartSection(isMobile: true),
          const SizedBox(height: 16),
          // 折线图（全宽）
          _buildLineChartSection(isMobile: true),
        ],
      ),
    );
  }

  /// 构建桌面端布局（原有布局）
  Widget _buildDesktopLayout() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部统计卡片
          _buildSummaryCards(),
          const SizedBox(height: 32),
          // 图表区域：左边柱状图 + 右边折线图
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 左边：本周任务完成趋势（柱状图）
                Expanded(
                  flex: 6,
                  child: _buildBarChartSection(),
                ),
                const SizedBox(width: 24),
                // 右边：达成趋势（折线图）
                Expanded(
                  flex: 4,
                  child: _buildLineChartSection(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建移动端统计卡片（2 列布局）
  Widget _buildMobileSummaryCards() {
    final stats = _getStats();
    final totalCompleted = stats?.totalCompleted ?? 0;
    final dailyAvg = stats?.dailyAverage ?? 0.0;

    return Row(
      children: [
        // 本周完成
        Expanded(
          child: _buildMobileSummaryCard(
            title: '本周完成',
            value: '$totalCompleted',
            icon: FluentIcons.checkmark_circle_24_filled,
            color: AmberColors.success,
          ),
        ),
        const SizedBox(width: 12),
        // 日均完成
        Expanded(
          child: _buildMobileSummaryCard(
            title: '日均完成',
            value: dailyAvg.toStringAsFixed(1),
            icon: FluentIcons.data_trending_24_filled,
            color: AmberColors.primary,
          ),
        ),
      ],
    );
  }

  /// 构建移动端单个统计卡片
  Widget _buildMobileSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AmberColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AmberColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AmberColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AmberColors.textPrimary,
              height: 1.1,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// 构建顶部统计卡片
  Widget _buildSummaryCards() {
    final stats = _getStats();
    final totalCompleted = stats?.totalCompleted ?? 0;
    final dailyAvg = stats?.dailyAverage ?? 0.0;

    return Row(
      children: [
        _buildSummaryCard(
          title: '本周完成',
          value: '$totalCompleted',
          icon: FluentIcons.checkmark_circle_24_filled,
          color: AmberColors.success,
          backgroundIcon: Icons.check_circle_outline, // 带圆圈的对钩
        ),
        const SizedBox(width: 16),
        _buildSummaryCard(
          title: '日均完成',
          value: dailyAvg.toStringAsFixed(1),
          icon: FluentIcons.data_trending_24_filled,
          color: AmberColors.primary,
          backgroundIcon: Icons.bar_chart_rounded, // 柱状图代表日均统计
        ),
        const SizedBox(width: 16),
        _buildSummaryCard(
          title: '专注时长',
          value: '-', // 暂不支持，后续可接入番茄钟数据
          icon: FluentIcons.timer_24_filled,
          color: AmberColors.warning,
          backgroundIcon: Icons.timer_outlined,
        ),
      ],
    );
  }

  /// 构建单个统计卡片（带背景模糊图标）
  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required IconData backgroundIcon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: AmberColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AmberColors.divider),
        ),
        child: Stack(
          children: [
            // 背景模糊图标（右侧居中）
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 0.8, sigmaY: 0.8), // 轻微模糊
                  child: Icon(
                    backgroundIcon,
                    size: 56, // 缩小到不会被截
                    color: color.withValues(alpha: 0.15),
                  ),
                ),
              ),
            ),
            // 前景内容
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AmberColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AmberColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建柱状图区域
  Widget _buildBarChartSection({bool isMobile = false}) {
    // 计算图表区域的参数
    const double leftPadding = 30; // 左侧Y轴标签空间
    const double bottomPadding = 30; // 底部X轴标签空间
    const double maxY = 12.0;

    // 移动端使用固定高度
    final chartHeight = isMobile ? 280.0 : null;

    return Container(
      height: chartHeight,
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: AmberColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AmberColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              Icon(
                FluentIcons.data_bar_vertical_24_filled,
                color: AmberColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                '本周任务完成趋势',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AmberColors.textPrimary,
                ),
              ),
              const Spacer(),
              // 导出数据按钮
              // TextButton.icon(
              //   onPressed: () {},
              //   icon: const Icon(FluentIcons.arrow_download_16_regular, size: 16),
              //   label: const Text('导出数据'),
              //   style: TextButton.styleFrom(
              //     foregroundColor: AmberColors.textSecondary,
              //     textStyle: const TextStyle(fontSize: 13),
              //   ),
              // ),
            ],
          ),
          const SizedBox(height: 24),
          // 柱状图（用 Stack 叠加五角星）
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 计算五角星位置
                final chartWidth = constraints.maxWidth - leftPadding;
                final chartHeight = constraints.maxHeight - bottomPadding;
                final barSpacing = chartWidth / _weeklyCompletedTasks.length;
                final maxValue = _weeklyCompletedTasks[_maxTaskIndex];
                final starX = leftPadding + barSpacing * _maxTaskIndex + barSpacing / 2 - 8;
                // 星星在柱子内部顶部（往下偏移让星星在柱子里面）
                final starY = chartHeight * (1 - maxValue / maxY) + 6;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 柱状图
                    BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: maxY,
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) => AmberColors.cardBackground,
                            tooltipPadding: const EdgeInsets.all(8),
                            tooltipMargin: 8,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              return BarTooltipItem(
                                '${rod.toY.round()} 个任务',
                                const TextStyle(
                                  color: AmberColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index >= 0 && index < _weekDays.length) {
                                  final isMax = index == _maxTaskIndex;
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      _weekDays[index],
                                      style: TextStyle(
                                        color: isMax ? AmberColors.primary : AmberColors.textSecondary,
                                        fontSize: 12,
                                        fontWeight: isMax ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                              reservedSize: bottomPadding,
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: leftPadding,
                              interval: 3,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(
                                    color: AmberColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                );
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 3,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: AmberColors.divider,
                            strokeWidth: 1,
                            dashArray: [5, 5],
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: _weeklyCompletedTasks.asMap().entries.map((entry) {
                          final isMax = entry.key == _maxTaskIndex;
                          return BarChartGroupData(
                            x: entry.key,
                            barRods: [
                              BarChartRodData(
                                toY: entry.value.toDouble(),
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: isMax
                                      ? [AmberColors.primary, AmberColors.primaryDark]
                                      : [
                                          AmberColors.primary.withValues(alpha: 0.6),
                                          AmberColors.primary.withValues(alpha: 0.8),
                                        ],
                                ),
                                width: 36,
                                // 只有顶部圆角，底部直角
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(10),
                                  topRight: Radius.circular(10),
                                ),
                                backDrawRodData: BackgroundBarChartRodData(
                                  show: true,
                                  toY: maxY,
                                  color: AmberColors.divider.withValues(alpha: 0.3),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                      duration: const Duration(milliseconds: 150),
                    ),
                    // 最高柱子内部顶部的五角星
                    Positioned(
                      left: starX,
                      top: starY,
                      child: const Icon(
                        Icons.star_rounded,
                        color: Colors.white, // 白色星星在深色柱子里更显眼
                        size: 16,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 显示某天达成率的计算详情弹窗
  /// debug 模式下显示技术字段名，非 debug 模式显示用户友好文案
  void _showAchievementDetailDialog(int dayIndex) {
    // 查找对应日期的详情
    final detail = _dailyAchievementDetails.firstWhere(
      (d) => d.weekday == dayIndex + 1, // weekday 是 1-7，dayIndex 是 0-6
      orElse: () => DailyAchievementDetail(
        date: DateTime.now(),
        weekday: dayIndex + 1,
        totalDueTasks: 0,
        achievedTasks: 0,
        rate: -1,
        taskDetails: [],
      ),
    );

    final dateStr = DateFormat('yyyy-MM-dd').format(detail.date);
    final ratePercent = detail.rate >= 0 ? '${(detail.rate * 100).toStringAsFixed(1)}%' : '无数据';

    // 根据 debug 模式区分判定标准的文案
    final dueCriteria = kDebugMode
        ? '应完成 = originalDueDate 为当天的任务'
        : '应完成 = 截止日期为当天的任务';
    final achievedCriteria = kDebugMode
        ? '按时完成 = isCompleted && postponeCount == 0'
        : '按时完成 = 已经完成 且 没有被自动顺延过';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${detail.weekdayText} ($dateStr) 达成率详情'),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 400,
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 计算公式
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📊 计算公式',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text('达成率 = 按时完成任务数 / 应完成任务数'),
                      Text('达成率 = ${detail.achievedTasks} / ${detail.totalDueTasks} = $ratePercent'),
                      const SizedBox(height: 8),
                      const Text(
                        '判定标准：',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text('• $dueCriteria'),
                      Text('• $achievedCriteria'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 任务详情列表
                if (detail.taskDetails.isEmpty)
                  const Text(
                    '当天没有应完成的任务',
                    style: TextStyle(color: Colors.grey),
                  )
                else ...[
                  Text(
                    '📋 任务列表 (${detail.taskDetails.length}个)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...detail.taskDetails.map((taskDetail) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          taskDetail,
                          style: const TextStyle(fontSize: 13),
                        ),
                      )),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 构建折线图区域（达成趋势）
  Widget _buildLineChartSection({bool isMobile = false}) {
    final averagePercent = (_weeklyAverageRate * 100).toInt();

    // 移动端使用固定高度
    final chartHeight = isMobile ? 260.0 : null;

    return Container(
      height: chartHeight,
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        // 浅橙色背景
        color: const Color(0xFFFFF8F0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              Icon(
                FluentIcons.arrow_trending_lines_24_regular,
                color: AmberColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                '达成趋势',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AmberColors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              // 帮助图标：悬停显示达成趋势的计算说明
              Tooltip(
                message:
                    '衡量任务按时完成情况\n'
                    '达成率 = 按时完成数 / 应完成数\n'
                    '延期完成的任务不计入按时完成',
                textStyle: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  height: 1.5,
                ),
                decoration: BoxDecoration(
                  color: AmberColors.textPrimary.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Icon(
                  FluentIcons.question_circle_16_regular,
                  size: 16,
                  color: AmberColors.textDisabled,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 达成率大数字
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$averagePercent%',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: AmberColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text(
                  '达成率',
                  style: TextStyle(
                    fontSize: 14,
                    color: AmberColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // 折线图（包裹 MouseRegion 让鼠标变手指提示可点击）
          Expanded(
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 1,
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AmberColors.cardBackground,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final percent = (spot.y * 100).toInt();
                        return LineTooltipItem(
                          '$percent%',
                          const TextStyle(
                            color: AmberColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                  // 点击顶点显示达成率计算详情
                  touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
                    if (event is FlTapUpEvent &&
                        response != null &&
                        response.lineBarSpots != null &&
                        response.lineBarSpots!.isNotEmpty) {
                      final spot = response.lineBarSpots!.first;
                      final dayIndex = spot.x.toInt();
                      _showAchievementDetailDialog(dayIndex);
                    }
                  },
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 0.25,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AmberColors.divider.withValues(alpha: 0.5),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1, // 每个点都检查
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                          // 显示周一、周四、周日，加顶部间距避免与折线顶点重叠
                          const textStyle = TextStyle(
                            fontSize: 10,
                            color: AmberColors.textSecondary,
                          );
                          if (index == 0)
                            return const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text('周一', style: textStyle),
                            );
                          if (index == 3)
                            return const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text('周四', style: textStyle),
                            );
                          if (index == 6)
                            return const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text('周日', style: textStyle),
                            );
                        return const SizedBox.shrink();
                      },
                        reservedSize: 32, // 增加预留空间以容纳 padding
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    // 过滤掉 -1（无数据）的点，只显示有数据的天
                    spots: _dailyCompletionRates.asMap().entries
                        .where((entry) => entry.value >= 0)
                        .map((entry) {
                          return FlSpot(entry.key.toDouble(), entry.value);
                        }).toList(),
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: AmberColors.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        final validSpots = _dailyCompletionRates
                            .where((r) => r >= 0).length;
                        // 最后一个有效点用实心圆
                        if (index == validSpots - 1) {
                          return FlDotCirclePainter(
                            radius: 5,
                            color: AmberColors.primary,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        }
                        // 其他点用空心圆
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Colors.white,
                          strokeWidth: 2,
                          strokeColor: AmberColors.primary,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AmberColors.primary.withValues(alpha: 0.2),
                          AmberColors.primary.withValues(alpha: 0.05),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ),
          ),
        ],
      ),
    );
  }
}
