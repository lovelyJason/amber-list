import 'package:fl_chart/fl_chart.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/models/poster_config.dart';
import '../../../../../core/models/widget_skins.dart';
import '../../../../providers/statistics_provider.dart';
import 'poster_watermark.dart';

/// 月视图海报 Widget
///
/// 将月度统计数据渲染为可导出的海报图片
/// 支持三种尺寸布局：竖版 9:16、方形 1:1、横版 16:9
///
/// 设计原则：
/// - 简化版图表，移除交互功能
/// - 根据尺寸自适应布局
/// - 底部显示琥珀清单 Logo 水印
class MonthlyPosterWidget extends StatelessWidget {
  /// 月度统计数据
  final MonthlyStatistics stats;

  /// 海报配置
  final PosterConfig config;

  const MonthlyPosterWidget({
    super.key,
    required this.stats,
    required this.config,
  });

  /// 获取皮肤配置
  WidgetSkinConfig get _skin => config.skinConfig;

  /// 获取目标日期
  DateTime get _targetDate => config.targetDate;

  @override
  Widget build(BuildContext context) {
    final size = config.getPosterSize();

    return Container(
      width: size.width,
      height: size.height,
      decoration: _buildBackgroundDecoration(),
      child: Stack(
        children: [
          // 创意风格：叠加半透明背景图
          if (config.styleType == PosterStyleType.creative &&
              _skin.isContrastSkin)
            Positioned.fill(
              child: Image.asset(
                _skin.backgroundImagePath!,
                fit: BoxFit.cover,
                opacity: const AlwaysStoppedAnimation(0.25), // 低透明度，不遮挡内容
              ),
            ),
          // 主要内容
          Padding(
            padding: EdgeInsets.all(size.width * 0.04), // 4% 边距
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 顶部标题
                _buildHeader(),
                SizedBox(height: size.height * 0.02),

                // 统计卡片
                _buildStatCards(),
                SizedBox(height: size.height * 0.025),

                // 图表区域
                Expanded(child: _buildChartsSection()),
                SizedBox(height: size.height * 0.015),

                // 底部水印
                const PosterWatermark(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建背景装饰
  BoxDecoration _buildBackgroundDecoration() {
    if (config.styleType == PosterStyleType.creative && _skin.isContrastSkin) {
      // 创意风格：使用纯色底色，背景图通过 Stack 叠加
      return BoxDecoration(
        color: _skin.startColor,
      );
    } else {
      // 品牌风格：使用渐变
      return BoxDecoration(gradient: _skin.previewGradient);
    }
  }

  /// 构建标题区域
  Widget _buildHeader() {
    final monthStr = DateFormat('yyyy年M月').format(_targetDate);
    final fontSize = config.isVertical ? 42.0 : 36.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              monthStr,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: _skin.textColor,
              ),
            ),
            Text(
              '月度统计报告',
              style: TextStyle(
                fontSize: fontSize * 0.4,
                color: _skin.secondaryTextColor,
              ),
            ),
          ],
        ),
        // Logo 图标
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _skin.textColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            FluentIcons.checkmark_circle_24_filled,
            size: fontSize * 1.2,
            color: _skin.iconColor,
          ),
        ),
      ],
    );
  }

  /// 构建统计卡片
  Widget _buildStatCards() {
    if (config.isVertical) {
      // 竖版：2x2 网格
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  '已完成',
                  '${stats.totalCompleted}',
                  FluentIcons.checkmark_circle_24_filled,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  '日均',
                  stats.dailyAverage.toStringAsFixed(1),
                  FluentIcons.calendar_day_24_filled,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  '效率指数',
                  '${stats.efficiencyScore}',
                  FluentIcons.gauge_24_filled,
                  subtitle: stats.efficiencyGrade,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  '待办积压',
                  '${stats.backlogCount}',
                  FluentIcons.clock_24_filled,
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      // 方形/横版：横向排列
      return Row(
        children: [
          Expanded(
            child: _buildStatCard(
              '已完成',
              '${stats.totalCompleted}',
              FluentIcons.checkmark_circle_24_filled,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              '日均',
              stats.dailyAverage.toStringAsFixed(1),
              FluentIcons.calendar_day_24_filled,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              '效率',
              '${stats.efficiencyScore}',
              FluentIcons.gauge_24_filled,
              subtitle: stats.efficiencyGrade,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              '积压',
              '${stats.backlogCount}',
              FluentIcons.clock_24_filled,
            ),
          ),
        ],
      );
    }
  }

  /// 构建单个统计卡片
  Widget _buildStatCard(
    String title,
    String value,
    IconData icon, {
    String? subtitle,
  }) {
    final valueFontSize = config.isVertical ? 36.0 : 28.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _skin.textColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _skin.textColor.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _skin.iconColor, size: 24),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: valueFontSize,
                  fontWeight: FontWeight.bold,
                  color: _skin.textColor,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: valueFontSize * 0.5,
                      fontWeight: FontWeight.w600,
                      color: _skin.secondaryTextColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: _skin.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建图表区域
  Widget _buildChartsSection() {
    if (config.isVertical) {
      // 竖版：上下堆叠
      return Column(
        children: [
          // 趋势折线图
          Expanded(
            flex: 3,
            child: _buildChartCard(
              title: '每日完成趋势',
              child: _buildTrendChart(),
            ),
          ),
          const SizedBox(height: 12),
          // 类型分布 + 热力图
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Expanded(
                  child: _buildChartCard(
                    title: '任务分布',
                    child: _buildTypeChart(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildChartCard(
                    title: '热力图',
                    child: _buildHeatmap(),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    } else if (config.isSquare) {
      // 方形：2x2 布局
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildChartCard(
                    title: '每日完成趋势',
                    child: _buildTrendChart(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildChartCard(
                    title: '任务分布',
                    child: _buildTypeChart(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _buildChartCard(
              title: '完成热力图',
              child: _buildHeatmap(),
            ),
          ),
        ],
      );
    } else {
      // 横版：并排布局，crossAxisAlignment.stretch 让子元素填满高度
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: _buildChartCard(
              title: '每日完成趋势',
              child: _buildTrendChart(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildChartCard(
              title: '任务分布',
              child: _buildTypeChart(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildChartCard(
              title: '热力图',
              child: _buildHeatmap(),
            ),
          ),
        ],
      );
    }
  }

  /// 构建图表卡片容器
  Widget _buildChartCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _skin.textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _skin.textColor.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _skin.textColor,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: child),
        ],
      ),
    );
  }

  /// 构建趋势折线图
  Widget _buildTrendChart() {
    final daysInMonth = stats.dailyCompletedCounts.length;
    if (daysInMonth == 0) {
      return Center(
        child: Text(
          '暂无数据',
          style: TextStyle(color: _skin.secondaryTextColor),
        ),
      );
    }

    final maxValue = stats.dailyCompletedCounts.isEmpty
        ? 10.0
        : (stats.dailyCompletedCounts.reduce((a, b) => a > b ? a : b) + 2)
            .toDouble();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxValue / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: _skin.textColor.withValues(alpha: 0.1),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (daysInMonth / 5).ceilToDouble(),
              getTitlesWidget: (value, meta) {
                final day = value.toInt() + 1;
                if (day == 1 || day == daysInMonth || day % 5 == 0) {
                  return Text(
                    '$day',
                    style: TextStyle(
                      color: _skin.secondaryTextColor,
                      fontSize: 10,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: maxValue / 4,
              reservedSize: 30,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: TextStyle(
                  color: _skin.secondaryTextColor,
                  fontSize: 10,
                ),
              ),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (daysInMonth - 1).toDouble(),
        minY: 0,
        maxY: maxValue,
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
              daysInMonth,
              (i) => FlSpot(i.toDouble(), stats.dailyCompletedCounts[i].toDouble()),
            ),
            isCurved: true,
            curveSmoothness: 0.3,
            color: _skin.textColor,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: _skin.textColor.withValues(alpha: 0.2),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建类型分布饼图
  Widget _buildTypeChart() {
    if (stats.typeDistribution.isEmpty) {
      return Center(
        child: Text(
          '暂无数据',
          style: TextStyle(color: _skin.secondaryTextColor),
        ),
      );
    }

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 30,
        pieTouchData: PieTouchData(enabled: false),
        sections: stats.typeDistribution.take(5).map((dist) {
          return PieChartSectionData(
            color: Color(dist.color),
            value: dist.percentage * 100,
            title: '',
            radius: 40,
          );
        }).toList(),
      ),
    );
  }

  /// 构建热力图
  Widget _buildHeatmap() {
    final daysInMonth = stats.heatmapData.length;
    if (daysInMonth == 0) {
      return Center(
        child: Text(
          '暂无数据',
          style: TextStyle(color: _skin.secondaryTextColor),
        ),
      );
    }

    final maxValue = stats.heatmapData.isEmpty
        ? 1
        : stats.heatmapData.reduce((a, b) => a > b ? a : b);

    // 计算第一天是星期几
    final firstDayOfMonth = DateTime(_targetDate.year, _targetDate.month, 1);
    final firstWeekday = firstDayOfMonth.weekday % 7; // 周日=0

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellSize = (constraints.maxWidth - 6 * 4) / 7; // 7列，6个间隙

        return Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            // 填充月初空白
            ...List.generate(
              firstWeekday,
              (_) => SizedBox(width: cellSize, height: cellSize),
            ),
            // 每天的格子
            ...List.generate(daysInMonth, (i) {
              final value = stats.heatmapData[i];
              final intensity = maxValue > 0 ? value / maxValue : 0.0;

              return Container(
                width: cellSize,
                height: cellSize,
                decoration: BoxDecoration(
                  color: _getHeatmapColor(intensity),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  /// 获取热力图颜色
  Color _getHeatmapColor(double intensity) {
    if (intensity <= 0) {
      return _skin.textColor.withValues(alpha: 0.05);
    } else if (intensity < 0.25) {
      return _skin.textColor.withValues(alpha: 0.15);
    } else if (intensity < 0.5) {
      return _skin.textColor.withValues(alpha: 0.3);
    } else if (intensity < 0.75) {
      return _skin.textColor.withValues(alpha: 0.5);
    } else {
      return _skin.textColor.withValues(alpha: 0.7);
    }
  }
}
