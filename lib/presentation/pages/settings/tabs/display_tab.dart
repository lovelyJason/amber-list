import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../../providers/display_settings_provider.dart';
import '../../../widgets/common/toast/toast_manager.dart';
import '../widgets/settings_section.dart';

/// 显示设置标签页
/// 控制任务列表项的显示选项，如标签、截止日期、优先级等
class DisplayTab extends ConsumerWidget {
  const DisplayTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(displaySettingsProvider);

    return ListView(
      padding: const EdgeInsets.all(AmberDimens.spacingLg),
      children: [
        // Windows 标题栏样式设置（仅 Windows 显示）
        if (Platform.isWindows)
          SettingsSection(
            title: '窗口样式',
            children: [
              _buildSwitchTile(
                icon: Icons.window_outlined,
                title: '使用 Windows 原生标题栏',
                subtitle: '关闭则使用 macOS 风格红绿灯按钮，需重启应用生效',
                value: settings.useNativeTitleBar,
                onChanged: (value) {
                  ref.read(displaySettingsProvider.notifier).setUseNativeTitleBar(value);
                  // 提示用户需要重启
                  ToastManager().show(
                    context,
                    '标题栏样式已更改，重启应用后生效',
                    type: ToastType.info,
                  );
                },
              ),
            ],
          ),
        if (Platform.isWindows) const SizedBox(height: AmberDimens.spacingMd),
        // 任务列表显示选项
        SettingsSection(
          title: '任务列表',
          children: [
            // 显示标签
            _buildSwitchTile(
              icon: Icons.label_outline,
              title: '显示标签',
              subtitle: '在任务项下方显示标签',
              value: settings.showTags,
              onChanged: (value) {
                ref.read(displaySettingsProvider.notifier).setShowTags(value);
              },
            ),
            const Divider(height: 1, indent: 56),
            // 显示截止日期
            _buildSwitchTile(
              icon: Icons.calendar_today_outlined,
              title: '显示截止日期',
              subtitle: '在任务项下方显示截止日期',
              value: settings.showDueDate,
              onChanged: (value) {
                ref.read(displaySettingsProvider.notifier).setShowDueDate(value);
              },
            ),
            const Divider(height: 1, indent: 56),
            // 过期任务标题颜色
            _buildColorTile(
              context: context,
              ref: ref,
              icon: Icons.title,
              title: '过期任务标题颜色',
              subtitle: '已过期任务的标题文字颜色',
              currentColor: Color(settings.overdueTitleColorValue),
              onColorSelected: (color) {
                ref.read(displaySettingsProvider.notifier).setOverdueTitleColor(color.toARGB32());
              },
            ),
            const Divider(height: 1, indent: 56),
            // 过期标签颜色
            _buildColorTile(
              context: context,
              ref: ref,
              icon: Icons.schedule,
              title: '过期标签颜色',
              subtitle: '"已过期"文字和日历图标的颜色',
              currentColor: Color(settings.overdueLabelColorValue),
              onColorSelected: (color) {
                ref.read(displaySettingsProvider.notifier).setOverdueLabelColor(color.toARGB32());
              },
            ),
          ],
        ),
      ],
    );
  }

  /// 构建带开关的设置项
  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: AmberColors.primary,
        size: 24,
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AmberColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
          color: AmberColors.textSecondary,
        ),
      ),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeTrackColor: AmberColors.primary,
      ),
      onTap: () => onChanged(!value),
    );
  }

  /// 构建颜色选择设置项
  Widget _buildColorTile({
    required BuildContext context,
    required WidgetRef ref,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color currentColor,
    required ValueChanged<Color> onColorSelected,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: AmberColors.primary,
        size: 24,
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AmberColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
          color: AmberColors.textSecondary,
        ),
      ),
      trailing: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: currentColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.grey.shade300,
            width: 1,
          ),
        ),
      ),
      onTap: () => _showColorPickerDialog(context, currentColor, onColorSelected),
    );
  }

  /// 显示颜色选择对话框
  void _showColorPickerDialog(
    BuildContext context,
    Color currentColor,
    ValueChanged<Color> onColorSelected,
  ) {
    // 预设的过期任务颜色选项
    final presetColors = <Color>[
      const Color(0xFFFF5722), // 深橙红（默认）
      const Color(0xFFF44336), // 红色
      const Color(0xFFE91E63), // 粉红
      const Color(0xFF9C27B0), // 紫色
      const Color(0xFF673AB7), // 深紫
      const Color(0xFF3F51B5), // 靛蓝
      const Color(0xFF2196F3), // 蓝色
      const Color(0xFF00BCD4), // 青色
      const Color(0xFF009688), // 蓝绿
      const Color(0xFF4CAF50), // 绿色
      const Color(0xFF8BC34A), // 浅绿
      const Color(0xFFFF9800), // 橙色
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择过期任务颜色'),
        content: SizedBox(
          width: 280,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: presetColors.map((color) {
              final isSelected = color.toARGB32() == currentColor.toARGB32();
              return GestureDetector(
                onTap: () {
                  onColorSelected(color);
                  Navigator.of(context).pop();
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.black : Colors.grey.shade300,
                      width: isSelected ? 3 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 20,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }
}
