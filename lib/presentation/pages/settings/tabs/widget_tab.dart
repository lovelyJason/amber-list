import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/models/widget_skins.dart';
import '../../../providers/widget_settings_provider.dart';
import '../widgets/settings_section.dart';

/// 小组件设置标签页
///
/// 配置 Android/iOS 桌面小组件的皮肤和样式
/// 皮肤设置对 Small/Medium/Large 三种尺寸的组件都生效
class WidgetTab extends ConsumerWidget {
  const WidgetTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(widgetSettingsProvider);

    // 仅移动端显示
    if (!Platform.isAndroid && !Platform.isIOS) {
      return _buildUnsupportedPlatform();
    }

    return ListView(
      padding: const EdgeInsets.all(AmberDimens.spacingLg),
      children: [
        // 小组件皮肤设置
        SettingsSection(
          title: '小组件皮肤',
          children: [
            _buildSkinSelector(context, ref, settings),
          ],
        ),
        const SizedBox(height: AmberDimens.spacingMd),
        // 交互设置
        SettingsSection(
          title: '交互设置',
          children: [
            _buildTapTextToCompleteSwitch(context, ref, settings),
          ],
        ),
        const SizedBox(height: AmberDimens.spacingMd),
        // 说明文字
        _buildHelpText(),
      ],
    );
  }

  /// 构建"点击文字完成任务"开关
  Widget _buildTapTextToCompleteSwitch(
    BuildContext context,
    WidgetRef ref,
    WidgetSettings settings,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AmberDimens.spacingMd,
        vertical: AmberDimens.spacingSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '点击文字完成任务',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  settings.tapTextToComplete
                      ? '点击任务文字或复选框都能切换完成状态'
                      : '仅点击复选框可切换，点击文字打开 App',
                  style: TextStyle(
                    fontSize: 12,
                    color: AmberColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: settings.tapTextToComplete,
            activeTrackColor: AmberColors.primary,
            onChanged: (value) {
              ref.read(widgetSettingsProvider.notifier).setTapTextToComplete(value);
            },
          ),
        ],
      ),
    );
  }

  /// 构建皮肤选择器
  Widget _buildSkinSelector(
    BuildContext context,
    WidgetRef ref,
    WidgetSettings settings,
  ) {
    final allSkins = WidgetSkins.allConfigs;
    final currentSkin = settings.smallWidgetSkin;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AmberDimens.spacingMd,
        vertical: AmberDimens.spacingSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 当前选中皮肤预览
          _buildCurrentSkinPreview(currentSkin),
          const SizedBox(height: AmberDimens.spacingMd),
          // 皮肤选项网格
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.0,
            ),
            itemCount: allSkins.length,
            itemBuilder: (context, index) {
              final skin = allSkins[index];
              final isSelected = skin.type == currentSkin;
              return _buildSkinOption(context, ref, skin, isSelected);
            },
          ),
        ],
      ),
    );
  }

  /// 构建当前皮肤预览卡片
  Widget _buildCurrentSkinPreview(WidgetSkinType currentSkin) {
    final config = WidgetSkins.getConfig(currentSkin);

    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        gradient: config.previewGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: config.centerColor.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 模拟任务列表
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题行
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: config.checkboxColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '示例任务 1',
                        style: TextStyle(
                          fontSize: 13,
                          color: config.textColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: config.checkboxColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '示例任务 2',
                        style: TextStyle(
                          fontSize: 13,
                          color: config.textColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // 底部时间
                Text(
                  '14:30',
                  style: TextStyle(
                    fontSize: 11,
                    color: config.secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
          // 当前皮肤标签
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                config.displayName,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建单个皮肤选项
  Widget _buildSkinOption(
    BuildContext context,
    WidgetRef ref,
    WidgetSkinConfig config,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () {
        // 统一设置所有尺寸 Widget 的皮肤
        ref.read(widgetSettingsProvider.notifier).setAllWidgetSkin(config.type);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: config.previewGradient,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AmberColors.primary : Colors.transparent,
            width: isSelected ? 3 : 0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AmberColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            // 皮肤名称
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Text(
                config.displayName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: config.textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // 选中标记
            if (isSelected)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: AmberColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 构建帮助说明文字
  Widget _buildHelpText() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AmberDimens.spacingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: AmberColors.textSecondary,
              ),
              const SizedBox(width: 8),
              const Text(
                '使用说明',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AmberColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '• 选择皮肤后，桌面小组件会自动更新\n'
            '• 如果小组件未更新，请尝试移除后重新添加\n'
            '• 皮肤设置对所有尺寸的小组件生效',
            style: TextStyle(
              fontSize: 12,
              color: AmberColors.textSecondary,
              height: 1.6,
            ),
          ),
          // iOS 平台特有提示
          if (Platform.isIOS) ...[
            const SizedBox(height: 16),
            _buildIOSHint(),
          ],
        ],
      ),
    );
  }

  /// 构建 iOS 平台特有提示
  ///
  /// iOS 小组件支持两种换肤方式：
  /// 1. App 设置 - 在此页面选择皮肤
  /// 2. 长按配置 - 长按桌面小组件选择皮肤（会覆盖 App 设置）
  Widget _buildIOSHint() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AmberColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AmberColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: 18,
            color: AmberColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'iOS 小组件换肤提示',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AmberColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '长按桌面小组件 → 编辑小组件 → 也可选择皮肤\n'
                  '长按配置的皮肤会覆盖此处的设置',
                  style: TextStyle(
                    fontSize: 11,
                    color: AmberColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建不支持平台的提示
  Widget _buildUnsupportedPlatform() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.phone_android_outlined,
            size: 64,
            color: AmberColors.textSecondary,
          ),
          const SizedBox(height: AmberDimens.spacingMd),
          const Text(
            '桌面小组件仅支持 Android 和 iOS',
            style: TextStyle(
              fontSize: 15,
              color: AmberColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
