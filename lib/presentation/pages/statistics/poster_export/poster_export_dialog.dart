import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/models/poster_config.dart';
import '../../../../core/models/widget_skins.dart';
import '../../../widgets/common/toast/toast_manager.dart';
import 'poster_generator.dart';
import 'poster_preview_dialog.dart';

/// 海报导出配置弹窗
///
/// 用户交互流程：
/// 1. 选择视图类型（月视图/周视图）
/// 2. 选择风格（品牌渐变/创意撞色）
/// 3. 选择具体皮肤配色
/// 4. 选择尺寸（9:16/1:1/16:9）
/// 5. 可选预览，确认后导出
class PosterExportDialog extends ConsumerStatefulWidget {
  /// 初始视图类型（从统计页面传入）
  final PosterViewType initialViewType;

  /// 当前选中的日期
  final DateTime selectedDate;

  const PosterExportDialog({
    super.key,
    required this.initialViewType,
    required this.selectedDate,
  });

  @override
  ConsumerState<PosterExportDialog> createState() => _PosterExportDialogState();
}

class _PosterExportDialogState extends ConsumerState<PosterExportDialog> {
  late PosterViewType _viewType;
  PosterStyleType _styleType = PosterStyleType.brand;
  PosterSizeType _sizeType = PosterSizeType.vertical9x16;
  WidgetSkinType _selectedSkin = WidgetSkinType.amber;

  /// 是否正在导出
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _viewType = widget.initialViewType;
  }

  /// 获取可选皮肤列表（根据风格筛选）
  List<WidgetSkinType> get _availableSkins {
    return PosterConfig.getSkinsForStyle(_styleType);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('导出统计海报'),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. 视图类型选择
              _buildSectionTitle('视图类型'),
              const SizedBox(height: 8),
              _buildViewTypeSelector(),
              const SizedBox(height: 24),

              // 2. 风格选择
              _buildSectionTitle('海报风格'),
              const SizedBox(height: 8),
              _buildStyleSelector(),
              const SizedBox(height: 24),

              // 3. 皮肤选择
              _buildSectionTitle('配色方案'),
              const SizedBox(height: 8),
              _buildSkinSelector(),
              const SizedBox(height: 24),

              // 4. 尺寸选择
              _buildSectionTitle('尺寸比例'),
              const SizedBox(height: 8),
              _buildSizeSelector(),
              const SizedBox(height: 16),

              // 5. 预览按钮
              _buildPreviewButton(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      actions: [
        TextButton(
          onPressed: _isExporting ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _isExporting ? null : _handleExport,
          style: FilledButton.styleFrom(
            backgroundColor: AmberColors.primary,
          ),
          child: _isExporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('导出'),
        ),
      ],
    );
  }

  /// 构建区块标题
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AmberColors.textPrimary,
      ),
    );
  }

  /// 构建视图类型选择器
  Widget _buildViewTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildRadioOption<PosterViewType>(
            value: PosterViewType.monthly,
            groupValue: _viewType,
            label: '月视图',
            icon: FluentIcons.calendar_month_24_regular,
            onChanged: (v) => setState(() => _viewType = v),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildRadioOption<PosterViewType>(
            value: PosterViewType.weekly,
            groupValue: _viewType,
            label: '周视图',
            icon: FluentIcons.calendar_week_numbers_24_regular,
            onChanged: (v) => setState(() => _viewType = v),
          ),
        ),
      ],
    );
  }

  /// 构建风格选择器
  Widget _buildStyleSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildRadioOption<PosterStyleType>(
            value: PosterStyleType.brand,
            groupValue: _styleType,
            label: '品牌渐变',
            icon: FluentIcons.color_24_regular,
            onChanged: (v) {
              setState(() {
                _styleType = v;
                // 切换风格时重置皮肤为第一个可用皮肤
                _selectedSkin = _availableSkins.first;
              });
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildRadioOption<PosterStyleType>(
            value: PosterStyleType.creative,
            groupValue: _styleType,
            label: '创意撞色',
            icon: FluentIcons.design_ideas_24_regular,
            onChanged: (v) {
              setState(() {
                _styleType = v;
                _selectedSkin = _availableSkins.first;
              });
            },
          ),
        ),
      ],
    );
  }

  /// 构建皮肤选择器
  Widget _buildSkinSelector() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _availableSkins.map((skin) {
        final config = WidgetSkins.getConfig(skin);
        final isSelected = _selectedSkin == skin;

        return GestureDetector(
          onTap: () => setState(() => _selectedSkin = skin),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: config.previewGradient,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AmberColors.primary : AmberColors.divider,
                width: isSelected ? 3 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AmberColors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      )
                    ]
                  : null,
            ),
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(10),
                  bottomRight: Radius.circular(10),
                ),
              ),
              child: Text(
                config.displayName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 构建尺寸选择器
  Widget _buildSizeSelector() {
    return Row(
      children: [
        _buildSizeOption(
          sizeType: PosterSizeType.vertical9x16,
          label: '竖版\n9:16',
          icon: Icons.smartphone_outlined,
        ),
        const SizedBox(width: 12),
        _buildSizeOption(
          sizeType: PosterSizeType.square1x1,
          label: '方形\n1:1',
          icon: Icons.crop_square_outlined,
        ),
        const SizedBox(width: 12),
        _buildSizeOption(
          sizeType: PosterSizeType.horizontal16x9,
          label: '横版\n16:9',
          icon: Icons.tablet_mac_outlined,
        ),
      ],
    );
  }

  /// 构建尺寸选项
  Widget _buildSizeOption({
    required PosterSizeType sizeType,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _sizeType == sizeType;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _sizeType = sizeType),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AmberColors.primaryLight
                : AmberColors.cardBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AmberColors.primary : AmberColors.divider,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color:
                    isSelected ? AmberColors.primary : AmberColors.textSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected
                      ? AmberColors.primary
                      : AmberColors.textSecondary,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建单选选项
  Widget _buildRadioOption<T>({
    required T value,
    required T groupValue,
    required String label,
    required IconData icon,
    required void Function(T) onChanged,
  }) {
    final isSelected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? AmberColors.primaryLight
              : AmberColors.cardBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AmberColors.primary : AmberColors.divider,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color:
                  isSelected ? AmberColors.primary : AmberColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? AmberColors.primary : AmberColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建预览按钮
  Widget _buildPreviewButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isExporting ? null : _handlePreview,
        icon: const Icon(FluentIcons.eye_24_regular, size: 18),
        label: const Text('预览效果'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AmberColors.primary,
          side: const BorderSide(color: AmberColors.primary),
        ),
      ),
    );
  }

  /// 构建当前配置
  PosterConfig _buildConfig() {
    return PosterConfig(
      viewType: _viewType,
      styleType: _styleType,
      sizeType: _sizeType,
      targetDate: widget.selectedDate,
      skinType: _selectedSkin,
    );
  }

  /// 处理预览
  void _handlePreview() {
    final config = _buildConfig();
    showDialog(
      context: context,
      builder: (context) => PosterPreviewDialog(config: config),
    );
  }

  /// 处理导出
  Future<void> _handleExport() async {
    setState(() => _isExporting = true);

    try {
      final config = _buildConfig();

      // 生成并导出海报
      final filePath = await PosterGenerator.generateAndExportPoster(
        config: config,
        ref: ref,
      );

      if (!mounted) return;

      if (filePath != null) {
        // 成功
        Navigator.pop(context);
        ToastManager().show(
          context,
          '海报已保存: $filePath',
          type: ToastType.success,
        );
      } else {
        // 用户取消或失败
        ToastManager().show(
          context,
          '导出已取消',
          type: ToastType.info,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ToastManager().show(
        context,
        '导出失败: $e',
        type: ToastType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }
}
