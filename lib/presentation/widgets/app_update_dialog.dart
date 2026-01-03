import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/constants.dart';
import '../../data/models/app_update_info.dart';
import '../providers/app_update_provider.dart';

/// ============================================================
/// 应用更新对话框
/// ============================================================
/// 显示更新信息，支持可选更新和强制更新两种模式
/// 强制更新时用户必须更新才能继续使用应用

class AppUpdateDialog extends ConsumerWidget {
  /// 更新检查结果
  final UpdateCheckResult result;

  /// 是否为强制更新（控制是否可以关闭对话框）
  final bool isForceUpdate;

  const AppUpdateDialog({
    super.key,
    required this.result,
    required this.isForceUpdate,
  });

  /// 显示更新对话框
  ///
  /// [context] BuildContext
  /// [result] 更新检查结果
  /// [isForceUpdate] 是否为强制更新
  static Future<void> show(
    BuildContext context, {
    required UpdateCheckResult result,
    required bool isForceUpdate,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: !isForceUpdate, // 强制更新时不可点击外部关闭
      builder: (context) => AppUpdateDialog(
        result: result,
        isForceUpdate: isForceUpdate,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateInfo = result.updateInfo!;

    return PopScope(
      // 强制更新时禁止返回键关闭
      canPop: !isForceUpdate,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AmberDimens.radiusLg),
        ),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(AmberDimens.spacingXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isForceUpdate
                          ? Colors.red.withValues(alpha: 0.1)
                          : AmberColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isForceUpdate
                          ? Icons.warning_amber_rounded
                          : Icons.system_update_outlined,
                      color: isForceUpdate ? Colors.red : AmberColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: AmberDimens.spacingMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isForceUpdate ? '需要更新' : '发现新版本',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'v${updateInfo.latestVersion}',
                          style: TextStyle(
                            fontSize: 14,
                            color: AmberColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AmberDimens.spacingLg),

              // 强制更新提示
              if (isForceUpdate) ...[
                Container(
                  padding: const EdgeInsets.all(AmberDimens.spacingMd),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.red.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: AmberDimens.spacingSm),
                      Expanded(
                        child: Text(
                          '当前版本过低，需要更新才能继续使用',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AmberDimens.spacingMd),
              ],

              // 版本信息
              Container(
                padding: const EdgeInsets.all(AmberDimens.spacingMd),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '当前版本',
                            style: TextStyle(
                              fontSize: 12,
                              color: AmberColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'v${result.currentVersion}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward,
                      color: AmberColors.textDisabled,
                      size: 20,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            '最新版本',
                            style: TextStyle(
                              fontSize: 12,
                              color: AmberColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'v${updateInfo.latestVersion}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AmberColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 更新日志
              if (updateInfo.releaseNotes.isNotEmpty) ...[
                const SizedBox(height: AmberDimens.spacingMd),
                const Text(
                  '更新内容',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AmberDimens.spacingSm),
                Container(
                  constraints: const BoxConstraints(maxHeight: 150),
                  padding: const EdgeInsets.all(AmberDimens.spacingMd),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      updateInfo.releaseNotes,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: AmberColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: AmberDimens.spacingLg),

              // 操作按钮
              Row(
                children: [
                  // 稍后再说（仅可选更新显示）
                  if (!isForceUpdate) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          ref.read(appUpdateProvider.notifier).skipCurrentVersion();
                          Navigator.of(context).pop();
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: AmberDimens.spacingMd,
                          ),
                          side: const BorderSide(color: AmberColors.divider),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AmberDimens.radiusMd),
                          ),
                        ),
                        child: const Text(
                          '稍后再说',
                          style: TextStyle(color: AmberColors.textSecondary),
                        ),
                      ),
                    ),
                    const SizedBox(width: AmberDimens.spacingMd),
                  ],

                  // 立即更新
                  Expanded(
                    flex: isForceUpdate ? 1 : 1,
                    child: ElevatedButton(
                      onPressed: () async {
                        final success = await ref
                            .read(appUpdateProvider.notifier)
                            .openDownloadUrl();
                        if (!success && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('无法打开下载链接，请稍后重试'),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isForceUpdate ? Colors.red : AmberColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: AmberDimens.spacingMd,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AmberDimens.radiusMd),
                        ),
                      ),
                      child: const Text(
                        '立即更新',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 强制更新拦截页面
/// 当用户版本过低时，全屏显示此页面，阻止使用应用
class ForceUpdateScreen extends ConsumerWidget {
  final UpdateCheckResult result;

  const ForceUpdateScreen({
    super.key,
    required this.result,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateInfo = result.updateInfo!;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(AmberDimens.spacingXl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 图标
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.system_update_alt_rounded,
                  color: Colors.red,
                  size: 64,
                ),
              ),

              const SizedBox(height: AmberDimens.spacingXl),

              // 标题
              const Text(
                '需要更新应用',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: AmberDimens.spacingMd),

              // 说明
              Text(
                '您当前使用的版本 (v${result.currentVersion}) 已不再支持\n请更新到最新版本 v${updateInfo.latestVersion} 以继续使用',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: AmberColors.textSecondary,
                ),
              ),

              const SizedBox(height: AmberDimens.spacingXl),

              // 更新按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final success = await ref
                        .read(appUpdateProvider.notifier)
                        .openDownloadUrl();
                    if (!success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('无法打开下载链接，请稍后重试'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('立即更新'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AmberColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: AmberDimens.spacingMd,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AmberDimens.spacingMd),

              // 重试检查
              TextButton(
                onPressed: () {
                  ref.read(appUpdateProvider.notifier).checkForUpdates();
                },
                child: const Text(
                  '重新检查',
                  style: TextStyle(color: AmberColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
