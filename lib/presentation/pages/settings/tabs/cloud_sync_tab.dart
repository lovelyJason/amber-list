import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/constants.dart';
import '../../../../data/services/sync/sync_config.dart';
import '../../../providers/sync_provider.dart';
import '../../../widgets/webdav_config_section.dart';
import '../../../widgets/qiniu_oss_config_section.dart';
import '../../../widgets/common/toast/toast_manager.dart';

/// ============================================================
/// 云同步标签页
/// ============================================================
/// 支持多种同步方式的配置入口：
/// - WebDAV（坚果云等）
/// - 七牛云 OSS
/// - 阿里云 OSS（预留）
/// - 腾讯云 COS（预留）
/// - 琥珀云托管服务（预留）
///
/// 设计理念：
/// 1. 用户可以同时配置多个平台的账密信息（都保存着）
/// 2. 通过单选按钮选择当前激活哪个同步方式
/// 3. 选择后自动切换，无需删除其他配置
/// ============================================================

class CloudSyncTab extends ConsumerWidget {
  const CloudSyncTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncType = ref.watch(syncTypeProvider);
    final webdavConfig = ref.watch(syncConfigProvider);
    final qiniuConfig = ref.watch(qiniuConfigProvider);

    // 判断各平台是否已配置（有账密信息）
    final webdavConfigured = webdavConfig != null && webdavConfig.isConfigured;
    final qiniuConfigured = qiniuConfig != null && qiniuConfig.isConfigured;

    return ListView(
      padding: const EdgeInsets.all(AmberDimens.spacingLg),
      children: [
        // 同步方式选择器
        _buildSyncSelector(context, ref, syncType, webdavConfigured, qiniuConfigured),
        const SizedBox(height: AmberDimens.spacingMd),

        // WebDAV 配置区域
        _buildSyncSection(
          context: context,
          ref: ref,
          type: SyncType.webdav,
          currentType: syncType,
          isConfigured: webdavConfigured,
          child: const WebDavConfigSection(),
        ),

        const SizedBox(height: AmberDimens.spacingMd),

        // 七牛云 OSS 配置区域
        _buildSyncSection(
          context: context,
          ref: ref,
          type: SyncType.qiniuOss,
          currentType: syncType,
          isConfigured: qiniuConfigured,
          child: const QiniuOssConfigSection(),
        ),

        const SizedBox(height: AmberDimens.spacingMd),

        // 预留：琥珀云托管服务入口
        _buildAmberCloudPlaceholder(context),
      ],
    );
  }

  /// 构建同步方式选择器
  Widget _buildSyncSelector(
    BuildContext context,
    WidgetRef ref,
    SyncType? currentType,
    bool webdavConfigured,
    bool qiniuConfigured,
  ) {
    return Container(
      padding: const EdgeInsets.all(AmberDimens.spacingMd),
      decoration: BoxDecoration(
        color: AmberColors.sidebarBackground,
        borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
        border: Border.all(color: AmberColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.sync_alt,
                color: AmberColors.primary,
                size: 20,
              ),
              const SizedBox(width: AmberDimens.spacingSm),
              const Text(
                '当前同步方式',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: AmberDimens.spacingSm),

          // 同步选项
          _buildSyncOption(
            context: context,
            ref: ref,
            type: SyncType.webdav,
            currentType: currentType,
            isConfigured: webdavConfigured,
            title: 'WebDAV',
            subtitle: webdavConfigured ? '已配置' : '未配置',
          ),
          _buildSyncOption(
            context: context,
            ref: ref,
            type: SyncType.qiniuOss,
            currentType: currentType,
            isConfigured: qiniuConfigured,
            title: '七牛云 OSS',
            subtitle: qiniuConfigured ? '已配置' : '未配置',
          ),
          _buildSyncOption(
            context: context,
            ref: ref,
            type: null, // 表示"不同步"
            currentType: currentType,
            isConfigured: true, // 总是可选
            title: '不同步',
            subtitle: '仅本地存储',
          ),
        ],
      ),
    );
  }

  /// 构建单个同步选项
  Widget _buildSyncOption({
    required BuildContext context,
    required WidgetRef ref,
    required SyncType? type,
    required SyncType? currentType,
    required bool isConfigured,
    required String title,
    required String subtitle,
  }) {
    final isSelected = type == currentType;
    final canSelect = isConfigured || type == null; // "不同步"总是可选

    return InkWell(
      onTap: canSelect ? () => _onSyncTypeChanged(ref, type, context) : null,
      borderRadius: BorderRadius.circular(AmberDimens.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AmberDimens.spacingXs,
          horizontal: AmberDimens.spacingSm,
        ),
        child: Row(
          children: [
            // Radio 按钮
            Radio<SyncType?>(
              value: type,
              groupValue: currentType,
              onChanged: canSelect
                  ? (value) => _onSyncTypeChanged(ref, value, context)
                  : null,
              activeColor: AmberColors.primary,
            ),
            const SizedBox(width: AmberDimens.spacingSm),
            // 标题和副标题
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: canSelect ? null : Colors.grey,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: canSelect
                          ? (isConfigured && type != null
                              ? AmberColors.success
                              : Colors.grey)
                          : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
            // 状态图标
            if (isSelected && type != null)
              Icon(
                Icons.check_circle,
                color: AmberColors.success,
                size: 20,
              ),
            if (!canSelect)
              Tooltip(
                message: '请先配置此同步方式',
                child: Icon(
                  Icons.info_outline,
                  color: Colors.grey.shade400,
                  size: 18,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 切换同步类型
  void _onSyncTypeChanged(WidgetRef ref, SyncType? type, BuildContext context) {
    ref.read(syncStateProvider.notifier).switchSyncType(type);

    // 显示切换提示（使用 ToastManager 替代丑陋的 SnackBar）
    final message = type == null
        ? '已关闭云同步'
        : '已切换到 ${type.displayName}';

    ToastManager().show(
      context,
      message,
      type: ToastType.success,
    );
  }

  /// 构建同步配置区块（带激活状态指示）
  Widget _buildSyncSection({
    required BuildContext context,
    required WidgetRef ref,
    required SyncType type,
    required SyncType? currentType,
    required bool isConfigured,
    required Widget child,
  }) {
    final isActive = type == currentType;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
        border: Border.all(
          color: isActive ? AmberColors.primary : AmberColors.divider,
          width: isActive ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          // 激活状态指示条
          if (isActive)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AmberDimens.spacingMd,
                vertical: AmberDimens.spacingXs,
              ),
              decoration: BoxDecoration(
                color: AmberColors.primary.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AmberDimens.radiusMd - 2),
                  topRight: Radius.circular(AmberDimens.radiusMd - 2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: AmberColors.primary,
                  ),
                  const SizedBox(width: AmberDimens.spacingXs),
                  Text(
                    '当前激活',
                    style: TextStyle(
                      fontSize: 12,
                      color: AmberColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          // 配置内容
          child,
        ],
      ),
    );
  }

  /// 构建琥珀云托管服务占位入口
  Widget _buildAmberCloudPlaceholder(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
        border: Border.all(color: AmberColors.divider),
      ),
      child: ListTile(
        leading: Icon(
          Icons.cloud_queue_outlined,
          color: Colors.grey.shade400,
        ),
        title: Text(
          '琥珀云托管服务',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        subtitle: Text(
          '即将推出 - 无需配置，开箱即用的云同步服务',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AmberDimens.spacingSm,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: AmberColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AmberDimens.radiusSm),
          ),
          child: const Text(
            '敬请期待',
            style: TextStyle(
              color: AmberColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
