import 'package:flutter/material.dart';

import '../../../core/utils/responsive_helper.dart';
import 'bottom_nav_bar.dart';
import 'drawer_list_sidebar.dart';

/// 自适应脚手架
/// 统一处理桌面端和移动端的布局差异
///
/// 设计哲学：
/// - 桌面端（>=600px）：显示 desktopBody（Row布局，包含侧边栏等）
/// - 移动端（<600px）：显示 mobileBody + 底部导航栏 + 抽屉
///
/// 使用方式：
/// ```dart
/// AdaptiveScaffold(
///   desktopBody: Row(...), // 桌面端布局
///   mobileBody: TaskListView(...), // 移动端主内容
///   mobileAppBar: AppBar(...), // 移动端顶部栏
/// )
/// ```
class AdaptiveScaffold extends StatelessWidget {
  /// 桌面端布局（完整的 Row 布局，包含侧边栏等）
  final Widget desktopBody;

  /// 移动端主内容区（不包含导航）
  final Widget mobileBody;

  /// 移动端顶部 AppBar（可选）
  final PreferredSizeWidget? mobileAppBar;

  /// 移动端是否显示抽屉按钮
  final bool showDrawer;

  /// 移动端是否显示底部导航栏
  final bool showBottomNav;

  /// 移动端浮动按钮（可选）
  final Widget? floatingActionButton;

  const AdaptiveScaffold({
    super.key,
    required this.desktopBody,
    required this.mobileBody,
    this.mobileAppBar,
    this.showDrawer = true,
    this.showBottomNav = true,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    // 使用 LayoutBuilder 监听宽度变化
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < ResponsiveHelper.mobileBreakpoint;

        if (isMobile) {
          return _buildMobileScaffold(context);
        } else {
          return _buildDesktopScaffold(context);
        }
      },
    );
  }

  /// 构建桌面端布局（直接显示 desktopBody）
  Widget _buildDesktopScaffold(BuildContext context) {
    return Scaffold(
      body: desktopBody,
    );
  }

  /// 构建移动端布局（Scaffold + 底部导航 + 抽屉）
  Widget _buildMobileScaffold(BuildContext context) {
    return Scaffold(
      appBar: mobileAppBar,
      body: mobileBody,
      drawer: showDrawer ? const DrawerListSidebar() : null,
      bottomNavigationBar: showBottomNav ? const MobileBottomNavBar() : null,
      floatingActionButton: floatingActionButton,
    );
  }
}
