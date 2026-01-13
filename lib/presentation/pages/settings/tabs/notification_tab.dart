import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../../../core/notifications/notification_settings_provider.dart';
import '../widgets/settings_section.dart';

/// 通知设置标签页
///
/// 功能:
/// - 待办积压通知开关
/// - 通知时间设置
/// - 通知规则说明
class NotificationTab extends ConsumerWidget {
  const NotificationTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);

    return ListView(
      padding: const EdgeInsets.all(AmberDimens.spacingLg),
      children: [
        // 待办积压提醒
        SettingsSection(
          title: '待办积压提醒',
          children: [
            // 开关
            _buildSwitchTile(
              icon: Icons.notifications_active_outlined,
              title: '下班前通知',
              subtitle: '每天提醒你清理积压的待办事项',
              value: settings.backlogNotificationEnabled,
              onChanged: (value) {
                ref
                    .read(notificationSettingsProvider.notifier)
                    .setBacklogNotificationEnabled(value);
              },
            ),
            // 时间选择（仅在开启时显示）
            if (settings.backlogNotificationEnabled)
              _buildTimeTile(
                context,
                ref,
                hour: settings.notifyHour,
              ),
          ],
        ),

        const SizedBox(height: AmberDimens.spacingMd),

        // 通知规则说明
        _buildInfoCard(
          context,
          title: '通知规则',
          content: '• 通知时间: 每天 ${_formatHour(settings.notifyHour)}\n'
              '• 触发条件: 有未完成且已过期的任务\n'
              '• 不打扰时段: 周末和中国法定节假日不发送\n'
              '• 通知内容: 积压数量 + 最高优先级任务标题\n'
              '• 运行要求: 仅应用运行时生效',
        ),
      ],
    );
  }

  /// 格式化小时为 "HH:00" 格式
  String _formatHour(int hour) {
    return '${hour.toString().padLeft(2, '0')}:00';
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

  /// 构建时间选择项
  Widget _buildTimeTile(
    BuildContext context,
    WidgetRef ref, {
    required int hour,
  }) {
    return ListTile(
      leading: const Icon(
        Icons.schedule_outlined,
        color: AmberColors.primary,
        size: 24,
      ),
      title: const Text(
        '通知时间',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AmberColors.textPrimary,
        ),
      ),
      subtitle: const Text(
        '选择每天提醒的时间',
        style: TextStyle(
          fontSize: 12,
          color: AmberColors.textSecondary,
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AmberColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          _formatHour(hour),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AmberColors.primary,
          ),
        ),
      ),
      onTap: () => _showHourPicker(context, ref, hour),
    );
  }

  /// 显示小时选择器
  void _showHourPicker(BuildContext context, WidgetRef ref, int currentHour) {
    // 生成可选时间列表（8:00 - 22:00）
    final hours = List.generate(15, (i) => i + 8);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择通知时间'),
        content: SizedBox(
          width: 280,
          height: 300,
          child: ListView.builder(
            itemCount: hours.length,
            itemBuilder: (context, index) {
              final hour = hours[index];
              final isSelected = hour == currentHour;

              return ListTile(
                leading: Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: isSelected ? AmberColors.primary : AmberColors.divider,
                ),
                title: Text(
                  _formatHour(hour),
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected
                        ? AmberColors.primary
                        : AmberColors.textPrimary,
                  ),
                ),
                onTap: () {
                  ref
                      .read(notificationSettingsProvider.notifier)
                      .setNotifyHour(hour);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
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
        color: AmberColors.cardBackground,
        borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
        border: Border.all(color: AmberColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 18,
                color: AmberColors.primary,
              ),
              const SizedBox(width: AmberDimens.spacingSm),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AmberColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AmberDimens.spacingSm),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              color: AmberColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
