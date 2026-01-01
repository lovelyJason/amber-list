import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import '../../../core/constants/constants.dart';
import '../../providers/providers.dart';

/// 移动端底部导航栏
/// 包含4个核心入口：清单、日历、笔记、番茄钟
///
/// 设计说明：
/// - 使用 BottomNavigationBar 实现标准的移动端导航
/// - "清单"入口统一管理收集箱、今天、各清单等任务视图
/// - 具体清单切换通过抽屉实现
/// - 选中项高亮显示琥珀主题色
class MobileBottomNavBar extends ConsumerWidget {
  const MobileBottomNavBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navState = ref.watch(appNavProvider);
    final currentIndex = _getNavIndex(navState.currentView);

    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) => _onNavTap(ref, index),
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
                ? FluentIcons.timer_24_filled
                : FluentIcons.timer_24_regular,
          ),
          label: '番茄钟',
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
      case NavView.pomodoro:
        return 3; // 番茄钟
    }
  }

  /// 底部导航栏点击处理
  void _onNavTap(WidgetRef ref, int index) {
    final views = [
      NavView.inbox, // 清单默认显示收集箱
      NavView.calendar,
      NavView.notes,
      NavView.pomodoro,
    ];
    ref.read(appNavProvider.notifier).setView(views[index]);
  }
}
