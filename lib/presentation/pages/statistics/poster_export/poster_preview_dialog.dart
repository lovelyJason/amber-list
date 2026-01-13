import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/models/poster_config.dart';
import '../../../providers/statistics_provider.dart';
import 'widgets/monthly_poster_widget.dart';
import 'widgets/weekly_poster_widget.dart';

/// 海报预览弹窗
///
/// 在导出前预览海报效果
/// 支持缩放预览，显示实际尺寸信息
class PosterPreviewDialog extends ConsumerStatefulWidget {
  /// 海报配置
  final PosterConfig config;

  const PosterPreviewDialog({
    super.key,
    required this.config,
  });

  @override
  ConsumerState<PosterPreviewDialog> createState() => _PosterPreviewDialogState();
}

class _PosterPreviewDialogState extends ConsumerState<PosterPreviewDialog> {
  /// 是否正在加载数据
  bool _isLoading = true;

  /// 统计数据（月度或周度）
  dynamic _stats;

  /// 错误信息
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  /// 加载统计数据
  Future<void> _loadStatistics() async {
    try {
      if (widget.config.viewType == PosterViewType.monthly) {
        // 月视图数据
        final asyncValue = ref.read(
          monthlyStatisticsForDateProvider(widget.config.targetDate),
        );
        if (asyncValue.hasValue) {
          setState(() {
            _stats = asyncValue.value;
            _isLoading = false;
          });
        } else if (asyncValue.isLoading) {
          // 等待数据加载
          final result = await ref.read(
            monthlyStatisticsForDateProvider(widget.config.targetDate).future,
          );
          if (mounted) {
            setState(() {
              _stats = result;
              _isLoading = false;
            });
          }
        } else if (asyncValue.hasError) {
          setState(() {
            _errorMessage = '加载数据失败: ${asyncValue.error}';
            _isLoading = false;
          });
        }
      } else {
        // 周视图数据
        final asyncValue = ref.read(
          weeklyStatisticsForDateProvider(widget.config.targetDate),
        );
        if (asyncValue.hasValue) {
          setState(() {
            _stats = asyncValue.value;
            _isLoading = false;
          });
        } else if (asyncValue.isLoading) {
          final result = await ref.read(
            weeklyStatisticsForDateProvider(widget.config.targetDate).future,
          );
          if (mounted) {
            setState(() {
              _stats = result;
              _isLoading = false;
            });
          }
        } else if (asyncValue.hasError) {
          setState(() {
            _errorMessage = '加载数据失败: ${asyncValue.error}';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '加载数据异常: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    // 计算预览区域最大尺寸（屏幕的 80%）
    final maxPreviewWidth = screenSize.width * 0.8;
    final maxPreviewHeight = screenSize.height * 0.75;

    // 获取海报的预览尺寸
    final previewSize = widget.config.getPreviewSize(
      maxWidth: maxPreviewWidth,
      maxHeight: maxPreviewHeight,
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: previewSize.width + 48, // 增加边距
        constraints: BoxConstraints(
          maxHeight: screenSize.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: AmberColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部标题栏
            _buildHeader(),
            // 预览区域
            Flexible(
              child: _buildPreviewArea(previewSize),
            ),
            // 底部尺寸信息
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  /// 构建顶部标题栏
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AmberColors.divider),
        ),
      ),
      child: Row(
        children: [
          const Text(
            '海报预览',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AmberColors.textPrimary,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
            color: AmberColors.textSecondary,
            tooltip: '关闭',
          ),
        ],
      ),
    );
  }

  /// 构建预览区域
  Widget _buildPreviewArea(Size previewSize) {
    if (_isLoading) {
      return SizedBox(
        height: previewSize.height,
        child: const Center(
          child: CircularProgressIndicator(color: AmberColors.primary),
        ),
      );
    }

    if (_errorMessage != null) {
      return SizedBox(
        height: previewSize.height,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: AmberColors.warning,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: AmberColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // 构建海报预览
    Widget posterWidget;
    if (widget.config.viewType == PosterViewType.monthly) {
      posterWidget = MonthlyPosterWidget(
        config: widget.config,
        stats: _stats as MonthlyStatistics,
      );
    } else {
      // 计算周的起止日期
      final targetDate = widget.config.targetDate;
      final weekday = targetDate.weekday;
      final weekStart = targetDate.subtract(Duration(days: weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));

      posterWidget = WeeklyPosterWidget(
        config: widget.config,
        stats: _stats as WeeklyStatistics,
        weekStart: weekStart,
        weekEnd: weekEnd,
      );
    }

    // 计算缩放比例
    final posterSize = widget.config.getPosterSize();
    final scale = previewSize.width / posterSize.width;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: previewSize.width,
              height: previewSize.height,
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: posterSize.width,
                  height: posterSize.height,
                  child: posterWidget,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建底部信息栏
  Widget _buildFooter() {
    final posterSize = widget.config.getPosterSize();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AmberColors.divider),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.photo_size_select_actual_outlined,
            size: 16,
            color: AmberColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Text(
            '导出尺寸: ${posterSize.width.toInt()} × ${posterSize.height.toInt()} px',
            style: const TextStyle(
              fontSize: 13,
              color: AmberColors.textSecondary,
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 1,
            height: 16,
            color: AmberColors.divider,
          ),
          const SizedBox(width: 16),
          Text(
            widget.config.getSizeDisplayName(),
            style: const TextStyle(
              fontSize: 13,
              color: AmberColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
