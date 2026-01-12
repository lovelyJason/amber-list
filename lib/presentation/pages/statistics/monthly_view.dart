import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/constants.dart';
import '../../../../data/datasources/local/database.dart';
import '../../providers/database_provider.dart';
import '../../providers/statistics_provider.dart';

/// 月视图统计页面
/// 显示指定月份的任务完成趋势、任务类型分布、热力图和成就
///
/// 设计说明：
/// - PC 端：左右分栏布局（趋势图+饼图 6:4，热力图+成就 4:6）
/// - 移动端：上下堆叠布局，卡片 2 列，图表全宽
/// - 支持通过 selectedDate 参数查看任意月份的数据
class MonthlyView extends ConsumerStatefulWidget {
  /// 是否为移动端布局
  final bool isMobile;

  /// 选中的日期（用于确定要显示哪个月的数据）
  /// 如果为 null，则显示本月数据
  final DateTime? selectedDate;

  const MonthlyView({super.key, this.isMobile = false, this.selectedDate});

  @override
  ConsumerState<MonthlyView> createState() => _MonthlyViewState();
}

class _MonthlyViewState extends ConsumerState<MonthlyView> {
  /// 获取目标日期（优先使用传入的 selectedDate，否则使用今天）
  DateTime get _targetDate => widget.selectedDate ?? DateTime.now();

  /// 获取统计数据
  /// 如果指定了 selectedDate，使用 family Provider 获取指定月数据
  /// 否则使用默认的 monthlyStatisticsProvider（本月数据）
  MonthlyStatistics? _getStats() {
    if (widget.selectedDate != null) {
      final asyncValue = ref.watch(monthlyStatisticsForDateProvider(_targetDate));
      return asyncValue.valueOrNull;
    }
    return ref.watch(monthlyStatisticsProvider);
  }

  @override
  Widget build(BuildContext context) {
    // 如果使用 family Provider 且数据还在加载中，显示加载指示器
    if (widget.selectedDate != null) {
      final asyncValue = ref.watch(monthlyStatisticsForDateProvider(_targetDate));
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

    final stats = _getStats() ?? MonthlyStatistics.empty();

    if (widget.isMobile) {
      return _buildMobileLayout(stats);
    } else {
      return _buildDesktopLayout(stats);
    }
  }

  /// 构建移动端布局
  /// 卡片 2 列，图表上下堆叠
  Widget _buildMobileLayout(MonthlyStatistics stats) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部统计卡片（2 列）
          _buildMobileSummaryCards(stats),
          const SizedBox(height: 16),
          // 趋势图（全宽）
          _buildTrendChartSection(stats, isMobile: true),
          const SizedBox(height: 16),
          // 任务类型分布（全宽）
          _buildTypeDistributionSection(stats, isMobile: true),
          const SizedBox(height: 16),
          // 热力图（全宽）
          _buildHeatmapSection(stats, isMobile: true),
          const SizedBox(height: 16),
          // 本月成就（全宽）
          _buildAchievementsSection(stats, isMobile: true),
        ],
      ),
    );
  }

  /// 构建桌面端布局（原有布局）
  Widget _buildDesktopLayout(MonthlyStatistics stats) {
    return SingleChildScrollView(
      // 顶部间距较小（8px），与周视图保持一致感觉
      // 左右底部保持 24px
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部四个统计卡片
          _buildSummaryCards(stats),
          const SizedBox(height: 24),
          // 中间区域：左边趋势图 + 右边任务类型分布
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左边：每日任务完成趋势（折线图）
              Expanded(
                flex: 6,
                child: _buildTrendChartSection(stats),
              ),
              const SizedBox(width: 24),
              // 右边：任务类型分布（环形图）
              Expanded(
                flex: 4,
                child: _buildTypeDistributionSection(stats),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // 底部区域：左边热力图 + 右边本月成就
          // 热力图卡片比趋势图窄一点，体现错落感（5:5 而非 6:4）
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左边：热力图（比上面趋势图窄）
              Expanded(
                flex: 4,
                child: _buildHeatmapSection(stats),
              ),
              const SizedBox(width: 24),
              // 右边：本月成就（比上面饼图宽）
              Expanded(
                flex: 6,
                child: _buildAchievementsSection(stats),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建移动端统计卡片（2 列布局）
  Widget _buildMobileSummaryCards(MonthlyStatistics stats) {
    final growthPercent = (stats.growthRate * 100).round();
    final growthText = growthPercent >= 0 ? '+$growthPercent%' : '$growthPercent%';

    return Column(
      children: [
        // 第一行：已完成 + 日均
        Row(
          children: [
            Expanded(
              child: _buildMobileSummaryCard(
                title: '已完成任务',
                value: '${stats.totalCompleted}',
                subtitle: '环比 $growthText',
                subtitleColor: growthPercent >= 0 ? AmberColors.success : AmberColors.warning,
                icon: FluentIcons.checkmark_circle_24_filled,
                color: AmberColors.success,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMobileSummaryCard(
                title: '日均完成',
                value: stats.dailyAverage.toStringAsFixed(1),
                subtitle: '个/天',
                icon: FluentIcons.calendar_day_24_filled,
                color: AmberColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 第二行：效率指数 + 待办积压
        Row(
          children: [
            Expanded(
              child: _buildMobileSummaryCard(
                title: '效率指数',
                value: '${stats.efficiencyScore}',
                subtitle: stats.efficiencyGrade,
                subtitleBadge: true,
                subtitleColor: _getGradeColor(stats.efficiencyGrade),
                icon: FluentIcons.gauge_24_filled,
                color: AmberColors.info,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMobileSummaryCard(
                title: '待办积压',
                value: '${stats.backlogCount}',
                subtitle: stats.backlogNeedsAttention ? '需关注' : '正常',
                subtitleColor: stats.backlogNeedsAttention
                    ? AmberColors.warning
                    : AmberColors.info,
                icon: FluentIcons.clock_24_filled,
                color: stats.backlogNeedsAttention
                    ? AmberColors.warning
                    : AmberColors.info,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建移动端单个统计卡片
  Widget _buildMobileSummaryCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    Color? subtitleColor,
    bool subtitleBadge = false,
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AmberColors.textPrimary,
                    height: 1.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              if (subtitleBadge)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: (subtitleColor ?? AmberColors.textSecondary).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: subtitleColor ?? AmberColors.textSecondary,
                    ),
                  ),
                )
              else
                Flexible(
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: subtitleColor ?? AmberColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 获取效率等级对应的颜色
  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'A+':
      case 'A':
        return AmberColors.success;
      case 'B+':
      case 'B':
        return AmberColors.primary;
      case 'C':
        return AmberColors.warning;
      default:
        return AmberColors.textSecondary;
    }
  }

  /// 构建顶部四个统计卡片
  Widget _buildSummaryCards(MonthlyStatistics stats) {
    final growthPercent = (stats.growthRate * 100).round();
    final growthText = growthPercent >= 0 ? '+$growthPercent%' : '$growthPercent%';
    final growthColor = growthPercent >= 0 ? AmberColors.success : AmberColors.warning;

    return Row(
      children: [
        // 1. 已完成任务
        _buildSummaryCard(
          title: '已完成任务',
          value: '${stats.totalCompleted}',
          subtitle: growthText,
          subtitleColor: growthColor,
          icon: FluentIcons.checkmark_circle_24_filled,
          color: AmberColors.success,
          backgroundIcon: Icons.check_circle_outline,
          progress: null,
        ),
        const SizedBox(width: 16),
        // 2. 日均完成（删除进度条，与其他卡片保持一致高度）
        _buildSummaryCard(
          title: '日均完成',
          value: stats.dailyAverage.toStringAsFixed(1),
          subtitle: '平均${stats.dailyAverage.toStringAsFixed(1)}/天',
          subtitleColor: AmberColors.textSecondary,
          icon: FluentIcons.data_trending_24_filled,
          color: AmberColors.primary,
          backgroundIcon: Icons.bar_chart_rounded,
          progress: null,
        ),
        const SizedBox(width: 16),
        // 3. 效率指数（删除进度条，与其他卡片保持一致高度）
        _buildSummaryCard(
          title: '效率指数',
          value: '${stats.efficiencyScore}',
          subtitle: stats.efficiencyGrade,
          subtitleColor: _getGradeColor(stats.efficiencyGrade),
          subtitleBadge: true,
          icon: FluentIcons.gauge_24_filled,
          color: AmberColors.info,
          backgroundIcon: Icons.speed_outlined,
          progress: null,
        ),
        const SizedBox(width: 16),
        // 4. 待办积压
        _buildSummaryCard(
          title: '待办积压',
          value: '${stats.backlogCount}',
          subtitle: stats.backlogNeedsAttention ? '需关注' : '正常',
          subtitleColor: stats.backlogNeedsAttention ? AmberColors.warning : AmberColors.success,
          subtitleBadge: true,
          icon: FluentIcons.warning_24_filled,
          color: stats.backlogNeedsAttention ? AmberColors.warning : AmberColors.info,
          backgroundIcon: Icons.pending_actions_outlined,
          progress: null,
        ),
      ],
    );
  }

  /// 构建单个统计卡片（带背景模糊图标和进度条）
  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String subtitle,
    required Color subtitleColor,
    bool subtitleBadge = false,
    required IconData icon,
    required Color color,
    required IconData backgroundIcon,
    double? progress,
    String? extraText,
    Color? extraColor,
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
                  imageFilter: ImageFilter.blur(sigmaX: 0.8, sigmaY: 0.8),
                  child: Icon(
                    backgroundIcon,
                    size: 56,
                    color: color.withValues(alpha: 0.15),
                  ),
                ),
              ),
            ),
            // 前景内容
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    // 用 Expanded 包裹文字列，避免窄窗口溢出
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AmberColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Flexible(
                                child: Text(
                                  value,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: AmberColors.textPrimary,
                                    height: 1.1,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              // 副标题/徽章
                              if (subtitleBadge)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: subtitleColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    subtitle,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: subtitleColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                )
                              else
                                Flexible(
                                  child: Text(
                                    subtitle,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: subtitleColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // 进度条
                if (progress != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AmberColors.divider,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 4,
                    ),
                  ),
                ],
                // 额外文本
                if (extraText != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: extraColor ?? AmberColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        extraText,
                        style: TextStyle(
                          fontSize: 11,
                          color: extraColor ?? AmberColors.success,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建每日任务完成趋势图区域
  Widget _buildTrendChartSection(MonthlyStatistics stats, {bool isMobile = false}) {
    final daysInMonth = stats.dailyCompletedCounts.length;
    if (daysInMonth == 0) {
      return _buildEmptyChartCard('每日任务完成趋势', '暂无数据');
    }

    // 判断是否为当前月，如果是历史月份则没有"今天"的概念
    final now = DateTime.now();
    final isCurrentMonth = _targetDate.year == now.year && _targetDate.month == now.month;
    // 当前月用今天日期，历史月用 -1（表示没有"今天"）
    final today = isCurrentMonth ? now.day : -1;

    // 计算 Y 轴最大值
    final maxCompleted = stats.dailyCompletedCounts.isEmpty
        ? 10
        : stats.dailyCompletedCounts.reduce((a, b) => a > b ? a : b);
    final maxCreated = stats.dailyCreatedCounts.isEmpty
        ? 10
        : stats.dailyCreatedCounts.reduce((a, b) => a > b ? a : b);
    final maxY = ((maxCompleted > maxCreated ? maxCompleted : maxCreated) + 2).toDouble();

    // 新增线条颜色（更浅的灰色）
    final createdLineColor = AmberColors.textSecondary.withValues(alpha: 0.4);

    // 移动端高度较矮
    final chartHeight = isMobile ? 280.0 : 350.0;

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
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: AmberColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '每日任务完成趋势',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AmberColors.textPrimary,
                ),
              ),
              const Spacer(),
              // 图例（新增用更浅的颜色）
              _buildLegendItem(AmberColors.primary, '完成'),
              const SizedBox(width: 16),
              _buildLegendItem(createdLineColor, '新增'),
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
                  maxY: maxY,
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => AmberColors.cardBackground,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final isCompleted = spot.barIndex == 0;
                          return LineTooltipItem(
                            '${spot.y.round()} ${isCompleted ? "完成" : "新增"}',
                            TextStyle(
                              color: isCompleted ? AmberColors.primary : createdLineColor,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }).toList();
                      },
                    ),
                    // 点击顶点显示当天详情
                    touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
                      if (event is FlTapUpEvent &&
                          response != null &&
                          response.lineBarSpots != null &&
                          response.lineBarSpots!.isNotEmpty) {
                        final spot = response.lineBarSpots!.first;
                        final dayIndex = spot.x.toInt(); // 0-indexed
                        _showDayDetailDialog(dayIndex, stats);
                      }
                    },
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY > 10 ? (maxY / 5).ceilToDouble() : 2,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: AmberColors.divider,
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
                          final day = value.toInt() + 1; // 1-indexed 日期
                          final isToday = day == today;

                          // 计算当天是否和 5 的倍数日期太近（距离 <= 1）
                          // 如果太近，优先显示当天，隐藏 5 的倍数
                          final isFiveMultiple = day % 5 == 0;
                          final todayNearFiveMultiple = (today % 5 == 0) ||
                              ((today - 1) % 5 == 0) ||
                              ((today + 1) % 5 == 0);

                          // 如果当天与 5 倍数太近，5 倍数日期让位给当天
                          final shouldHideFiveMultiple = isFiveMultiple &&
                              !isToday &&
                              todayNearFiveMultiple &&
                              (day - today).abs() <= 1;

                          // 显示 1日、5日、10日...、最后一天、以及当天
                          // 但如果 5 倍数与当天太近，隐藏 5 倍数
                          final shouldShow = (day == 1 ||
                              (isFiveMultiple && !shouldHideFiveMultiple) ||
                              day == daysInMonth ||
                              isToday);
                          if (!shouldShow) return const SizedBox.shrink();

                          // 当天只用文字高亮（琥珀金 + 加粗），不用背景高亮，避免挤在一起
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              '$day日',
                              style: TextStyle(
                                color: isToday ? AmberColors.primary : AmberColors.textSecondary,
                                fontSize: 10,
                                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          );
                        },
                        reservedSize: 28,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: maxY > 10 ? (maxY / 5).ceilToDouble() : 2,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                              color: AmberColors.textSecondary,
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    // 完成任务线（实线）
                    LineChartBarData(
                      spots: stats.dailyCompletedCounts.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value.toDouble());
                      }).toList(),
                      isCurved: true,
                      curveSmoothness: 0.3,
                      color: AmberColors.primary,
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          final isToday = index == today - 1;
                          // 当天用实心大圆点，其他用空心小圆点
                          if (isToday) {
                            return FlDotCirclePainter(
                              radius: 5,
                              color: AmberColors.primary,
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            );
                          }
                          return FlDotCirclePainter(
                            radius: 3,
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
                    // 新增任务线（虚线，颜色更浅）
                    LineChartBarData(
                      spots: stats.dailyCreatedCounts.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value.toDouble());
                      }).toList(),
                      isCurved: true,
                      curveSmoothness: 0.3,
                      color: createdLineColor,
                      barWidth: 2,
                      isStrokeCapRound: true,
                      dashArray: [5, 5],
                      dotData: const FlDotData(show: false),
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

  /// 显示某天的任务完成详情弹窗
  void _showDayDetailDialog(int dayIndex, MonthlyStatistics stats) {
    // 使用选中的目标月份，而不是当前月
    final targetDate = DateTime(_targetDate.year, _targetDate.month, dayIndex + 1);
    final dateStr = '${_targetDate.month}月${dayIndex + 1}日';
    final completed = stats.dailyCompletedCounts[dayIndex];
    final created = stats.dailyCreatedCounts[dayIndex];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$dateStr 任务详情'),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 350,
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 统计数据
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
                        '📊 当日统计',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildClickableStatItem(
                              label: '完成任务',
                              value: '$completed',
                              color: AmberColors.primary,
                              onTap: kDebugMode && completed > 0
                                  ? () => _showTaskListDialog(
                                        context,
                                        '完成任务',
                                        targetDate,
                                        isCompleted: true,
                                      )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildClickableStatItem(
                              label: '新增任务',
                              value: '$created',
                              color: AmberColors.textSecondary,
                              onTap: kDebugMode && created > 0
                                  ? () => _showTaskListDialog(
                                        context,
                                        '新增任务',
                                        targetDate,
                                        isCreated: true,
                                      )
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // 净完成量
                      Row(
                        children: [
                          const Text('净完成量：'),
                          Text(
                            '${completed - created}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: (completed - created) >= 0
                                  ? AmberColors.success
                                  : AmberColors.warning,
                            ),
                          ),
                          Text(
                            (completed - created) >= 0
                                ? ' (完成 > 新增)'
                                : ' (新增 > 完成)',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AmberColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 说明
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AmberColors.primaryLight.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '💡 数据说明',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• 完成任务：当天标记为完成的任务数',
                        style: TextStyle(fontSize: 13),
                      ),
                      const Text(
                        '• 新增任务：当天创建的任务数',
                        style: TextStyle(fontSize: 13),
                      ),
                      const Text(
                        '• 净完成量 = 完成 - 新增',
                        style: TextStyle(fontSize: 13),
                      ),
                      if (kDebugMode) ...[
                        const SizedBox(height: 8),
                        const Text(
                          '🔧 Debug: 点击数字查看具体任务',
                          style: TextStyle(fontSize: 12, color: AmberColors.info),
                        ),
                      ],
                    ],
                  ),
                ),
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

  /// 显示任务列表弹窗（debug模式下点击数字触发）
  Future<void> _showTaskListDialog(
    BuildContext parentContext,
    String title,
    DateTime targetDate, {
    bool isCompleted = false,
    bool isCreated = false,
  }) async {
    final database = ref.read(databaseProvider);
    final allTasks = await database.getAllTasks();

    // 当天的起止时间
    final dayStart = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    // 筛选任务
    List<Task> filteredTasks;
    if (isCompleted) {
      // 当天完成的任务
      filteredTasks = allTasks.where((t) =>
          t.isCompleted &&
          !t.isDeleted &&
          t.completedAt != null &&
          !t.completedAt!.isBefore(dayStart) &&
          t.completedAt!.isBefore(dayEnd)).toList();
    } else if (isCreated) {
      // 当天创建的任务
      filteredTasks = allTasks.where((t) =>
          !t.isDeleted &&
          !t.createdAt.isBefore(dayStart) &&
          t.createdAt.isBefore(dayEnd)).toList();
    } else {
      filteredTasks = [];
    }

    // 按时间排序
    filteredTasks.sort((a, b) {
      if (isCompleted) {
        return (b.completedAt ?? DateTime.now()).compareTo(a.completedAt ?? DateTime.now());
      } else {
        return b.createdAt.compareTo(a.createdAt);
      }
    });

    if (!parentContext.mounted) return;

    final fullDateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    showDialog(
      context: parentContext,
      builder: (context) => AlertDialog(
        title: Text('$title (${filteredTasks.length}个)'),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 500,
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: filteredTasks.isEmpty
              ? const Center(child: Text('没有找到任务'))
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: filteredTasks.asMap().entries.map((entry) {
                      final index = entry.key;
                      final task = entry.value;
                      return Container(
                        margin: EdgeInsets.only(bottom: index < filteredTasks.length - 1 ? 8 : 0),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AmberColors.divider),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 任务标题
                            Row(
                              children: [
                                Icon(
                                  task.isCompleted
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  size: 16,
                                  color: task.isCompleted
                                      ? AmberColors.success
                                      : AmberColors.textSecondary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    task.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      decoration: task.isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Debug 信息
                            DefaultTextStyle(
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: AmberColors.textSecondary,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('id: ${task.id}'),
                                  Text('createdAt: ${fullDateFormat.format(task.createdAt)}'),
                                  if (task.completedAt != null)
                                    Text('completedAt: ${fullDateFormat.format(task.completedAt!)}'),
                                  if (task.dueDate != null)
                                    Text('dueDate: ${DateFormat('yyyy-MM-dd').format(task.dueDate!)}'),
                                  if (task.originalDueDate != null)
                                    Text('originalDueDate: ${DateFormat('yyyy-MM-dd').format(task.originalDueDate!)}'),
                                  Text('postponeCount: ${task.postponeCount}'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
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

  /// 构建可点击的统计项（用于弹窗内，debug模式下可点击）
  Widget _buildClickableStatItem({
    required String label,
    required String value,
    required Color color,
    VoidCallback? onTap,
  }) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AmberColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
            // debug 模式下添加下划线提示可点击
            decoration: onTap != null ? TextDecoration.underline : null,
            decorationColor: color.withValues(alpha: 0.5),
          ),
        ),
      ],
    );

    if (onTap != null) {
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: content,
        ),
      );
    }
    return content;
  }

  /// 构建图例项
  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AmberColors.textSecondary,
          ),
        ),
      ],
    );
  }

  /// 构建任务类型分布区域（环形图）
  Widget _buildTypeDistributionSection(MonthlyStatistics stats, {bool isMobile = false}) {
    if (stats.typeDistribution.isEmpty) {
      return _buildEmptyChartCard('任务类型分布', '暂无数据');
    }

    final totalCount = stats.totalCompleted;

    // 移动端高度较矮
    final chartHeight = isMobile ? 300.0 : 350.0;

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
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: AmberColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '任务类型分布',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AmberColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 环形图（使用自定义绘制实现径向渐变效果）
          Expanded(
            child: Center(
              child: CustomPaint(
                size: const Size(180, 180),
                painter: _GradientDonutPainter(
                  distributions: stats.typeDistribution,
                  centerRadius: 55,
                  ringWidth: 35,
                ),
                child: SizedBox(
                  width: 180,
                  height: 180,
                  child: Center(
                    // 中心文字
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '总量',
                          style: TextStyle(
                            fontSize: 12,
                            color: AmberColors.textSecondary,
                          ),
                        ),
                        Text(
                          '$totalCount',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AmberColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 图例列表
          ...stats.typeDistribution.take(4).map((dist) {
            final percent = (dist.percentage * 100).round();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Color(dist.color),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dist.name,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AmberColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '$percent%',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AmberColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// 构建热力图区域（横向日历式布局，每行7天）
  Widget _buildHeatmapSection(MonthlyStatistics stats, {bool isMobile = false}) {
    final daysInMonth = stats.heatmapData.length;
    if (daysInMonth == 0) {
      return _buildEmptyChartCard('任务完成热力图', '暂无数据');
    }

    // 计算热力图最大值（用于颜色映射）
    final maxValue = stats.heatmapData.isEmpty
        ? 1
        : stats.heatmapData.reduce((a, b) => a > b ? a : b);

    // 计算目标月份第一天是星期几（使用 _targetDate 而不是当前时间）
    final firstDayOfMonth = DateTime(_targetDate.year, _targetDate.month, 1);
    final firstWeekday = (firstDayOfMonth.weekday % 7); // 周日=0, 周一=1...周六=6

    // 计算需要多少行（周）
    final totalCells = firstWeekday + daysInMonth;
    final numRows = (totalCells / 7).ceil();

    // 移动端高度较矮
    final chartHeight = isMobile ? 240.0 : 280.0;

    return Container(
      height: chartHeight,
      padding: EdgeInsets.all(isMobile ? 12 : 16),
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
                FluentIcons.grid_24_regular,
                color: AmberColors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                '任务完成热力图',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AmberColors.textPrimary,
                ),
              ),
              // TODO: 后续可添加"查看详情"按钮，跳转到月度任务列表
            ],
          ),
          const SizedBox(height: 12),
          // 热力图网格（每行7天 = 一周，4-5行 = 一个月）
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth;
                final availableHeight = constraints.maxHeight;

                // 固定小间距
                const gap = 4.0;

                // 根据可用空间计算格子大小
                // 宽度：7 个格子 + 6 个间距
                final cellByWidth = (availableWidth - gap * 6) / 7;
                // 高度：numRows 个格子 + (numRows-1) 个间距
                final cellByHeight = (availableHeight - gap * (numRows - 1)) / numRows;
                // 取较小值保证不溢出
                final cellSize = cellByWidth < cellByHeight ? cellByWidth : cellByHeight;

                // 计算实际总宽高，用于居中
                final totalWidth = cellSize * 7 + gap * 6;
                final totalHeight = cellSize * numRows + gap * (numRows - 1);

                return Center(
                  child: SizedBox(
                    width: totalWidth,
                    height: totalHeight,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(numRows, (rowIndex) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: rowIndex < numRows - 1 ? gap : 0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(7, (colIndex) {
                              final dayIndex = rowIndex * 7 + colIndex - firstWeekday;

                              if (dayIndex < 0 || dayIndex >= daysInMonth) {
                                // 空白单元格（月初/月末的空位）
                                return Container(
                                  width: cellSize,
                                  height: cellSize,
                                  margin: EdgeInsets.only(right: colIndex < 6 ? gap : 0),
                                );
                              }
                              final value = stats.heatmapData[dayIndex];
                              final intensity = maxValue > 0 ? value / maxValue : 0.0;
                              return Tooltip(
                                message: '${dayIndex + 1}日: $value 个任务',
                                child: Container(
                                  width: cellSize,
                                  height: cellSize,
                                  margin: EdgeInsets.only(right: colIndex < 6 ? gap : 0),
                                  decoration: BoxDecoration(
                                    color: _getHeatmapColor(intensity),
                                    borderRadius: BorderRadius.circular(cellSize * 0.15),
                                  ),
                                ),
                              );
                            }),
                          ),
                        );
                      }),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // 热力图图例（放在 Expanded 外面，固定高度）
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text(
                '少',
                style: TextStyle(fontSize: 11, color: AmberColors.textSecondary),
              ),
              const SizedBox(width: 4),
              ...List.generate(5, (index) {
                final intensity = index / 4;
                return Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: _getHeatmapColor(intensity),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
              const SizedBox(width: 4),
              const Text(
                '多',
                style: TextStyle(fontSize: 11, color: AmberColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 获取热力图颜色（基于强度 0.0-1.0）
  Color _getHeatmapColor(double intensity) {
    if (intensity <= 0) {
      return const Color(0xFFF5F5F5); // 灰色（无数据）
    } else if (intensity < 0.25) {
      return const Color(0xFFFFF3E0); // 最浅橙色
    } else if (intensity < 0.5) {
      return const Color(0xFFFFE0B2); // 浅橙色
    } else if (intensity < 0.75) {
      return const Color(0xFFFFB74D); // 中等橙色
    } else {
      return AmberColors.primary; // 深橙色
    }
  }

  /// 构建本月成就区域
  Widget _buildAchievementsSection(MonthlyStatistics stats, {bool isMobile = false}) {
    // 移动端高度较矮
    final chartHeight = isMobile ? 240.0 : 280.0;

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
                FluentIcons.trophy_24_filled,
                color: AmberColors.warning,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                '本月成就',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AmberColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 成就列表
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: stats.achievements.length.clamp(0, 4),
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final achievement = stats.achievements[index];
                return _buildAchievementItem(achievement);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 构建单个成就项
  Widget _buildAchievementItem(Achievement achievement) {
    final iconColor = achievement.isAchieved
        ? AmberColors.warning
        : AmberColors.textDisabled;
    final bgColor = achievement.isAchieved
        ? AmberColors.warning.withValues(alpha: 0.1)
        : AmberColors.divider.withValues(alpha: 0.3);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: achievement.isAchieved
            ? Border.all(color: AmberColors.warning.withValues(alpha: 0.3))
            : null,
      ),
      child: Row(
        children: [
          // 成就图标
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              achievement.icon,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(width: 12),
          // 成就信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: achievement.isAchieved
                        ? AmberColors.textPrimary
                        : AmberColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  achievement.description,
                  style: TextStyle(
                    fontSize: 11,
                    color: achievement.isAchieved
                        ? AmberColors.textSecondary
                        : AmberColors.textDisabled,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // 达成状态图标
          if (achievement.isAchieved)
            Icon(
              FluentIcons.checkmark_circle_24_filled,
              color: AmberColors.success,
              size: 20,
            ),
        ],
      ),
    );
  }

  /// 构建空数据卡片
  Widget _buildEmptyChartCard(String title, String message) {
    return Container(
      height: 350,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AmberColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AmberColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: AmberColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AmberColors.textPrimary,
                ),
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  color: AmberColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 自定义绘制器：带径向渐变效果的环形图
///
/// 设计哲学：
/// - 每个扇形区域从外侧到内侧有颜色渐变（外深内浅）
/// - 模拟光照从中心向外辐射的效果
/// - 比 fl_chart 的纯色环形图更有立体感
class _GradientDonutPainter extends CustomPainter {
  final List<TaskTypeDistribution> distributions;
  final double centerRadius;
  final double ringWidth;

  _GradientDonutPainter({
    required this.distributions,
    required this.centerRadius,
    required this.ringWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = centerRadius + ringWidth;

    // 计算总数
    final total = distributions.fold<double>(0, (sum, d) => sum + d.count);
    if (total == 0) return;

    // 起始角度（从顶部开始，-90度）
    double startAngle = -90 * (3.14159265359 / 180);
    const gap = 2 * (3.14159265359 / 180); // 2度的间隙

    for (final dist in distributions) {
      final sweepAngle = (dist.count / total) * 2 * 3.14159265359 - gap;
      if (sweepAngle <= 0) continue;

      final baseColor = Color(dist.color);

      // 创建径向渐变：外侧颜色深，内侧颜色浅
      final gradient = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [
          baseColor.withValues(alpha: 0.3), // 内侧浅
          baseColor, // 外侧深
        ],
        stops: const [0.5, 1.0],
      );

      // 创建渐变着色器
      final rect = Rect.fromCircle(center: center, radius: outerRadius);
      final paint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth
        ..strokeCap = StrokeCap.butt;

      // 绘制弧形
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: centerRadius + ringWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _GradientDonutPainter oldDelegate) {
    return oldDelegate.distributions != distributions ||
        oldDelegate.centerRadius != centerRadius ||
        oldDelegate.ringWidth != ringWidth;
  }
}
