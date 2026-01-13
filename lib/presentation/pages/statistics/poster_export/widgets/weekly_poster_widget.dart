import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/constants.dart';
import '../../../../../core/models/poster_config.dart';
import '../../../../../core/models/widget_skins.dart';
import '../../../../providers/statistics_provider.dart';

/// 周视图海报 Widget
///
/// 用于导出为图片的周统计海报，包含：
/// - 周范围标题（如 "2025年1月 第2周"）
/// - 本周完成数、日均完成数
/// - 每日完成柱状图
/// - 达成率折线图
/// - 琥珀清单 Logo 水印
///
/// 设计说明：
/// - 支持三种尺寸布局（9:16 竖版、1:1 方形、16:9 横版）
/// - 品牌风格使用渐变背景，创意风格使用水墨背景图
class WeeklyPosterWidget extends StatelessWidget {
  /// 海报配置（尺寸、风格、皮肤等）
  final PosterConfig config;

  /// 周统计数据
  final WeeklyStatistics stats;

  /// 周的起止日期范围
  final DateTime weekStart;
  final DateTime weekEnd;

  const WeeklyPosterWidget({
    super.key,
    required this.config,
    required this.stats,
    required this.weekStart,
    required this.weekEnd,
  });

  /// 获取皮肤配置
  WidgetSkinConfig get _skin => config.skinConfig;

  /// 星期标签
  static const List<String> _weekDays = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  Widget build(BuildContext context) {
    final posterSize = config.getPosterSize();

    return Container(
      width: posterSize.width,
      height: posterSize.height,
      decoration: _buildBackground(),
      child: Stack(
        children: [
          // 背景装饰
          _buildBackgroundDecoration(),
          // 主要内容
          Padding(
            padding: _getContentPadding(),
            child: _buildContent(),
          ),
          // 底部 Logo 水印
          Positioned(
            left: 0,
            right: 0,
            bottom: _getBottomPadding(),
            child: _buildWatermark(),
          ),
        ],
      ),
    );
  }

  /// 获取内容区域 Padding
  EdgeInsets _getContentPadding() {
    if (config.isVertical) {
      return const EdgeInsets.fromLTRB(48, 80, 48, 120);
    } else if (config.isSquare) {
      return const EdgeInsets.fromLTRB(48, 56, 48, 100);
    } else {
      return const EdgeInsets.fromLTRB(80, 48, 80, 80);
    }
  }

  /// 获取底部 Logo 间距
  double _getBottomPadding() {
    if (config.isVertical) return 48;
    if (config.isSquare) return 32;
    return 24;
  }

  /// 构建背景装饰
  BoxDecoration _buildBackground() {
    if (config.styleType == PosterStyleType.brand) {
      // 品牌风格：纯色或渐变背景
      return BoxDecoration(
        gradient: _skin.previewGradient,
      );
    } else {
      // 创意风格：使用皮肤的起始色作为背景底色
      return BoxDecoration(
        color: _skin.startColor,
      );
    }
  }

  /// 构建背景装饰元素
  Widget _buildBackgroundDecoration() {
    if (config.styleType == PosterStyleType.creative &&
        _skin.backgroundImagePath != null) {
      // 创意风格：水墨背景图，低透明度不遮挡内容
      return Positioned.fill(
        child: Image.asset(
          _skin.backgroundImagePath!,
          fit: BoxFit.cover,
          opacity: const AlwaysStoppedAnimation(0.25),
        ),
      );
    }

    // 品牌风格：抽象装饰圆
    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
        ),
        Positioned(
          bottom: -150,
          left: -80,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
        ),
      ],
    );
  }

  /// 构建主要内容
  Widget _buildContent() {
    if (config.isVertical) {
      return _buildVerticalLayout();
    } else if (config.isSquare) {
      return _buildSquareLayout();
    } else {
      return _buildHorizontalLayout();
    }
  }

  /// 构建竖版布局（9:16）
  Widget _buildVerticalLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 顶部标题区
        _buildHeader(),
        const SizedBox(height: 48),
        // 统计卡片（2x1）
        _buildStatCards(isVertical: true),
        const SizedBox(height: 48),
        // 每日完成柱状图
        Expanded(
          flex: 5,
          child: _buildBarChart(),
        ),
        const SizedBox(height: 32),
        // 达成率折线图
        Expanded(
          flex: 4,
          child: _buildLineChart(),
        ),
      ],
    );
  }

  /// 构建方形布局（1:1）
  Widget _buildSquareLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 顶部标题区
        _buildHeader(),
        const SizedBox(height: 32),
        // 统计卡片（横向排列）
        _buildStatCards(isVertical: false),
        const SizedBox(height: 32),
        // 图表区域
        Expanded(
          child: Row(
            children: [
              // 柱状图
              Expanded(
                flex: 6,
                child: _buildBarChart(),
              ),
              const SizedBox(width: 24),
              // 折线图
              Expanded(
                flex: 4,
                child: _buildLineChart(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建横版布局（16:9）
  Widget _buildHorizontalLayout() {
    return Row(
      children: [
        // 左侧：标题 + 统计卡片
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 40),
              _buildStatCards(isVertical: true),
              const Spacer(),
            ],
          ),
        ),
        const SizedBox(width: 48),
        // 右侧：图表
        Expanded(
          flex: 7,
          child: Column(
            children: [
              Expanded(
                flex: 6,
                child: _buildBarChart(),
              ),
              const SizedBox(height: 24),
              Expanded(
                flex: 4,
                child: _buildLineChart(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 构建标题区域
  Widget _buildHeader() {
    final weekNum = _getWeekNumber();
    final monthStr = DateFormat('yyyy年M月').format(weekStart);
    final rangeStr =
        '${DateFormat('M.d').format(weekStart)} - ${DateFormat('M.d').format(weekEnd)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 主标题：月份 + 第N周
        Text(
          '$monthStr 第$weekNum周',
          style: TextStyle(
            fontSize: config.isHorizontal ? 40 : 48,
            fontWeight: FontWeight.bold,
            color: _skin.textColor,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        // 副标题：日期范围
        Text(
          rangeStr,
          style: TextStyle(
            fontSize: config.isHorizontal ? 18 : 22,
            color: _skin.secondaryTextColor,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  /// 获取周数（当月第几周）
  int _getWeekNumber() {
    final firstDayOfMonth = DateTime(weekStart.year, weekStart.month, 1);
    final firstMondayOfMonth = firstDayOfMonth.subtract(
      Duration(days: (firstDayOfMonth.weekday - 1) % 7),
    );
    return ((weekStart.difference(firstMondayOfMonth).inDays) ~/ 7) + 1;
  }

  /// 构建统计卡片
  Widget _buildStatCards({required bool isVertical}) {
    final cards = [
      _buildStatCard(
        title: '本周完成',
        value: '${stats.totalCompleted}',
        unit: '个任务',
      ),
      _buildStatCard(
        title: '日均完成',
        value: stats.dailyAverage.toStringAsFixed(1),
        unit: '个/天',
      ),
    ];

    if (isVertical) {
      return Row(
        children: [
          Expanded(child: cards[0]),
          const SizedBox(width: 16),
          Expanded(child: cards[1]),
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(child: cards[0]),
          const SizedBox(width: 16),
          Expanded(child: cards[1]),
        ],
      );
    }
  }

  /// 构建单个统计卡片
  Widget _buildStatCard({
    required String title,
    required String value,
    required String unit,
  }) {
    final bool isDarkSkin = _skin.textColor == Colors.white ||
        _skin.textColor.computeLuminance() > 0.5;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkSkin
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkSkin
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: _skin.secondaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: _skin.textColor,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: 14,
                    color: _skin.secondaryTextColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建柱状图
  Widget _buildBarChart() {
    final bool isDarkSkin = _skin.textColor == Colors.white ||
        _skin.textColor.computeLuminance() > 0.5;

    // 找到最大值的索引
    int maxIndex = 0;
    int maxValue = stats.dailyCompletedCounts[0];
    for (int i = 1; i < stats.dailyCompletedCounts.length; i++) {
      if (stats.dailyCompletedCounts[i] > maxValue) {
        maxValue = stats.dailyCompletedCounts[i];
        maxIndex = i;
      }
    }

    // 计算 Y 轴最大值（向上取整到合适的值）
    final maxY = (maxValue == 0) ? 6.0 : (maxValue * 1.3).ceilToDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkSkin
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Text(
            '每日完成趋势',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _skin.textColor,
            ),
          ),
          const SizedBox(height: 20),
          // 柱状图
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < _weekDays.length) {
                          final isMax = index == maxIndex;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _weekDays[index],
                              style: TextStyle(
                                color: isMax
                                    ? _skin.iconColor
                                    : _skin.secondaryTextColor,
                                fontSize: 12,
                                fontWeight:
                                    isMax ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                      reservedSize: 32,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: maxY > 6 ? (maxY / 4).ceilToDouble() : 2,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            color: _skin.secondaryTextColor,
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY > 6 ? (maxY / 4).ceilToDouble() : 2,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: _skin.secondaryTextColor.withValues(alpha: 0.2),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups:
                    stats.dailyCompletedCounts.asMap().entries.map((entry) {
                  final isMax = entry.key == maxIndex;
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.toDouble(),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: isMax
                              ? [_skin.iconColor, _skin.iconColor]
                              : [
                                  _skin.iconColor.withValues(alpha: 0.5),
                                  _skin.iconColor.withValues(alpha: 0.7),
                                ],
                        ),
                        width: config.isHorizontal ? 40 : 32,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建折线图（达成率）
  Widget _buildLineChart() {
    final bool isDarkSkin = _skin.textColor == Colors.white ||
        _skin.textColor.computeLuminance() > 0.5;
    final avgPercent = (stats.weeklyAverageRate * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkSkin
            ? _skin.iconColor.withValues(alpha: 0.2)
            : _skin.iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Row(
            children: [
              Text(
                '达成趋势',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _skin.textColor,
                ),
              ),
              const Spacer(),
              Text(
                '$avgPercent%',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _skin.iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 折线图
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 1,
                lineTouchData: LineTouchData(enabled: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 0.25,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: _skin.secondaryTextColor.withValues(alpha: 0.2),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        // 只显示周一、周四、周日
                        if (index == 0 || index == 3 || index == 6) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              _weekDays[index],
                              style: TextStyle(
                                fontSize: 10,
                                color: _skin.secondaryTextColor,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                      reservedSize: 28,
                    ),
                  ),
                  leftTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: stats.dailyAchievementRates
                        .asMap()
                        .entries
                        .where((entry) => entry.value >= 0)
                        .map((entry) =>
                            FlSpot(entry.key.toDouble(), entry.value))
                        .toList(),
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: _skin.iconColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: _skin.iconColor,
                          strokeWidth: 2,
                          strokeColor: isDarkSkin ? Colors.white : Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _skin.iconColor.withValues(alpha: 0.3),
                          _skin.iconColor.withValues(alpha: 0.05),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建底部水印
  Widget _buildWatermark() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Logo 图标
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AmberColors.primary, AmberColors.primaryDark],
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Center(
            child: Text(
              '琥',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // 应用名称
        Text(
          '琥珀清单',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: _skin.secondaryTextColor,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}
