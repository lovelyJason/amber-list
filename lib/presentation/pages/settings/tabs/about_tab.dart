import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/constants/constants.dart';
import '../../../providers/app_update_provider.dart';
import '../../../widgets/app_update_dialog.dart';
import '../../../widgets/common/toast/toast_manager.dart';
import '../widgets/settings_section.dart';
import '../widgets/settings_tile.dart';

/// 关于标签页
class AboutTab extends ConsumerWidget {
  const AboutTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听更新状态
    final updateState = ref.watch(appUpdateProvider);

    return ListView(
      padding: const EdgeInsets.all(AmberDimens.spacingLg),
      children: [
        SettingsSection(
          title: '应用信息',
          children: [
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final versionText = snapshot.hasData
                    ? '${snapshot.data!.version} (${snapshot.data!.buildNumber})'
                    : 'Loading...';
                return SettingsTile(
                  icon: Icons.info_outline,
                  title: '版本',
                  subtitle: versionText,
                );
              },
            ),
            // 检查更新按钮
            SettingsTile(
              icon: Icons.system_update_outlined,
              title: '检查更新',
              subtitle: _getUpdateSubtitle(updateState),
              trailing: updateState.isChecking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AmberColors.primary,
                      ),
                    )
                  : (updateState.hasUpdate
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AmberColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '有更新',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : null),
              onTap: updateState.isChecking
                  ? null
                  : () => _checkForUpdates(context, ref),
            ),
            SettingsTile(
              icon: Icons.feedback_outlined,
              title: '反馈建议',
              subtitle: '遇到问题或有建议？告诉我们',
              onTap: () => _showFeedbackDialog(context),
            ),
            SettingsTile(
              icon: Icons.history,
              title: '更新日志',
              subtitle: '查看版本更新历史',
              onTap: () {
                // TODO: 打开更新日志
              },
            ),
            // 仅桌面端显示日志功能（移动端不写日志文件）
            if (Platform.isMacOS || Platform.isWindows || Platform.isLinux)
              SettingsTile(
                icon: Icons.article_outlined,
                title: '应用日志',
                subtitle: '查看运行日志，排查问题',
                onTap: () => _showLogOptionsDialog(context),
              ),
          ],
        ),
        const SizedBox(height: AmberDimens.spacingLg),
        SettingsSection(
          title: '支持开发',
          children: [
            SettingsTile(
              icon: Icons.favorite_outline,
              title: '请开发者喝杯咖啡',
              subtitle: '您的支持是我持续更新的动力',
              onTap: () => _showDonationDialog(context),
            ),
          ],
        ),
      ],
    );
  }

  /// 获取更新状态的副标题文案
  String _getUpdateSubtitle(AppUpdateState state) {
    if (state.isChecking) {
      return '正在检查...';
    }

    final result = state.lastCheckResult;
    if (result == null) {
      return '点击检查是否有新版本';
    }

    if (!result.success) {
      return '检查失败: ${result.error ?? "未知错误"}';
    }

    if (result.hasUpdate) {
      return '新版本 v${result.updateInfo?.latestVersion} 可用';
    }

    return '当前已是最新版本';
  }

  /// 检查更新
  Future<void> _checkForUpdates(BuildContext context, WidgetRef ref) async {
    final result = await ref.read(appUpdateProvider.notifier).checkForUpdates();

    if (!context.mounted) return;

    if (result.success && result.hasUpdate) {
      // 有更新，显示更新对话框
      AppUpdateDialog.show(
        context,
        result: result,
        isForceUpdate: result.isForceUpdate,
      );
    } else if (result.success && !result.hasUpdate) {
      // 已是最新版本，显示提示
      ToastManager().show(
        context,
        '当前已是最新版本',
        type: ToastType.success,
      );
    } else if (!result.success) {
      // 检查失败，显示错误
      ToastManager().show(
        context,
        '检查更新失败: ${result.error ?? "未知错误"}',
        type: ToastType.error,
      );
    }
  }

  /// 显示反馈弹窗
  void _showFeedbackDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AmberDimens.radiusLg),
        ),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(AmberDimens.spacingXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题
              const Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    color: AmberColors.primary,
                    size: 24,
                  ),
                  SizedBox(width: AmberDimens.spacingSm),
                  Text(
                    '反馈建议',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AmberDimens.spacingLg),

              // 文案
              const Text(
                '有任何问题或建议？\n添加微信好友，直接与我沟通\n我会认真倾听每一条反馈 💬',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: AmberColors.textSecondary,
                ),
              ),
              const SizedBox(height: AmberDimens.spacingLg),

              // 二维码
              Container(
                padding: const EdgeInsets.all(AmberDimens.spacingMd),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
                  border: Border.all(
                    color: AmberColors.divider,
                    width: 1,
                  ),
                ),
                child: Image.asset(
                  'assets/images/wechat-add.jpg',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: AmberDimens.spacingMd),

              // 提示文字
              const Text(
                '微信扫码添加好友',
                style: TextStyle(
                  fontSize: 12,
                  color: AmberColors.textDisabled,
                ),
              ),
              const SizedBox(height: AmberDimens.spacingLg),

              // 关闭按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext),
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
                  child: const Text('好的'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 获取日志目录路径
  String _getLogDirectory() {
    String home = '';
    if (Platform.isMacOS) {
      home = Platform.environment['HOME'] ?? '';
    } else if (Platform.isWindows) {
      home = Platform.environment['USERPROFILE'] ?? '';
    } else if (Platform.isLinux) {
      home = Platform.environment['HOME'] ?? '';
    }
    return '$home/amber-list/logs';
  }

  /// 显示日志选项弹窗
  void _showLogOptionsDialog(BuildContext context) {
    final logDir = _getLogDirectory();

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AmberDimens.radiusLg),
        ),
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(AmberDimens.spacingLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题
              const Row(
                children: [
                  Icon(
                    Icons.article_outlined,
                    color: AmberColors.primary,
                    size: 24,
                  ),
                  SizedBox(width: AmberDimens.spacingSm),
                  Text(
                    '应用日志',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AmberDimens.spacingSm),

              // 日志路径
              Container(
                padding: const EdgeInsets.all(AmberDimens.spacingSm),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AmberDimens.radiusSm),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.folder_outlined,
                      size: 16,
                      color: AmberColors.textSecondary,
                    ),
                    const SizedBox(width: AmberDimens.spacingXs),
                    Expanded(
                      child: Text(
                        logDir,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AmberColors.textSecondary,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AmberDimens.spacingMd),

              // 选项列表
              _LogOptionTile(
                icon: Platform.isMacOS ? Icons.folder_open : Icons.folder_open,
                title: Platform.isMacOS ? '在 Finder 中打开' : '在资源管理器中打开',
                subtitle: '打开日志文件夹',
                onTap: () {
                  Navigator.pop(dialogContext);
                  _openInFileManager(context, logDir);
                },
              ),
              _LogOptionTile(
                icon: Icons.code,
                title: '用 VS Code 打开',
                subtitle: '需要已安装 VS Code',
                onTap: () {
                  Navigator.pop(dialogContext);
                  _openInVSCode(context, logDir);
                },
              ),
              _LogOptionTile(
                icon: Icons.edit_note,
                title: '用系统编辑器打开',
                subtitle: Platform.isMacOS ? '使用 TextEdit 打开' : '使用记事本打开',
                onTap: () {
                  Navigator.pop(dialogContext);
                  _openInSystemEditor(context, logDir);
                },
              ),

              const SizedBox(height: AmberDimens.spacingMd),

              // 关闭按钮
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('取消'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 在文件管理器中打开日志目录
  Future<void> _openInFileManager(BuildContext context, String logDir) async {
    try {
      // 确保目录存在
      final dir = Directory(logDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      if (Platform.isMacOS) {
        await Process.run('open', [logDir]);
      } else if (Platform.isWindows) {
        await Process.run('explorer', [logDir.replaceAll('/', '\\')]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [logDir]);
      }
    } catch (e) {
      if (context.mounted) {
        ToastManager().show(context, '打开失败: $e', type: ToastType.error);
      }
    }
  }

  /// 用 VS Code 打开日志目录
  Future<void> _openInVSCode(BuildContext context, String logDir) async {
    try {
      // 确保目录存在
      final dir = Directory(logDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final result = await Process.run('code', [logDir], runInShell: true);

      if (result.exitCode != 0 && context.mounted) {
        ToastManager().show(
          context,
          '打开失败，请确认已安装 VS Code 并添加到 PATH',
          type: ToastType.warning,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ToastManager().show(
          context,
          '打开失败，请确认已安装 VS Code',
          type: ToastType.error,
        );
      }
    }
  }

  /// 用系统默认文本编辑器打开日志文件
  Future<void> _openInSystemEditor(BuildContext context, String logDir) async {
    try {
      // 确保目录存在
      final dir = Directory(logDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // 优先打开 warning.log，如果没有则打开 error.log
      final warningLog = File('$logDir/warning.log');
      final errorLog = File('$logDir/error.log');

      String? targetFile;
      if (await warningLog.exists()) {
        targetFile = warningLog.path;
      } else if (await errorLog.exists()) {
        targetFile = errorLog.path;
      } else {
        // 没有日志文件，创建一个空的 warning.log
        await warningLog.create();
        targetFile = warningLog.path;
      }

      if (Platform.isMacOS) {
        // macOS 使用 open -e 打开 TextEdit
        await Process.run('open', ['-e', targetFile]);
      } else if (Platform.isWindows) {
        // Windows 使用 notepad
        await Process.run('notepad', [targetFile.replaceAll('/', '\\')]);
      } else if (Platform.isLinux) {
        // Linux 使用 xdg-open
        await Process.run('xdg-open', [targetFile]);
      }
    } catch (e) {
      if (context.mounted) {
        ToastManager().show(context, '打开失败: $e', type: ToastType.error);
      }
    }
  }

  /// 显示捐赠弹窗
  void _showDonationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AmberDimens.radiusLg),
        ),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(AmberDimens.spacingXl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 标题
              const Row(
                children: [
                  Icon(
                    Icons.favorite,
                    color: Color(0xFFE94435), // 红心颜色
                    size: 24,
                  ),
                  SizedBox(width: AmberDimens.spacingSm),
                  Text(
                    '支持开发者',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AmberDimens.spacingLg),

              // 煽情文案
              const Text(
                '开发不易，维护更难\n如果这个应用对你有所帮助\n欢迎请我喝杯咖啡 ☕️',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: AmberColors.textSecondary,
                ),
              ),
              const SizedBox(height: AmberDimens.spacingLg),

              // 二维码
              Container(
                padding: const EdgeInsets.all(AmberDimens.spacingMd),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
                  border: Border.all(
                    color: AmberColors.divider,
                    width: 1,
                  ),
                ),
                child: Image.asset(
                  'assets/images/wechat-receive-code.jpg',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: AmberDimens.spacingMd),

              // 提示文字
              const Text(
                '微信扫一扫',
                style: TextStyle(
                  fontSize: 12,
                  color: AmberColors.textDisabled,
                ),
              ),
              const SizedBox(height: AmberDimens.spacingLg),

              // 关闭按钮
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext),
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
                  child: const Text('谢谢，下次一定'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 日志选项按钮组件
class _LogOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _LogOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AmberDimens.spacingSm,
          vertical: AmberDimens.spacingMd,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AmberColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AmberDimens.radiusSm),
              ),
              child: Icon(
                icon,
                color: AmberColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: AmberDimens.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AmberColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AmberColors.textDisabled,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
