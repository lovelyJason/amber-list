import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/constants.dart';
import '../../providers/providers.dart';

/// 智能清单组件
/// 包含收集箱、今天、最近7天等智能视图的渲染
class SidebarSmartLists {
  /// 垃圾桶图标的 GlobalKey（用于获取位置做删除动画）
  static final GlobalKey trashIconKey = GlobalKey();

  /// 构建智能清单项
  static Widget buildSmartListItem(
    BuildContext context,
    WidgetRef ref, {
    IconData? icon,
    Widget? customIcon,
    required String title,
    required NavView view,
    required bool isSelected,
    GlobalKey? itemKey,
  }) {
    return Padding(
      key: itemKey,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? AmberColors.primary.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: ListTile(
          dense: true,
          selected: isSelected,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          leading: customIcon ??
              Icon(
                icon,
                size: 20,
                color:
                    isSelected ? AmberColors.primary : AmberColors.textPrimary,
              ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: AmberColors.textPrimary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          onTap: () {
            ref.read(appNavProvider.notifier).setView(view);
          },
        ),
      ),
    );
  }

  /// 构建"今天"图标（显示当前日期）
  static Widget buildTodayIcon(bool isSelected) {
    final now = DateTime.now();
    final day = now.day.toString();
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          isSelected
              ? FluentIcons.calendar_ltr_24_filled
              : FluentIcons.calendar_ltr_24_regular,
          size: 20,
          color: isSelected ? AmberColors.primary : AmberColors.textPrimary,
        ),
        Positioned(
          top: 6,
          child: Text(
            day,
            style: TextStyle(
              fontSize: day.length > 1 ? 8 : 9,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : AmberColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  /// 构建"最近7天"图标
  static Widget buildUpcomingIcon(bool isSelected) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          isSelected
              ? FluentIcons.calendar_work_week_24_filled
              : FluentIcons.calendar_work_week_24_regular,
          size: 20,
          color: isSelected ? AmberColors.primary : AmberColors.textPrimary,
        ),
        Positioned(
          top: 6,
          child: Text(
            '7',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : AmberColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
