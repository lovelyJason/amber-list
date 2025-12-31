import 'package:flutter/material.dart';
import '../../../../core/constants/constants.dart';
import '../widgets/settings_section.dart';
import '../widgets/settings_tile.dart';

/// 关于标签页
class AboutTab extends StatelessWidget {
  const AboutTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AmberDimens.spacingLg),
      children: [
        SettingsSection(
          title: '应用信息',
          children: [
            const SettingsTile(
              icon: Icons.info_outline,
              title: '版本',
              subtitle: '1.0.0',
            ),
            // SettingsTile(
            //   icon: Icons.code,
            //   title: '开源项目',
            //   subtitle: '在GitHub上查看源代码',
            //   onTap: () {
            //     // TODO: 打开GitHub链接
            //   },
            // ),
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
