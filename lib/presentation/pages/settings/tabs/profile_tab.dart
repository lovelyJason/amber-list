import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/constants.dart';
import '../../../providers/user_profile_provider.dart';
import '../../../widgets/activation_dialog.dart';
import '../../../widgets/animated_logo.dart';
import '../../../widgets/common/toast/toast_manager.dart';
import '../widgets/settings_section.dart';

/// 个人信息设置标签页
/// 用于修改用户头像等个人化设置
class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);

    return ListView(
      padding: const EdgeInsets.all(AmberDimens.spacingLg),
      children: [
        // 激活状态区块
        SettingsSection(
          title: '激活状态',
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AmberDimens.spacingMd,
                vertical: AmberDimens.spacingSm,
              ),
              child: ActivationStatusCard(),
            ),
          ],
        ),
        const SizedBox(height: AmberDimens.spacingLg),
        // 头像设置区域
        SettingsSection(
          title: '头像',
          children: [
            _buildAvatarSection(context, ref, profile),
          ],
        ),
        const SizedBox(height: AmberDimens.spacingMd),
        // 说明文字
        _buildInfoCard(context),
      ],
    );
  }

  /// 构建头像设置区域
  Widget _buildAvatarSection(
    BuildContext context,
    WidgetRef ref,
    UserProfile profile,
  ) {
    return Padding(
      padding: const EdgeInsets.all(AmberDimens.spacingMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头像预览
          _buildAvatarPreview(profile),
          const SizedBox(width: AmberDimens.spacingLg),
          // 操作按钮区
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '自定义头像',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AmberColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AmberDimens.spacingXs),
                Text(
                  profile.hasCustomAvatar
                      ? '已设置自定义头像，将显示在侧边栏顶部'
                      : '当前使用默认的琥珀清单 Logo',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AmberColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AmberDimens.spacingMd),
                // 操作按钮
                Wrap(
                  spacing: AmberDimens.spacingSm,
                  runSpacing: AmberDimens.spacingSm,
                  children: [
                    // 选择图片按钮
                    ElevatedButton.icon(
                      onPressed: () => _pickAndSetAvatar(context, ref),
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: Text(profile.hasCustomAvatar ? '更换头像' : '选择图片'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AmberColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AmberDimens.spacingMd,
                          vertical: AmberDimens.spacingSm,
                        ),
                      ),
                    ),
                    // 清除头像按钮（仅在有自定义头像时显示）
                    if (profile.hasCustomAvatar)
                      OutlinedButton.icon(
                        onPressed: () => _clearAvatar(context, ref),
                        icon: const Icon(Icons.restore_outlined, size: 18),
                        label: const Text('恢复默认'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AmberColors.textSecondary,
                          side: BorderSide(color: AmberColors.divider),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AmberDimens.spacingMd,
                            vertical: AmberDimens.spacingSm,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建头像预览
  Widget _buildAvatarPreview(UserProfile profile) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
        boxShadow: [
          BoxShadow(
            color: AmberColors.primaryTransparent,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
        child: profile.hasCustomAvatar
            ? Image.file(
                File(profile.avatarPath!),
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // 图片加载失败，显示默认 Logo
                  return const AnimatedLogo(
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  );
                },
              )
            : const AnimatedLogo(
                width: 80,
                height: 80,
                fit: BoxFit.cover,
              ),
      ),
    );
  }

  /// 构建说明卡片
  Widget _buildInfoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AmberDimens.spacingMd),
      decoration: BoxDecoration(
        color: AmberColors.primaryLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
        border: Border.all(
          color: AmberColors.divider,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 20,
            color: AmberColors.primary.withValues(alpha: 0.8),
          ),
          const SizedBox(width: AmberDimens.spacingSm),
          const Expanded(
            child: Text(
              '自定义头像将替换侧边栏顶部的默认 Logo。\n支持 PNG、JPG、GIF 格式，建议使用正方形图片以获得最佳显示效果。',
              style: TextStyle(
                fontSize: 12,
                color: AmberColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 选择并设置头像
  Future<void> _pickAndSetAvatar(BuildContext context, WidgetRef ref) async {
    try {
      // 打开文件选择器
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: false,
        withReadStream: false,
      );

      if (result == null || result.files.isEmpty) {
        return; // 用户取消选择
      }

      final filePath = result.files.first.path;
      if (filePath == null) {
        if (context.mounted) {
          ToastManager().show(context, '无法获取文件路径', type: ToastType.error);
        }
        return;
      }

      final sourceFile = File(filePath);
      if (!await sourceFile.exists()) {
        if (context.mounted) {
          ToastManager().show(context, '文件不存在', type: ToastType.error);
        }
        return;
      }

      // 检查文件大小（限制 5MB）
      final fileSize = await sourceFile.length();
      if (fileSize > 5 * 1024 * 1024) {
        if (context.mounted) {
          ToastManager().show(context, '图片文件过大，请选择小于 5MB 的图片', type: ToastType.warning);
        }
        return;
      }

      // 设置头像
      final savedPath = await ref.read(userProfileProvider.notifier).setAvatar(sourceFile);

      if (savedPath != null && context.mounted) {
        ToastManager().show(context, '头像设置成功', type: ToastType.success);
      } else if (context.mounted) {
        ToastManager().show(context, '头像设置失败', type: ToastType.error);
      }
    } catch (e) {
      if (context.mounted) {
        ToastManager().show(context, '选择图片失败: $e', type: ToastType.error);
      }
    }
  }

  /// 清除头像（恢复默认）
  Future<void> _clearAvatar(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(userProfileProvider.notifier).clearAvatar();
      if (context.mounted) {
        ToastManager().show(context, '已恢复默认 Logo', type: ToastType.info);
      }
    } catch (e) {
      if (context.mounted) {
        ToastManager().show(context, '操作失败: $e', type: ToastType.error);
      }
    }
  }
}
