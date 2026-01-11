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
import 'common/toast/toast_manager.dart';
import 'mac_traffic_lights.dart';
import 'sync_conflict_dialog.dart';

/// 窄侧边栏（最左侧图标栏）
class NarrowSidebar extends ConsumerStatefulWidget {
  const NarrowSidebar({super.key});

  @override
  ConsumerState<NarrowSidebar> createState() => _NarrowSidebarState();
}

class _NarrowSidebarState extends ConsumerState<NarrowSidebar> {
  /// 鼠标是否悬浮在同步指示器上
  bool _isSyncHovered = false;

  @override
  void dispose() {
    super.dispose();
  }

  /// 同步指示器悬浮进入
  void _handleHoverEnter(PointerEnterEvent event) {
    setState(() => _isSyncHovered = true);
  }

  /// 同步指示器悬浮离开
  void _handleHoverExit(PointerExitEvent event) {
    setState(() => _isSyncHovered = false);
  }

  /// 处理日历点击 - 直接跳转到日历页面
  /// 未激活时日历页面会自己显示遮罩层和激活提示
  void _handleCalendarTap(BuildContext context, WidgetRef ref) {
    ref.read(appNavProvider.notifier).setView(NavView.calendar);
  }

  /// 判断当前视图是否属于任务列表相关视图
  /// 包括：收集箱、今天、最近7天、自定义清单、全部、已完成、垃圾桶
  bool _isTaskListView(NavView view) {
    return view == NavView.inbox ||
        view == NavView.today ||
        view == NavView.upcoming ||
        view == NavView.list ||
        view == NavView.all ||
        view == NavView.completed ||
        view == NavView.trash;
  }

  @override
  Widget build(BuildContext context) {
    final navState = ref.watch(appNavProvider);
    final displaySettings = ref.watch(displaySettingsProvider);
    final isWindows = Platform.isWindows;
    // Windows 下根据用户设置决定是否显示红绿灯
    final showTrafficLights = isWindows && !displaySettings.useNativeTitleBar;

    return Container(
      width: AmberDimens.narrowSidebarWidth,
      color: AmberColors.narrowSidebarBackground,
      child: Column(
        children: [
          // Mac-style window controls (Traffic Lights)
          // Windows: 仅在使用 macOS 风格时显示红绿灯
          // macOS: 系统原生红绿灯，这里只留空间
          if (showTrafficLights)
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
          else if (isWindows && displaySettings.useNativeTitleBar)
            // Windows 原生标题栏模式：不需要额外留空间
            const SizedBox(height: AmberDimens.spacingSm)
          else
            // macOS/Linux：顶部留出系统窗口控制按钮的空间(红黄绿按钮约22px高)
            const SizedBox(
              height: AmberDimens.spacingXl + AmberDimens.spacingXs,
            ),
          // Logo/头像
          _buildLogo(),
          const SizedBox(height: AmberDimens.spacingLg),
          // 导航图标
          
          // 1. 清单/任务入口 (Lists) - 包含所有任务相关视图
          // 已完成和垃圾桶也属于任务列表范畴，需要高亮清单图标
          _buildNavItem(
            context,
            ref,
            icon: _isTaskListView(navState.currentView)
                ? FluentIcons.text_bullet_list_square_24_filled
                : FluentIcons.text_bullet_list_square_24_regular,
            tooltip: '清单',
            // 点击默认跳转到 Today，或者保持当前视图如果已经在任务列表视图中
            onTap: () {
              if (!_isTaskListView(navState.currentView)) {
                ref.read(appNavProvider.notifier).setView(NavView.today);
              }
            },
            isSelected: _isTaskListView(navState.currentView),
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

          // 5. 统计 (Statistics)
          _buildNavItem(
            context,
            ref,
            icon: navState.currentView == NavView.statistics
                ? FluentIcons.data_histogram_24_filled
                : FluentIcons.data_histogram_24_regular,
            tooltip: '统计',
            view: NavView.statistics,
            isSelected: navState.currentView == NavView.statistics,
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
  ///
  /// 交互设计：
  /// - 右下角始终显示小刷新角标，提示用户可点击同步
  /// - 悬浮时背景高亮，鼠标变成手型
  /// - 点击触发同步
  Widget _buildSyncIndicator(WidgetRef ref) {
    final syncState = ref.watch(syncStateProvider);
    final syncType = ref.watch(syncTypeProvider);

    // 未配置同步 - 不显示
    if (syncType == null) {
      return const SizedBox.shrink();
    }

    // 确定主图标和颜色
    IconData icon;
    Color color;
    String tooltip;

    if (syncState.isSyncing) {
      icon = FluentIcons.cloud_sync_24_regular;
      color = AmberColors.info;
      tooltip = '正在同步...';
    } else if (syncState.lastError != null) {
      icon = FluentIcons.cloud_dismiss_24_regular;
      color = AmberColors.warning;
      tooltip = '同步失败: ${syncState.lastError}\n点击重试';
    } else if (syncState.lastSyncTime != null) {
      icon = FluentIcons.cloud_checkmark_24_regular;
      color = AmberColors.success;
      final timeAgo = _formatTimeAgo(syncState.lastSyncTime!);
      tooltip = '上次同步: $timeAgo\n点击立即同步';
    } else {
      icon = FluentIcons.cloud_24_regular;
      color = AmberColors.textSecondary;
      tooltip = '等待同步\n点击立即同步';
    }

    // 点击同步的回调
    Future<void> handleSync() async {
      if (syncState.isSyncing) return;

      // 设置冲突决策回调
      ref.read(syncStateProvider.notifier).onConflictDetected = (
        conflicts, {
        int autoPostponeMergedCount = 0,
      }) async {
        if (!mounted) return null;
        return showSyncConflictDialog(
          context,
          conflicts: conflicts,
          autoPostponeMergedCount: autoPostponeMergedCount,
        );
      };

      // 设置首次同步冲突回调（检测到双端都有数据时弹窗）
      ref.read(syncStateProvider.notifier).onFirstSyncConflict = (conflict) async {
        if (!mounted) return null;
        return showFirstSyncConflictDialog(
          context,
          localTaskCount: conflict.localTaskCount,
          remoteVersion: conflict.remoteVersion,
          remoteDevice: conflict.remoteDevice,
          remoteLastSync: conflict.remoteLastSync,
        );
      };

      final success = await ref.read(syncStateProvider.notifier).manualSync();

      // 同步成功播放音效
      if (success && mounted) {
        ref.read(soundServiceProvider).playSuccess();
      } else if (!success && mounted) {
        // 同步失败，检查错误信息并提示
        final syncState = ref.read(syncStateProvider);
        final errorMsg = syncState.lastError ?? '同步失败';

        // 针对 429 错误特殊处理
        if (errorMsg.contains('429')) {
          ToastManager().show(
            context,
            '请求太频繁，请稍后再试',
            type: ToastType.warning,
          );
        } else {
          ToastManager().show(
            context,
            errorMsg,
            type: ToastType.error,
          );
        }
      }
    }

    return MouseRegion(
      onEnter: _handleHoverEnter,
      onExit: _handleHoverExit,
      cursor: syncState.isSyncing
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: Tooltip(
        message: tooltip,
        preferBelow: false,
        child: GestureDetector(
          onTap: handleSync,
          child: Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.symmetric(vertical: AmberDimens.spacingXs),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
              color: _isSyncHovered && !syncState.isSyncing
                  ? Colors.black.withValues(alpha: 0.08)
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
                : _buildSyncIconWithBadge(icon, color),
          ),
        ),
      ),
    );
  }

  /// 构建带刷新角标的云图标
  ///
  /// 悬浮时右下角显示小刷新图标，提示用户可以点击同步
  Widget _buildSyncIconWithBadge(IconData mainIcon, Color mainColor) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // 主图标（云）
        Icon(mainIcon, size: AmberDimens.iconSizeLg, color: mainColor),
        // 悬浮时显示右下角刷新角标
        if (_isSyncHovered)
          Positioned(
            right: 2,
            bottom: 2,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: AmberColors.sidebarBackground,
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(
                FluentIcons.arrow_sync_12_regular,
                size: 10,
                color: AmberColors.primary,
              ),
            ),
          ),
      ],
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

  /// Logo/头像 - 显示用户自定义头像或默认的琥珀 Logo
  /// 点击弹出下拉菜单，包含设置入口
  Widget _buildLogo() {
    final profile = ref.watch(userProfileProvider);

    return PopupMenuButton<String>(
      tooltip: '',
      offset: const Offset(50, 0), // 菜单显示在头像右侧
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AmberDimens.radiusMd),
      ),
      color: AmberColors.cardBackground,
      elevation: 8,
      onSelected: (value) {
        if (value == 'settings') {
          // 打开设置弹窗
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
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'settings',
          height: 40,
          child: Row(
            children: [
              Icon(
                FluentIcons.settings_24_regular,
                size: 18,
                color: AmberColors.textPrimary,
              ),
              const SizedBox(width: AmberDimens.spacingSm),
              const Text(
                '设置',
                style: TextStyle(
                  fontSize: 14,
                  color: AmberColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
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
          child: profile.hasCustomAvatar
              ? Image.file(
                  File(profile.avatarPath!),
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // 图片加载失败，显示默认 Logo
                    return const AnimatedLogo(
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    );
                  },
                )
              : const AnimatedLogo(
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
