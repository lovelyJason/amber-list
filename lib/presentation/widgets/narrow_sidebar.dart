import 'dart:async';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart'; // Import window_manager
import 'dart:io';

import '../../core/constants/constants.dart';
import '../providers/providers.dart';
import '../pages/settings/settings_page.dart';
import 'animated_logo.dart';
import 'mac_traffic_lights.dart';
import 'sync_conflict_dialog.dart';

/// 窄侧边栏（最左侧图标栏）
class NarrowSidebar extends ConsumerStatefulWidget {
  const NarrowSidebar({super.key});

  @override
  ConsumerState<NarrowSidebar> createState() => _NarrowSidebarState();
}

class _NarrowSidebarState extends ConsumerState<NarrowSidebar> {
  Timer? _hoverTimer;
  bool _showRefresh = false;

  @override
  void dispose() {
    _hoverTimer?.cancel();
    super.dispose();
  }

  void _handleHoverEnter(PointerEnterEvent event) {
    _hoverTimer?.cancel();
    _hoverTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showRefresh = true;
        });
      }
    });
  }

  void _handleHoverExit(PointerExitEvent event) {
    _hoverTimer?.cancel();
    if (_showRefresh) {
      setState(() {
        _showRefresh = false;
      });
    }
  }

  /// 处理日历点击 - 直接跳转到日历页面
  /// 未激活时日历页面会自己显示遮罩层和激活提示
  void _handleCalendarTap(BuildContext context, WidgetRef ref) {
    ref.read(appNavProvider.notifier).setView(NavView.calendar);
  }

  @override
  Widget build(BuildContext context) {
    final navState = ref.watch(appNavProvider);
    final isWindows = Platform.isWindows;

    return Container(
      width: AmberDimens.narrowSidebarWidth,
      color: AmberColors.narrowSidebarBackground,
      child: Column(
        children: [
          // Mac-style window controls (Traffic Lights)
          if (isWindows)
            SizedBox(
              height: 40,
              child: DragToMoveArea(
                child: Container(
                  padding: const EdgeInsets.only(top: 18),
                  alignment: Alignment.topCenter,
                  child: const MacTrafficLights(),
                ),
              ),
            )
          else
            // 顶部留出macOS窗口控制按钮的空间(红黄绿按钮约22px高)
            const SizedBox(
              height: AmberDimens.spacingXl + AmberDimens.spacingXs,
            ),
          // Logo/头像
          _buildLogo(),
          const SizedBox(height: AmberDimens.spacingLg),
          // 导航图标
          
          // 1. 清单/任务入口 (Lists) - 包含 Inbox, Today, Upcoming, Lists, All
          _buildNavItem(
            context,
            ref,
            icon:
                (navState.currentView == NavView.inbox ||
                    navState.currentView == NavView.today ||
                    navState.currentView == NavView.upcoming ||
                    navState.currentView == NavView.list ||
                    navState.currentView == NavView.all)
                ? FluentIcons.text_bullet_list_square_24_filled
                : FluentIcons.text_bullet_list_square_24_regular,
            tooltip: '清单',
            // 点击默认跳转到 Today，或者保持当前视图如果已经在这些视图中
            onTap: () {
              if (navState.currentView != NavView.inbox &&
                  navState.currentView != NavView.today &&
                  navState.currentView != NavView.upcoming &&
                  navState.currentView != NavView.list &&
                  navState.currentView != NavView.all) {
                ref.read(appNavProvider.notifier).setView(NavView.today);
              }
            },
            isSelected:
                navState.currentView == NavView.inbox ||
                navState.currentView == NavView.today ||
                navState.currentView == NavView.upcoming ||
                navState.currentView == NavView.list ||
                navState.currentView == NavView.all,
          ),

          // 2. 笔记 (Notes)
          _buildNavItem(
            context,
            ref,
            // 笔记 - 笔记本样式
            icon: navState.currentView == NavView.notes
                ? FluentIcons.notepad_24_filled
                : FluentIcons.notepad_24_regular,
            tooltip: '笔记',
            view: NavView.notes,
            isSelected: navState.currentView == NavView.notes,
          ),

          // 3. 日历 (Calendar) - 需要激活才能使用
          _buildNavItem(
            context,
            ref,
            icon: navState.currentView == NavView.calendar
                ? FluentIcons.calendar_ltr_24_filled
                : FluentIcons.calendar_ltr_24_regular,
            tooltip: '日历',
            isSelected: navState.currentView == NavView.calendar,
            onTap: () => _handleCalendarTap(context, ref),
          ),

          // 4. 番茄时钟 (Pomodoro)
          _buildNavItem(
            context,
            ref,
            icon: navState.currentView == NavView.pomodoro
                ? FluentIcons.timer_24_filled
                : FluentIcons.timer_24_regular,
            tooltip: '番茄时钟',
            view: NavView.pomodoro,
            isSelected: navState.currentView == NavView.pomodoro,
          ),
          const Spacer(),
          // 同步状态指示器
          _buildSyncIndicator(ref),
          const SizedBox(height: AmberDimens.spacingXs),
          // 设置按钮
          _buildNavItem(
            context,
            ref,
            icon: FluentIcons.settings_24_regular,
            tooltip: '设置',
            onTap: () {
              // 🔧 使用 Dialog 替代独立窗口，完全没有黑屏
              showDialog(
                context: context,
                barrierColor: Colors.black54,
                builder: (context) => Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding: const EdgeInsets.all(40),
                  child: Container(
                    width: 1000,
                    height: 700,
                    decoration: BoxDecoration(
                      color: AmberColors.background,
                      borderRadius: BorderRadius.circular(AmberDimens.radiusLg),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AmberDimens.radiusLg),
                      child: const SettingsPage(windowId: null),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AmberDimens.spacingMd),
        ],
      ),
    );
  }



  /// 同步状态指示器 - 显示在侧边栏底部
  Widget _buildSyncIndicator(WidgetRef ref) {
    final syncState = ref.watch(syncStateProvider);
    final isConfigured =
        ref.watch(syncConfigProvider) != null ||
        ref.watch(qiniuConfigProvider) != null;

    // 未配置同步 - 不显示
    if (!isConfigured) {
      return const SizedBox.shrink();
    }

    // 确定图标和颜色
    IconData icon;
    Color color;
    String tooltip;
    VoidCallback? onTap;

    if (syncState.isSyncing) {
      // 正在同步：显示加载圈
      icon = FluentIcons.arrow_sync_circle_24_regular;
      color = AmberColors.info;
      tooltip = '正在同步...';
    } else if (_showRefresh) {
      // 悬停显示刷新：显示刷新图标
      icon = FluentIcons.arrow_sync_24_regular; // 使用普通的刷新箭头
      color = AmberColors.textPrimary; // 颜色稍微深一点表示可点击
      tooltip = '点击立即同步';
      onTap = () async {
        // 点击后立即重置刷新图标状态（因为马上会变成 isSyncing）
        setState(() => _showRefresh = false);

        // 设置冲突决策回调（在同步过程中弹窗让用户选择）
        ref.read(syncStateProvider.notifier).onConflictDetected = (conflicts) async {
          if (!mounted) return null;
          // 弹出冲突决策弹窗
          return showSyncConflictDialog(context, conflicts: conflicts);
        };

        final success = await ref.read(syncStateProvider.notifier).manualSync();

        // 同步成功播放音效
        if (success && mounted) {
          ref.read(soundServiceProvider).playSuccess();
        }
      };
    } else if (syncState.lastError != null) {
      icon = FluentIcons.warning_24_regular;
      color = AmberColors.warning;
      tooltip = '同步失败: ${syncState.lastError}';
    } else if (syncState.lastSyncTime != null) {
      icon = FluentIcons.cloud_checkmark_24_regular;
      color = AmberColors.success;
      final timeAgo = _formatTimeAgo(syncState.lastSyncTime!);
      tooltip = '上次同步: $timeAgo';
    } else {
      icon = FluentIcons.cloud_24_regular;
      color = AmberColors.textSecondary;
      tooltip = '等待同步';
    }

    return MouseRegion(
      onEnter: _handleHoverEnter,
      onExit: _handleHoverExit,
      cursor: _showRefresh
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: Tooltip(
        message: tooltip,
        preferBelow: false,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.symmetric(vertical: AmberDimens.spacingXs),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
              color: _showRefresh && !syncState.isSyncing
                  ? Colors.black.withValues(alpha: 0.05) // 悬停刷新时加个淡背景
                  : Colors.transparent,
            ),
            child: syncState.isSyncing
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AmberColors.info,
                        ),
                      ),
                    ),
                  )
                : Icon(icon, size: AmberDimens.iconSizeLg, color: color),
          ),
        ),
      ),
    );
  }

  /// 格式化时间为 "xx分钟前"
  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    return '${diff.inDays}天前';
  }

  /// Logo - 琥珀中封存的昆虫
  Widget _buildLogo() {
    return Tooltip(
      message: '琥珀清单 - 封存万物,历久弥新',
      preferBelow: false,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
          boxShadow: [
            BoxShadow(
              color: AmberColors.primaryTransparent,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
          child: const AnimatedLogo(
            width: 40,
            height: 40,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    WidgetRef ref, {
    IconData? icon,
    Widget? customIcon,
    required String tooltip,
    NavView? view,
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    assert(icon != null || customIcon != null, 'Either icon or customIcon must be provided');

    return Tooltip(
      message: tooltip,
      preferBelow: false,
      waitDuration: const Duration(milliseconds: 500),
      child: InkWell(
        onTap: onTap ?? () {
          if (view != null) {
            ref.read(appNavProvider.notifier).setView(view);
          }
        },
        borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
        child: Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.symmetric(vertical: AmberDimens.spacingXs),
          decoration: BoxDecoration(
            color: isSelected ? AmberColors.primaryLight : Colors.transparent,
            borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
          ),
          child: Center( // 确保图标居中
            child: customIcon ?? Icon(
              icon,
              size: AmberDimens.iconSizeLg,
              color: isSelected ? AmberColors.primary : AmberColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }


}
