import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screenshot/screenshot.dart';

import '../../../../core/models/poster_config.dart';
import '../../../../data/services/export_service.dart';
import '../../../providers/statistics_provider.dart';
import 'widgets/monthly_poster_widget.dart';
import 'widgets/weekly_poster_widget.dart';

/// 海报生成器
///
/// 负责将海报 Widget 渲染为图片并导出保存
/// 使用 screenshot package 实现 Widget 截图
///
/// 主要功能：
/// 1. 根据配置构建海报 Widget
/// 2. 使用 ScreenshotController 渲染 Widget 为图片
/// 3. 调用 ExportService 保存图片文件
class PosterGenerator {
  /// 生成并导出海报
  ///
  /// [config] 海报配置
  /// [ref] Riverpod ref，用于获取统计数据
  ///
  /// 返回保存的文件路径，用户取消或失败返回 null
  static Future<String?> generateAndExportPoster({
    required PosterConfig config,
    required WidgetRef ref,
  }) async {
    try {
      debugPrint('[PosterGenerator] 开始生成海报...');

      // 1. 获取统计数据
      final stats = await _fetchStatistics(config, ref);
      if (stats == null) {
        debugPrint('[PosterGenerator] 获取统计数据失败');
        return null;
      }

      // 2. 构建海报 Widget
      final posterWidget = _buildPosterWidget(config, stats);

      // 3. 渲染为图片
      final imageBytes = await _renderWidgetToImage(
        widget: posterWidget,
        size: config.getPosterSize(),
      );

      if (imageBytes == null) {
        debugPrint('[PosterGenerator] 渲染图片失败');
        return null;
      }

      debugPrint('[PosterGenerator] 图片渲染成功，大小: ${imageBytes.length} bytes');

      // 4. 导出保存
      final fileName = config.getFileName();
      final savedPath = await ExportService.exportPosterImage(imageBytes, fileName);

      return savedPath;
    } catch (e, stack) {
      debugPrint('[PosterGenerator] 生成海报出错: $e');
      debugPrint('[PosterGenerator] Stack: $stack');
      return null;
    }
  }

  /// 生成海报图片（不保存，用于预览）
  ///
  /// 返回图片字节数据
  static Future<Uint8List?> generatePosterImage({
    required PosterConfig config,
    required WidgetRef ref,
  }) async {
    try {
      // 1. 获取统计数据
      final stats = await _fetchStatistics(config, ref);
      if (stats == null) return null;

      // 2. 构建海报 Widget
      final posterWidget = _buildPosterWidget(config, stats);

      // 3. 渲染为图片
      return await _renderWidgetToImage(
        widget: posterWidget,
        size: config.getPosterSize(),
      );
    } catch (e) {
      debugPrint('[PosterGenerator] 生成预览图片出错: $e');
      return null;
    }
  }

  /// 获取统计数据
  static Future<dynamic> _fetchStatistics(
    PosterConfig config,
    WidgetRef ref,
  ) async {
    if (config.viewType == PosterViewType.monthly) {
      // 月视图：获取 MonthlyStatistics
      final asyncValue = ref.read(monthlyStatisticsForDateProvider(config.targetDate));
      // 如果数据还在加载，等待加载完成
      if (asyncValue.isLoading) {
        // 强制刷新并等待结果
        final result = await ref.refresh(monthlyStatisticsForDateProvider(config.targetDate).future);
        return result;
      }
      return asyncValue.valueOrNull;
    } else {
      // 周视图：获取 WeeklyStatistics
      final asyncValue = ref.read(weeklyStatisticsForDateProvider(config.targetDate));
      if (asyncValue.isLoading) {
        final result = await ref.refresh(weeklyStatisticsForDateProvider(config.targetDate).future);
        return result;
      }
      return asyncValue.valueOrNull;
    }
  }

  /// 构建海报 Widget
  static Widget _buildPosterWidget(PosterConfig config, dynamic stats) {
    if (config.viewType == PosterViewType.monthly) {
      return MonthlyPosterWidget(
        config: config,
        stats: stats as MonthlyStatistics,
      );
    } else {
      // 计算周的起止日期
      final targetDate = config.targetDate;
      final weekday = targetDate.weekday;
      final weekStart = targetDate.subtract(Duration(days: weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));

      return WeeklyPosterWidget(
        config: config,
        stats: stats as WeeklyStatistics,
        weekStart: weekStart,
        weekEnd: weekEnd,
      );
    }
  }

  /// 将 Widget 渲染为图片
  ///
  /// 使用 screenshot package 的 captureFromWidget 方法
  /// 这种方式不需要 BuildContext，可以在后台渲染
  static Future<Uint8List?> _renderWidgetToImage({
    required Widget widget,
    required Size size,
  }) async {
    try {
      final screenshotController = ScreenshotController();

      // 使用 captureFromWidget 在后台渲染 Widget
      final imageBytes = await screenshotController.captureFromWidget(
        MediaQuery(
          data: MediaQueryData(size: size),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Material(
              type: MaterialType.transparency,
              child: widget,
            ),
          ),
        ),
        pixelRatio: 2.0, // 2x 高清输出
        targetSize: size,
        delay: const Duration(milliseconds: 100), // 等待渲染完成
      );

      return imageBytes;
    } catch (e, stack) {
      debugPrint('[PosterGenerator] 渲染图片异常: $e');
      debugPrint('[PosterGenerator] Stack: $stack');
      return null;
    }
  }
}
