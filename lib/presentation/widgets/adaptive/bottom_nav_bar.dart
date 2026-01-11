import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../../../core/constants/constants.dart';
import '../../providers/providers.dart';

/// 移动端底部导航栏
/// 包含4个核心入口：清单、日历、笔记、更多
///
/// 设计说明：
/// - 使用 BottomNavigationBar 实现标准的移动端导航
/// - "清单"入口统一管理收集箱、今天、各清单等任务视图
/// - 具体清单切换通过抽屉实现
/// - "更多"入口弹出菜单，包含番茄钟、统计等功能
/// - 选中项高亮显示琥珀主题色
class MobileBottomNavBar extends ConsumerWidget {
  const MobileBottomNavBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navState = ref.watch(appNavProvider);
    final currentIndex = _getNavIndex(navState.currentView);

    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) => _onNavTap(context, ref, index),
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AmberColors.primary,
      unselectedItemColor: AmberColors.textSecondary,
      backgroundColor: AmberColors.cardBackground,
      selectedFontSize: 11,
      unselectedFontSize: 11,
      elevation: 8,
      items: [
        BottomNavigationBarItem(
          icon: Icon(
            currentIndex == 0
                ? FluentIcons.task_list_ltr_24_filled
                : FluentIcons.task_list_ltr_24_regular,
          ),
          label: '清单',
        ),
        BottomNavigationBarItem(
          icon: Icon(
            currentIndex == 1
                ? FluentIcons.calendar_ltr_24_filled
                : FluentIcons.calendar_ltr_24_regular,
          ),
          label: '日历',
        ),
        BottomNavigationBarItem(
          icon: Icon(
            currentIndex == 2
                ? FluentIcons.document_24_filled
                : FluentIcons.document_24_regular,
          ),
          label: '笔记',
        ),
        BottomNavigationBarItem(
          icon: Icon(
            currentIndex == 3
                ? FluentIcons.more_horizontal_24_filled
                : FluentIcons.more_horizontal_24_regular,
          ),
          label: '更多',
        ),
      ],
    );
  }

  /// 根据当前视图获取底部导航栏索引
  int _getNavIndex(NavView view) {
    switch (view) {
      // 所有任务相关视图都归到"清单"
      case NavView.inbox:
      case NavView.today:
      case NavView.upcoming:
      case NavView.all:
      case NavView.list:
      case NavView.completed:
      case NavView.trash:
        return 0; // 清单
      case NavView.calendar:
        return 1; // 日历
      case NavView.notes:
        return 2; // 笔记
      // 番茄钟和统计在"更多"菜单里
      case NavView.pomodoro:
      case NavView.statistics:
        return 3; // 更多
    }
  }

  /// 底部导航栏点击处理
  void _onNavTap(BuildContext context, WidgetRef ref, int index) {
    if (index == 3) {
      // 点击"更多"按钮，弹出菜单
      _showMoreMenu(context, ref);
    } else {
      final views = [
        NavView.inbox, // 清单默认显示收集箱
        NavView.calendar,
        NavView.notes,
      ];
      ref.read(appNavProvider.notifier).setView(views[index]);
    }
  }

  /// 显示"更多"菜单
  void _showMoreMenu(BuildContext context, WidgetRef ref) {
    final navState = ref.read(appNavProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: AmberColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 番茄钟
              _buildMenuItem(
                context,
                ref,
                icon: navState.currentView == NavView.pomodoro
                    ? FluentIcons.timer_24_filled
                    : FluentIcons.timer_24_regular,
                label: '番茄钟',
                isSelected: navState.currentView == NavView.pomodoro,
                onTap: () {
                  Navigator.pop(context);
                  ref.read(appNavProvider.notifier).setView(NavView.pomodoro);
                },
              ),
              // 统计
              _buildMenuItem(
                context,
                ref,
                icon: navState.currentView == NavView.statistics
                    ? FluentIcons.data_bar_vertical_24_filled
                    : FluentIcons.data_bar_vertical_24_regular,
                label: '统计',
                isSelected: navState.currentView == NavView.statistics,
                onTap: () {
                  Navigator.pop(context);
                  ref.read(appNavProvider.notifier).setView(NavView.statistics);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建菜单项
  Widget _buildMenuItem(
    BuildContext context,
    WidgetRef ref, {
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AmberColors.primary : AmberColors.textSecondary,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? AmberColors.primary : AmberColors.textPrimary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check, color: AmberColors.primary, size: 20)
          : null,
      onTap: onTap,
    );
  }
}
