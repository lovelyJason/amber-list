import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/constants.dart';
import '../list_sidebar/list_sidebar.dart';
import '../animated_logo.dart';

/// 移动端抽屉侧边栏
/// 封装清单列表，在移动端以 Drawer 形式展示
///
/// 设计说明：
/// - 复用桌面端的 ListSidebar 组件内容
/// - 顶部显示 Logo 和应用名称
/// - 用户可以在这里切换清单、查看标签等
class DrawerListSidebar extends ConsumerWidget {
  const DrawerListSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      backgroundColor: AmberColors.sidebarBackground,
      child: SafeArea(
        child: Column(
          children: [
            // 抽屉顶部 - Logo 和标题
            _buildDrawerHeader(context),
            const Divider(height: 1, color: AmberColors.divider),
            // 清单列表（复用桌面端组件，抽屉模式）
            const Expanded(
              child: ListSidebar(inDrawer: true),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建抽屉头部
  Widget _buildDrawerHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AmberDimens.spacingMd,
        vertical: AmberDimens.spacingLg,
      ),
      child: Row(
        children: [
          // Logo
          const AnimatedLogo(width: 40, height: 40),
          const SizedBox(width: AmberDimens.spacingMd),
          // 标题
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '琥珀清单',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AmberColors.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Amber List',
                  style: TextStyle(
                    fontSize: 12,
                    color: AmberColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          // 关闭按钮
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.close,
              color: AmberColors.textSecondary,
            ),
            tooltip: '关闭',
          ),
        ],
      ),
    );
  }
}
