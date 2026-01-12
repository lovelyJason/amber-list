import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../../providers/task_management_settings_provider.dart';
import '../widgets/settings_section.dart';

/// 任务管理设置标签页
///
/// 控制任务行为相关的设置，与显示设置分离
/// - 自动顺延：过期任务自动改为今天
/// - 后续可扩展：默认优先级、默认提醒时间、重复任务设置等
class TaskManagementTab extends ConsumerWidget {
  const TaskManagementTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(taskManagementSettingsProvider);

    return ListView(
      padding: const EdgeInsets.all(AmberDimens.spacingLg),
      children: [
        // 过期任务处理
        SettingsSection(
          title: '过期任务处理',
          children: [
            // 自动顺延过期任务
            _buildSwitchTile(
              icon: Icons.update_rounded,
              title: '自动顺延过期任务',
              subtitle: '自动将过期任务的截止日期改为今天',
              value: settings.enableAutoPostpone,
              onChanged: (value) {
                ref
                    .read(taskManagementSettingsProvider.notifier)
                    .setEnableAutoPostpone(value);
              },
            ),
          ],
        ),
        const SizedBox(height: AmberDimens.spacingMd),
        // 提示说明
        _buildInfoCard(
          context,
          title: '关于自动顺延',
          content: '• 开启后，App 启动时会自动将过期任务移动到今天\n'
              '• 关闭后，过期任务会显示在"今天"视图的"已过期"区域\n'
              '• 你可以在"已过期"区域手动点击"顺延"按钮处理',
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

  /// 构建信息提示卡片
  Widget _buildInfoCard(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(AmberDimens.spacingMd),
      decoration: BoxDecoration(
        color: AmberColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AmberColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: AmberColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AmberColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              color: AmberColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
